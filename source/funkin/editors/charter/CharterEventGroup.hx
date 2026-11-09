package funkin.editors.charter;

import flixel.util.FlxSort;
import funkin.backend.system.Conductor;
import funkin.editors.charter.CharterBackdropGroup.EventBackdrop;

/** Grupo de eventos del charter. */
class CharterEventGroup extends FlxTypedGroup<CharterEvent> {
	public static var stopThisFuckingShitDudeIstg = false;
	public var eventsBackdrop:EventBackdrop;
	public var eventsRowText:UIText;

	public var autoSort:Bool = true;
	var __lastSort:Int = 0;

	/** Cada cuantos frames se barre la lista completa buscando eventos vacios (la ventana visible se filtra siempre). */
	static inline var FULL_FILTER_EVERY:Int = 60;
	var __framesSinceFullFilter:Int = 0;

	/** Ventana [__begin, __end) de `members` que esta a la vista. */
	var __begin:Int = 0;
	var __end:Int = 0;

	function updateRange() {
		var zoom:Float = camera != null ? camera.zoom : 1;
		var max:Float = FlxG.height / 70 / zoom + 2;

		var curStep:Float = Conductor.curStepFloat;
		if (!FlxG.sound.music.playing)
			curStep = Charter.instance.gridBackdrops.conductorSprY / 40;

		__begin = SortedArrayUtil.binarySearch(members, curStep - max, getStep);
		__end = SortedArrayUtil.binarySearch(members, curStep + max, getStep);
		if (__end < members.length) __end++;
	}

	/** Recorre solo los eventos visibles y los seleccionados que quedaron fuera de la ventana (arrastrados, p. ej.). */
	function forEachVisible(func:CharterEvent->Void) {
		updateRange();

		for (i in __begin...__end) {
			var e = members[i];
			if (e != null) func(e);
		}

		for (s in Charter.selection.copy())
			if (s != null && s is CharterEvent) {
				var e:CharterEvent = cast s;
				if (e.ID < __begin || e.ID >= __end) func(e);
			}
	}

	public override function update(elapsed:Float) {
		if (!CharterEventGroup.stopThisFuckingShitDudeIstg) {
			filterVisible();
			if (++__framesSinceFullFilter >= FULL_FILTER_EVERY) {
				__framesSinceFullFilter = 0;
				filterEvents();
			}
		}
		if (autoSort && members.length != __lastSort)
			sortEvents();

		forEachVisible(function(e:CharterEvent) {
			e.eventsBackdrop = eventsBackdrop;
			e.snappedToGrid = true;
			e.cameras = cameras;
			if (e.exists && e.active) e.update(elapsed);
		});

		eventsRowText.y = FlxMath.lerp(eventsRowText.y, -40 + (members[0] != null ? Math.min(members[0].y, 0) : 0), 1/10);
	}

	public override function remove(v:CharterEvent, force:Bool = true):CharterEvent {
		v.ID = -1;
		return super.remove(v, force);
	}

	public override function draw() {
		forEachVisible(function(e:CharterEvent) {
			e.eventsBackdrop = eventsBackdrop;
			e.snappedToGrid = true;
			e.cameras = cameras;
			if (e.exists && e.visible) e.draw();
		});
	}

	public inline function sortEvents() {
		__lastSort = members.length;
		this.sort(sortEventsFilter);
		updateEventsIDs();
		updateEventsBackdrop();
	}

	public inline function updateEventsIDs()
		for (i => n in members) n.ID = i;

	public inline function updateEventsBackdrop()
		for (event in members)
			event.eventsBackdrop = eventsBackdrop;

	/** Quita los eventos sin contenido de TODA la lista (de atras hacia adelante, para poder borrar mientras se recorre). */
	public function filterEvents() {
		var i = members.length - 1;
		while (i >= 0) {
			var event = members[i];
			if (event != null && event.events.length == 0) {
				remove(event, true);
				event.kill();
			}
			i--;
		}
	}

	/** Igual que `filterEvents` pero solo sobre la ventana visible. */
	function filterVisible() {
		updateRange();
		var i = __end - 1;
		while (i >= __begin) {
			var event = members[i];
			if (event != null && event.events.length == 0) {
				remove(event, true);
				event.kill();
			}
			i--;
		}
	}

	static function getStep(e:CharterEvent):Float
		return e.step;

	public dynamic function sortEventsFilter(i:Int, e1:CharterEvent, e2:CharterEvent)
		return FlxSort.byValues(FlxSort.ASCENDING, e1.step, e2.step);
}
