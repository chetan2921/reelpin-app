import java.io.File
import java.util.Properties
import org.gradle.api.GradleException
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read Google Maps API key from local.properties (gitignored)
val localProps = Properties()
val localPropsFile = rootProject.file("local.properties")
if (localPropsFile.exists()) {
    localProps.load(localPropsFile.inputStream())
}

fun readSimpleConfigValue(file: File, key: String): String? {
    if (!file.exists()) return null

    return file.useLines { lines ->
        lines
            .map(String::trim)
            .filter { line ->
                line.isNotEmpty() &&
                    !line.startsWith("#") &&
                    line.contains("=")
            }
            .map { line ->
                val separator = line.indexOf('=')
                line.substring(0, separator).trim() to
                    line.substring(separator + 1).trim()
            }
            .firstOrNull { (parsedKey, value) ->
                parsedKey == key && value.isNotEmpty()
            }
            ?.second
    }
}

val mapsApiKey: String =
    localProps.getProperty("MAPS_API_KEY")?.trim().takeUnless { it.isNullOrEmpty() }
        ?: readSimpleConfigValue(rootProject.file("../assets/config/local.env"), "MAPS_API_KEY")
        ?: readSimpleConfigValue(rootProject.file("../ios/Flutter/Secrets.xcconfig"), "MAPS_API_KEY")
        ?: ""

val requestedTasks = gradle.startParameter.taskNames.map(String::lowercase)
val isReleaseBuildRequested = requestedTasks.any { "release" in it }
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
} else if (isReleaseBuildRequested) {
    throw GradleException(
        "Missing android/key.properties for release build. Add keyAlias, keyPassword, storeFile, and storePassword before building a Play Store bundle.",
    )
}

val hasGoogleServicesConfig = listOf(
    "google-services.json",
    "src/debug/google-services.json",
    "src/release/google-services.json",
).map(::file).any { it.exists() }

if (hasGoogleServicesConfig) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.chetanjain.reelpin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.chetanjain.reelpin"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    if (hasReleaseKeystore) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
