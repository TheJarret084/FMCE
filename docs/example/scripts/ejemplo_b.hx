function onUpdateScore(missed)
{
    if (missed) {
        brillar(scoreTxt); // viene de ejemplo A
        accuracyTxt.text += " | fallos: " + vecesFallado;
    }
}

function onSongStart()
{
    // por si quieres llamar una funcion de un script concreto:
    scripts.getByName("ejemplo_a").call("brillar", [timeBar, 0.5]);

    // y cargar otro .hx del nivel (data/scripts/):
    // var utils = importScript("utils");
    // utils.call("algo", [1, 2]);
}

// Los dos nombres funcionan (puedes mezclar Psych y Codename en el mismo script):
function postCreate()      { /* Codename */ }
function onCreatePost()    { /* Psych    */ }
function beatHit(curBeat)  { if (curBeat % 4 == 0) hud.beatHit(); }   // Codename, recibe el beat
function onBeatHit()       { /* Psych, sin argumentos */ }
