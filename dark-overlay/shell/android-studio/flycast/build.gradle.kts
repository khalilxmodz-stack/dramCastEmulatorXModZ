plugins {
    alias(libs.plugins.android.application)
}

fun gitVersionName(): String {
    // Falls back to a fixed name when building from a source archive without git metadata
    return try {
        providers.exec {
            commandLine("git", "describe", "--tags", "--always")
        }.standardOutput.asText.get().trim()
    } catch (e: Exception) {
        "dark-dev"
    }
}

android {
    namespace = "com.flycast.emulator"
    ndkVersion = "29.0.14206865"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        // Different from the upstream id so "Flycast Dark" installs next to the original Flycast.
        // The Java/JNI package (namespace above) is intentionally unchanged: native code looks up
        // classes such as com/flycast/emulator/emu/LocaleUtils by that name.
        applicationId = "com.flycast.emulator.dark"
        minSdk = 21
        targetSdk = 36
        versionCode = 8
        versionName = gitVersionName()
        vectorDrawables.useSupportLibrary = true

        // 32-bit ARM only. Every native dependency is built by the CMake project for this ABI.
        ndk {
            abiFilters += "armeabi-v7a"
        }

        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_ARM_MODE=arm"
                arguments += "-DSENTRY_UPLOAD_URL=" + (System.getenv("SENTRY_UPLOAD_URL") ?: "")
                arguments += "-DUSE_OPENMP=OFF"
                arguments += "-DANDROID_WEAK_API_DEFS=ON"
            }
        }

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("../debug.keystore")
        }
        create("release") {
            storeFile = file("../playstore.jks")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            keyAlias = "uploadkey"
            keyPassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Release keystore only when its password is provided; otherwise sign with the
            // repository's debug keystore so CI/local builds produce an installable APK without secrets.
            signingConfig = if (System.getenv("ANDROID_KEYSTORE_PASSWORD") != null)
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    externalNativeBuild {
        cmake {
            path = file("../../../CMakeLists.txt")
            version = "3.22.1"
        }
    }
    packaging {
        jniLibs {
            // not used
            excludes += "lib/*/libz.so"
            // This is necessary for libadrenotools custom driver loading
            useLegacyPackaging = true
        }
        resources {
            excludes += "META-INF/DEPENDENCIES"
        }
    }
}

dependencies {
    implementation(libs.appcompat)
    implementation(libs.commons.lang3)
    implementation(libs.httpclient5)
    implementation(libs.slf4j.android)
    implementation(fileTree("libs") { include("*.aar", "*.jar") })
    implementation(libs.documentfile)
    testImplementation(libs.junit)
    androidTestImplementation(libs.espresso.core)
    androidTestImplementation(libs.ext.junit)
}