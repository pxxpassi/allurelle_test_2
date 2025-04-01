import os
import cv2
import time
import numpy as np
from flask import Flask, request, jsonify, send_file
from ultralytics import YOLO
from werkzeug.utils import secure_filename
from flask_cors import CORS
import json
import pandas as pd

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes
app.config['MAX_CONTENT_LENGTH'] = 32 * 1024 * 1024  # 32MB upload limit

# Set upload and processed image paths (overwrite files instead of storing multiple)
UPLOAD_FOLDER = "uploads"
PROCESSED_FOLDER = "processed"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(PROCESSED_FOLDER, exist_ok=True)

UPLOAD_PATH = os.path.join(UPLOAD_FOLDER, "uploadedimage.jpg")
PROCESSED_PATH = os.path.join(PROCESSED_FOLDER, "processedimage.jpg")

# Load multiple YOLO models
MODEL_PATHS = {
    "Acne": "acnenew.pt",
    "Dark Spots": "spots_model.pt",
    "Wrinkles": "wrinkles_model.pt"
}

# Map detected skin conditions to skincare concerns
SKIN_CONCERN_MAPPING = {
    "Acne": "acne",
    "Dark Spots": "hyperpigmentation",
    "Wrinkles": "wrinkles"
}

CONFIDENCE_THRESHOLDS = {
    "Acne": 0.10,
    "Dark Spots": 0.40,
    "Wrinkles": 0.40
}

SKIN_CONCERN_TO_INGREDIENTS = {
    "acne": ["salicylic acid", "benzoyl peroxide", "tea tree oil"],
    "dryness": ["hyaluronic acid", "glycerin", "ceramides"],
    "wrinkles": ["retinol", "peptides", "vitamin c"],
    "redness": ["centella", "niacinamide", "aloe vera"],
    "hyperpigmentation": ["vitamin c", "alpha arbutin", "kojic acid"],
    "oily_skin": ["niacinamide", "clay", "salicylic acid"],
    "sensitive_skin": ["aloe vera", "chamomile", "oat extract"],
    "large_pores": ["salicylic acid", "glycolic acid", "niacinamide"]
}


models = {}
for label, path in MODEL_PATHS.items():
    try:
        models[label] = YOLO(path)
        print(f"{label} model loaded successfully")
    except Exception as e:
        print(f"Error loading {label} model: {e}")

# Load skincare products dataset
PRODUCTS_CSV = "cosmetics.csv"  # Ensure this file exists
if os.path.exists(PRODUCTS_CSV):
    df_products = pd.read_csv(PRODUCTS_CSV)
else:
    df_products = pd.DataFrame()  # Empty DataFrame to avoid crashes

# Image preprocessing
def preprocess_image(image):
    """Enhance image for better skin analysis."""
    try:
        lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)

        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        cl = clahe.apply(l)

        enhanced_lab = cv2.merge([cl, a, b])
        enhanced_bgr = cv2.cvtColor(enhanced_lab, cv2.COLOR_LAB2BGR)

        return enhanced_bgr
    except Exception as e:
        print(f"Error in image preprocessing: {e}")
        return image
    

def recommend_products(detected_issues, skin_type):
    """Generate product recommendations based on detected skin issues and skin type."""
    if df_products.empty:
        return {"error": "Product database not loaded"}

    recommended = {}

    for category in ["Cleanser", "Eye Cream", "Face Mask", "Moisturizer", "Sun Protect", "Treatment"]:
        # Filter products by category
        category_products = df_products[df_products["Label"].str.lower() == category.lower()]

        # Filter by skin type suitability
        if skin_type in ["Combination", "Dry", "Normal", "Oily", "Sensitive"]:
            category_products = category_products[category_products[skin_type] == 1]

        # Score products based on ingredient matching
        if "Ingredients" in category_products.columns:
            category_products["Match_Score"] = category_products["Ingredients"].apply(
                lambda x: sum(ing in x.lower() for issue in detected_issues 
                              for ing in SKIN_CONCERN_TO_INGREDIENTS.get(issue.lower(), []))
            )
        else:
            category_products["Match_Score"] = 0  # Default if no ingredients column

        # Sort by Match Score and Rank
        category_products = category_products.sort_values(by=["Match_Score", "Rank"], ascending=[False, False])

        category_products = category_products.head(2)

        # Select the top product for this category
        if not category_products.empty:
            best_product = category_products.iloc[0]
            recommended[category] = {
                "Name": str(best_product["Name"]),
                "Brand": str(best_product["Brand"]),
                "Price": float(best_product["Price"]),
                "Rank": float(best_product["Rank"])
            }

    return recommended


