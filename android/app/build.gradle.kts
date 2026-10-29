@file:Suppress("DEPRECATION", "DEPRECATION_ERROR")

import java.io.File
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Apply the Flutter Gradle Plugin after the Android application plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

val releaseStorePath = signingProperties.getProperty("storeFile")
val releaseStoreFile: File? = releaseStorePath?.let { rootProject.file(it) }
val releaseSigningConfigured = listOf(
    "keyAlias",
    "keyPassword",
    "storePassword",
).all {
    val value = signingProperties.getProperty(it)
    !value.isNullOrBlank() && value != "CHANGE_ME"
} &&
    releaseStoreFile?.isFile == true

android {
    namespace = "com.example.check_in_go"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.check_in_go"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = maxOf(flutter.targetSdkVersion, 36)
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigningConfigured) {
        signingConfigs.create("release") {
            keyAlias = signingProperties.getProperty("keyAlias")
            keyPassword = signingProperties.getProperty("keyPassword")
            storeFile = releaseStoreFile
            storePassword = signingProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val requestsReleaseBuild = allTasks.any { it.name.contains("Release", ignoreCase = true) }
    if (requestsReleaseBuild && !releaseSigningConfigured) {
        throw GradleException(
            "Release signing is not configured. Create android/key.properties " +
                "from android/key.properties.example and add your private keystore."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
