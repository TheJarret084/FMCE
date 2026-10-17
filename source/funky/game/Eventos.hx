package funky.game;

import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.core.Log;
import funky.game.Stage.StageObject;
import funky.scripting.Scripts;

/** Un evento de `events.json`: `time` es el tiempo ORIGINAL del archivo (segundos) y `actions` sus acciones. */
typedef Evento = {
	var time:Float;
	var actions:Array<Dynamic>;
	/** Posicion en el archivo: desempata dos eventos con el mismo `time` (el sort de Haxe no es estable). */
	var orden:Int;
}

/** Una transicion en curso. Corre con el tiempo de la MUSICA (no con el reloj del juego), asi se pausa y no se desfasa. */
private class Transicion
{
	public var clave:String;
	public var inicio:Float;
	public var duracion:Float;
	public var curva:Float->Float;
	/** Recibe el avance ya suavizado (0..1). */
	public var aplicar:Float->Void;

	public function new(clave:String, inicio:Float, duracion:Float, curva:Float->Float, aplicar:Float->Void)
	{
		this.clave = clave;
		this.inicio = inicio;
		this.duracion = duracion;
		this.curva = curva;
		this.aplicar = aplicar;
	}
}

/** Eventos del nivel (`events.json`): tipos y props en `docs/eventos.md`. */
class Eventos
{
	static inline var MAX_PACK_DEPTH:Int = 8;
	/** Curva cuando el evento dice "default"/"Classic" o no dice nada. */
	static final CURVA_BASE:Float->Float = FlxEase.cubeOut;
	/** Un flash de duracion 0 se ve al menos este rato (ms). */
	static inline var FLASH_MIN_MS:Float = 16;

	/** Todos los eventos, ordenados por `time`. */
	public var lista(default, null):Array<Evento> = [];
	/** `action_packs` del archivo: cada uno es una lista de acciones (para `RunActionPack`). */
	public var packs(default, null):Array<Array<Dynamic>>;
	/** Escenario del nivel; null si no trae `scene.json`. */
	public var stage(default, null):Null<Stage>;
	public var song(default, null):SongData;
	public var cargado(default, null):Bool = false;
	/** HUD del nivel; PlayState lo asigna cuando lo crea (Eventos se crea antes). */
	/** Vida maxima en la escala de FNMM (la de aqui es PlayHUD.MAX_HEALTH). */
	static inline var FNMM_MAX_HEALTH:Float = 30;

	public var hud:Null<PlayHUD> = null;

	/** Lo asigna PlayState: evento GUI (props.visible) para ocultar/mostrar strums, notas y HUD. */
	public var onGui:Null<Bool->Void> = null;

	var siguiente:Int = 0;
	var transiciones:Array<Transicion> = [];
	var avisados:Map<String, Bool> = new Map<String, Bool>();

