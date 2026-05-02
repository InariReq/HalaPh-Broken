plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun readMapsApiKeyFromDotEnv(): String {
    val envFile = listOf(
        rootProject.file("../.env"),
        rootProject.file(".env"),
    ).firstOrNull { it.exists() } ?: return ""

    val key = envFile.readLines()
        .asSequence()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") }
        .firstOrNull { it.startsWith("MAPS_API_KEY=") }
        ?.substringAfter("=")
        ?.trim()
        ?.removeSurrounding("\"")
        ?.removeSurrounding("'")
        .orEmpty()

    return key
}

val mapsApiKey = System.getenv("MAPS_API_KEY")
    ?.takeIf { it.isNotBlank() }
    ?: readMapsApiKeyFromDotEnv()

android {
    namespace = "com.halaph.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.halaph.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Load release signing config from environment or keystore
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: ""
            val keystorePw = System.getenv("KEYSTORE_PASSWORD") ?: ""
            val envKeyAlias = System.getenv("KEY_ALIAS") ?: ""
            val keyPw = System.getenv("KEY_PASSWORD") ?: ""

            if (keystorePath.isNotEmpty() && keystorePw.isNotEmpty()) {
                storeFile = file(keystorePath)
                storePassword = keystorePw
                keyAlias = envKeyAlias
                keyPassword = keyPw
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (System.getenv("KEYSTORE_PATH") != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
