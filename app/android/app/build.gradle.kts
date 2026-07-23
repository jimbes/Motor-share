plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.besse.redl"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.besse.redl"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("redlRelease") {
            // A fixed, checked-in keystore (not a production/Play-Store key)
            // so every CI build - each running on a fresh, otherwise-random
            // debug keystore - is signed identically. Without this, each
            // GitHub Actions run signs with a different auto-generated
            // debug key and Android refuses to install the "update" over
            // the previous release.
            storeFile = file("../redl-release.keystore")
            storePassword = "redl-poc-signing"
            keyAlias = "redl"
            keyPassword = "redl-poc-signing"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("redlRelease")
        }
    }
}

flutter {
    source = "../.."
}
