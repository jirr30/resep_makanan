-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**
-keep class com.resepku.resep_makanan.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Auth + Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Firestore
-keep class com.google.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Keep model classes from obfuscation (Firestore serialization)
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
