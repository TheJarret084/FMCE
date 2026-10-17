# `building/`

| Archivo | Para que |
| --- | --- |
| `build.sh` | Linux/macOS: `bash building/build.sh <hl\|cpp\|android> <debug\|release> [args de lime]` |
| `build.bat` | Windows: `building\build.bat <hl\|cpp> <debug\|release> [args de lime]` |
| `android-build.sh` | Android: prepara SDK/NDK y llama a `build.sh android` |
| `libs.txt` | Dependencias (`nombre [version]`). Los scripts las instalan solos |
| `alsoft.txt` | Config de OpenAL que `Project.xml` copia al build (si falta, no compila) |

Android guarda sus datos en `/storage/emulated/0/.JarretLabs-FMCE/` (pide "Acceso a todos los archivos" la primera vez).

Salida en `building/artifacts/`: `FMCE-<OS>-x64-<target>-<tipo>.zip` o `FMCE-Android-<tipo>.apk`
(el CI depende de esos nombres). Haxe 4.3.7 (`FMCE_ALLOW_ANY_HAXE=1` para saltar la comprobacion).

## CI (`.github/workflows/`)

- `build.yml`: Linux + Windows. Tags `v*`/`release-v*` = HL release, `debug-v*` = HL debug. A mano: eliges `cpp`/`hl` y `debug`/`release`.
- `android-release.yml`: APK en cada tag `v*` (NDK r21e fijo por hxcpp 4.3.2, no lo cambies).

## Android

Sin `building/android.keystore` el release sale firmado en debug (instalable). Para uno real:
`keytool -genkey -v -keystore building/android.keystore -alias fmce -keyalg RSA -keysize 2048 -validity 10000`.

## Video (hxvlc)

`FunkinVideoSprite` usa hxvlc, que solo existe en C++: Windows/Linux lo traen, HashLink usa un stub.
En Android viene activado (el splash lo usa); para apagarlo compila con `-DFMCE_NO_VIDEO_ANDROID`.
