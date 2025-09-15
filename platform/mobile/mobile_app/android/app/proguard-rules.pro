# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep our application classes
-keep class com.echowright.app.** { *; }

# Firebase (if using)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to hide the original source file name
-renamesourcefileattribute SourceFile

# Prevent stripping of methods/fields referenced via reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Preserve Kotlin metadata
-keep class kotlin.Metadata { *; }

# OkHttp and Retrofit (commonly used networking libraries)
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-dontwarn okio.**