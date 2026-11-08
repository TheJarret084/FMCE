package funky.core;

import flixel.FlxG;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** Config global del juego. Se guarda como XML en assets/data/config/settings.xml. */
class ClientPrefs
{
    public static final PATH:String = "assets/data/config/settings.xml";
    static final LEGACY_PATH:String = "assets/data/config/settings.json";
    public static final MIN_LANES:Int = 1;
    public static final MAX_LANES:Int = 9;
    public static final CENTER_COLOR:Int = 0xFFD8D8D8;

    public static var data:Dynamic = defaultData();

    static function defaultLaneKeys():Array<Array<String>>
    {
        return [
            ["LEFT", "A"],
            ["DOWN", "S"],
            ["UP",   "W"],
            ["RIGHT","D"],
            ["I"],
            ["K"],
            ["J"],
            ["L"],
            ["SPACE"]
        ];
    }

    static function defaultGamepadLaneButtons():Array<String>
    {
        return ["X", "A", "Y", "B"];
    }

    static function defaultMenuKeys():Dynamic
    {
        return {
            up:      ["UP", "W"],
            down:    ["DOWN", "S"],
            left:    ["LEFT", "A"],
            right:   ["RIGHT", "D"],
            accept:  ["ENTER", "SPACE"],
            back:    ["ESCAPE"],
            pause:   ["ENTER"]
        };
    }

    static function defaultMenuGamepad():Dynamic
    {
        return {
            up: "DPAD_UP",
            down: "DPAD_DOWN",
            left: "DPAD_LEFT",
            right: "DPAD_RIGHT",
            accept: "A",
            back: "B",
            pause: "START"
        };
    }

    static function defaultData():Dynamic
    {
        return {
            // Nombre del archivo multikey (sin extensión ni ruta):
            // el formato original usa "multikeysettings": "multikeyData"
            multikeysettings: "multikeyData",

            // El JSON real usa "downscrool" (typo del autor, se respeta)
            downscrool: false,
            botplay: false,
            middlescroll: false,
            ghostTapping: true,
            missSound: true,
            noteSplashes: true,
            // true = el splash inicial se salta y va directo al TITLE
            skipIntro: false,
            // Idioma de la interfaz (carpeta en assets/languages/<codigo>/)
            language: "es",
            // Skin de notas (assets/images/game/notes/skins/<id>/noteSkin.xml)
            noteSkin: "default",
            masterVolume: 1.0,
            musicVolume: 1.0,
            sfxVolume: 1.0,

            laneCount: 4,
            // laneCount por strumLine: [playerLaneCount, enemyLaneCount]
            // Si está vacío o null, se usa laneCount global para todos.
            laneCountPerStrumLine: [4, 4],

            multikey: true,
            laneKeys: defaultLaneKeys(),
            gamepadLaneButtons: defaultGamepadLaneButtons(),
            menuKeys: defaultMenuKeys(),
            menuGamepad: defaultMenuGamepad(),

            leftKeys:  ["LEFT", "A"],
            downKeys:  ["DOWN", "S"],
            upKeys:    ["UP",   "W"],
            rightKeys: ["RIGHT","D"],

            strumDefaultColor: 0x828282,
            strumAlpha: 0.95,
            editorSFX: true,
            bypassEditorsResize: false,

            /**
             * noteColors: [ 0xCA4E9D, 0x00FFFE, 0x10FA05, 0xFC3844, 0x35B162, 0xFF0001, 0xEF05FA, 0x03C7BB,
             * 0xF5F0E8 ],
             */
            noteColors: [
                0xCA4E9D, 0x00FFFE, 0x10FA05, 0xFC3844,
                0x35B162, 0xFF0001, 0xEF05FA, 0x03C7BB,
                0xF5F0E8
            ],
            pressedColors: [
                0xC576A8, 0x4AEBEB, 0x55E84F, 0xE46E75,
                0x3A8957, 0xB51414, 0xAA17B0, 0x1B918A,
                0xF5F0E8
            ]
        };
    }

    /** Archivo de configuracion: `<carpeta de datos>/.JarretLabs-FMCE/FMCE.sol` (en Android la carpeta de datos ya es .JarretLabs-FMCE). */
    public static function solPath():String
    {
        #if android
        return Storage.dataDirectory() + "/FMCE.sol";
        #else
        return haxe.io.Path.join([Storage.dataDirectory(), Storage.path, "FMCE.sol"]);
        #end
    }

    /** Devuelve el XML guardado en el .sol, o null si no existe o esta corrupto. */
    static function readSol():Null<String>
    {
        try
        {
            var path = solPath();
            if (!FileSystem.exists(path)) return null;
            var box:Dynamic = haxe.Unserializer.run(File.getContent(path));
            var xml:Dynamic = Reflect.field(box, "xml");
            return Std.isOfType(xml, String) ? (xml : String) : null;
        }
        catch (e)
        {
            trace('[ClientPrefs] FMCE.sol ilegible, se usan los valores por defecto: ' + e);
            return null;
        }
    }

    static function writeSol(xml:String):Void
    {
        var path = solPath();
        var dir = haxe.io.Path.directory(path);
        if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
        // Se escribe a un temporal y se renombra: un corte a mitad no deja el .sol roto.
        var tmp = path + ".tmp";
        File.saveContent(tmp, haxe.Serializer.run({version: 2, xml: xml}));
        if (FileSystem.exists(path)) FileSystem.deleteFile(path);
        FileSystem.rename(tmp, path);
    }

    public static function load():Void
    {
        data = defaultData();

        try
        {
            var fromSol = readSol();
            if (fromSol != null)
                loadXml(fromSol);
            else
            {
                // Primer arranque / migracion: settings.xml viejo (dentro de assets, ahora en assets.pack) -> FMCE.sol
                var legacyXml = assetText(PATH);
                var legacyJson = legacyXml == null ? assetText(LEGACY_PATH) : null;
                if (legacyXml != null) loadXml(legacyXml);
                else if (legacyJson != null) loadLegacyJson(legacyJson);
                save();
            }

            syncActiveGroupToLaneKeys();
        }
        catch (e)
        {
            trace('[ClientPrefs] Error loading: ' + e);
            save();
        }
    }

