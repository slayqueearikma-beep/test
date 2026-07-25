# Flutter wrapper
-keep class io.flutter.** { *; }

# Flutter references Play Core deferred-component APIs that this app does not use.
# Without these rules, R8 fails minifyRelease with "Missing class com.google.android.play.core.*".
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
