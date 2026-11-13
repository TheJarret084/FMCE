package funky.core;

#if (!nme && !flash)
import funky.backend.shaders.CustomShader;

@:keep
class NoteSkinShader extends CustomShader
{
	public function new(fragSource:String, ?vertSource:String, ?name:String)
	{
		super();
		path = name == null ? "noteskin" : name;
		failed = fragSource == null || fragSource.length == 0;
		glFragmentSource = fragSource;
		if (vertSource != null && vertSource.length > 0) glVertexSource = vertSource;
	}
}
#end
