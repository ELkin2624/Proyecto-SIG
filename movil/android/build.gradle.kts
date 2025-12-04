// movil/android/build.gradle.kts
buildscript {
    // En Kotlin definimos variables con val, no con ext.
    val kotlin_version = "1.7.20"
    
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Asegúrate de que esta versión de gradle coincida con la que tenías
        classpath("com.android.tools.build:gradle:8.1.0")
        // Aquí usamos la variable definida arriba
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        // El plugin de Google Services para Firebase
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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