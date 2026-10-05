plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

val releaseStorePath = providers.environmentVariable("GLASSMAIL_RELEASE_STORE_FILE").orNull
    ?: providers.gradleProperty("glassmailReleaseStoreFile").orNull
val releaseStorePassword = providers.environmentVariable("GLASSMAIL_RELEASE_STORE_PASSWORD").orNull
    ?: providers.gradleProperty("glassmailReleaseStorePassword").orNull
val releaseKeyAlias = providers.environmentVariable("GLASSMAIL_RELEASE_KEY_ALIAS").orNull
    ?: providers.gradleProperty("glassmailReleaseKeyAlias").orNull
val releaseKeyPassword = providers.environmentVariable("GLASSMAIL_RELEASE_KEY_PASSWORD").orNull
    ?: providers.gradleProperty("glassmailReleaseKeyPassword").orNull
val releaseSigningConfigured = listOf(releaseStorePath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword).all { !it.isNullOrBlank() }

val requireReleaseSigning = providers.environmentVariable("GLASSMAIL_REQUIRE_RELEASE_SIGNING").orNull
    ?.equals("true", ignoreCase = true) == true ||
    providers.gradleProperty("glassmailRequireReleaseSigning").orNull
        ?.equals("true", ignoreCase = true) == true

// Gate artifact-producing tasks, not release compilation used by test/lint.
gradle.taskGraph.whenReady {
    val buildsReleaseArtifact = allTasks.any {
        it.project.path == project.path &&
            it.name in setOf(
                "assembleRelease", "bundleRelease", "packageRelease", "packageReleaseBundle",
                "signReleaseBundle", "validateSigningRelease"
            )
    }
    if (requireReleaseSigning && buildsReleaseArtifact && !releaseSigningConfigured) {
        throw GradleException(
            "Release signing is required but inputs are incomplete. Set all four " +
                "GLASSMAIL_RELEASE_STORE_FILE, GLASSMAIL_RELEASE_STORE_PASSWORD, " +
                "GLASSMAIL_RELEASE_KEY_ALIAS, and GLASSMAIL_RELEASE_KEY_PASSWORD " +
                "environment variables (or their glassmailRelease* Gradle properties)."
        )
    }
}

android {
    namespace = "com.glassmail.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.glassmail.app"
        minSdk = 34
        targetSdk = 35
        versionCode = 10000
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (releaseSigningConfigured) signingConfig = signingConfigs.getByName("release")
        }
    }

    packaging {
        resources.excludes += "/META-INF/NOTICE.md"
        resources.excludes += "/META-INF/LICENSE.md"
    }
}

dependencies {
    implementation(project(":core:model"))
    implementation(project(":core:database"))
    implementation(project(":core:imap"))
    implementation(project(":core:security"))
    implementation(project(":domain:mail"))
    implementation(project(":data:mail"))
    implementation(project(":sync"))
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(project(":designsystem:glass"))
    implementation(project(":designsystem"))
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.work.runtime.ktx)

    testImplementation(libs.junit)
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    testImplementation("io.mockk:mockk:1.13.8")
    testImplementation(libs.androidx.room.runtime)
}
