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
El keystore solo se usa si `building/check-keystore.sh` lo da por bueno (abre con `ANDROID_KEY_ALIAS` y
`ANDROID_STORE_PASSWORD` y se puede leer la llave); si falta o esta danado, el build sigue firmado en debug.

## Flixel / OpenFL (forks de Codename)

`libs.txt` instala `cne-flixel` (Flixel **5.3.x**), `cne-flixel-addons`, `cne-openfl` y `cne-flixel-animate` (rama `old`), igual que Codename Engine:
la UI de los editores (charter, hover, seleccion) esta portada de ahi. Si ya tenias flixel/openfl de haxelib, los scripts los reemplazan por el fork
(haxelib los marca como `git`; vuelve al normal con `haxelib install flixel`). Como ese Flixel es mas viejo que el 6.x:
no hay `FlxG.switchState(X.new)` (usa `new X()`), el mouse/touch usa `screenX/screenY` (no `viewX/viewY`) y `FlxRuntimeShader` va vendido en `source/flixel/addons/display/`.

## Video (hxvlc)

`FunkinVideoSprite` usa hxvlc (el fork de Codename: https://github.com/CodenameCrew/cne-hxvlc, ya esta en `libs.txt`), que solo existe
en C++: HashLink usa un stub. En **Linux** hay que instalar libVLC (headers incluidos) antes de compilar, el CI ya lo hace:
`sudo apt-get install vlc libvlc-dev libvlccore-dev vlc-bin` (Windows y macOS no piden nada).
En Android viene activado (el splash lo usa); para apagarlo compila con `-DFMCE_NO_VIDEO_ANDROID`.

## assets.pack
`pack-assets.py` compila `assets/` en `building/_pack/assets.pack` (los scripts de build lo corren solos; necesita Python 3). Ver `DOCS/addons-y-pack.md`.
