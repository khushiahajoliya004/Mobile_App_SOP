## Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Google Play Core (referenced by Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

## Dio / OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

## Gson / JSON
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

## App classes
-keep class com.callrecorder.call_recorder_app.** { *; }

## AudioPlayers
-keep class xyz.luan.audioplayers.** { *; }

## Record plugin
-keep class com.llfbandit.record.** { *; }

## Permission handler
-keep class com.baseflow.permissionhandler.** { *; }

## Flutter foreground task
-keep class com.pravera.flutter_foreground_task.** { *; }

## Shared preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

## Path provider
-keep class io.flutter.plugins.pathprovider.** { *; }

## General
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