    /** Texto de un archivo de assets/ (viven en assets.pack, no en disco): null si no existe. Cae al disco si el build trae assets sueltos. */
    static function assetText(path:String):Null<String>
    {
        try
        {
            if (openfl.utils.Assets.exists(path)) return openfl.utils.Assets.getText(path);
            if (FileSystem.exists(path)) return File.getContent(path);
        }
        catch (e) {}
        return null;
    }

    static function loadLegacyJson(raw:String):Void
    {
        var parsed:Dynamic = Json.parse(raw);
        if (parsed == null) return;

        if (Reflect.hasField(parsed, "multikeysettings"))
            data.multikeysettings = Std.string(Reflect.field(parsed, "multikeysettings"));

        data.downscrool = getBool(parsed, "downscrool", false);
        data.botplay = getBool(parsed, "botplay", false);
        data.middlescroll = getBool(parsed, "middlescroll", false);
        data.ghostTapping = getBool(parsed, "ghostTapping", true);
        data.missSound = getBool(parsed, "missSound", true);
        data.noteSplashes = getBool(parsed, "noteSplashes", true);
        data.skipIntro = getBool(parsed, "skipIntro", false);
        if (Reflect.hasField(parsed, "language"))
        {
            var lang = Std.string(Reflect.field(parsed, "language"));
            if (lang != null && lang.length > 0) data.language = lang;
        }
        if (Reflect.hasField(parsed, "noteSkin"))
        {
            var skin = Std.string(Reflect.field(parsed, "noteSkin"));
            if (skin != null && skin.length > 0) data.noteSkin = skin;
        }
        data.masterVolume = getFloat(parsed, "masterVolume", 1.0);
        data.musicVolume = getFloat(parsed, "musicVolume", 1.0);
        data.sfxVolume = getFloat(parsed, "sfxVolume", 1.0);

        data.laneCount = clampInt(
            getInt(parsed, "laneCount", getInt(parsed, "strumCount", 4)),
            MIN_LANES, MAX_LANES
        );

        var lcps = getArrayField(parsed, "laneCountPerStrumLine");
        if (lcps != null && lcps.length > 0)
        {
            var arr:Array<Int> = [];
            for (v in lcps)
                arr.push(clampInt(Std.int(asFloat(v, data.laneCount)), MIN_LANES, MAX_LANES));
            data.laneCountPerStrumLine = arr;
        }
        else data.laneCountPerStrumLine = [data.laneCount, data.laneCount];

        data.laneKeys = normalizeLaneKeys(
            getLaneKeysFromParsed(parsed),
            cast defaultLaneKeys()
        );

        data.gamepadLaneButtons = normalizeGamepadButtons(
            getArrayField(parsed, "gamepadLaneButtons"),
            cast defaultGamepadLaneButtons()
        );

        loadMenuBindingsFromDynamic(parsed);
        applyLegacyLaneFields();

        data.strumDefaultColor = getInt(parsed, "strumDefaultColor", 0x828282);
        data.strumAlpha = getFloat(parsed, "strumAlpha", 0.95);
        data.noteColors = normalizeColorArray(
            getArrayField(parsed, "noteColors"),
            cast defaultData().noteColors,
            CENTER_COLOR
        );
        data.pressedColors = normalizeColorArray(
            getArrayField(parsed, "pressedColors"),
            cast defaultData().pressedColors,
            CENTER_COLOR
        );

        for (kc in 4...10)
        {
            var field = 'kg$kc';
            if (Reflect.hasField(parsed, field))
            {
                var v:Dynamic = Reflect.field(parsed, field);
                if (Std.isOfType(v, Array)) Reflect.setField(data, field, v);
            }
        }
    }

