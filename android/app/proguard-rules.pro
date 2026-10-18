# ML Kit Text Recognition optional language modules
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google_mlkit_text_recognition.**
-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google_mlkit_commons.**
-keep class com.google_mlkit_commons.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }

# Speech to text
-dontwarn com.csdcorp.speech_to_text.**
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Flutter Local Notifications & Gson (Required for Scheduled Notifications)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.** { *; }
-keepclassmembers class * extends com.google.gson.TypeAdapter {
    public <init>(...);
}
-keepclassmembers enum * { *; }
-dontwarn com.dexterous.**
-dontwarn com.google.gson.**

