package hxAnonCls;

import haxe.macro.*;
#if macro
import hxAnonCls.Macros.*;
import hxAnonCls.Names.*;
import haxe.macro.Expr;
import tink.macro.Types;
using Lambda;
#end

class AnonCls {
	macro static public function make(expr:Expr):Expr {
		switch (expr) {
			case macro (new $t($a{args}):$extend):
				var ct = TPath(t);
				var t = Context.follow(Context.typeof(macro (null:$ct)));
				switch (t) {
					case TInst(_t, params):
						var clsType = _t.get();
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
										//super
										macro var $superObjName:$ct;
									},
									{
										//parent
										macro var $parentIdent:$localClassCt = this;
									},
									{	
										//this
										//TODO: should not use TExtend, but to construct TAnonymous manually
										var ct = TExtend([typeToTypePath(t)], [
											for (f in fields)
											if (!existingFields.exists(function(ef) return ef.name == f.name || f.name == "new"))
											{
												access: [for (a in f.access) if (a != AInline) a],
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
																	Context.error("Explict return type is needed.", f.pos);
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
																	Context.error("Explict type is needed.", f.pos);
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
																	Context.error("Explict type is needed.", f.pos);
																}
															},
															null
														);
												},
												pos: f.pos,
											}
										]);
										macro var $thisObjName:$ct;
									}
								]);

							var ctor = getCtor(clsType);
							if (ctor != null) {
								//super()
								var fType = Context.toComplexType(ctor.type);
								typeHints.push(macro var $superCtorName:$fType);
							}

							var clsFields:Array<Field> = [];
							var hasParentAcc = false;
							var locals = [];
							var localNames = new Map();
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
											var te = Context.typeExpr(
												macro $b{typeHints.concat([mapWithHint(e)])}
											);
											var parentHint = getParentHint(te);
											te = addPriAcc(te);
											te = mapParent(te, parentHint);
											// trace(te);
											// trace(TypedExprTools.toString(te));
											e = Context.getTypedExpr(te);
											e = mapUnbound(e, getUnbounds(te));
											locals = getLocals(te, getLocalTVars());
											e = mapLocals(e, locals);
											// trace(ExprTools.toString(e));
											switch (e) {
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
													laste = unmapWithHint(laste);

													function mapParentAcc(e:Expr):Expr {
														return switch (e) {
															case {expr: EConst(CIdent("`")), pos: pos}:
																hasParentAcc = true;
																macro @:pos(pos) this.$contextObjName.$parentObjName;
															case _:
																ExprTools.map(e, mapParentAcc);
														}
													}
													laste = mapParentAcc(laste);
													switch (laste) {
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
												case _: throw e;
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
							
							var contextArg = {name:contextObjName, type:contextCt};

							if (needContext){
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
								(clsType.isInterface || getCtor(clsType) == null)
							) {
								clsFields.push(ctorField = {
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
							if (needContext) {
								ctorField.kind = switch (ctorField.kind) {
									case FFun(fun):
										FFun({
											params: fun.params,
											args: fun.args.concat([contextArg]),
											expr: macro {
												this.$contextObjName = $i{contextObjName};
												${fun.expr}
											},
											ret: fun.ret
										});
									case _:
										throw "constructor should be a function";
								}
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