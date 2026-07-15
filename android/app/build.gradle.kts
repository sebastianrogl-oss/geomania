import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release-Signierschlüssel: liegt bewusst außerhalb der Versionskontrolle
// (siehe .gitignore) und wird hier eingelesen, damit `flutter build apk
// --release` nicht mehr mit dem Debug-Keystore signiert. Fehlt die Datei,
// bricht der Build sofort mit einer klaren Meldung ab statt später mit
// einem kryptischen Gradle-Fehler tief in der Signing-Task.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    throw GradleException(
        "android/key.properties fehlt. Für den Release-Build wird diese Datei mit " +
            "storePassword, keyPassword, keyAlias und storeFile benötigt " +
            "(siehe android/app/geomania-release-key.jks)."
    )
}

android {
    namespace = "com.northlight.geomania"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.northlight.geomania"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
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

dependencies {
    // play-services-ads-api (AdMob) zieht transitiv eine veraltete
    // androidx.work:work-runtime:2.7.0 herein, die mit den übrigen
    // (neueren) AndroidX-Bibliotheken im Projekt kollidiert und im
    // Release-Build beim Start mit "Failed to create an instance of
    // androidx.work.impl.WorkDatabase" abstürzt — explizite neuere Version
    // erzwingen behebt den Versionskonflikt.
    implementation("androidx.work:work-runtime:2.9.1")
}
