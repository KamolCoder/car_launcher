"""Adds a release signing config (from env vars) to the generated app/build.gradle.kts.

CL_KEYSTORE set  -> release APK signed with the persistent key (updates install over each other).
CL_KEYSTORE unset -> falls back to the debug key, as before.
"""
import sys

path = sys.argv[1]
src = open(path, encoding="utf-8").read()

signing = '''
    signingConfigs {
        create("release") {
            val keystore = System.getenv("CL_KEYSTORE")
            if (keystore != null) {
                storeFile = file(keystore)
                storePassword = System.getenv("CL_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CL_KEY_ALIAS")
                keyPassword = System.getenv("CL_KEY_PASSWORD")
            }
        }
    }

    buildTypes {'''

old_release = 'signingConfig = signingConfigs.getByName("debug")'
new_release = (
    'signingConfig = if (System.getenv("CL_KEYSTORE") != null) '
    'signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
)

if "\n    buildTypes {" not in src or old_release not in src:
    sys.exit("build.gradle.kts template changed: cannot patch signing")

src = src.replace("\n    buildTypes {", signing, 1).replace(old_release, new_release, 1)
open(path, "w", encoding="utf-8").write(src)
print("signing config patched")