    static function loadXml(raw:String):Void
    {
        var root = Xml.parse(raw).firstElement();
        if (root == null) throw "settings.xml has no root element";

        var languageNode = firstChild(root, "language");
        if (languageNode != null)
        {
            var code = languageNode.get("code");
            if (code == null) code = languageNode.get("value");
            if (code != null && code.length > 0) data.language = code;
        }

        var gameplay = firstChild(root, "gameplay");
        if (gameplay != null)
        {
            data.downscrool = parseXmlBool(gameplay.get("downscroll"), false);
            data.botplay = parseXmlBool(gameplay.get("botplay"), false);
            data.middlescroll = parseXmlBool(gameplay.get("middlescroll"), false);
            data.ghostTapping = parseXmlBool(gameplay.get("ghostTapping"), true);
            data.missSound = parseXmlBool(gameplay.get("missSound"), true);
            data.noteSplashes = parseXmlBool(gameplay.get("noteSplashes"), true);
            data.skipIntro = parseXmlBool(gameplay.get("skipIntro"), false);

            data.masterVolume = parseXmlFloat(gameplay.get("masterVolume"), 1.0);
            data.musicVolume = parseXmlFloat(gameplay.get("musicVolume"), 1.0);
            data.sfxVolume = parseXmlFloat(gameplay.get("sfxVolume"), 1.0);

            var mk = gameplay.get("multikeysettings");
            if (mk != null && mk.length > 0)
                data.multikeysettings = mk;
        }

        var notes = firstChild(root, "notes");
        if (notes != null)
        {
            var skin = notes.get("skin");
            if (skin == null) skin = notes.get("id");
            if (skin != null && skin.length > 0) data.noteSkin = skin;
        }

        var display = firstChild(root, "display");
        if (display != null)
        {
            funky.backend.system.framerate.Framerate.debugMode =
                parseXmlBool(display.get("fps"), funky.backend.system.framerate.Framerate.debugMode > 0) ? 1 : 0;
            funky.backend.system.LogOverlay.enabled = parseXmlBool(display.get("logs"), funky.backend.system.LogOverlay.enabled);
        }

        var editor = firstChild(root, "editor");
        if (editor != null)
        {
            funkin.options.Options.editorSFX = parseXmlBool(editor.get("sfx"), funkin.options.Options.editorSFX);
            funkin.options.Options.intensiveBlur = parseXmlBool(editor.get("intensiveBlur"), funkin.options.Options.intensiveBlur);
            funkin.options.Options.maxUndos = Std.int(Math.max(1, parseXmlFloat(editor.get("maxUndos"), funkin.options.Options.maxUndos)));
            funkin.options.Options.charterAutoSaves = parseXmlBool(editor.get("autoSaves"), funkin.options.Options.charterAutoSaves);
            funkin.options.Options.charterAutoSaveTime = Math.max(10, parseXmlFloat(editor.get("autoSaveTime"), funkin.options.Options.charterAutoSaveTime));
        }

        var lanes = firstChild(root, "lanes");
        if (lanes != null)
        {
            data.laneCount = clampInt(parseXmlInt(lanes.get("count"), 4), MIN_LANES, MAX_LANES);

            var lineArr:Array<Int> = [];
            for (node in lanes.elementsNamed("strumLine"))
                lineArr.push(clampInt(
                    parseXmlInt(node.get("count"), data.laneCount),
                    MIN_LANES,
                    MAX_LANES
                ));
            if (lineArr.length > 0)
                data.laneCountPerStrumLine = lineArr;

            var keyboard = firstChild(lanes, "keyboard");
            if (keyboard != null)
            {
                var parsedKeys:Array<Dynamic> = [];
                for (lane in keyboard.elementsNamed("lane"))
                {
                    var vals:Array<Dynamic> = [];
                    for (key in lane.elementsNamed("key"))
                    {
                        var name = key.get("name");
                        if (name != null) vals.push(name);
                    }
                    parsedKeys.push(vals);
                }
                data.laneKeys = normalizeLaneKeys(
                    parsedKeys,
                    cast defaultLaneKeys()
                );
            }

            var gamepad = firstChild(lanes, "gamepad");
            if (gamepad != null)
            {
                var buttons:Array<Dynamic> = [];
                for (lane in gamepad.elementsNamed("lane"))
                {
                    var name = lane.get("button");
                    buttons.push(name == null ? "" : name);
                }
                data.gamepadLaneButtons = normalizeGamepadButtons(
                    buttons,
                    cast defaultGamepadLaneButtons()
                );
            }
        }

        var menu = firstChild(root, "menuControls");
        if (menu != null)
            loadMenuBindingsFromXml(menu);

        var colors = firstChild(root, "colors");
        if (colors != null)
        {
            data.strumDefaultColor = parseXmlInt(colors.get("strumDefault"), 0x828282);
            data.strumAlpha = parseXmlFloat(colors.get("strumAlpha"), 0.95);
            data.noteColors = readXmlColorList(
                colors, "noteColors", cast defaultData().noteColors
            );
            data.pressedColors = readXmlColorList(
                colors, "pressedColors", cast defaultData().pressedColors
            );
        }

        var keygroups = firstChild(root, "keygroups");
        if (keygroups != null)
        {
            for (group in keygroups.elementsNamed("group"))
            {
                var kc = parseXmlInt(group.get("lanes"), 0);
                if (kc <= 0) continue;

                var binds:Array<Array<String>> = [];
                for (lane in group.elementsNamed("lane"))
                {
                    var row:Array<String> = [];
                    for (key in lane.elementsNamed("key"))
                    {
                        var name = key.get("name");
                        if (name != null && name.length > 0) row.push(name);
                    }
                    binds.push(row);
                }
                Reflect.setField(data, 'kg$kc', binds);
            }
        }

        applyLegacyLaneFields();
    }

    static function firstChild(root:Xml, name:String):Xml
    {
        for (node in root.elementsNamed(name)) return node;
        return null;
    }

    static function readXmlColorList(root:Xml, name:String, fallback:Array<Int>):Array<Int>
    {
        var section = firstChild(root, name);
        if (section == null) return fallback.copy();

        var arr:Array<Dynamic> = [];
        for (item in section.elementsNamed("color"))
        {
            var value = item.get("value");
            if (value != null) arr.push(value);
        }
        return normalizeColorArray(arr, fallback, CENTER_COLOR);
    }

    static function parseXmlInt(value:String, fallback:Int):Int
    {
        if (value == null) return fallback;
        var n = Std.parseInt(StringTools.trim(value));
        return n == null ? fallback : n;
    }

    static function parseXmlFloat(value:String, fallback:Float):Float
    {
        if (value == null) return fallback;
        var n = Std.parseFloat(StringTools.trim(value));
        return Math.isNaN(n) ? fallback : n;
    }

    static function parseXmlBool(value:String, fallback:Bool):Bool
    {
        if (value == null) return fallback;
        var s = StringTools.trim(value).toLowerCase();
        return (s == "true" || s == "1" || s == "yes" || s == "on");
    }

    /** Sincroniza el keygroup activo (player laneCount) al array legacy laneKeys. */
    public static function syncActiveGroupToLaneKeys():Void
    {
        var kc = getLaneCountForStrumLine(0);
        var field = 'kg$kc';
        if (!Reflect.hasField(data, field)) return;
        var v:Dynamic = Reflect.field(data, field);
        if (!Std.isOfType(v, Array)) return;
        var binds:Array<Array<String>> = cast v;
        if (!Std.isOfType(data.laneKeys, Array)) data.laneKeys = [];
        var lk:Array<Array<String>> = cast data.laneKeys;
        for (i in 0...binds.length)
        {
            while (lk.length <= i) lk.push([]);
            if (binds[i] != null) lk[i] = binds[i].copy();
        }
        data.laneKeys = lk;
        applyLegacyLaneFields();
    }

