allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Injeksi dependensi concurrent-futures ke camera_android_camerax agar class
    // CallbackToFutureAdapter ditemukan saat kompilasi Java di Gradle 9.x.
    if (project.name == "camera_android_camerax") {
        plugins.withId("com.android.library") {
            dependencies {
                add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
            }
        }
    }

    // tflite_flutter 0.12.1 mengompilasi Java ke target 11, sedangkan Kotlin
    // bawaan memakai JVM terbaru → samakan target Kotlin ke 11 (Tahap D).
    if (project.name == "tflite_flutter") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
