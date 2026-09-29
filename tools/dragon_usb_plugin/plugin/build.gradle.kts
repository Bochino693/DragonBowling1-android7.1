import org.jetbrains.kotlin.gradle.dsl.JvmTarget
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.lazersport.dragon.usbserial"
    compileSdk = 36
    buildFeatures { buildConfig = true }
    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = "DragonUsbSerial"
        manifestPlaceholders["godotPluginPackageName"] = "com.lazersport.dragon.usbserial"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }
}
dependencies {
    compileOnly("org.godotengine:godot:4.6.1.stable")
    implementation("com.github.mik3y:usb-serial-for-android:3.11.0")
}
