allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // flutter_jailbreak_detection depends on rootbeer 0.1.0 (JitPack), whose prebuilt
    // libtoolChecker.so is only 4 KB page aligned — Google Play rejects the bundle with
    // "Your app does not support 16 KB memory page sizes". rootbeer-lib 0.1.2 (Maven
    // Central, same API) ships 16 KB aligned binaries.
    configurations.all {
        resolutionStrategy.dependencySubstitution {
            substitute(module("com.github.scottyab:rootbeer"))
                .using(module("com.scottyab:rootbeer-lib:0.1.2"))
                .because("rootbeer 0.1.0 native lib is not 16 KB page aligned")
        }
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