	public function new(song:SongData, stage:Null<Stage>)
	{
		this.song = song;
		this.stage = stage;
		packs = song.actionPacks;

		var indice = 0;
		for (crudo in song.events)
			lista.push({time: numero(campo(crudo, "time")), actions: arreglo(campo(crudo, "actions")), orden: indice++});
		lista.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : a.orden - b.orden));

		cargado = lista.length > 0;
		if (cargado) Log.info('[Eventos] ' + lista.length + ' eventos, ' + packs.length + ' packs');
	}

	/** PlayState lo llama cada frame con el tiempo de la musica (ms). */
	public function update(songTime:Float):Void
	{
		while (siguiente < lista.length && lista[siguiente].time * 1000 <= songTime)
		{
			var evento = lista[siguiente];
			siguiente++;
			for (accion in evento.actions) ejecutarAccion(accion, evento.time * 1000, 0);
		}
		avanzar(songTime);
	}

	public function destroy():Void
	{
		lista = [];
		transiciones = [];
		avisados = new Map<String, Bool>();
		stage = null;
		hud = null;
		onGui = null;
	}

	function ejecutarAccion(accion:Dynamic, inicio:Float, profundidad:Int):Void
	{
		ejecutar(texto(campo(accion, "type"), ""), campo(accion, "props"), inicio, profundidad);
	}

	/** Hace UNA accion. `inicio` = tiempo (ms) en que debia pasar; de ahi cuentan sus transiciones. */
	public function ejecutar(tipo:String, props:Dynamic, inicio:Float, profundidad:Int = 0):Void
	{
		// onEvent(nombre, props, tiempo en ms): Function_Stop deja el evento sin ejecutar.
		if (Scripts.has && Scripts.call("onEvent", [tipo, props, inicio]))
			return;

		switch (tipo)
		{
			case "CameraSet": camaraSet(props, inicio);
			case "CameraZoom": camaraZoom(props, inicio);
			case "CameraShake", "CamaraShake": cameraShake(props);
			case "ObjectPositionSet": objetoPosicion(props, inicio);
			case "ObjectVisibilitySet": objetoVisibilidad(props);
			case "ObjectOpacitySet": objetoOpacidad(props, inicio);
			case "ObjectAnimationSet": objetoAnimacion(props);
			case "ScreenFlash": pantallaFlash(props, inicio);
			case "RunActionPack": correrPack(props, inicio, profundidad);
			case "BarIconChange", "BarIconChance": cambioIcon(props);
			case "ObjectSpriteSet": objetoSprite(props);
			case "ObjectChartChange": objetoChart(props);
			case "GUI": if (onGui != null) onGui(booleano(campo(props, "visible"), true));
			case "PlayerHealth": vidaJugador(props);
			default: avisar("tipo:" + tipo, 'evento desconocido "' + tipo + '" (props: ' + claves(props) + ')');
		}
	}

	/** PlayerHealth: value/minHealth vienen en la escala de FNMM (0..30); aqui se pasan a la del HUD. */
	function vidaJugador(props:Dynamic):Void
	{
		if (hud == null)
		{
			avisar("health:hud", 'PlayerHealth: todavia no hay HUD');
			return;
		}

		var escala = PlayHUD.MAX_HEALTH / FNMM_MAX_HEALTH;
		var valor = numeroDe(props, ["value"], 0) * escala;
		var minimo = numeroDe(props, ["minHealth"], 0) * escala;
		var vida = hud.health;

		switch (texto(campo(props, "operation"), "set").toLowerCase())
		{
			case "set": hud.setHealth(valor);
			case "add": hud.setHealth(vida + valor);
			// remove no baja de minHealth; si ya esta por debajo no se toca.
			case "remove", "sub", "subtract": if (vida > minimo) hud.setHealth(Math.max(minimo, vida - valor));
			default: avisar("health:op", 'PlayerHealth: operacion desconocida "' + texto(campo(props, "operation"), "") + '"');
		}
	}

	/** shakes = cuantas sacudidas, delay (+ timeUnit) = tiempo entre ellas, strength = pixeles. */
	function cameraShake(props:Dynamic):Void
	{
		var count = Std.int(numeroDe(props, ["shakes", "count"], 1));
		var delayMs = song.unitToMs(numeroDe(props, ["delay"], 0.1), texto(campo(props, "timeUnit"), "seconds"));
		var intensity = campo(props, "strength") != null ? numero(campo(props, "strength")) / FlxG.width : numeroDe(props, ["intensity"], 0.01);

		shakeLoop(count, Math.max(0.02, delayMs / 1000), intensity);
	}

	/** Una sacudida y, si quedan, la siguiente tras `delay` segundos. */
	function shakeLoop(count:Int, delay:Float, intensity:Float):Void
	{
		if (count <= 0) return;

		for (cam in FlxG.cameras.list)
			cam.shake(intensity, delay * 0.8);

		if (count > 1)
			new FlxTimer().start(delay, function(_) shakeLoop(count - 1, delay, intensity));
	}

	function cambioIcon(props:Dynamic):Void
	{
		if (hud == null)
		{
			avisar("icon:hud", 'BarIconChange: todavia no hay HUD');
			return;
		}

		var sprite = texto(campo(props, "sprite"), "");
		var target = Std.int(numero(campo(props, "target")));

		var icon:Null<HealthIcon> = switch (target)
		{
			case 0: hud.iconOpponent;
			case 1: hud.iconPlayer;
			default: null;
		}

		if (icon == null)
		{
			avisar("icon:" + target, 'BarIconChange: el target "' + target + '" esta fuera de rango (0 = oponente, 1 = jugador)');
			return;
		}

		if (sprite == "")
		{
			avisar("icon:sprite", 'BarIconChange: falta "sprite"');
			return;
		}

		icon.changeIcon(sprite);
	}

	function camaraSet(props:Dynamic, inicio:Float):Void
	{
		if (stage == null) return;
		var destino = Std.int(numero(campo(props, "target")));
		if (destino < 0 || destino >= stage.camPoints.length)
		{
			avisar("cam:" + destino, 'CameraSet: no existe la camara ' + destino);
			return;
		}
		var punto = stage.camPoints[destino];
		Scripts.call("onMoveCamera", [destino]);
		var x0 = stage.camX;
		var y0 = stage.camY;
		var s0 = stage.camScale;
		var st = stage;
		transicion("cam", inicio, duracion(props, "transitionTime", "transitionTimeUnit"), curvaDe(props), function(k)
		{
			st.camX = mezcla(x0, punto.x, k);
			st.camY = mezcla(y0, punto.y, k);
			st.camScale = mezcla(s0, punto.scale, k);
		});
	}

	function camaraZoom(props:Dynamic, inicio:Float):Void
	{
		if (stage == null) return;
		var z0 = stage.zoomMul;
		var z1 = numero(campo(props, "value"), 1);
		var st = stage;
		transicion("zoom", inicio, duracion(props, "transitionTime", "transitionTimeUnit"), curvaDe(props), function(k) st.zoomMul = mezcla(z0, z1, k));
	}

	function objetoPosicion(props:Dynamic, inicio:Float):Void
	{
		var objeto = buscar(props);
		if (objeto == null) return;
		var indice = Std.int(numero(campo(props, "transform")));
		if (indice < 0 || indice >= objeto.transforms.length)
		{
			avisar("tr:" + campo(props, "object") + ":" + indice, 'ObjectPositionSet: el objeto ' + campo(props, "object") + ' no tiene transform ' + indice);
			return;
		}
		var destino = objeto.transforms[indice];
		var x0 = objeto.x;
		var y0 = objeto.y;
		var s0 = objeto.scale;
		var sY0 = objeto.scaleY;
		var sx0 = objeto.scrollX;
		var sy0 = objeto.scrollY;
		transicion("pos:" + Std.int(numero(campo(props, "object"))), inicio, duracion(props, "transitionTime", "transitionTimeUnit"), curvaDe(props), function(k)
		{
			objeto.x = mezcla(x0, destino.x, k);
			objeto.y = mezcla(y0, destino.y, k);
			objeto.scale = mezcla(s0, destino.scale, k);
			objeto.scaleY = mezcla(sY0, destino.scaleY, k);
			objeto.scrollX = mezcla(sx0, destino.scrollX, k);
			objeto.scrollY = mezcla(sy0, destino.scrollY, k);
		});
	}

	function objetoVisibilidad(props:Dynamic):Void
	{
		var objeto = buscar(props);
		if (objeto != null) objeto.shown = booleano(campo(props, "value"), true);
	}

	function objetoOpacidad(props:Dynamic, inicio:Float):Void
	{
		var objeto = buscar(props);
		if (objeto == null) return;
		var o0 = objeto.opacity;
		var o1 = numero(campo(props, "value"), 1);
		transicion("opa:" + Std.int(numero(campo(props, "object"))), inicio, duracion(props, "transitionTime", "transitionTimeUnit"), curvaDe(props),
			function(k) objeto.opacity = mezcla(o0, o1, k));
	}

	function objetoAnimacion(props:Dynamic):Void
	{
		var objeto = buscar(props);
		if (objeto == null) return;
		var animacion = Std.int(numero(campo(props, "anim")));
		// En un objeto de video, "animacion" es el numero de video (0..count-1).
		if (objeto.video != null ? !stage.setVideo(objeto, animacion) : !objeto.sprite.playIndex(animacion, true))
			avisar("anim:" + campo(props, "object") + ":" + animacion, 'ObjectAnimationSet: el objeto ' + campo(props, "object") + ' no tiene la animacion ' + animacion);
	}

	function objetoSprite(props:Dynamic):Void
	{
		var objeto = buscar(props);
		if (objeto == null) return;

		var nombre = primerTexto(props, ["sprite", "spr", "name", "value"]);
		if (nombre == "")
		{
			avisar("spr:vacio", 'ObjectSpriteSet: falta el sprite (props: ' + claves(props) + ')');
			return;
		}

		if (!stage.setSprite(objeto, nombre))
			avisar("spr:" + nombre, 'ObjectSpriteSet: no se pudo poner "' + nombre + '" en el objeto ' + campo(props, "object") + ' (no esta en sprites/ o el objeto es un video)');
	}

	function objetoChart(props:Dynamic):Void
	{
		var objeto = buscar(props);
		if (objeto == null) return;

		var linea = primerNumero(props, ["chart", "strumLine", "strumline", "target", "value"]);
		if (linea == null)
		{
			avisar("chart:vacio", 'ObjectChartChange: falta el chart (props: ' + claves(props) + ')');
			return;
		}

		if (!stage.setChart(objeto, Std.int(linea)))
			avisar("chart:" + linea, 'ObjectChartChange: el chart ' + linea + ' no es valido (-1 = ninguno, 0 = jugador, 1 = oponente, 2+ = extras)');
	}

	function pantallaFlash(props:Dynamic, inicio:Float):Void
	{
		if (stage == null || stage.flash == null) return;
		var flash = stage.flash;
		var alfa = numero(campo(props, "alpha"), 1);
		flash.color = FlxColor.fromRGB(Std.int(numero(campo(props, "color_r"), 255)), Std.int(numero(campo(props, "color_g"), 255)), Std.int(numero(campo(props, "color_b"), 255)));
		flash.alpha = alfa;
		var ms = Math.max(FLASH_MIN_MS, song.unitToMs(numero(campo(props, "duration")), texto(campo(props, "timeUnit"), "seconds")));
		transicion("flash", inicio, ms, FlxEase.linear, function(k) flash.alpha = alfa * (1 - k));
	}

	function correrPack(props:Dynamic, inicio:Float, profundidad:Int):Void
	{
		var indice = Std.int(numero(campo(props, "actionPack")));
		if (profundidad >= MAX_PACK_DEPTH)
		{
			avisar("pack-prof:" + indice, 'RunActionPack ' + indice + ': demasiados packs anidados (' + MAX_PACK_DEPTH + ')');
			return;
		}
		if (indice < 0 || indice >= packs.length)
		{
			avisar("pack:" + indice, 'RunActionPack: no existe el pack ' + indice);
			return;
		}
		for (accion in packs[indice]) ejecutarAccion(accion, inicio, profundidad + 1);
	}

	/** Nueva transicion; si hay otra con la misma `clave` se reemplaza (la propiedad queda donde estaba). */
	function transicion(clave:String, inicio:Float, duracion:Float, curva:Float->Float, aplicar:Float->Void):Void
	{
		var i = transiciones.length;
		while (--i >= 0) if (transiciones[i].clave == clave) transiciones.splice(i, 1);
		if (duracion <= 0)
		{
			aplicar(1);
			return;
		}
		transiciones.push(new Transicion(clave, inicio, duracion, curva, aplicar));
	}

	function avanzar(tiempo:Float):Void
	{
		var i = 0;
		while (i < transiciones.length)
		{
			var t = transiciones[i];
			var avance = (tiempo - t.inicio) / t.duracion;
			if (avance >= 1)
			{
				t.aplicar(1);
				transiciones.splice(i, 1);
				continue;
			}
			if (avance > 0) t.aplicar(t.curva(avance));
			i++;
		}
	}

	inline function duracion(props:Dynamic, claveTiempo:String, claveUnidad:String):Float
		return song.unitToMs(numero(campo(props, claveTiempo)), texto(campo(props, claveUnidad), "seconds"));

	inline function curvaDe(props:Dynamic):Float->Float
		return curva(texto(campo(props, "easingType"), ""));

	/** Nombre de curva del archivo -> funcion de `FlxEase`. Ver la tabla en la cabecera de la clase. */
	static function curva(nombre:String):Float->Float
	{
		var n = nombre.toLowerCase();
		if (n == "" || n == "default" || n == "classic") return CURVA_BASE;

		var base = n;
		var modo = "";
		for (sufijo in ["inout", "in", "out"])
			if (n.length > sufijo.length && StringTools.endsWith(n, sufijo))
			{
				base = n.substr(0, n.length - sufijo.length);
				modo = sufijo;
				break;
			}
		if (modo == "") modo = (base == "bounce" || base == "elastic") ? "out" : "inout";

		return switch (base)
		{
			case "linear": FlxEase.linear;
			case "quad": elegir(modo, FlxEase.quadIn, FlxEase.quadOut, FlxEase.quadInOut);
			case "cube" | "cubic": elegir(modo, FlxEase.cubeIn, FlxEase.cubeOut, FlxEase.cubeInOut);
			case "circ": elegir(modo, FlxEase.circIn, FlxEase.circOut, FlxEase.circInOut);
			case "sine": elegir(modo, FlxEase.sineIn, FlxEase.sineOut, FlxEase.sineInOut);
			case "expo": elegir(modo, FlxEase.expoIn, FlxEase.expoOut, FlxEase.expoInOut);
			case "back": elegir(modo, FlxEase.backIn, FlxEase.backOut, FlxEase.backInOut);
			case "bounce": elegir(modo, FlxEase.bounceIn, FlxEase.bounceOut, FlxEase.bounceInOut);
			case "elastic": elegir(modo, FlxEase.elasticIn, FlxEase.elasticOut, FlxEase.elasticInOut);
			default: CURVA_BASE;
		};
	}

	static inline function elegir(modo:String, entrada:Float->Float, salida:Float->Float, ambas:Float->Float):Float->Float
		return modo == "in" ? entrada : (modo == "out" ? salida : ambas);

	/** El objeto de `props.object` (indice de `scene.json`), o null (con aviso una sola vez). */
	function buscar(props:Dynamic):Null<StageObject>
	{
		if (stage == null) return null;
		var objeto = stage.objectAt(campo(props, "object"));
		if (objeto == null) avisar("obj:" + campo(props, "object"), 'no existe el objeto ' + campo(props, "object") + ' de scene.json');
		return objeto;
	}

	/** Un aviso por clave: un evento roto se repite muchas veces y no debe llenar el log. */
	function avisar(clave:String, mensaje:String):Void
	{
		if (avisados.exists(clave)) return;
		avisados.set(clave, true);
		Log.warn('[Eventos] ' + mensaje);
	}

	static inline function mezcla(a:Float, b:Float, k:Float):Float return a + (b - a) * k;

	/** Nombres de las props que trae un evento (para avisos cuando falta una). */
	static function claves(props:Dynamic):String
		return props == null ? "ninguna" : Reflect.fields(props).join(", ");

	/** Primer texto no vacio entre varias claves posibles. */
	static function primerTexto(props:Dynamic, nombres:Array<String>):String
	{
		for (nombre in nombres)
		{
			var valor = campo(props, nombre);
			if (valor == null) continue;
			var cadena = Std.string(valor);
			if (cadena != "" && cadena != "null") return cadena;
		}
		return "";
	}

	/** Primer numero presente entre varias claves posibles, o null. */
	static function primerNumero(props:Dynamic, nombres:Array<String>):Null<Float>
	{
		for (nombre in nombres)
		{
			var valor = campo(props, nombre);
			if (valor == null) continue;
			var parsed = Std.parseFloat(Std.string(valor));
			if (!Math.isNaN(parsed)) return parsed;
		}
		return null;
	}

	static function numeroDe(props:Dynamic, nombres:Array<String>, defecto:Float):Float
	{
		var valor = primerNumero(props, nombres);
		return valor == null ? defecto : valor;
	}

	static inline function campo(objeto:Dynamic, nombre:String):Dynamic
		return objeto == null ? null : Reflect.field(objeto, nombre);

	static function arreglo(valor:Dynamic):Array<Dynamic>
		return Std.isOfType(valor, Array) ? cast valor : [];

	static function texto(valor:Dynamic, defecto:String):String
	{
		if (valor == null) return defecto;
		var convertido = Std.string(valor);
		return convertido == "null" ? defecto : convertido;
	}

	static function numero(valor:Dynamic, defecto:Float = 0):Float
	{
		if (valor == null) return defecto;
		var convertido = Std.parseFloat(Std.string(valor));
		return Math.isNaN(convertido) ? defecto : convertido;
	}

	static function booleano(valor:Dynamic, defecto:Bool):Bool
	{
		if (valor == null) return defecto;
		if (Std.isOfType(valor, Bool)) return valor == true;
		var convertido = Std.string(valor).toLowerCase();
		if (convertido == "true") return true;
		if (convertido == "false") return false;
		var n = Std.parseFloat(convertido);
		return Math.isNaN(n) ? defecto : n != 0;
	}
}
