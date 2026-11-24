allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application") version "9.3.2" apply false
    id("com.google.gms.google-services") version "4.5.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
}

// Standard Flutter project layout: Gradle writes into the top-level build/
// folder, where `flutter build apk` / `appbundle` look for the output.
// Without this the APK landed in android/app/build/ and Flutter reported
// "Gradle build failed to produce an .apk file" after a successful build.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

