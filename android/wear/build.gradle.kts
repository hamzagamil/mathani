import java.util.Properties

// The Wear OS app (specs/017 research R6): the same applicationId and signing key as the phone
// app, so the Data Layer pairs them and Play keeps both in one listing.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// One version source: `version: 1.10.0+36` in pubspec.yaml. The watch's versionCode is the
// phone's plus 1 000 000, so the two never collide in Play.
val pubspecVersion = Regex("""(?m)^version:\s*([^+\s]+)\+(\d+)""")
    .find(rootProject.file("../pubspec.yaml").readText())
    ?: error("No version in pubspec.yaml")

android {
    namespace = "app.mathani.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mthani.app"
        // Wear OS 3 and later.
        minSdk = 30
        targetSdk = 36
        versionCode = 1_000_000 + pubspecVersion.groupValues[2].toInt()
        versionName = pubspecVersion.groupValues[1]
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                // The same upload key as the phone app (key.properties gives an absolute path).
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }

    buildFeatures { compose = true }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.08.00"))
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.wear.compose:compose-material:1.5.0")
    implementation("androidx.wear.compose:compose-foundation:1.5.0")
    implementation("androidx.wear.tiles:tiles:1.5.0")
    implementation("androidx.wear.protolayout:protolayout:1.3.0")
    implementation("androidx.concurrent:concurrent-futures-ktx:1.2.0")
    implementation("androidx.wear.watchface:watchface-complications-data-source-ktx:1.2.1")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
