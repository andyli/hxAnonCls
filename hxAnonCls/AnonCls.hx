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
						var posInfo = Context.getPosInfos(expr.pos);
						var localModule = Context.getLocalModule().split(".");
						var localPack = localModule.copy();
						var localModuleName = localPack.pop();
						var clsName = localModuleName + "_" + clsType.name + "_" + posInfo.min;
						
						try {
							var type = Context.getType(localModule.join(".") + "." + clsName);
						} catch(err:Dynamic) {
							var fields = switch (extend) {
								case TAnonymous(fields): fields;
								case _: throw "It should be used in the form of `AnonCls.make((new MyClass():{ override public function xxx() return 'something'; }))`";
							};

							if (
								(clsType.isInterface || clsType.constructor == null) &&
								!fields.exists(function(f) return f.name == "new")
							) {
								fields.push({
									access: [APublic],
									name: "new",
									kind: FFun({
										args: [],
										ret: null,
										expr: macro {}
									}),
									pos: expr.pos
								});
							}
							
							var superTypePath = typeToTypePath(t);
							var typeDef:TypeDefinition = {
								pack: localModule,
								kind: if (clsType.isInterface) {
									TDClass(null, [superTypePath], false);
								} else {
									TDClass(superTypePath, null, false);
								},
								name: clsName,
								fields: fields,
								pos: expr.pos
							}
							Context.defineModule(
								localModule.join("."),
								[typeDef]
								#if (haxe_ver >= 3.2),
								[],
								[for (ct in Context.getLocalUsing()) {
									var ct = ct.get();
									{
										pack: ct.pack,
										name: ct.name,
										params: [],
									}
								}]
								#end
							);
						}

						var tPath = { pack:[], name:localModuleName, sub:clsName };
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