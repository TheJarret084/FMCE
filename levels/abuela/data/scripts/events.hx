import funky.core.WindowUtils;

function postCreate() {
    WindowUtils.winTitle = window.title = "postroff";
}

function onSongEnd() {
    WindowUtils.titleReset();
}