package hxAnonCls;

import haxe.macro.*;
#if macro
import haxe.macro.Expr;
using StringTools;
using Lambda;
#end

class AnonCls {
	#if macro
	static function typeToTypePath(t:Type):TypePath {
		return switch (Context.follow(t)) {
			case TInst(t, params):
				var clsType = t.get();
				{
					pack:clsType.pack, 
					name:clsType.module.substring(clsType.module.lastIndexOf(".")+1), 
					sub:clsType.name,
					params:[for (p in params) TPType(Context.toComplexType(p))]
				};
			case TEnum(t, params):
				var clsType = t.get();
				{
					pack:clsType.pack, 
					name:clsType.module.substring(clsType.module.lastIndexOf(".")+1), 
					sub:clsType.name,
					params:[for (p in params) TPType(Context.toComplexType(p))]
				};
			case TType(t, params):
				var clsType = t.get();
				{
					pack:clsType.pack, 
					name:clsType.module.substring(clsType.module.lastIndexOf(".")+1), 
					sub:clsType.name,
					params:[for (p in params) TPType(Context.toComplexType(p))]
				};
			case _: throw 'Cannot convert this to TypePath: $t';
		};
	}
	#end

	macro static public function make(expr:Expr):Expr {
		switch (expr) {
			case macro (new $t($a{args}):$extend):
				var ct = TPath(t);
				var t = Context.follow(Context.typeof(macro (null:$ct)));
				switch (t) {
					case TInst(_t, params):
						var clsType = _t.get();
						var fields = switch (extend) {
							case TAnonymous(fields): fields;
							case _: throw "It should be used in the form of `AnonCls.make((new MyClass():{ override public function xxx() return 'something'; }))`";
						};
						var moduleName = clsType.module.substring(clsType.module.lastIndexOf(".")+1);
						var posInfo = Context.getPosInfos(expr.pos);
						var superTypePath = typeToTypePath(t);
						var typeDef:TypeDefinition = {
							pack: clsType.pack,
							kind: if (clsType.isInterface) {
								TDClass(null, [superTypePath], false);
							} else {
								TDClass(superTypePath, null, false);
							},
							name: clsType.name + "_" + Context.getLocalModule().replace(".", "_") + "_" + posInfo.min,
							fields: if (
								(clsType.isInterface || clsType.constructor == null) &&
								!fields.exists(function(f) return f.name == "new")
							) {
								fields.concat([{
									name: "new",
									kind: FFun({
										args: [],
										ret: null,
										expr: macro {}
									}),
									pos: expr.pos
								}]);
							} else {
								fields;
							},
							pos: expr.pos
						}
						Context.defineType(typeDef);

						var tPath = { pack:typeDef.pack, name: typeDef.name };
						return macro new $tPath($a{args});
					default:
						throw "Only able to create anonymous class of class or interface.";
				}
			default:
				throw "It should be used in the form of `AnonCls.make((new MyClass():{ override public function xxx() return 'something'; }))`";
		}
		return macro {};
	}
}