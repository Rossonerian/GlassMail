plugins { alias(libs.plugins.android.test); alias(libs.plugins.kotlin.android) }

android {
    namespace = "com.glassmail.benchmark"; compileSdk = 35; targetProjectPath = ":app"
    defaultConfig { minSdk = 34; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
}
kotlin { jvmToolchain(17) }
dependencies { implementation(libs.androidx.benchmark.macro); implementation(libs.androidx.test.ext.junit) }
