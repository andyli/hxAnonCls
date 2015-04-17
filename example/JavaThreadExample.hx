/*
	Use a build macro as follows (haxe 3.1.3+), or 
	add `--macro "hxAnonCls.Macros.buildAll()"` to our hxml (haxe 3.2+).
*/
@:build(hxAnonCls.Macros.build())
class JavaThreadExample {
	static function main():Void {
		/*
			Block Syntax

			When using this syntax, we provide a code block that contains
			variable or function declarations to somewhere an instance
			of a class/interface is expected.
			The block can be given to a `var` expression as follows,
			or to a function call as an argument.

			hxAnonCls automatically adds `@:overload`/`override`
			when needed when using this syntax.
		*/
		var thread:java.lang.Thread = {
			var msg = "running in a separated thread";
			function run():Void {
				trace(msg);
			}
		};
		thread.start();

		/*
			Type-Check Syntax

			The type-check expression is in the form of `(variable:Type)`.
			The (extra) parentheses are required.

			It allows higher customizability than block syntax.
			It lets us declare things that are not allowed with
			block syntax. For example, `public`, `inline`,
			`static`, metadata, and constructor.

			hxAnonCls doen't automatically adds `@:overload`/
			`override` - we have to be explicit when using this
			syntax.
		*/
		var thread = (new java.lang.Thread("my thread"):{
			var name:String;
			public function new(name:String):Void {
				super();
				this.name = name;
			}
			@:overload override function run():Void {
				trace("running " + name);
			}
		});
		thread.start();
	}
}