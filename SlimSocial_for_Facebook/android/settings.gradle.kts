pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    // 2.x is required by in_app_purchase_android 0.5.0, which calls
    // KotlinAndroidProjectExtension.compilerOptions -- absent from KGP 1.x, so
    // the build failed inside that plugin's own build script. 2.2.20 is the
    // floor Flutter 3.44.8 asks for; anything lower builds but warns.
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