    public static function save():Void
    {
        try
        {
            syncLegacyLaneFields();

            var root = Xml.createElement("settings");
            root.set("version", "2");

            var language = Xml.createElement("language");
            language.set("code", getLanguage());
            root.addChild(language);

            var gameplay = Xml.createElement("gameplay");
            gameplay.set("downscroll", Std.string(isDownScroll()));
            gameplay.set("botplay", Std.string(isBotplay()));
            gameplay.set("middlescroll", Std.string(isMiddleScroll()));
            gameplay.set("ghostTapping", Std.string(isGhostTapping()));
            gameplay.set("missSound", Std.string(isMissSound()));
            gameplay.set("noteSplashes", Std.string(isNoteSplashes()));
            gameplay.set("skipIntro", Std.string(isSkipIntro()));
            gameplay.set("masterVolume", Std.string(getMasterVolume()));
            gameplay.set("musicVolume", Std.string(getMusicVolume()));
            gameplay.set("sfxVolume", Std.string(getSfxVolume()));
            gameplay.set("multikeysettings", getMultikeyFile());
            root.addChild(gameplay);

            var notes = Xml.createElement("notes");
            notes.set("skin", getNoteSkin());
            root.addChild(notes);

            var lanes = Xml.createElement("lanes");
            lanes.set("count", Std.string(getLaneCount()));

            var lineCounts = getLaneCountPerStrumLine();
            for (i in 0...lineCounts.length)
            {
                var line = Xml.createElement("strumLine");
                line.set("index", Std.string(i));
                line.set("count", Std.string(lineCounts[i]));
                lanes.addChild(line);
            }

            var keyboard = Xml.createElement("keyboard");
            var allKeys:Array<Array<String>> = cast data.laneKeys;
            for (i in 0...allKeys.length)
            {
                var lane = Xml.createElement("lane");
                lane.set("index", Std.string(i));

                var keys = allKeys[i];
                if (keys != null)
                {
                    for (keyName in keys)
                    {
                        if (keyName == null || keyName.length == 0) continue;
                        var key = Xml.createElement("key");
                        key.set("name", keyName);
                        lane.addChild(key);
                    }
                }
                keyboard.addChild(lane);
            }
            lanes.addChild(keyboard);

            var gamepad = Xml.createElement("gamepad");
            var padButtons = getGamepadLaneButtons();
            for (i in 0...padButtons.length)
            {
                var lane = Xml.createElement("lane");
                lane.set("index", Std.string(i));
                lane.set("button", padButtons[i] == null ? "" : padButtons[i]);
                gamepad.addChild(lane);
            }
            lanes.addChild(gamepad);
            root.addChild(lanes);

            root.addChild(writeMenuBindingsXml());

            var colors = Xml.createElement("colors");
            colors.set("strumDefault", Std.string(
                getInt(data, "strumDefaultColor", 0x828282)
            ));
            colors.set("strumAlpha", Std.string(
                getFloat(data, "strumAlpha", 0.95)
            ));
            colors.addChild(writeXmlColorList("noteColors", cast data.noteColors));
            colors.addChild(writeXmlColorList("pressedColors", cast data.pressedColors));
            root.addChild(colors);

            var keygroups = Xml.createElement("keygroups");
            for (kc in 4...10)
            {
                var field = 'kg$kc';
                if (!Reflect.hasField(data, field)) continue;

                var value:Dynamic = Reflect.field(data, field);
                if (!Std.isOfType(value, Array)) continue;

                var group = Xml.createElement("group");
                group.set("lanes", Std.string(kc));

                var binds:Array<Array<String>> = cast value;
                for (i in 0...binds.length)
                {
                    var lane = Xml.createElement("lane");
                    lane.set("index", Std.string(i));

                    if (binds[i] != null)
                    {
                        for (keyName in binds[i])
                        {
                            if (keyName == null || keyName.length == 0) continue;
                            var key = Xml.createElement("key");
                            key.set("name", keyName);
                            lane.addChild(key);
                        }
                    }
                    group.addChild(lane);
                }
                keygroups.addChild(group);
            }
            root.addChild(keygroups);

            // Pantalla: contador de FPS (visible + opacidad) y logs en pantalla. Se leen de donde viven (los toggles del menu y F2 los cambian directo).
            var display = Xml.createElement("display");
            display.set("fps", Std.string(funky.backend.system.framerate.Framerate.debugMode > 0));
            display.set("logs", Std.string(funky.backend.system.LogOverlay.enabled));
            root.addChild(display);

            // Opciones de los editores (las de Codename: funkin.options.Options).
            var editor = Xml.createElement("editor");
            editor.set("sfx", Std.string(funkin.options.Options.editorSFX));
            editor.set("intensiveBlur", Std.string(funkin.options.Options.intensiveBlur));
            editor.set("maxUndos", Std.string(funkin.options.Options.maxUndos));
            editor.set("autoSaves", Std.string(funkin.options.Options.charterAutoSaves));
            editor.set("autoSaveTime", Std.string(funkin.options.Options.charterAutoSaveTime));
            root.addChild(editor);

            writeSol('<?xml version="1.0" encoding="UTF-8"?>\n' + root.toString());
        }
        catch (e)
        {
            trace('[ClientPrefs] Error saving: ' + e);
        }
    }

    static function writeXmlColorList(name:String, values:Array<Int>):Xml
    {
        var section = Xml.createElement(name);
        if (values != null)
        {
            for (i in 0...values.length)
            {
                var c = Xml.createElement("color");
                c.set("index", Std.string(i));
                c.set("value", Std.string(values[i]));
                section.addChild(c);
            }
        }
        return section;
    }

    /**
     * ¿Scroll hacia abajo?
     * Lee "downscrool" del JSON (typo original del autor, se respeta).
     */
    public static function isDownScroll():Bool
        return getBool(data, "downscrool", false);

