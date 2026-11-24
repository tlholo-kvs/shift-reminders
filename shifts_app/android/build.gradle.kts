allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val localAppData = System.getenv("LOCALAPPDATA")
val buildCacheRoot = if (localAppData != null) {
    rootProject.layout.projectDirectory.dir("$localAppData/flutter-build/shift-reminders")
} else {
    rootProject.layout.projectDirectory.dir("../../build")
}
val newBuildDir: Directory = buildCacheRoot
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)?.let {
            it.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
