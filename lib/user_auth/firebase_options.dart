// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;


/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if  (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCC0C6u6tvcguoJmNFTg8ZasPSDctSyIt8',
    appId: '1:209405482210:web:ab3e2412f8d956b78afabb',
    messagingSenderId: '209405482210',
    projectId: 'allurelle-68a9d',
    authDomain: 'allurelle-68a9d.firebaseapp.com',
    storageBucket: 'allurelle-68a9d.appspot.com',
    measurementId: 'G-43LXC8FMY4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6TU1vnbMf7Id8ZjvxKPg--WdIGv38qbc',
    appId: '1:209405482210:android:776e9cc403b07f668afabb',
    messagingSenderId: '209405482210',
    projectId: 'allurelle-68a9d',
    storageBucket: 'allurelle-68a9d.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDF6hmRD7h-3vD1nU2WxnMAqIoF5BXWHuY',
    appId: '1:209405482210:ios:618e66fe74eb5f9c8afabb',
    messagingSenderId: '209405482210',
    projectId: 'allurelle-68a9d',
    storageBucket: 'allurelle-68a9d.appspot.com',
    iosBundleId: 'com.example.allurelleTest2',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDF6hmRD7h-3vD1nU2WxnMAqIoF5BXWHuY',
    appId: '1:209405482210:ios:618e66fe74eb5f9c8afabb',
    messagingSenderId: '209405482210',
    projectId: 'allurelle-68a9d',
    storageBucket: 'allurelle-68a9d.appspot.com',
    iosBundleId: 'com.example.allurelleTest2',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCC0C6u6tvcguoJmNFTg8ZasPSDctSyIt8',
    appId: '1:209405482210:web:f2412bb5f9cfc6f68afabb',
    messagingSenderId: '209405482210',
    projectId: 'allurelle-68a9d',
    authDomain: 'allurelle-68a9d.firebaseapp.com',
    storageBucket: 'allurelle-68a9d.appspot.com',
    measurementId: 'G-9R9PS1N2GR',
  );
}