    public static function setDownScroll(v:Bool):Void
        Reflect.setField(data, "downscrool", v);

    public static function isBotplay():Bool
        return getBool(data, "botplay", false);

    public static function setBotplay(v:Bool):Void
        Reflect.setField(data, "botplay", v);

    public static function isMiddleScroll():Bool
        return getBool(data, "middlescroll", false);

    public static function setMiddleScroll(v:Bool):Void
        Reflect.setField(data, "middlescroll", v);

    public static function isGhostTapping():Bool
        return getBool(data, "ghostTapping", true);

    public static function setGhostTapping(v:Bool):Void
        Reflect.setField(data, "ghostTapping", v);

    public static function isMissSound():Bool
        return getBool(data, "missSound", true);

    public static function setMissSound(v:Bool):Void
        Reflect.setField(data, "missSound", v);

    public static function isNoteSplashes():Bool
        return getBool(data, "noteSplashes", true);

    public static function setNoteSplashes(v:Bool):Void
        Reflect.setField(data, "noteSplashes", v);

    /** Saltar el splash inicial e ir directo al TITLE. */
    public static function isSkipIntro():Bool
        return getBool(data, "skipIntro", false);

    public static function setSkipIntro(v:Bool):Void
        Reflect.setField(data, "skipIntro", v);

    /** Codigo del idioma guardado (carpeta en assets/languages/). */
    public static function getLanguage():String
    {
        var v = Reflect.hasField(data, "language") ? Std.string(Reflect.field(data, "language")) : "es";
        v = v == null ? "" : StringTools.trim(v);
        return v.length > 0 ? v : "es";
    }

    public static function setLanguage(v:String):Void
        Reflect.setField(data, "language", v == null ? "es" : StringTools.trim(v));

    /** Id del skin de notas (assets/images/game/notes/skins/<id>/noteSkin.xml). */
    public static function getNoteSkin():String
    {
        var v = Reflect.hasField(data, "noteSkin") ? Std.string(Reflect.field(data, "noteSkin")) : "default";
        v = v == null ? "" : StringTools.trim(v);
        return v.length > 0 ? v : "default";
    }

    public static function setNoteSkin(v:String):Void
        Reflect.setField(data, "noteSkin", v == null ? "default" : StringTools.trim(v));

    public static function getMasterVolume():Float
    {
        return clamp01(asFloat(Reflect.field(data, "masterVolume"), 1.0));
    }

    public static function setMasterVolume(v:Float):Void
        Reflect.setField(data, "masterVolume", clamp01(v));

    public static function getMusicVolume():Float
    {
        return clamp01(asFloat(Reflect.field(data, "musicVolume"), 1.0));
    }

    public static function setMusicVolume(v:Float):Void
        Reflect.setField(data, "musicVolume", clamp01(v));

    public static function getSfxVolume():Float
    {
        return clamp01(asFloat(Reflect.field(data, "sfxVolume"), 1.0));
    }

    public static function setSfxVolume(v:Float):Void
        Reflect.setField(data, "sfxVolume", clamp01(v));

    public static function applyAudio():Void
    {
        try
        {
            if (FlxG.sound.music != null)
                FlxG.sound.music.volume = getMasterVolume() * getMusicVolume();
        }
        catch (e:Dynamic) {}
    }

    /**
     * Nombre del archivo multikey (sin extensión ni ruta).
     * Lee "multikeysettings" del JSON.
     */
    public static function getMultikeyFile():String
    {
        var v = Reflect.hasField(data, "multikeysettings")
            ? Std.string(Reflect.field(data, "multikeysettings")) : "";
        return (v != null && v.length > 0) ? v : "multikeyData";
    }

    public static function getLaneCount():Int
        return clampInt(getInt(data, "laneCount", 4), MIN_LANES, MAX_LANES);

    public static function setLaneCount(v:Int):Void
        data.laneCount = clampInt(v, MIN_LANES, MAX_LANES);

    /**
     * Devuelve cuántas lanes tiene la strumLine indicada.
     * strumLineIdx 0 = player, 1 = enemy (según isPlayerStrumLine en PlayState).
     */
    public static function getLaneCountForStrumLine(strumLineIdx:Int):Int
    {
        var arr:Array<Dynamic> = Std.isOfType(data.laneCountPerStrumLine, Array)
            ? cast data.laneCountPerStrumLine : null;

        if (arr != null && strumLineIdx >= 0 && strumLineIdx < arr.length)
        {
            var n = clampInt(Std.int(asFloat(arr[strumLineIdx], getLaneCount())), MIN_LANES, MAX_LANES);
            return n;
        }
        return getLaneCount();
    }

    public static function getLaneCountPerStrumLine():Array<Int>
    {
        var arr:Array<Dynamic> = Std.isOfType(data.laneCountPerStrumLine, Array)
            ? cast data.laneCountPerStrumLine : null;

        if (arr == null) return [getLaneCount(), getLaneCount()];

        var out:Array<Int> = [];
        for (v in arr) out.push(clampInt(Std.int(asFloat(v, getLaneCount())), MIN_LANES, MAX_LANES));
        return out;
    }

    public static function setLaneCountForStrumLine(strumLineIdx:Int, v:Int):Void
    {
        if (!Std.isOfType(data.laneCountPerStrumLine, Array))
            data.laneCountPerStrumLine = [getLaneCount(), getLaneCount()];

        var arr:Array<Int> = cast data.laneCountPerStrumLine;
        while (arr.length <= strumLineIdx) arr.push(getLaneCount());
        arr[strumLineIdx] = clampInt(v, MIN_LANES, MAX_LANES);
        data.laneCountPerStrumLine = arr;
    }

    public static function getLaneKeys(lane:Int):Array<String>
    {
        var lanes:Array<Dynamic> = Std.isOfType(data.laneKeys, Array) ? cast data.laneKeys : null;
        if (lanes == null || lane < 0 || lane >= lanes.length) return [];

        var raw = lanes[lane];
        if (!Std.isOfType(raw, Array)) return [];
        return normalizeKeys(cast raw, []);
    }

