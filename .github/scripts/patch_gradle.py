import os


def patch_android_build():
    key_alias = os.environ.get('ANDROID_KEY_ALIAS', '').strip()
    store_pw = os.environ.get('ANDROID_STORE_PASSWORD', '').strip()
    key_pw = os.environ.get('ANDROID_KEY_PASSWORD', '').strip()
    store_file = os.environ.get('ANDROID_KEYSTORE_PATH', 'trueme-release.jks').strip()
    has_release_signing = bool(
        key_alias
        and store_pw
        and key_pw
        and os.path.exists(os.path.join('android', 'app', store_file))
    )

    # 1. Patch Kotlin DSL
    kts_path = 'android/app/build.gradle.kts'
    if os.path.exists(kts_path):
        with open(kts_path, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'isCoreLibraryDesugaringEnabled' not in content:
            content = content.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
        if 'multiDexEnabled' not in content:
            content = content.replace('defaultConfig {', 'defaultConfig {\n        multiDexEnabled = true')
        if has_release_signing and 'signingConfigs.getByName("release")' not in content:
            release_signing_kts = f'''signingConfigs {{
        create("release") {{
            keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: ""
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: ""
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "{store_file}")
            storePassword = System.getenv("ANDROID_STORE_PASSWORD") ?: ""
        }}
    }}\n    '''
            if 'buildTypes {' in content:
                content = content.replace('buildTypes {', release_signing_kts + 'buildTypes {')
        if 'isMinifyEnabled' not in content:
            target_signing = 'signingConfigs.getByName("release")' if has_release_signing else 'signingConfigs.getByName("debug")'
            content = content.replace(
                'signingConfig = signingConfigs.getByName("debug")',
                f'signingConfig = {target_signing}\n            isMinifyEnabled = false\n            isShrinkResources = false',
            )
        if 'checkReleaseBuilds' not in content:
            content = content.replace('buildTypes {', 'lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n    buildTypes {')
        if 'coreLibraryDesugaring(' not in content:
            if 'dependencies {' in content:
                content = content.replace('dependencies {', 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")')
            else:
                content += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        with open(kts_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Patched build.gradle.kts (release_signing={has_release_signing})')

    # 2. Patch Groovy
    groovy_path = 'android/app/build.gradle'
    if os.path.exists(groovy_path):
        with open(groovy_path, 'r', encoding='utf-8') as f:
            content = f.read()
        if 'coreLibraryDesugaringEnabled' not in content:
            content = content.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true')
        if 'multiDexEnabled' not in content:
            content = content.replace('defaultConfig {', 'defaultConfig {\n        multiDexEnabled true')
        if has_release_signing and 'signingConfigs.release' not in content:
            release_signing_groovy = f'''signingConfigs {{
        release {{
            keyAlias System.getenv("ANDROID_KEY_ALIAS") ?: ""
            keyPassword System.getenv("ANDROID_KEY_PASSWORD") ?: ""
            storeFile file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "{store_file}")
            storePassword System.getenv("ANDROID_STORE_PASSWORD") ?: ""
        }}
    }}\n    '''
            if 'buildTypes {' in content:
                content = content.replace('buildTypes {', release_signing_groovy + 'buildTypes {')
        if 'minifyEnabled' not in content:
            target_signing = 'signingConfigs.release' if has_release_signing else 'signingConfigs.debug'
            content = content.replace(
                'signingConfig signingConfigs.debug',
                f'signingConfig {target_signing}\n            minifyEnabled false\n            shrinkResources false',
            )
        if 'checkReleaseBuilds' not in content:
            content = content.replace('buildTypes {', 'lintOptions {\n        checkReleaseBuilds false\n        abortOnError false\n    }\n    buildTypes {')
        if 'coreLibraryDesugaring ' not in content:
            if 'dependencies {' in content:
                content = content.replace('dependencies {', 'dependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"')
            else:
                content += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
        with open(groovy_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Patched build.gradle (release_signing={has_release_signing})')


if __name__ == '__main__':
    patch_android_build()
