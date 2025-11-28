plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// --- HER SKAL KODEN VÆRE ---
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties") // Bemærk: rootProject.file leder i app-mappen, når vi er i app-modulet i denne kontekst, eller vi kan bruge 'file("key.properties")' direkte hvis den ligger i app mappen.
// For at være helt sikker på stien, da du lagde den i app-mappen:
if (file("key.properties").exists()) {
    keystoreProperties.load(java.io.FileInputStream(file("key.properties")))
} else if (rootProject.file("key.properties").exists()) {
     // Fallback hvis du flyttede den tilbage
    keystoreProperties.load(java.io.FileInputStream(rootProject.file("key.properties")))
}
// ----------------------------

android {
    namespace = "com.example.gendo"
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
        applicationId = "com.example.gendo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = if (keystoreProperties["storeFile"] != null) file(keystoreProperties["storeFile"] as String) else null
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true 
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}