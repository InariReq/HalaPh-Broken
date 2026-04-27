allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

buildscript {
    extra.set("kotlin.version", "2.0.21")
}

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
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate

        try {
            val getNamespace = androidExtension.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            }
            val currentNamespace = getNamespace?.invoke(androidExtension) as? String
            if (!currentNamespace.isNullOrBlank()) return@afterEvaluate

            val setNamespace = androidExtension.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            } ?: return@afterEvaluate

            val fallbackNamespace = if (project.group.toString().isNotBlank() &&
                project.group.toString() != "unspecified"
            ) {
                project.group.toString()
            } else {
                "com.example.${project.name.replace("-", "_")}"
            }
            setNamespace.invoke(androidExtension, fallbackNamespace)
        } catch (_: Throwable) {
            // Ignore reflection fallback failures; plugins with proper namespace are unaffected.
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
