# FMCE

FMCE is a HaxeFlixel/OpenFL rhythm-game project that loads playable levels from
`levels/`.

> **Want to build it?** See [`building/README.md`](building/README.md) for the
> full desktop and Android instructions.

## Requirements

- Haxe 4.3.7
- A platform toolchain supported by Lime
- Android builds additionally require JDK 17, Android SDK, and Android NDK 25

Las dependencias estan en [`building/libs.txt`](building/libs.txt) y `build.sh` / `build.bat`
las instalan solos antes de compilar.

## Quick start

```bash
# Linux / macOS
./building/build.sh cpp release        # o: hl debug

# Windows
building\build.bat cpp release
```

El resultado queda en `building/artifacts/`. Android:

```bash
./building/android-build.sh release   # -> building/artifacts/FMCE-Android-release.apk
```

Para probar rapido sin empaquetar: `haxelib run lime test linux -hl -debug -DTEST_BUILD`.

## Project layout

- `source/`: game code
- `assets/`: packaged resources
- `levels/`: playable FNMM levels distributed with the game
- `building/`: `build.sh`, `build.bat`, `android-build.sh`, `libs.txt` y la guia
- `.github/workflows/`: CI builds

## Build status

The build system is wired up for desktop (HashLink and C++) and Android.

`source/` still holds **two generations of the engine**. Haxe only compiles
what is type-reachable from `Main.hx`, so only the second generation is built:

```
Main.hx -> funky.menus.TitleState -> funky.menus.MainMenuState
        -> funky.menus.FreeplayState -> funky.game.PlayState
        -> funky.menus.PauseSubState
```

`TitleState` and `MainMenuState` are `FlxState`s rather than
`MusicBeatState`s, so they call `TransitionHandler` directly instead of
inheriting `transitionTo()`.

The first generation — `funky.fnmm/`, `funky.gameplay/`, `funky.states/`,
`funky.substates/`, `funky.ui/` and `funky.api/` — still never compiles. It
references five classes that do not exist anywhere in the repository:

| Missing class | Referenced from |
| --- | --- |
| `NoteSkin` | `funky/ui/FMNote.hx`, `funky/ui/HoldNote.hx`, `funky/ui/StrumNote.hx` |
| `funky.gameplay.StrumLine` | `funky/gameplay/StrumSystem.hx` |
| `LevelSelectState` | `funky/states/FreeplayState.hx` |
| `EditorMenuState` | `funky/states/PlayState.hx` |
| `GameoverState` | `funky/states/PlayState.hx` |

These are latent rather than blocking: they stay invisible precisely because
nothing reaches them. They will fail the build the moment that code is wired
back up.

`funky/editors/` and `funky/backend/shaders/` are also empty, though
`Paths.hx` still points at editor functionality.

### Live utilities

The shared helpers in `funky.core` are all reachable from the live path:

| Helper | Used by |
| --- | --- |
| `TransitionHandler` | every state switch, plus the enter curtain |
| `KeyBinds` | menu navigation, accept, back and pause (keyboard + gamepad) |
| `ControlsCheck` | gameplay lane input (keyboard + gamepad) |
| `Conductor` | beat/step tracking, driven from `PlayState` |

`CoolUtil` and `funky.api.DiscordClient` are the two remaining unreferenced
files. Neither should be wired in as-is:

- `DiscordClient` sits behind `#if DISCORD_RPC`, which `Project.xml` leaves
  commented out, so it compiles to nothing. Turning it on needs all three of the
  `<define>`/`<haxelib>`/`<haxedef>` lines plus a `hxdiscord_rpc` entry in
  `building/libs.xml`.
- `CoolUtil` is a ~740-line port from Codename Engine that **has never been
  compiled**, because nothing referenced it. It reaches into non-public Flixel
  APIs via `@:privateAccess` and its `keyToString` switch mixes a `null`
  pattern with `Int` cases. Referencing it from the live path would pull all of
  that into the build for the first time, so it needs a `lime test` before it is
  trusted. Its `playMenuSong` is also unusable as-is: it defaults to
  `Looping_Rooms`, a Codename asset FMCE does not ship.

See `tareas.md` for the rework plan.

## Credits

FMCE includes work derived from Friday Night Funkin' and Kade Engine. See
`LICENSE` and the original projects for their respective notices.

a
