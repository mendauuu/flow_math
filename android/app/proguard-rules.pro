# Scheduled reminders: flutter_local_notifications stores them with Gson,
# which needs generic type info that R8 would otherwise strip.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
