pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "GlassMail"
include(
    ":app",
    ":core:model",
    ":core:security",
    ":core:database",
    ":core:imap",
    ":domain:mail",
    ":data:mail",
    ":sync",
    ":designsystem",
    ":designsystem:glass",
    ":benchmark",
)
