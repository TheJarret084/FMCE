var _arrowShadow:Dynamic = null;

function onLoad()
{
	// Sin carpeta, HudSkinScript ya busca hudskins/<id>/shaders y luego noteskins/<id>/shaders.
	_arrowShadow = shader('dropShadow');
	if (_arrowShadow == null) _arrowShadow = shader('dropShadow', 'hudskins/' + skin.id + '/shaders');
	if (_arrowShadow == null) return;
	_arrowShadow.hset('_alpha', 0.6);
	_arrowShadow.hset('_disx', 4.0);
	_arrowShadow.hset('_disy', 10.0);
	_arrowShadow.hset('inner', false);
	_arrowShadow.hset('inverted', false);
	_arrowShadow.hset('knockout', false);
}

function onNote(note, lane)
{
	setShader(note, _arrowShadow);
}

function onReceptor(strum, lane)
{
	setShader(strum, _arrowShadow);
	strum.alpha = 0.95;
}

function onReceptorColor(strum, lane, pressed)
{
	setShader(strum, _arrowShadow);
	strum.alpha = 0.95;
}

function onConfirm(sprite, lane)
{
	setShader(sprite, _arrowShadow);
}

function onSplash(splash, lane)
{
	setShader(splash, _arrowShadow);
}
