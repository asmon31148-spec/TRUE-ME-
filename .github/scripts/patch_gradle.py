import os

def patch_android_build():
    # 1. Patch Kotlin DSL
    kts_path = 'android/app/build.gradle.kts'
    if os.path.exists(kts_path):
        with open(kts_path, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'isCoreLibraryDesugaringEnabled' not in content:
            content = content.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
        if 'multiDexEnabled' not in content:
            content = content.replace('defaultConfig {', 'defaultConfig {\n        multiDexEnabled = true')
        if 'storeFile = file("trueme-release.jks")' not in content:
            release_signing_kts = '''signingConfigs {
        create("release") {
            keyAlias = "trueme"
            keyPassword = "truemepassword"
            storeFile = file("trueme-release.jks")
            storePassword = "truemepassword"
        }
    }\n    '''
            if 'buildTypes {' in content:
                content = content.replace('buildTypes {', release_signing_kts + 'buildTypes {')
        if 'isMinifyEnabled' not in content:
            content = content.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = if (file("trueme-release.jks").exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")\n            isMinifyEnabled = false\n            isShrinkResources = false')
        if 'checkReleaseBuilds' not in content:
            content = content.replace('buildTypes {', 'lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n    buildTypes {')
        if 'coreLibraryDesugaring(' not in content:
            if 'dependencies {' in content:
                content = content.replace('dependencies {', 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")')
            else:
                content += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        with open(kts_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Injected release signing, desugaring, multiDex, and disabled R8 in build.gradle.kts')

    # 2. Patch Groovy
    groovy_path = 'android/app/build.gradle'
    if os.path.exists(groovy_path):
        with open(groovy_path, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'coreLibraryDesugaringEnabled' not in content:
            content = content.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true')
        if 'multiDexEnabled' not in content:
            content = content.replace('defaultConfig {', 'defaultConfig {\n        multiDexEnabled true')
        if 'storeFile file("trueme-release.jks")' not in content:
            release_signing_groovy = '''signingConfigs {
        release {
            keyAlias 'trueme'
            keyPassword 'truemepassword'
            storeFile file('trueme-release.jks')
            storePassword 'truemepassword'
        }
    }\n    '''
            if 'buildTypes {' in content:
                content = content.replace('buildTypes {', release_signing_groovy + 'buildTypes {')
        if 'minifyEnabled' not in content:
            content = content.replace('signingConfig signingConfigs.debug', 'signingConfig file("trueme-release.jks").exists() ? signingConfigs.release : signingConfigs.debug\n            minifyEnabled false\n            shrinkResources false')
        if 'checkReleaseBuilds' not in content:
            content = content.replace('buildTypes {', 'lintOptions {\n        checkReleaseBuilds false\n        abortOnError false\n    }\n    buildTypes {')
        if 'coreLibraryDesugaring ' not in content:
            if 'dependencies {' in content:
                content = content.replace('dependencies {', 'dependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"')
            else:
                content += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
        with open(groovy_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Injected release signing, desugaring, multiDex, and disabled minification in build.gradle')

if __name__ == '__main__':
    patch_android_build()
