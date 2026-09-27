import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config from key.properties (if present) or environment variables.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

fun signingProp(propName: String, envName: String): String? =
    keyProperties.getProperty(propName) ?: System.getenv(envName)

android {
    namespace = "com.glassmail.dev.glassmail"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.glassmail.dev.glassmail"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 34
        targetSdk = 35
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = signingProp("storeFile", "GLASSMAIL_KEYSTORE")
            val storePass    = signingProp("storePassword", "GLASSMAIL_KEYSTORE_PASSWORD")
            val keyAlias_    = signingProp("keyAlias", "GLASSMAIL_KEY_ALIAS")
            val keyPass      = signingProp("keyPassword", "GLASSMAIL_KEY_PASSWORD")

            if (storeFilePath != null && storePass != null && keyAlias_ != null && keyPass != null) {
                storeFile      = file(storeFilePath)
                storePassword  = storePass
                keyAlias       = keyAlias_
                keyPassword    = keyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Shrinking / obfuscation disabled for v1; enable when ProGuard rules are tuned.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
