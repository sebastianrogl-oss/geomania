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
        // Von flutter_local_notifications ab Version 10 verlangt — ohne
        // diesen Schalter bricht schon der Debug-Build ab:
        // "Dependency ':flutter_local_notifications' requires core library
        // desugaring to be enabled for :app".
        //
        // Desugaring bildet neuere Java-APIs (hier vor allem java.time, das
        // das Plugin für die Zeitzonen-Behandlung geplanter Benachrichtigungen
        // braucht) auf älteren Android-Versionen nach. Nötig unabhängig davon,
        // ob die App geplante Benachrichtigungen nutzt.
        isCoreLibraryDesugaringEnabled = true
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
    // Die Bibliothek zum Desugaring, siehe isCoreLibraryDesugaringEnabled
    // oben. Version wie in der Anleitung des Plugins angegeben.
    //
    // Die Anleitung nennt zusätzlich multiDexEnabled = true. Das ist hier
    // nicht nötig: minSdk steht auf 24, und ab minSdk 21 schaltet das
    // Android-Gradle-Plugin Multidex von sich aus ein.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // play-services-ads-api (AdMob) zieht transitiv eine veraltete
    // androidx.work:work-runtime:2.7.0 herein, die mit den übrigen
    // (neueren) AndroidX-Bibliotheken im Projekt kollidiert und im
    // Release-Build beim Start mit "Failed to create an instance of
    // androidx.work.impl.WorkDatabase" abstürzt — explizite neuere Version
    // erzwingen behebt den Versionskonflikt.
    implementation("androidx.work:work-runtime:2.9.1")
}
