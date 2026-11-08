package funky.game;

import flixel.FlxSprite;
import funky.core.ClientPrefs;
import funky.core.NoteRGBShader;
import funky.core.NoteSkin;

/** Four-key receptor adapted from Codename's Strum, without controls or scripting layers. */
class Strum extends FlxSprite
{
	public var lane(default, null):Int;
	public var laneCount(default, null):Int;
	public var lastHit:Float = -5000;

	/** Skin con el que se creo este receptor (los cambios se aplican al reiniciar la cancion). */
	var skin:NoteSkin;

	/**
	 * Estado presionado para el que hay un shader asignado. `null` = todavia no se
	 * asigno ninguno, asi que el primer `applyColor` siempre entra.
	 */
	var rgbPressed:Null<Bool> = null;

	/** `confirm(..., false)` lo marca cada frame que un sustain sigue sonando; `updateInput` lo consume. */
	var holding:Bool = false;

	/**
	 * The "confirm" frames are ~230px wide against a ~154px receptor. Playing them on
	 * this sprite would make a hit spill over the neighbouring lane, so they live in
	 * their own sprite sized to the same slot, the way FNF handles it.
	 */
	public var confirmSprite(default, null):Null<FlxSprite>;

	public function new(lane:Int, x:Float, y:Float, slotWidth:Float = 110, laneCount:Int = 4)
	{
		super(x, y);
		this.lane = lane;
		this.laneCount = laneCount;
		skin = NoteSkin.current();

		var atlas = skin.frames();
		if (atlas != null)
		{
			frames = atlas;
			animation.addByPrefix("static", skin.animFor("receptor", lane), 24, false);
			animation.addByPrefix("pressed", skin.animFor("press", lane), 24, false);
			animation.play("static");
		}
		else makeGraphic(100, 100, 0xFF888888);
		// Fit the receptor to its lane slot instead of a hardcoded 0.7, otherwise
		// 5-9 lane charts draw the receptors on top of each other.
		setGraphicSize(Std.int(slotWidth), 0);
		updateHitbox();
		alpha = ClientPrefs.getStrumAlpha();
		applyColor(false);

		if (atlas != null)
		{
			confirmSprite = new FlxSprite(x, y);
			confirmSprite.frames = atlas;
			confirmSprite.animation.addByPrefix("confirm", skin.animFor("confirm", lane), 24, false);
			// Misma escala que el receptor: antes se medía con el frame 0 del atlas (no el confirm),
			// así el confirm salía con otro tamaño y corrido respecto al receptor.
			confirmSprite.scale.set(scale.x, scale.y);
			confirmSprite.updateHitbox();
			confirmSprite.alpha = ClientPrefs.getStrumAlpha();
			// El confirm usa el tinte presionado, igual que antes de usar el shader RGB.
			skin.applyTo(confirmSprite, lane, true, laneCount);
			confirmSprite.visible = false;
		}
	}

	/**
	 * El tinte RGB vive en el shader, asi que cambiar de color es cambiar de instancia.
	 * Flixel avisa que tocar `shader` seguido es caro, asi que `updateInput` solo lo hace
	 * cuando el estado presionado/reposo cambia de verdad.
	 */
	function applyColor(pressed:Bool):Void
	{
		if (pressed == rgbPressed) return;
		rgbPressed = pressed;

		switch (skin.type)
		{
			case SPARROW:
				shader = null;
			case TINT:
				// Reposo: el color base de los receptores (strumDefaultColor); apretado: el color de la nota.
				shader = null;
				color = pressed ? skin.tintFor(lane, true, laneCount) : ClientPrefs.strumIdleColor();
			case RGB:
				var colors = pressed ? skin.rgbFor(lane, true, laneCount) : ClientPrefs.idleRgb();
				shader = colors == null ? null : NoteRGBShader.forColors(colors);
		}
	}

	public function updateInput(pressed:Bool, justPressed:Bool):Void
	{
		applyColor(pressed);
		if (animation.numFrames > 0 || animation.getNameList().length > 0) animation.play(pressed ? "pressed" : "static");
		if (confirmSprite != null)
		{
			// Con el sustain sonando el confirm se queda en su ultimo frame; si no, se oculta al terminar.
			if (confirmSprite.animation.finished && !holding) confirmSprite.visible = false;
			holding = false;
			syncConfirm();
			// El receptor se oculta mientras se ve el confirm: antes se dibujaban uno sobre otro (flecha doble).
			visible = !confirmSprite.visible;
		}
	}

	/** Centra el confirm sobre el receptor (sus frames son mas grandes que el receptor). */
	function syncConfirm():Void
	{
		confirmSprite.updateHitbox();
		confirmSprite.setPosition(x + (width - confirmSprite.width) * 0.5, y + (height - confirmSprite.height) * 0.5);
	}

	/**
	 * @param restart true en golpes (cabeza de nota): reinicia la animacion. false en cada frame de un
	 *                sustain: solo la mantiene visible, sin reiniciarla (antes parpadeaba cada frame).
	 */
	public function confirm(songTime:Float, restart:Bool = true):Void
	{
		lastHit = songTime;
		if (confirmSprite == null) return;
		confirmSprite.alpha = ClientPrefs.getStrumAlpha();
		if (restart || !confirmSprite.visible)
			confirmSprite.animation.play("confirm", true);
		else
			holding = true;
		confirmSprite.visible = true;
		visible = false;
		syncConfirm();
	}
}
