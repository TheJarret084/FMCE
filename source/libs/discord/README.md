# Discord Rich Presence

Un solo `source/funky/api/DiscordClient.hx` (lo que usa el juego: `menuPresence()`, `customPresence()`...) con dos backends:

| Plataforma | Backend | Que necesita |
| --- | --- | --- |
| **Escritorio** (Windows, Linux, Mac) con target cpp | haxelib **hxdiscord_rpc** (`DISCORD_RPC`) | nada mas: esta en `building/libs.txt` |
| **Android** | **Discord Social SDK**, desde el `.aar` (`DISCORD_SDK`) | `source/libs/discord/android/discord_partner_sdk.aar` |
| HashLink / HTML5 | ninguno (no hace nada) | - |

No pide iniciar sesion: la presencia se la pasa al Discord que el usuario ya tiene abierto (en Android, a la app de Discord).

## Android (el .aar)

Copia `discord_partner_sdk.aar` a `source/libs/discord/android/` (pesa 30 MB, no va en el zip). El `krisp.aar` no hace falta (es solo voz).

- `source/libs/discord/android/build.gradle`: envuelve el `.aar` como modulo de Gradle (Lime `<dependency>` en `Project.xml`). Trae las `.so`
  de cada ABI, las clases Java y el manifest del SDK.
- `source/java/org/fmce/DiscordInit.java`: le pasa la Activity al SDK antes de crear el cliente (lo llama `DiscordClient` por JNI). Usa reflexion, asi compila aunque no este el `.aar`.
- `building/discord-android.sh`: saca las `.so` del `.aar` a `building/_discord/` para el enlace de hxcpp (lo llama `building/build.sh`).
- `source/funky/api/DiscordSdk.hx` + `native/DiscordBridge.cpp` + `DiscordBuild.hx`: el puente a C++ (`source/libs/discord/include/` trae
  `discordpp.h` y `cdiscord.h`, sacados del mismo `.aar`).

**El `.aar` es obligatorio para compilar Android**: sin el, Gradle falla. Si quieres compilar sin Rich Presence, agrega
`-DFMCE_NO_DISCORD` al comando de lime.

## Nombre

Se ve **"Funky Maker: CNE"** porque asi se llama la aplicacion en https://discord.com/developers (ID `1509746395962409071`). Discord lo toma
de ahi: no se cambia por codigo. Las imagenes (`fmce`, `freeplay`, ...) son los *Art Assets* de Rich Presence de esa misma aplicacion.

## Ojo

- El `.aar` trae permisos de microfono / servicio en primer plano en su manifest (son del SDK de voz); no se piden en tiempo de ejecucion,
  pero salen en el manifest del APK.
- Para probar: Discord abierto (o instalado en el celular) y Ajustes > Actividad > Compartir actividad en tu perfil.
