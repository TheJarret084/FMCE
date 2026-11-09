package advanced.editors;

import funkin.editors.ui.*;
import funkin.editors.ui.UIWarningSubstate.WarningButton;
import funky.game.SpriteBuilder;

/** Ventana para importar un sprite PNG con su atlas y vista previa (solo escritorio). */
class SpriteImportScreen extends UISubstateWindow
{
	var levelDir:String;
	var onDone:Null<String->Void>;

	var explorer:UIImageExplorer;
	var explorerLabel:UIText;
	var nameLabel:UIText;
	var nameBox:UITextBox;
	var saveButton:UIButton;
	var closeButton:UIButton;

	public function new(levelDir:String, ?onDone:String->Void)
	{
		super();
		this.levelDir = levelDir;
		this.onDone = onDone;
	}

	public override function create():Void
	{
		winTitle = "Importar sprite";
		winWidth = 360;
		winHeight = 230;
		super.create();

		explorerLabel = new UIText(20, windowSpr.y + 30 + 16 - 4, 0, "Imagen (.png / .jpg) - con su .xml o .json al lado si es atlas");
		add(explorerLabel);

		explorer = new UIImageExplorer(20, windowSpr.y + 30 + 16 + 20, 320, 58, function(_, _) refresh());
		add(explorer);

		nameLabel = new UIText(20, 0, 0, "Nombre del sprite");
		add(nameLabel);
		nameBox = new UITextBox(20, 0, "", 320, 32);
		add(nameBox);

		saveButton = new UIButton(0, 0, "Importar", doSave, 125);
		saveButton.selectable = false;
		add(saveButton);

		closeButton = new UIButton(0, 0, "Cancelar", function() close(), 125);
		closeButton.color = 0xFFFF0000;
		add(closeButton);

		refresh();
	}

	/** Reacomoda todo segun la altura que tenga el explorador (cambia al cargar la imagen). */
	function refresh():Void
	{
		var loaded = explorer.imageBytes != null;

		if (loaded && nameBox.label.text == "") nameBox.label.text = explorer.imageName;
		if (!loaded) nameBox.label.text = "";

		nameLabel.x = explorer.x;
		nameLabel.y = explorer.y + explorer.bHeight + 12;
		nameBox.x = explorer.x;
		nameBox.y = nameLabel.y + 18;

		windowSpr.bWidth = 20 + explorer.bWidth + 20;
		windowSpr.bHeight = Std.int(nameBox.y + nameBox.bHeight) + 14 + saveButton.bHeight + 14;

		saveButton.x = windowSpr.x + windowSpr.bWidth - 20 - saveButton.bWidth;
		closeButton.x = saveButton.x - 20 - closeButton.bWidth;
		closeButton.y = saveButton.y = nameBox.y + nameBox.bHeight + 14;

		saveButton.selectable = loaded;
	}

	function doSave():Void
	{
		var name = SpriteImporter.cleanName(nameBox.label.text);
		if (explorer.imageBytes == null || name == "") return;

		if (SpriteBuilder.exists(levelDir, name) || sys.FileSystem.exists(SpriteBuilder.spriteDir(levelDir, name)))
		{
			var buttons:Array<WarningButton> = [
				{
					label: "Reemplazar",
					color: 0xFFFF0000,
					onClick: function(_) write(name, true)
				},
				{
					label: "Cancelar",
					onClick: function(_) {}
				}
			];
			openSubState(new UIWarningSubstate("El sprite ya existe", "Ya hay un sprite llamado \"" + name + "\" en este nivel.\nReemplazar cambia su imagen y su atlas (su config.json se conserva).", buttons, false));
			return;
		}

		write(name, false);
	}

	function write(name:String, overwrite:Bool):Void
	{
		var error = SpriteImporter.importBytes(levelDir, name, explorer.imageBytes, explorer.isJpg, explorer.dataKind, explorer.dataText, overwrite);
		if (error != null)
		{
			openSubState(new UIWarningSubstate("No se pudo importar", error, [{label: "Cerrar", onClick: function(_) {}}]));
			return;
		}

		if (onDone != null) onDone(name);
		close();
	}
}
