package hxAnonCls;

import haxe.macro.*;
#if macro
import haxe.macro.Expr;
import tink.macro.Types;
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

	static function mapWithHint(expr:Expr):Expr {
		return switch (expr) {
			case macro super.$field:
				macro @:pos(expr.pos) ___super___.$field;
			case macro super:
				macro @:pos(expr.pos) ___superNew___;
			case macro this:
				macro @:pos(expr.pos) ___this___;
			case _:
				ExprTools.map(expr, mapWithHint);
		}
	}

	static function unmapWithHint(expr:Expr):Expr {
		return switch (expr) {
			case macro ___super___.$field:
				macro @:pos(expr.pos) super.$field;
			case macro ___superNew___:
				macro @:pos(expr.pos) super;
			case macro ___this___:
				macro @:pos(expr.pos) this;
			case _:
				ExprTools.map(expr, unmapWithHint);
		}
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

							var existingFields = switch (Types.getFields(t)) {
								case Failure(err): Context.error(err.message, err.pos);
								case Success(fs): fs;
							}
							var typeHints =
								[
									for (f in existingFields) {
										var fName = f.name;
										var fType = Context.toComplexType(f.type);
										macro var $fName:$fType;
									}
								]
								.concat([
									for (f in fields)
									if (f.name != "new")
									{
										var fName = f.name;
										switch (f.kind) {
											case FFun(fun):
												var existingType = 
												switch (existingFields.find(function(f) return f.name == fName))
												{
													case {type:TFun(args, ret)}:
														{args: args, ret:ret};
													case _:
														null;
												}
												var fType =
													TFunction(
														[
															for (a in fun.args)
															a.type
														],
														fun.ret != null ? fun.ret : Context.toComplexType(existingType.ret)
													);
												// trace(fType);
												var e = macro var $fName:$fType;
												// trace(ExprTools.toString(e));
												e;
											case FVar(t,e):
												macro var $fName:$t = $e;
											case FProp(_, _, t, e):
												macro var $fName:$t = $e;
										}
									}
								])
								.concat([
									{
										//___super___
										var ct = Context.toComplexType(t);
										macro var ___super___:$ct;
									},
									{	
										//___this___
										//TODO: should not use TExtend, but to construct TAnonymous manually
										var ct = TExtend([typeToTypePath(t)], [
											for (f in fields)
											if (!existingFields.exists(function(ef) return ef.name == f.name || f.name == "new"))
											{
												access: f.access,
												name: f.name,
												kind: switch (f.kind) {
													case FFun(fun):
														FFun({
															params: fun.params,
															args: fun.args,
															ret: if (fun.ret != null) {
																fun.ret;
															} else {
																var sf = existingFields.find(function(ef) return ef.name == f.name);
																if (sf == null) {
																	try {
																		Context.toComplexType(Context.typeof(fun.expr));
																	} catch (err:Dynamic) {
																		Context.error("Explict return type needed.", f.pos);
																	}
																} else {
																	switch (sf.type) {
																		case TFun(args, ret):
																			Context.toComplexType(ret);
																		case _:
																			throw sf.type;
																	}
																}
															},
															expr: null
														});
													case FVar(t, e):
														FVar(
															if (t != null || e == null) {
																t;
															} else {
																try {
																	Context.toComplexType(Context.typeof(e));
																} catch (err:Dynamic) {
																	Context.error("Explict type needed.", f.pos);
																}
															},
															null
														);
													case FProp(get, set, t, e):
														FProp(
															get,
															set,
															if (t != null || e == null) {
																t;
															} else {
																try {
																	Context.toComplexType(Context.typeof(e));
																} catch (err:Dynamic) {
																	Context.error("Explict type needed.", f.pos);
																}
															},
															null
														);
												},
												pos: f.pos,
											}
										]);
										macro var ___this___:$ct;
									}
								]);
							
							function getCtor(t:haxe.macro.Type.ClassType):Null<haxe.macro.Type.ClassField> {
								if (t == null)
									return null;
								if (t.constructor != null)
									return t.constructor.get();
								if (t.superClass != null)
									return getCtor(t.superClass.t.get());
								return null;
							}

							var ctor = getCtor(clsType);
							if (ctor != null) {
								//___superNew___
								var fType = Context.toComplexType(ctor.type);
								typeHints.push(macro var ___superNew___:$fType);
							}

							var clsFields:Array<Field> = [];
							for (f in fields) {
								clsFields.push({
									access: f.access,
									name: f.name,
									kind: switch (f.kind) {
										case FFun(fun):
											var e = {
												expr: EFunction(f.name, fun),
												pos: f.pos
											};
											var te = Context.getTypedExpr(Context.typeExpr(
												macro $b{typeHints.concat([mapWithHint(e)])}
											));
											switch (te) {
												case macro $b{es}:
													var laste = 
													switch (es[es.length-1]) {
														case macro {
															var $name:$type = $efun;
															$_;
														}:
															// trace(name);
															efun;
														case e:
															throw ExprTools.toString(e); 
													}
													switch (unmapWithHint(laste)) {
														case ue = {expr:EFunction(_, fun)}:
															// trace(ExprTools.toString(ue));
															FFun({
																params: fun.params,
																args: fun.args,
																ret: f.name == "new" ? null : fun.ret,
																expr: fun.expr,
															});
														case e:
															throw e;
													}
												case _: throw te;
											}
										case _: f.kind;
									},
									pos: f.pos
								});
							}

							// clsFields.unshift({
							// 	access: [APrivate],
							// 	name: "__impl__",
							// 	kind: FVar(null, {
							// 		var ofields = [
							// 			for (f in fields)
							// 			if (f.kind.match(FFun(_)))
							// 			{
							// 				field: f.name,
							// 				expr: switch(f.kind) {
							// 					case FFun(fun):
							// 						{
							// 							expr: EFunction(null, fun),
							// 							pos: f.pos
							// 						}
							// 					case _: throw "should be FFun";
							// 				}
							// 			}
							// 		];
							// 		{
							// 			expr: EObjectDecl(ofields),
							// 			pos: Context.currentPos()
							// 		}
							// 	}),
							// 	pos: Context.currentPos(),
							// });

							if (
								(clsType.isInterface || clsType.constructor == null) &&
								!clsFields.exists(function(f) return f.name == "new")
							) {
								clsFields.push({
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
								fields: clsFields,
								pos: expr.pos
							}

							Context.defineType(typeDef);
							// Context.defineModule(
							// 	localModule.join("."),
							// 	[typeDef]
							// 	#if (haxe_ver >= 3.2),
							// 	[],
							// 	[for (ct in Context.getLocalUsing()) {
							// 		var ct = ct.get();
							// 		{
							// 			pack: ct.pack,
							// 			name: ct.name,
							// 			params: [],
							// 		}
							// 	}]
							// 	#end
							// );
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