    public static function setLaneKeys(lane:Int, keys:Array<String>):Void
    {
        if (!Std.isOfType(data.laneKeys, Array)) data.laneKeys = defaultLaneKeys();
        var lanes:Array<Array<String>> = cast data.laneKeys;
        while (lanes.length <= lane) lanes.push([]);
        lanes[lane] = normalizeKeys(cast keys, []);
        data.laneKeys = lanes;
        syncLegacyLaneFields();
    }

    public static function getGamepadLaneButtons():Array<String>
    {
        var raw:Array<Dynamic> = getArrayField(data, "gamepadLaneButtons");
        return normalizeGamepadButtons(raw, cast defaultGamepadLaneButtons());
    }

    public static function setGamepadLaneButton(lane:Int, button:String):Void
    {
        var buttons = getGamepadLaneButtons();
        while (buttons.length <= lane) buttons.push("");
        buttons[lane] = button == null ? "" : StringTools.trim(button).toUpperCase();
        data.gamepadLaneButtons = buttons;
    }

    static function normalizeGamepadButtons(arr:Array<Dynamic>, fallback:Array<String>):Array<String>
    {
        var out:Array<String> = [];
        if (arr != null)
        {
            for (v in arr)
            {
                var s = v == null ? "" : StringTools.trim(Std.string(v)).toUpperCase();
                out.push(s);
            }
        }

        while (out.length < MAX_LANES)
            out.push(out.length < fallback.length ? fallback[out.length] : "");

        if (out.length > MAX_LANES)
            out = out.slice(0, MAX_LANES);

        return out;
    }

    public static function getMenuKeyboard(action:String):Array<String>
    {
        var menu:Dynamic = Reflect.field(data, "menuKeys");
        if (menu == null) menu = defaultMenuKeys();
        var v:Dynamic = Reflect.field(menu, action);
        return normalizeKeys(Std.isOfType(v, Array) ? cast v : [], []);
    }

    public static function getMenuGamepad(action:String):String
    {
        var menu:Dynamic = Reflect.field(data, "menuGamepad");
        if (menu == null) menu = defaultMenuGamepad();
        var v:Dynamic = Reflect.field(menu, action);
        if (v == null || Std.string(v).length == 0)
        {
            var defaults = defaultMenuGamepad();
            v = Reflect.field(defaults, action);
        }
        return Std.string(v).toUpperCase();
    }

    public static function setMenuKeyboard(action:String, slot:Int, key:String):Void
    {
        var menu:Dynamic = ensureMenuMap("menuKeys", defaultMenuKeys());
        var values:Array<String> = getMenuKeyboard(action);
        while (values.length <= slot) values.push("");
        values[slot] = key == null ? "" : StringTools.trim(key).toUpperCase();
        Reflect.setField(menu, action, values);
        data.menuKeys = menu;
    }

    public static function setMenuGamepad(action:String, button:String):Void
    {
        var menu:Dynamic = ensureMenuMap("menuGamepad", defaultMenuGamepad());
        Reflect.setField(menu, action, button == null ? "" : StringTools.trim(button).toUpperCase());
        data.menuGamepad = menu;
    }

    static function ensureMenuMap(field:String, defaults:Dynamic):Dynamic
    {
        var value = Reflect.field(data, field);
        if (value == null)
        {
            value = defaults;
            Reflect.setField(data, field, value);
        }
        return value;
    }

    static function loadMenuBindingsFromDynamic(parsed:Dynamic):Void
    {
        var kb = Reflect.field(parsed, "menuKeys");
        if (kb != null) data.menuKeys = normalizeMenuKeyboard(kb);

        var gp = Reflect.field(parsed, "menuGamepad");
        if (gp != null) data.menuGamepad = normalizeMenuGamepad(gp);
    }

    static function loadMenuBindingsFromXml(menu:Xml):Void
    {
        var keyboard = firstChild(menu, "keyboard");
        if (keyboard != null)
        {
            var map = defaultMenuKeys();
            for (action in keyboard.elementsNamed("action"))
            {
                var name = action.get("name");
                if (name == null) continue;
                var values:Array<String> = [];
                for (key in action.elementsNamed("key"))
                {
                    var keyName = key.get("name");
                    if (keyName != null && keyName.length > 0) values.push(keyName);
                }
                Reflect.setField(map, name, normalizeKeys(values, []));
            }
            data.menuKeys = normalizeMenuKeyboard(map);
        }

        var gamepad = firstChild(menu, "gamepad");
        if (gamepad != null)
        {
            var map = defaultMenuGamepad();
            for (action in gamepad.elementsNamed("action"))
            {
                var name = action.get("name");
                var button = action.get("button");
                if (name != null && button != null) Reflect.setField(map, name, button);
            }
            data.menuGamepad = normalizeMenuGamepad(map);
        }
    }

    static function writeMenuBindingsXml():Xml
    {
        var root = Xml.createElement("menuControls");

        var keyboard = Xml.createElement("keyboard");
        var actions = ["up", "down", "left", "right", "accept", "back", "pause"];
        for (action in actions)
        {
            var node = Xml.createElement("action");
            node.set("name", action);
            for (keyName in getMenuKeyboard(action))
            {
                if (keyName == null || keyName.length == 0) continue;
                var key = Xml.createElement("key");
                key.set("name", keyName);
                node.addChild(key);
            }
            keyboard.addChild(node);
        }
        root.addChild(keyboard);

        var gamepad = Xml.createElement("gamepad");
        for (action in actions)
        {
            var node = Xml.createElement("action");
            node.set("name", action);
            node.set("button", getMenuGamepad(action));
            gamepad.addChild(node);
        }
        root.addChild(gamepad);
        return root;
    }

