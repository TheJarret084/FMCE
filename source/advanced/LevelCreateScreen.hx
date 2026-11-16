package advanced;

import advanced.AdvLang;
import funkin.editors.ui.*;
import funky.backend.LevelCreator;

/**
 * NUEVO NIVEL (como en Codename): primero se pide el nombre, que queda en meta.json como displayName.
 * La carpeta se crea con un identificador (base64 del timestamp de creacion), asi el nombre se puede repetir o cambiar.
 */
class LevelCreateScreen extends UISubstateWindow
{
	var onCreated:String->Void;

	var nameLabel:UIText;
	var nameBox:UITextBox;
	var hint:UIText;
	var error:UIText;
	var createButton:UIButton;
	var cancelButton:UIButton;

	public function new(onCreated:String->Void)
	{
		super();
		this.onCreated = onCreated;
	}

	public override function create():Void
	{
		winTitle = AdvLang.t("levelCreate.title", null, "Nuevo nivel");
		winWidth = 380;
		winHeight = 210;
		super.create();

		var wx = windowSpr.x;
		var wy = windowSpr.y;

		nameLabel = new UIText(wx + 20, wy + 46, 0, AdvLang.t("levelCreate.nameLabel", null, "Nombre del nivel"));
		add(nameLabel);

		nameBox = new UITextBox(wx + 20, wy + 66, "", 340, 32);
		add(nameBox);

		hint = new UIText(wx + 20, wy + 104, 0, AdvLang.t("levelCreate.hint", null, "Este nombre es el que se ve en los menus."));
		hint.alpha = 0.6;
		add(hint);

		error = new UIText(wx + 20, wy + 124, 0, "");
		error.color = 0xFFFF8A8A;
		add(error);

		createButton = new UIButton(wx + windowSpr.bWidth - 20 - 125, wy + winHeight - 14 - 32, AdvLang.t("levelCreate.create", null, "Crear"), doCreate, 125);
		add(createButton);

		cancelButton = new UIButton(createButton.x - 20 - 125, createButton.y, AdvLang.t("levelCreate.cancel", null, "Cancelar"), function() close(), 125);
		cancelButton.color = 0xFFFF0000;
		add(cancelButton);
	}

	function doCreate():Void
	{
		var result = LevelCreator.create(nameBox.label.text);
		if (!result.ok)
		{
			error.text = result.error;
			return;
		}
		var folder = result.folder;
		close();
		if (onCreated != null) onCreated(folder);
	}
}
