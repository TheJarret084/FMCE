public var finalNotesScale:Float = 0.7;

var noteSkin:String = "rempalago";

function create()
{
    if (stage != null && stage.stageXML != null)
    {
        if (stage.stageXML.exists("noteSkin"))
            noteSkin = stage.stageXML.get("noteSkin");
    }
}

function onStrumCreation(e)
{
	if (e.strum.strumLine.cpu) return;
    e.sprite = "game/notes/rempalago";

    switch (e.strum.ID)
    {
        case 0: e.animPrefix = "left";
        case 1: e.animPrefix = "down";
        case 2: e.animPrefix = "up";
        case 3: e.animPrefix = "right";
        case 4: e.animPrefix = "plusleft";
        case 5: e.animPrefix = "plusright";
    }
}

function onPostStrumCreation(e)
{
	if (e.strum.strumLine.cpu) return;
    e.strum.antialiasing = true;

    e.strum.scale.set(finalNotesScale, finalNotesScale);
    e.strum.updateHitbox();

    e.strum.x += (e.strum.ID - 2.5) * 18;
}


function onNoteCreation(e)
{
    if (e.note.strumLine.cpu) return;

    e.noteSprite = "game/notes/rempalago";
}


function onPostNoteCreation(e)
{
    if (e.note.strumLine.cpu) return;

    var note = e.note;
    var prefix:String = "";

    switch (note.strumID)
    {
        case 0: prefix = "purple";
        case 1: prefix = "blue";
        case 2: prefix = "green";
        case 3: prefix = "red";
        case 4: prefix = "yellow";
        case 5: prefix = "pink";
        default: return;
    }

    note.animation.addByPrefix("scroll", prefix + " head", 24, false);
    note.animation.addByPrefix("hold", prefix + " hold piece", 24, true);

    var endPrefix:String = prefix + " hold end";
    if (prefix == "purple")
        endPrefix = "pruple end hold";

    note.animation.addByPrefix("holdend", endPrefix, 24, false);

    if (note.isSustainNote)
    {
        if (note.nextSustain != null)
            note.animation.play("hold", true);
        else
            note.animation.play("holdend", true);
    }
    else
    {
        note.animation.play("scroll", true);
    }

    note.alpha = note.isSustainNote ? 0.6 : 1;
    note.antialiasing = true;

    if (!note.isSustainNote)
        note.scale.set(finalNotesScale, finalNotesScale);
    else
        note.scale.x = finalNotesScale;

    note.updateHitbox();
}


function onNoteHit(e)
{
    e.showSplash = false;
}