def detect_skin_issues():
    if not models:
        return None, {"error": "Models not loaded"}

    try:
        original_img = cv2.imread(UPLOAD_PATH)
        if original_img is None:
            return None, {"error": "Failed to load image"}

        enhanced_img = preprocess_image(original_img)
        detected_issues = []
        colors = {"Acne": (255, 0, 0), "Dark Spots": (0, 255, 0), "Wrinkles": (0, 0, 255)}

        all_boxes = []

        # Run each model separately and collect bounding boxes
        for label, model in models.items():
            img_copy = enhanced_img.copy()
            results = model(img_copy)

            for result in results:
                if not hasattr(result, "boxes") or result.boxes is None:
                    continue  # Skip if no boxes detected

                boxes = result.boxes.xyxy.cpu().numpy() if result.boxes.xyxy is not None else []
                confidences = result.boxes.conf.cpu().numpy() if result.boxes.conf is not None else []
                classes = result.boxes.cls.cpu().numpy() if result.boxes.cls is not None else []

                if len(boxes) == 0:
                    continue  # Skip empty results

                for box, confidence, cls in zip(boxes, confidences, classes):
                    threshold = CONFIDENCE_THRESHOLDS.get(label, 0.20)  # Default to 0.50 if not found

                    if confidence > threshold:  # ✅ Apply class-specific threshold
                        x1, y1, x2, y2 = map(int, box)
                        all_boxes.append((x1, y1, x2, y2, label, int(cls), confidence, colors[label]))

        # Apply Weighted NMS
        final_boxes = weighted_nms(all_boxes)

        # Draw bounding boxes and collect detected issues
        for (x1, y1, x2, y2, label, cls, confidence, color) in final_boxes:
            cv2.rectangle(enhanced_img, (x1, y1), (x2, y2), color, 2)
            issue_label = f"{label} ({confidence:.2f})"
            detected_issues.append({"label": issue_label, "bbox": [x1, y1, x2, y2], "confidence": confidence})
            cv2.putText(enhanced_img, issue_label, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        cv2.imwrite(PROCESSED_PATH, enhanced_img)

        if not detected_issues:
            return PROCESSED_PATH, {"message": "No significant skin issues detected"}

        return PROCESSED_PATH, detected_issues
    except Exception as e:
        return None, {"error": str(e)}


def weighted_nms(boxes, iou_threshold=0.4):
    """Applies Weighted Non-Maximum Suppression (WNMS) to retain overlapping detections."""
    if not boxes:
        return []

    boxes = sorted(boxes, key=lambda x: x[6], reverse=True)  # Sort by confidence
    keep_boxes = []

    while boxes:
        chosen_box = boxes.pop(0)
        keep_boxes.append(chosen_box)

        filtered_boxes = []
        for b in boxes:
            if compute_iou(chosen_box, b) < iou_threshold or chosen_box[4] != b[4]:  # Different label keeps both
                filtered_boxes.append(b)
        
        boxes = filtered_boxes  # Update list with non-overlapping boxes

    return keep_boxes

def compute_iou(box1, box2):
    """Computes Intersection-over-Union (IoU) for two bounding boxes."""
    x1, y1, x2, y2 = max(box1[0], box2[0]), max(box1[1], box2[1]), min(box1[2], box2[2]), min(box1[3], box2[3])
    inter_area = max(0, x2 - x1) * max(0, y2 - y1)
    box1_area = (box1[2] - box1[0]) * (box1[3] - box1[1])
    box2_area = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union_area = box1_area + box2_area - inter_area
    return inter_area / union_area if union_area > 0 else 0


@app.route("/analyze", methods=["POST"])
def analyze_image():
    """API Endpoint to receive an image, process it, and return results."""
    print("Received image analysis request")

    if "image" not in request.files:
        return jsonify({"error": "No image file provided"}), 400

    file = request.files["image"]

    try:
        # Overwrite the uploaded image
        file.save(UPLOAD_PATH)

        processed_path, issues = detect_skin_issues()

        if processed_path is None:
            return jsonify(issues), 500  # Issues contains error details

        # Construct URL for processed image
        base_url = request.host_url.rstrip("/")
        processed_image_url = f"{base_url}/get_processed?t={int(time.time())}"  # Add timestamp to prevent caching

        return json.dumps({
            "message": "Analysis complete",
            "issues_detected": issues if isinstance(issues, list) else [],
            "processed_image_url": processed_image_url,
        }, default=lambda x: float(x) if isinstance(x, np.float32) else x), 200, {"Content-Type": "application/json"}

    except Exception as e:
        print(f"❌ Error analyzing image: {e}")
        return jsonify({"error": "Server error"}), 500

@app.route('/recommend', methods=['POST'])
def recommender_products():
    """Receives detected issues and returns skincare recommendations."""
    print("Received recommendations request")
    try:
        data = request.get_json()
        detected_issues = data.get("detectedIssues", [])
        skin_type = data.get("skinType")

        print(skin_type)

        recommendations = recommend_products(detected_issues, skin_type)
        return jsonify({"recommendedProducts": recommendations}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Serve latest processed image
@app.route("/get_processed", methods=["GET"])
def get_processed_image():
    """Endpoint to serve processed image."""
    if not os.path.exists(PROCESSED_PATH):
        return jsonify({"error": "Processed image not found"}), 404
    return send_file(PROCESSED_PATH, mimetype="image/jpeg")


# Run Flask app
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000, use_reloader=False)
