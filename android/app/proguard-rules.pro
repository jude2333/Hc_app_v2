# Flutter default rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter deferred components but not used)
-dontwarn com.google.android.play.core.**

# open_filex
-dontwarn com.crazecoder.openfile.**
-keep class com.crazecoder.openfile.** { *; }
