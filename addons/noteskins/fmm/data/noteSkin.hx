import funky.backend.shaders.CustomShader;

var _arrowShadow:CustomShader;
var pathShader:String = 'noteskins/' + skin.id + '/shaders';

function onLoad()
{
	_arrowShadow = new CustomShader('dropShadow', pathShader);
	_arrowShadow.hset('_alpha', 0.6); // transparencia de la sombra
	_arrowShadow.hset('_disx', 4.0);  // desplazamiento x
	_arrowShadow.hset('_disy', 10.0); // desplazamiento y
}

function onNote(note, lane)
{
	note.shader = _arrowShadow;
}

function onReceptor(strum, lane)
{
	strum.shader = _arrowShadow;
}

function onReceptorColor(strum, lane, pressed)
{
	strum.shader = _arrowShadow;
}

function onConfirm(sprite, lane)
{
	sprite.shader = _arrowShadow;
}

/*
function onSplash(splash, lane)
{
	splash.shader = _arrowShadow;
}
*/
