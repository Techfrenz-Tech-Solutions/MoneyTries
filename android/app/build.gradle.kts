plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.greenvault"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Required for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.greenvault"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            // NOTE: still using the debug signingConfig here, same as
            // before — not changed by this fix. It's not the cause of
            // the "release APK gets no push" issue (FCM delivery itself
            // doesn't check the app's signing key/SHA-1 — that only
            // matters for Firebase Auth, Dynamic Links, and App Check /
            // Play Integrity, none of which this app uses). It DOES
            // matter before a real Play Store submission, though: create
            // a dedicated release keystore, reference it via a
            // signingConfigs { create("release") { ... } } block plus an
            // untracked key.properties file, and register its SHA-1/
            // SHA-256 (`keytool -list -v -keystore your.jks`) as a
            // second Android app fingerprint in Firebase Console >
            // Project settings > Your apps — the debug fingerprint can
            // stay registered alongside it.

            // Currently false (unchanged) — see proguard-rules.pro for
            // the keep rules to use if/when this is switched on for a
            // production shrink.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {

    // Required by flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Android SplashScreen compatibility
    implementation("androidx.core:core-splashscreen:1.0.1")
}