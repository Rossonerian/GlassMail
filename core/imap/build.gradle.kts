plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(project(":core:model"))
    implementation(project(":domain:mail"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.android.mail)
    implementation(libs.android.activation)
    testImplementation(libs.junit)
}
