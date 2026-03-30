plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Cargokit設定
apply(from = "../../cargokit/gradle/plugin.gradle")

// Cargokitの拡張プロパティを設定（相対パスで指定）
extensions.configure<Any>("cargokit") {
    this.javaClass.getMethod("setManifestDir", String::class.java).invoke(this, "../../rust")
    this.javaClass.getMethod("setLibname", String::class.java).invoke(this, "rust")
}

android {
    namespace = "jp.godzhigella.meiso"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    flavorDimensions += "channel"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "jp.godzhigella.meiso"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    productFlavors {
        create("production") {
            dimension = "channel"
            applicationId = "jp.godzhigella.meiso"
            resValue("string", "app_name", "Meiso")
        }
        create("beta") {
            dimension = "channel"
            applicationId = "jp.godzhigella.meiso.beta"
            resValue("string", "app_name", "Meiso Beta")
            ndk {
                abiFilters += "arm64-v8a"
            }
        }
    }

    buildTypes {
        release {
            // Zapstore v1.1.9 で debug keystore (SHA256: ba94cf06...) で公開済み。
            // 署名を変更すると既存ユーザーがアップデートできなくなるため、
            // production flavor も debug keystore を維持する。
            // Zapstore 向けビルドは必ずローカルで行うこと (CI の debug keystore は別物)。
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// Cargokit設定
// プラグインは上でapply済み
// cargokitは自動的に設定を読み取ります
