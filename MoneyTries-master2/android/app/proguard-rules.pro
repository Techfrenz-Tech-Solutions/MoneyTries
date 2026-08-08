# android/app/proguard-rules.pro
#
# minifyEnabled/shrinkResources are currently OFF for the release build
# type (see app/build.gradle.kts), so R8 does not run and none of this is
# active yet — these rules are not the fix for the current "release APK
# gets no push" issue (that's the hardcoded LAN base URL in
# push_repository.dart). This file exists so that the moment minification
# IS turned on (e.g. before a Play Store submission, to shrink the APK),
# FCM/local-notifications keep working instead of breaking silently from
# R8 stripping or renaming classes it can't see are used via reflection.

# Firebase Cloud Messaging / Firebase Installations — reflection-based
# model classes and the FirebaseMessagingService itself.
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.installations.** { *; }
-keep class com.google.firebase.iid.** { *; }
-dontwarn com.google.firebase.**

# flutter_local_notifications — uses reflection to deserialize scheduled
# notification data across app restarts/reboots.
-keep class com.dexterous.** { *; }

# Gson is used internally by flutter_local_notifications for the above.
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep the app's own background message handler entry point — it's only
# referenced from Dart via @pragma('vm:entry-point'), which R8 can't see.
-keep class io.flutter.plugins.firebase.messaging.** { *; }