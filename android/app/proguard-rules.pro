
# HalaPH Android release fix.
# Keep Gson TypeToken generic signatures for flutter_local_notifications.
# Without this, R8 can strip the generic Signature metadata and Android release APK
# can fail when scheduling/canceling notifications.
-keepattributes Signature
-keepattributes *Annotation*

-keep,allowobfuscation,allowshrinking,allowoptimization class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking,allowoptimization class * extends com.google.gson.reflect.TypeToken

-dontwarn com.google.gson.**