    static function normalizeMenuKeyboard(value:Dynamic):Dynamic
    {
        var defaults = defaultMenuKeys();
        var out = {};
        for (action in ["up", "down", "left", "right", "accept", "back", "pause"])
        {
            var v = Reflect.field(value, action);
            var fallback:Array<String> = cast Reflect.field(defaults, action);
            Reflect.setField(out, action, normalizeKeys(Std.isOfType(v, Array) ? cast v : [], fallback));
        }
        return out;
    }

    static function normalizeMenuGamepad(value:Dynamic):Dynamic
    {
        var defaults = defaultMenuGamepad();
        var out = {};
        for (action in ["up", "down", "left", "right", "accept", "back", "pause"])
        {
            var v = Reflect.field(value, action);
            var fallback = Std.string(Reflect.field(defaults, action));
            var text = v == null ? fallback : StringTools.trim(Std.string(v)).toUpperCase();
            if (text.length == 0) text = fallback;
            Reflect.setField(out, action, text);
        }
        return out;
    }

    /** Opacidad de los receptores, leída de colors/@strumAlpha en settings.xml. */
    public static function getStrumAlpha():Float
        return clamp01(getFloat(data, "strumAlpha", 0.95));

    public static function noteColorForLane(lane:Int, pressed:Bool = false, ?laneCount:Int):Int
    {
        var colors:Array<Int> = pressed
            ? normalizeColorArray(getArrayField(data, "pressedColors"), cast defaultData().pressedColors, CENTER_COLOR)
            : normalizeColorArray(getArrayField(data, "noteColors"),    cast defaultData().noteColors,    CENTER_COLOR);

        if (colors == null || colors.length == 0)
            colors = pressed ? cast defaultData().pressedColors : cast defaultData().noteColors;

        var total = laneCount != null ? clampInt(laneCount, MIN_LANES, MAX_LANES) : getLaneCount();
        if (lane < 0) lane = 0;
        if (lane >= total) lane = total - 1;

        var idx = colorIndexForLane(lane, total);
        if (idx < 0) idx = 0;
        if (idx >= colors.length) idx = colors.length - 1;
        if (idx < 0) idx = 0;

        return withAlpha(colors[idx]);
    }

    /** Los tres colores que `NoteRGBShader` le suma a cada canal. */
    public static function noteRgbForLane(lane:Int, pressed:Bool = false, ?laneCount:Int):Array<Int>
    {
        return rgbFromBase(noteColorForLane(lane, pressed, laneCount));
    }

    /** Igual que `noteRgbForLane` pero desde un color ya resuelto (lo usan los note skins). */
    public static function rgbFromBase(base:Int):Array<Int>
    {
        var r = (base >> 16) & 0xFF;
        var g = (base >> 8) & 0xFF;
        var b = base & 0xFF;
        return [
            0xFF000000 | (r << 16) | (g << 8) | b,
            0xFFFFFFFF,
            0xFF000000 | (scale(r, RGB_SHADOW) << 16) | (scale(g, RGB_SHADOW) << 8) | scale(b, RGB_SHADOW + RGB_SHADOW_BLUE_LIFT)
        ];
    }

    /**
     * Paleta del receptor en reposo: gris parejo para todas las lanes (`strumDefaultColor`, 0x828282
     * de base).
     */
    public static function idleRgb():Array<Int>
    {
        var base = getInt(data, "strumDefaultColor", 0x828282);
        var r = (base >> 16) & 0xFF;
        var g = (base >> 8) & 0xFF;
        var b = base & 0xFF;
        return [
            0xFF000000 | (r << 16) | (g << 8) | b,
            0xFF000000 | (r << 16) | (g << 8) | b,
            0xFF000000 | (scale(r, 0.5) << 16) | (scale(g, 0.5) << 8) | scale(b, 0.55)
        ];
    }

    /** Cuanto se atenua el canal azul de la sombra. */
    static final RGB_SHADOW:Float = 0.35;
    /** Y el empuje extra de azul que mantiene las flechas frias en vez de apagadas. */
    static final RGB_SHADOW_BLUE_LIFT:Float = 0.12;

    static inline function scale(channel:Int, factor:Float):Int
    {
        return clampInt(Std.int(Math.round(channel * factor)), 0, 255);
    }

    public static function laneVisualIndex(lane:Int, ?laneCount:Int):Int
    {
        var total = laneCount != null ? clampInt(laneCount, MIN_LANES, MAX_LANES) : getLaneCount();
        if (lane < 0) lane = 0;
        if (lane >= total) lane = total - 1;

        if (total % 2 == 1 && lane == Std.int(Math.floor(total / 2))) return -1;
        return colorIndexForLane(lane, total);
    }

    /**
     * Indice en la paleta `noteColors` para cada lane (izq -> der).
     * 4K: [0 morado, 1 celeste, 2 verde, 3 rojo] = LEFT, DOWN, UP, RIGHT.
     * Multikey: mitad izquierda usa 4..7, mitad derecha 0..3 (de afuera hacia el centro), centro impar = 8.
     */
    public static function colorIndexForLane(lane:Int, total:Int):Int
    {
        if (total <= 4) return clampInt(lane, 0, 3);

        if (total == 5) return switch (lane) {
            case 0: 0; case 1: 1; case 2: 8; case 3: 2; default: 3;
        };

        var half = Std.int(total / 2);
        if (total % 2 == 1)
        {
            if (lane == half) return 8;
            if (lane < half) return clampInt(4 + lane, 4, 7);
            return clampInt(lane - half - 1, 0, 3);
        }

        if (lane < half) return clampInt(4 + lane, 4, 7);
        return clampInt(lane - half, 0, 3);
    }

