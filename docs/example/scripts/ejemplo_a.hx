
public var vecesFallado = 0;
static var rondas = 0; // se comparte entre scripts

public function brillar(spr, tiempo:Float = 0.2)   // funcion compartida: otro script la llama como `brillar(x)`
{
    FlxTween.color(spr, tiempo, FlxColor.WHITE, FlxColor.WHITE);
}

function onCreatePost()
{
    healthBar.visible = false;         // oculta la barra de vida (igual que en Codename)
    missesTxt.color = 0xFFFF8AFF;
    hud.setTimeBarStyle("multi");      // "pinklime" | "mono" | "multi"
}

function noteMiss(note)
{
    vecesFallado++;
}

function onEnenyHit(note) {
    health -= health * (vecesFallado * 0.067);
}
