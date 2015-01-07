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

	static function addPriAcc(te:haxe.macro.Type.TypedExpr):haxe.macro.Type.TypedExpr {
		function isPrivateFieldAccess(fa:haxe.macro.Type.FieldAccess):Bool {
			return switch (fa) {
				case FInstance(_, cf)
				   | FStatic(_, cf)
				   | FClosure(_, cf)
				if (!cf.get().isPublic):
					true;
				case _:
					false;
			}
		}
		switch (te) {
			case {expr: TField(e, isPrivateFieldAccess(_) => true), t:t, pos:pos}:
				return {
					expr: TMeta(
						{
							name: ":privateAccess",
							params: [],
							pos: pos
						},
						te
					),
					t: t,
					pos: pos
				}
			case _:
		}
		return TypedExprTools.map(te, addPriAcc);
	}

	static function getCtor(t:haxe.macro.Type.ClassType):Null<haxe.macro.Type.ClassField> {
		if (t == null)
			return null;
		if (t.constructor != null)
			return t.constructor.get();
		if (t.superClass != null)
			return getCtor(t.superClass.t.get());
		return null;
	}

	static function getUnbounds(te:haxe.macro.Type.TypedExpr):Array<haxe.macro.Type.TypedExpr> {
		var unbounds = [];
		function _map(te:haxe.macro.Type.TypedExpr):haxe.macro.Type.TypedExpr {
			return switch (te.expr) {
				case TLocal(v)
				if ((untyped v.meta:Metadata).exists(function(m) return m.name == ":unbound")):
					unbounds.push(te);
					te;
				case _:
					TypedExprTools.map(te, _map);
			}
		}
		_map(te);
		return unbounds;
	}

	static function posEq(pos1:Position, pos2:Position):Bool {
		var pos1 = Context.getPosInfos(pos1);
		var pos2 = Context.getPosInfos(pos2);
		return pos1.file == pos2.file && pos1.min == pos2.min && pos1.max == pos2.max;
	}

	static function mapUnbound(e:Expr, unbounds:Array<haxe.macro.Type.TypedExpr>):Expr {
		function _map(e:Expr):Expr {
			return switch (e) {
				case macro $i{ident}
				if (unbounds.exists(function(te)
					return switch (te) {
						case {expr: TLocal(v), pos: pos}:
							v.name == ident && posEq(pos, e.pos);
						case _:
							false;
					}
				)):
					macro untyped $e;
				case _:
					ExprTools.map(e, _map);
			}
		}
		return _map(e);
	}

	static function getLocalTVars():Map<String,haxe.macro.Type.TVar> {
		#if (haxe_ver >= 3.2)
			return Context.getLocalTVars();
		#else
			var vars = Context.getLocalVars();
			var tvars = new Map();
			for (v in vars.keys()) {
				var te = Context.typeExpr({expr:EConst(CIdent(v)), pos:Context.currentPos()});
				switch (te.expr) {
					case TLocal(v):
						tvars[v.name] = v;
					case _:
						throw "should be TLocal";
				}
			}
			return tvars;
		#end
	}

	static function getLocals(te:haxe.macro.Type.TypedExpr, tvars:Map<String,haxe.macro.Type.TVar>):Array<haxe.macro.Type.TypedExpr> {
		var tlocals = [];
		function _map(te:haxe.macro.Type.TypedExpr):haxe.macro.Type.TypedExpr {
			return switch (te.expr) {
				case TLocal(v)
				if (tvars.exists(v.name) && tvars[v.name].id == v.id):
				tlocals.push(te);
					te;
				case _:
					TypedExprTools.map(te, _map);
			}
		}
		_map(te);
		return tlocals;
	}

	static function mapLocals(e:Expr, locals:Array<haxe.macro.Type.TypedExpr>):Expr {
		function _map(e:Expr):Expr {
			return switch (e) {
				case macro $i{ident}
				if (locals.exists(function(te)
					return switch (te) {
						case {expr: TLocal(v), pos: pos}:
							v.name == ident && posEq(pos, e.pos);
						case _:
							false;
					}
				)):
					macro this.___context___.$ident;
				case _:
					ExprTools.map(e, _map);
			}
		}
		return _map(e);
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
										//___super___
										macro var ___super___:$ct;
									},
									{	
										//___this___
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

							var ctor = getCtor(clsType);
							if (ctor != null) {
								//___superNew___
								var fType = Context.toComplexType(ctor.type);
								typeHints.push(macro var ___superNew___:$fType);
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
											te = addPriAcc(te);
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
																macro @:pos(pos) this.___context___.___parent___;
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
							var localClass = Context.getLocalClass().get();
							var dynamicType = Context.getType("Dynamic");
							var contextCt = {
								var fields:Array<Field> = [];
								if (hasParentAcc) {
									var localClassCt = TPath({
										pack:localClass.pack, 
										name:localClass.module.substring(localClass.module.lastIndexOf(".")+1), 
										sub:localClass.name,
										params:[for (p in localClass.params) TPType(macro:Dynamic)]
									});
									fields.push({
										name: "___parent___",
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
										name: "get_" + v,
										kind: FFun({
											args: [],
											ret: vCt,
											expr: null,
										}),
										pos: Context.currentPos(),
									});
									fields.push({
										name: "set_" + v,
										kind: FFun({
											args: [{name:"___", type:vCt}],
											ret: vCt,
											expr: null,
										}),
										pos: Context.currentPos(),
									});
								}
								TAnonymous(fields);
							};
							
							var contextArg = {name:"___context___", type:contextCt};

							if (needContext){
								var fields = [];
								if (hasParentAcc) {
									fields.push({field: "___parent___", expr: macro this});
								}
								for (vname in localNames.keys()) {
									fields.push({field: "get_" + vname, expr: macro function() return $i{vname}});
									fields.push({field: "set_" + vname, expr: macro function(___) return $i{vname} = ___});
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
												this.___context___ = ___context___;
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