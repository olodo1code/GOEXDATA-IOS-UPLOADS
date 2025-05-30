// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'splash_screen.dart';

// // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// //   await Firebase.initializeApp();
// //   print("Handling a background message: ${message.messageId}");
// //   print("Background message data: ${message.data}");
// //   if (message.notification != null) {
// //     print("Background message notification: ${message.notification?.title}");
// //   }
// // }

// // void main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //   await Firebase.initializeApp();

// //   FirebaseMessaging messaging = FirebaseMessaging.instance;

// //   NotificationSettings settings = await messaging.requestPermission(
// //     alert: true,
// //     badge: true,
// //     sound: true,
// //     provisional: false,
// //   );
// //   if (settings.authorizationStatus == AuthorizationStatus.authorized) {
// //     print('Notification permission granted');
// //   } else {
// //     print('Notification permission denied');
// //   }

// //   String? token = await messaging.getToken();
// //   print('FCM Token: $token');

// //   try {
// //     await messaging.subscribeToTopic('webdroidx_topic');
// //     print('Subscribed to webdroidx_topic');
// //   } catch (e) {
// //     print('Error subscribing to topic: $e');
// //   }

// //   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
// //     print('Got a message whilst in the foreground!');
// //     print('Message data: ${message.data}');
// //     if (message.notification != null) {
// //       print(
// //           'Message also contained a notification: ${message.notification?.title}');
// //     }
// //   });

// //   RemoteMessage? initialMessage = await messaging.getInitialMessage();
// //   if (initialMessage != null) {
// //     print('App opened from terminated state by notification');
// //     print('Initial message data: ${initialMessage.data}');
// //   }

// //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
// //     print('Message opened app: ${message.data}');
// //   });

// //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// //   runApp(const MyApp());
// // }

// // class MyApp extends StatelessWidget {

// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print("Handling a background message: ${message.messageId}");
//   print("Background message data: ${message.data}");
//   if (message.notification != null) {
//     print("Background message notification: ${message.notification?.title}");
//   }
// }

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();

//   // Register the background message handler early
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//   FirebaseMessaging messaging = FirebaseMessaging.instance;

//   NotificationSettings settings = await messaging.requestPermission(
//     alert: true,
//     badge: true,
//     sound: true,
//     provisional: false,
//   );
//   if (settings.authorizationStatus == AuthorizationStatus.authorized) {
//     print('Notification permission granted');
//   } else {
//     print('Notification permission denied');
//   }

//   String? token = await messaging.getToken();
//   print('FCM Token: $token');

//   try {
//     await messaging.subscribeToTopic('webdroidx_topic');
//     print('Subscribed to webdroidx_topic');
//   } catch (e) {
//     print('Error subscribing to topic: $e');
//   }

//   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//     print('Got a message whilst in the foreground!');
//     print('Message data: ${message.data}');
//     if (message.notification != null) {
//       print(
//           'Message also contained a notification: ${message.notification?.title}');
//     }
//   });

//   RemoteMessage? initialMessage = await messaging.getInitialMessage();
//   if (initialMessage != null) {
//     print('App opened from terminated state by notification');
//     print('Initial message data: ${initialMessage.data}');
//     // Handle navigation or data processing based on the initialMessage
//   }

//   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
//     print('Message opened app: ${message.data}');
//     // Handle navigation or data processing based on the message that opened the app
//   });

//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: ThemeData(
//         primaryColor: const Color.fromARGB(255, 3, 10, 73),
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'splash_screen.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Check if Firebase is already initialized to prevent duplicate initialization
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
      print("Firebase initialized in background handler");
    } catch (e) {
      print("Error initializing Firebase in background handler: $e");
    }
  }

  print("Handling a background message: ${message.messageId}");
  print("Background message data: ${message.data}");
  if (message.notification != null) {
    print("Background message notification: ${message.notification?.title}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted');
    } else {
      print('Notification permission denied');
    }

    String? token = await messaging.getToken();
    print('FCM Token: $token');

    try {
      await messaging.subscribeToTopic('webdroidx_topic');
      print('Subscribed to webdroidx_topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print(
            'Message also contained a notification: ${message.notification?.title}');
      }
    });

    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from terminated state by notification');
      print('Initial message data: ${initialMessage.data}');
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened app: ${message.data}');
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 3, 10, 73),
      ),
      home: const SplashScreen(),
    );
  }
}
