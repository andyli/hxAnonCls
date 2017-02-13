package hxAnonCls;

import haxe.macro.*;
#if macro
import haxe.macro.Type;
import hxAnonCls.Macros.*;
import hxAnonCls.Names.*;
import haxe.macro.Expr;
import tink.macro.Types;
using Lambda;
#end

class AnonCls {
	#if macro
	static var built = new Map<String, {args:Array<Expr>}>();
	#end
	macro static public function make(expr:Expr):Expr {
		function badSyntaxError():Dynamic {
			return Context.error("It should be used in the form of `(new Type():{ public function method() { } })`", expr.pos);
		}
		function notTInstError():Dynamic {
			return Context.error("Only able to create anonymous class of class or interface.", expr.pos);
		}
		var inputExpr = expr;
		var isBuild = switch (expr) {
			case macro @:hxAnonClsMacrosBuild $e:
				expr = e;
				true;
			case _:
				false;
		}
		if (!isBuild) {
			switch (expr) {
				case macro hxAnonCls.AnonCls.make(@:hxAnonClsMacrosBuild $e):
					expr = e;
				case _: //pass
			}
		}
		
		var input:{
			type:Type,
			args:Array<Expr>,
			fields:Array<Field>
		} = switch (expr) {
			case macro hxAnonCls.AnonCls.make($_): //in case the expr is wrapped by build macros
				return expr;
			case macro $b{exprs}:
				var type = Context.getExpectedType();
				if (type == null) {
					if (isBuild)
						return expr;
					else
						Context.error("Cannot figure out expected type.", expr.pos);
				}
				switch (Context.follow(type)) {
					case type = TInst(t, params):
						var existingFields = switch (Types.getFields(type)) {
							case Failure(err): Context.error(err.message, err.pos);
							case Success(fs): fs;
						}

						var clsType = t.get();
						if (clsType.constructor != null) {
							var ctr = clsType.constructor.get();
							switch (ctr.type) {
								case TFun([], _): //pass
								case ctrType:
									if (!ctr.meta.has(":overload")) {
										if (isBuild)
											return inputExpr;
										else {
											Context.error("Constructor requires input argument(s). Use type-check expression syntax instead.", expr.pos);
										}
									} else {
										// trace(ctr.meta.get());
									}
							}
						}

						{
							type: type,
							args: [],
							fields: [
								for (expr in exprs)
								switch (expr.expr) {
									case EVars([v]):
										var clsField = existingFields.find(function(f) return f.name == v.name);
										var access = [];
										var meta = [];
										if (clsField != null) {
											if (clsField.meta.has(":overload"))
												meta.push({
													name: ":overload",
													params: [],
													pos: Context.currentPos()
												});
										}

										{
											name: v.name,
											meta: meta,
											access: access,
											kind: FVar(v.type, v.expr),
											pos: expr.pos
										}
									case EFunction(name, fun):
										var clsField = existingFields.find(function(f) return f.name == name);
										var access = [];
										var meta = [];
										if (clsField != null) {
											if (!clsType.isInterface)
												access.push(AOverride);
											if (clsField.isPublic)
												access.push(APublic);
											if (clsField.meta.has(":overload"))
												meta.push({
													name: ":overload",
													params: [],
													pos: Context.currentPos()
												});
										}
										
										{
											name: name,
											meta: meta,
											access: access,
											kind: FFun(fun),
											pos: expr.pos
										}
									case _:
										if (isBuild)
											return inputExpr;
										else
											Context.error("Cannot convert expression to class field.", expr.pos);
								}
							]
						}
					case _:
						if (isBuild)
							return inputExpr;
						else
							notTInstError();
				}
			case macro (new $typePath($a{args}):$extend):
				var complexType = TPath(typePath);
				var t = Context.follow(Context.typeof(macro (null:$complexType)));
				switch (t) {
					case TInst(_t, params):
						{
							type: t,
							args: args,
							fields: switch (extend) {
								case TAnonymous(fields): fields;
								case _: badSyntaxError();
							}
						}
					default:
						notTInstError();
				}
			default:
				badSyntaxError();
		}
		var type = input.type;
		var typePath = typeToTypePath(type);
		var complexType = TPath(typePath);
		var args = input.args;
		var fields = input.fields;
		switch (type) {
			case TInst(clsType, params):
				var clsType = clsType.get();
				var posInfo = Context.getPosInfos(expr.pos);
				var localClass = Context.getLocalClass().get();
				var localClassCt = TPath({
					pack:localClass.pack,
					name:localClass.module.substring(localClass.module.lastIndexOf(".")+1),
					sub:localClass.name,
					params:[for (p in localClass.params) TPType(macro:Dynamic)]
				});
				var localModule = Context.getLocalModule().split(".");
				var localPack = localModule.copy();
				var localModuleName = localPack.pop();
				var clsName = localModuleName + "_" + clsType.name + "_" + posInfo.min;
				var clsFullName = localModule.join(".") + "." + clsName;
				if (built.exists(clsFullName)) {
					var builtData = built[clsFullName];
					args = builtData.args;
				} else {
					var existingFields = switch (Types.getFields(type)) {
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
											case null:
												null;
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
												if (fun.ret != null)
													fun.ret
												else
													if (existingType != null && existingType.ret != null)
														Context.toComplexType(existingType.ret)
													else
														macro:Dynamic
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
								//super
								macro var $superObjName:$complexType;
							},
							{
								//this
								//TODO: should not use TExtend, but to construct TAnonymous manually
								// var ct = TExtend([typeToTypePath(t)], [
								// 	for (f in fields)
								// 	if (!existingFields.exists(function(ef) return ef.name == f.name || f.name == "new"))
								// 	{
								// 		access: [for (a in f.access) if (a != AInline) a],
								// 		name: f.name,
								// 		kind: switch (f.kind) {
								// 			case FFun(fun):
								// 				FFun({
								// 					params: fun.params,
								// 					args: fun.args,
								// 					ret: if (fun.ret != null) {
								// 						fun.ret;
								// 					} else {
								// 						var sf = existingFields.find(function(ef) return ef.name == f.name);
								// 						if (sf == null) {
								// 							Context.error("Explict return type is needed.", f.pos);
								// 						} else {
								// 							switch (sf.type) {
								// 								case TFun(args, ret):
								// 									Context.toComplexType(ret);
								// 								case _:
								// 									throw sf.type;
								// 							}
								// 						}
								// 					},
								// 					expr: null
								// 				});
								// 			case FVar(t, e):
								// 				FVar(
								// 					if (t != null || e == null) {
								// 						t;
								// 					} else {
								// 						try {
								// 							Context.toComplexType(Context.typeof(e));
								// 						} catch (err:Dynamic) {
								// 							Context.error("Explict type is needed.", f.pos);
								// 						}
								// 					},
								// 					null
								// 				);
								// 			case FProp(get, set, t, e):
								// 				FProp(
								// 					get,
								// 					set,
								// 					if (t != null || e == null) {
								// 						t;
								// 					} else {
								// 						try {
								// 							Context.toComplexType(Context.typeof(e));
								// 						} catch (err:Dynamic) {
								// 							Context.error("Explict type is needed.", f.pos);
								// 						}
								// 					},
								// 					null
								// 				);
								// 		},
								// 		pos: f.pos,
								// 	}
								// ]);
								macro var $thisObjName:Dynamic;
							}
						]);

					// It may be inside a static function, where `this` cannot be used.
					try {
						Context.typeof(macro this);
						typeHints.push(
						{
							//parent
							macro var $parentIdent:$localClassCt = this;
						});
					} catch(e:Dynamic){
						typeHints.push(
						{
							//parent
							macro var $parentIdent = null;
						});
					}

					var ctor = getCtor(clsType);
					if (ctor != null) {
						//super()
						// var fType = Context.toComplexType(ctor.type);
						var fType = macro:Dynamic;
						typeHints.push(macro var $superCtorName:$fType);
					}

					var clsFields:Array<Field> = [];
					var hasParentAcc = false;
					var locals = [];
					var localNames = new Map();
					for (f in fields) {
						clsFields.push({
							doc: f.doc,
							meta: f.meta,
							access: f.access,
							name: f.name,
							kind: switch (f.kind) {
								case FVar(t, e):
									var ae = tohxAnonClsExpr(e, typeHints, locals);
									e = ae.e;
									if (ae.hasParentAcc) hasParentAcc = true;
									if (t != null) {
										t = Context.toComplexType(Context.typeof(macro (untyped null:$t)));
									}
									FVar(t, e);
								case FProp(get, set, t, e):
									var ae = tohxAnonClsExpr(e, typeHints, locals);
									e = ae.e;
									if (ae.hasParentAcc) hasParentAcc = true;
									if (t != null) {
										t = Context.toComplexType(Context.typeof(macro (untyped null:$t)));
									}
									FProp(get, set, t, e);
								case FFun(fun):
									var e = {
										expr: EFunction(f.name, fun),
										pos: f.pos
									};

									var ae = tohxAnonClsExpr(e, typeHints, locals);
									e = ae.e;
									if (ae.hasParentAcc) hasParentAcc = true;

									switch (e) {
										case macro {
											var $name:$type = ${{expr:EFunction(_, fun)}};
											$_;
										}:
											FFun({
												params: fun.params,
												args: fun.args,
												ret: f.name == "new" ? null : fun.ret,
												expr: fun.expr,
											});
										case e:
											throw ExprTools.toString(e);
									}
								case _: f.kind;
							},
							pos: f.pos
						});
					}

					for (v in locals.map(function(l) return
						switch(l.expr) {
							case TLocal(v): v;
							case _: throw "should be TLocal";
						})
					)
						localNames[v.name] = v.t;

					var needContext = hasParentAcc || locals.length > 0;
					var dynamicType = Context.getType("Dynamic");
					var contextCt = {
						var fields:Array<Field> = [];
						if (hasParentAcc) {
							fields.push({
								name: parentObjName,
								kind: FProp("default", "never", localClassCt, null),
								pos: Context.currentPos(),
							});
						}
						for (v in localNames.keys()) {
							var vCt = Context.toComplexType(localNames[v]);
							fields.push({
								meta: [{name:":optional", params: [], pos: Context.currentPos()}],
								name: v,
								kind: FProp("get", "set", vCt),
								pos: Context.currentPos(),
							});
							fields.push({
								name: getterName(v),
								kind: FFun({
									args: [],
									ret: vCt,
									expr: null,
								}),
								pos: Context.currentPos(),
							});
							fields.push({
								name: setterName(v),
								kind: FFun({
									args: [{name:setterArgName, type:vCt}],
									ret: vCt,
									expr: null,
								}),
								pos: Context.currentPos(),
							});
						}
						TAnonymous(fields);
					};

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

					var ctorField = clsFields.find(function(f) return f.name == "new");
					if (
						ctorField == null &&
						(needContext || clsType.isInterface || getCtor(clsType) == null)
					) {
						var superCtor = getCtor(clsType);
						var callArgs = [for (i in 0...args.length) {
							var name = "arg" + i;
							macro @:pos(args[i].pos) $i{name};
						}];
						clsFields.push(ctorField = {
							access: [APublic],
							name: "new",
							kind: FFun({
								args: [for (i in 0...args.length) {
									var a = args[i];
									{
										name: "arg" + i,
										type: Context.toComplexType(Context.typeof(a)),
										opt: false
									}
								}],
								ret: null,
								expr: superCtor == null ? macro {} : macro { super($a{callArgs}); }
							}),
							pos: expr.pos
						});
					}
					if (needContext) {
						var contextArg = {name:contextObjName, type:contextCt};
						ctorField.kind = switch (ctorField.kind) {
							case FFun(fun):
								FFun({
									params: fun.params,
									args: fun.args.concat([contextArg]),
									expr: switch (getFirstExpr(fun.expr)) {
										case macro super($a{callArgs}):
											var setContext = macro this.$contextObjName = $i{contextObjName};
											switch (fun.expr) {
												case macro $b{exprs}:
													macro $b{exprs.concat([setContext])}
												case _:
													macro {
														${fun.expr};
														$setContext;
													}
											}
										case _:
											macro {
												this.$contextObjName = $i{contextObjName};
												${fun.expr}
											}
									},
									ret: fun.ret
								});
							case _:
								throw "constructor should be a function";
						}

						var fields = [];
						if (hasParentAcc) {
							fields.push({field: parentObjName, expr: macro this});
						}
						for (vname in localNames.keys()) {
							fields.push({field: getterName(vname), expr: macro function() return $i{vname}});
							fields.push({field: setterName(vname), expr: macro function($setterArgName) return $i{vname} = $i{setterArgName}});
						}
						args.push({expr: EObjectDecl(fields), pos: Context.currentPos()});

						clsFields.push({
							access: [APrivate],
							name: contextArg.name,
							kind: FProp("default", "null", contextArg.type, null),
							pos: Context.currentPos()
						});
					}

					var typeDef:TypeDefinition = {
						pack: [],
						meta: if (clsType.meta.has(":javaNative"))
							[{name: ":nativeGen", pos: Context.currentPos()}]
						else
							[],
						kind: if (clsType.isInterface) {
							TDClass(null, [typePath], false);
						} else {
							TDClass(typePath, null, false);
						},
						name: clsName,
						fields: clsFields,
						pos: expr.pos
					}

					Context.defineType(typeDef);
					built[clsFullName] = {
						args: args
					}

					var printer = new haxe.macro.Printer();
					// var str = printer.printTypeDefinition(typeDef);
					// sys.FileSystem.createDirectory("dump");
					// sys.io.File.saveContent("dump/" + typeDef.pack.join(".") + "." + typeDef.name + ".hx", str);

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

				var tPath = { pack:[], name:clsName };
				return macro new $tPath($a{args});
			case _: throw type;
		}
	}
}
