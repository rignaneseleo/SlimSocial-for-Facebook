plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "it.rignanese.leo.slim"
    compileSdk = 36

    defaultConfig {
        applicationId = "it.rignanese.leo.slimfacebook"
        minSdk = 24
        targetSdk = 36
        versionCode = 117
        versionName = "26.05.03+117"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    flavorDimensions += "store"
    productFlavors {
        create("full") {
            dimension = "store"
            buildConfigField("boolean", "IS_FULL_FLAVOR", "true")
            // SECRET — empty default for dev/local builds; CI injects via env.
            buildConfigField(
                "String",
                "SENTRY_DSN",
                "\"${System.getenv("SENTRY_DSN") ?: ""}\""
            )
        }
        create("fdroid") {
            dimension = "store"
            buildConfigField("boolean", "IS_FULL_FLAVOR", "false")
            // No SENTRY_DSN field in this flavor — only src/full references it.
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
        unitTests.isIncludeAndroidResources = true
    }

    lint {
        // Phase 11 ports ~70 keys × 42 locales from Flutter JSON. Many
        // legacy locale files don't carry every new Kotlin-port key; the
        // English fallback covers them at runtime, so demote
        // MissingTranslation from error to warning rather than dropping the
        // affected strings.
        warning += "MissingTranslation"
        // Likewise extra translations in old locale files (keys that no
        // longer exist in the canonical en-US.json) are informational only.
        warning += "ExtraTranslation"
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")

    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.navigation:navigation-compose:2.8.4")

    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("androidx.webkit:webkit:1.15.0")
    implementation("androidx.browser:browser:1.8.0")

    implementation("com.google.accompanist:accompanist-permissions:0.36.0")

    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // Proprietary deps — only land in the `full` (Play Store) flavor so the
    // F-Droid APK contains zero Sentry / Billing / Review classes.
    "fullImplementation"("io.sentry:sentry-android:7.+")
    "fullImplementation"("com.android.billingclient:billing-ktx:7.+")
    "fullImplementation"("com.google.android.play:review-ktx:2.+")

    testImplementation("org.junit.jupiter:junit-jupiter:5.11.3")
    testImplementation("io.kotest:kotest-assertions-core:5.9.1")
    testImplementation("app.cash.turbine:turbine:1.1.0")
    testImplementation("io.mockk:mockk:1.13.13")
    testImplementation("org.robolectric:robolectric:4.13")
    testImplementation("androidx.test:core-ktx:1.6.1")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")

    // JUnit4 + Vintage engine — Robolectric WebView tests run on JUnit4
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.junit.vintage:junit-vintage-engine:5.11.3")
}

tasks.withType<Test> {
    useJUnitPlatform()
}
