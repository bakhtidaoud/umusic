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
}

subprojects {
    val project = this
    if (project.name != "app") {
        try {
            project.evaluationDependsOn(":app")
        } catch (e: Exception) {}
    }

    val applyAndroidFix = {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                // Set compileOptions to Java 17
                val baseExtension = project.extensions.getByType(com.android.build.gradle.BaseExtension::class.java)
                baseExtension.compileOptions.apply {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }

                // Set Kotlin JVM target to 17
                project.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
                    compilerOptions {
                        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget("17"))
                    }
                }

                // Set namespace if missing
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val currentNamespace = getNamespace.invoke(android)
                    if (currentNamespace == null) {
                        val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                        val fixedNamespace = "com.umusic.fixed." + project.name.replace("-", ".")
                        setNamespace.invoke(android, fixedNamespace)
                    }
                } catch (e: Exception) {}
            }
        }
    }

    if (project.state.executed) {
        applyAndroidFix()
    } else {
        project.afterEvaluate {
            applyAndroidFix()
        }
    }

    // Silence "source value 8 is obsolete" and other compiler warnings
    tasks.withType<JavaCompile> {
        options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-unchecked", "-Xlint:-deprecation"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