    static function applyLegacyLaneFields():Void
    {
        if (!Std.isOfType(data.laneKeys, Array)) return;
        var lanes:Array<Array<String>> = cast data.laneKeys;
        data.leftKeys  = laneOrDefault(lanes, 0, ["LEFT",  "A"]);
        data.downKeys  = laneOrDefault(lanes, 1, ["DOWN",  "S"]);
        data.upKeys    = laneOrDefault(lanes, 2, ["UP",    "W"]);
        data.rightKeys = laneOrDefault(lanes, 3, ["RIGHT", "D"]);
    }

    static function syncLegacyLaneFields():Void
    {
        // laneKeys es la fuente de verdad del gameplay.
        // Los campos leftKeys/downKeys/upKeys/rightKeys son solamente
        // compatibilidad legacy y deben reflejar laneKeys, no pisarlo.
        if (!Std.isOfType(data.laneKeys, Array))
            data.laneKeys = defaultLaneKeys();

        var lanes:Array<Array<String>> = cast data.laneKeys;
        while (lanes.length < MAX_LANES) lanes.push([]);
        if (lanes.length > MAX_LANES) lanes = lanes.slice(0, MAX_LANES);

        data.laneKeys = lanes;
        applyLegacyLaneFields();
    }

    static function laneOrDefault(lanes:Array<Array<String>>, idx:Int, fallback:Array<String>):Array<String>
    {
        if (lanes == null || idx < 0 || idx >= lanes.length || lanes[idx] == null || lanes[idx].length == 0)
            return fallback.copy();
        return normalizeKeys(cast lanes[idx], fallback);
    }

    static function getLaneKeysFromParsed(parsed:Dynamic):Array<Dynamic>
    {
        var lk = getArrayField(parsed, "laneKeys");
        if (lk != null) return lk;

        var legacy:Array<Dynamic> = [];
        legacy.push(getArrayField(parsed, "leftKeys"));
        legacy.push(getArrayField(parsed, "downKeys"));
        legacy.push(getArrayField(parsed, "upKeys"));
        legacy.push(getArrayField(parsed, "rightKeys"));
        return legacy;
    }

    static function normalizeLaneKeys(arr:Array<Dynamic>, fallback:Array<Array<String>>):Array<Array<String>>
    {
        var out:Array<Array<String>> = [];
        if (arr != null)
        {
            for (v in arr)
            {
                if (Std.isOfType(v, Array))   out.push(normalizeKeys(cast v, []));
                else if (v != null)           out.push(normalizeKeys([Std.string(v)], []));
                else                          out.push([]);
            }
        }
        while (out.length < MIN_LANES) out.push([]);
        while (out.length < MAX_LANES) out.push([]);
        if (out.length == 0) return fallback.copy();
        return out;
    }

    static function normalizeColorArray(arr:Array<Dynamic>, fallback:Array<Int>, centerColor:Int):Array<Int>
    {
        var out:Array<Int> = [];
        if (arr != null) for (v in arr) { var c = parseColor(v); if (c != null) out.push(c); }
        if (out.length == 0) out = fallback.copy();
        while (out.length < 4) out.push(fallback[out.length % fallback.length]);
        return out;
    }

    static function parseColor(v:Dynamic):Null<Int>
    {
        if (v == null) return null;
        var s = StringTools.trim(Std.string(v));
        if (s.length == 0) return null;
        if (StringTools.startsWith(s, "0x") || StringTools.startsWith(s, "0X"))
            s = "0x" + s.substr(2);
        var n = Std.parseInt(s);
        if (n == null) { var f = Std.parseFloat(s); if (Math.isNaN(f)) return null; n = Std.int(f); }
        return withAlpha(n);
    }

    static inline function withAlpha(color:Int):Int
        return (color & 0xFF000000) != 0 ? color : (0xFF000000 | (color & 0x00FFFFFF));

    static function getArrayField(obj:Dynamic, field:String):Array<Dynamic>
    {
        if (obj == null || !Reflect.hasField(obj, field)) return null;
        var v:Dynamic = Reflect.field(obj, field);
        return Std.isOfType(v, Array) ? cast v : null;
    }

    static function getFloat(obj:Dynamic, field:String, fallback:Float):Float
    {
        if (obj == null || !Reflect.hasField(obj, field)) return fallback;
        var raw = Reflect.field(obj, field);
        if (raw == null) return fallback;
        var p = Std.parseFloat(Std.string(raw));
        return Math.isNaN(p) ? fallback : p;
    }

    static function getInt(obj:Dynamic, field:String, fallback:Int):Int
    {
        if (obj == null || !Reflect.hasField(obj, field)) return fallback;
        var v = Reflect.field(obj, field);
        if (v == null) return fallback;
        var n = Std.parseInt(Std.string(v));
        return n == null ? fallback : n;
    }

    static function getBool(obj:Dynamic, field:String, fallback:Bool):Bool
    {
        if (obj == null || !Reflect.hasField(obj, field)) return fallback;
        var v = Reflect.field(obj, field);
        if (v == null) return fallback;
        if (Std.isOfType(v, Bool)) return cast v;
        var s = StringTools.trim(Std.string(v)).toLowerCase();
        return (s == "true" || s == "1" || s == "yes" || s == "on");
    }

    static function clampInt(v:Int, min:Int, max:Int):Int
        return v < min ? min : (v > max ? max : v);

    static function asFloat(v:Dynamic, fallback:Float):Float
    {
        if (v == null) return fallback;
        var p = Std.parseFloat(Std.string(v));
        return Math.isNaN(p) ? fallback : p;
    }

    static function normalizeKeys(arr:Array<Dynamic>, fallback:Array<String>):Array<String>
    {
        if (arr == null) return fallback.copy();
        var out:Array<String> = [];
        for (v in arr)
        {
            var s = Std.string(v);
            if (s == null) continue;
            s = StringTools.trim(s).toUpperCase();
            if (s.length == 0) continue;
            out.push(s);
        }
        return out.length > 0 ? out : fallback.copy();
    }

    static inline function clamp01(v:Float):Float
    {
        return v < 0 ? 0 : (v > 1 ? 1 : v);
    }
}

