package hxAnonCls;

import haxe.macro.*;
import haxe.macro.Expr;
import haxe.macro.Type;
using StringTools;
using Lambda;
import hxAnonCls.Names.*;

@:allow(hxAnonCls)
class Macros {
	static public function build():Array<Field> {
		var fields = Context.getBuildFields();
		for (f in fields) {
			f.kind = switch (f.kind) {
				case FFun(f):
					FFun({
						args: f.args,
						params: f.params,
						expr: mapCheckType(f.expr),
						ret: f.ret
					});
				case _: //TODO
					f.kind;
			}
		}
		return fields;
	}

	static function mapCheckType(e:Expr):Expr {
		return switch (e) {
			case macro (new $t($a{args}):$extend)
			if (extend.match(TAnonymous(_))):
				macro hxAnonCls.AnonCls.make($e);
			case _:
				ExprTools.map(e, mapCheckType);
		}
	}

	static function tohxAnonClsExpr(e:Null<Expr>, typeHints:Array<Expr>, locals:Array<TypedExpr>):{
		e: Null<Expr>,
		hasParentAcc: Bool
	} {
		return if (e != null) {
			var te = Context.typeExpr(
				macro $b{typeHints.concat([mapWithHint(e)])}
			);
			var parentHint = getParentHint(te);
			te = mapParent(te, parentHint);
			e = typedExprToExpr(te);
			getLocals(te, getLocalTVars(), locals);
			e = mapLocals(e, locals);
			switch (e) {
				case macro $b{es}:
					// for (e in es) {
					// 	trace(ExprTools.toString(e));
					// }
					var laste = es[es.length-1];
					laste = unmapWithHint(laste);
					var hasParentAcc = false;
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
					{
						e: laste,
						hasParentAcc: hasParentAcc
					}
				case _: throw e;
			}
		} else {
			e: e,
			hasParentAcc: false
		}
	}

	static function getFirstExpr(expr:Expr):Expr {
		return switch (expr) {
			case macro $b{exprs} if (exprs.length >= 1):
				getFirstExpr(exprs[0]);
			case macro ($e):
				getFirstExpr(e);
			case _: expr;
		}
	}

	static function typeToTypePath(t:Type):TypePath {
		return switch (Context.follow(t)) {
			case TInst(t, params):
				baseTypeToTypePath(t.get(), [for (p in params) TPType(Context.toComplexType(p))]);
			case TEnum(t, params):
				baseTypeToTypePath(t.get(), [for (p in params) TPType(Context.toComplexType(p))]);
			case TType(t, params):
				baseTypeToTypePath(t.get(), [for (p in params) TPType(Context.toComplexType(p))]);
			case _: throw 'Cannot convert this to TypePath: $t';
		};
	}

	static function fieldAccessName(fa:FieldAccess):String {
		return switch (fa) {
			case FInstance(_, cf),
			     FStatic(_, cf),
			     FAnon(cf),
			     FClosure(_, cf):
				cf.get().name;
			case FDynamic(s):
				s;
			case FEnum(_, ef):
				ef.name;
		}
	}

	static function baseTypeToTypePath(t:BaseType, params:Array<TypeParam>):TypePath {
		return {
			pack:t.pack, 
			name:t.module.substring(t.module.lastIndexOf(".")+1), 
			sub:t.name,
			params:params
		};
	}

	static function mapWithHint(expr:Expr):Expr {
		return switch (expr) {
			case macro super.$field:
				macro @:pos(expr.pos) $i{superObjName}.$field;
			case macro super:
				macro @:pos(expr.pos) $i{superCtorName};
			case macro this:
				macro @:pos(expr.pos) $i{thisObjName};
			case _:
				ExprTools.map(expr, mapWithHint);
		}
	}

	static function unmapWithHint(expr:Expr):Expr {
		return switch (expr) {
			case macro $i{_superObjName}.$field if (_superObjName == superObjName):
				macro @:pos(expr.pos) super.$field;
			case macro $i{_superCtorName} if (_superCtorName == superCtorName):
				macro @:pos(expr.pos) super;
			case macro $i{_thisObjName} if (_thisObjName == thisObjName):
				macro @:pos(expr.pos) this;
			case _:
				ExprTools.map(expr, unmapWithHint);
		}
	}

	static function isPrivateFieldAccess(fa:FieldAccess):Bool {
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

	static function getCtor(t:ClassType):Null<ClassField> {
		if (t == null)
			return null;
		if (t.constructor != null)
			return t.constructor.get();
		if (t.superClass != null)
			return getCtor(t.superClass.t.get());
		return null;
	}

	static function posEq(pos1:Position, pos2:Position):Bool {
		var pos1 = Context.getPosInfos(pos1);
		var pos2 = Context.getPosInfos(pos2);
		return pos1.file == pos2.file && pos1.min == pos2.min && pos1.max == pos2.max;
	}

	static function getParentHint(te:TypedExpr):TypedExpr {
		var parent = null;
		function _map(te:TypedExpr) {
			return parent != null ? te : switch (te.expr) {
				case TVar(v, _) if (v.name == parentIdent):
					parent = te;
				case _:
					haxe.macro.TypedExprTools.map(te, _map);
			}
		}
		_map(te);
		return parent;
	}

	static function getLocalTVars():Map<String,TVar> {
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

	static function getLocals(te:TypedExpr, tvars:Map<String,TVar>, out:Array<TypedExpr>):Array<TypedExpr> {
		if (out == null) out = [];
		function _map(te:TypedExpr):TypedExpr {
			return switch (te.expr) {
				case TLocal(v)
				if (tvars.exists(v.name) && tvars[v.name].id == v.id):
				out.push(te);
					te;
				case _:
					TypedExprTools.map(te, _map);
			}
		}
		_map(te);
		return out;
	}

	static function mapParent(te:TypedExpr, parentHint:TypedExpr):TypedExpr {
		function _map(te:TypedExpr):TypedExpr {
			return switch [te, parentHint] {
				case [{expr: TLocal(v)}, {expr:TVar(hv, parentThis)}]
				if (v.id == hv.id):
					parentThis;
				case _:
					TypedExprTools.map(te, _map);
			}
		}
		return _map(te);
	}

	static function mapLocals(e:Expr, locals:Array<TypedExpr>):Expr {
		function _map(e:Expr):Expr {
			return switch (e) {
				case macro $i{ident}
				if (ident == "this"):
					macro this.$contextObjName.$parentObjName;
				case macro $i{ident}
				if (locals.exists(function(te)
					return switch (te) {
						case {expr: TLocal(v), pos: pos}:
							v.name == ident && posEq(pos, e.pos);
						case _:
							false;
					}
				)):
					macro this.$contextObjName.$ident;
				case _:
					ExprTools.map(e, _map);
			}
		}
		return _map(e);
	}

	static function typedExprToExpr(te:TypedExpr):Expr {
		return switch (te.expr) {
			// case TConst(c:haxe.macro.TConstant):

			case TLocal(v)
			if ((untyped v.meta:Metadata).exists(function(m) return m.name == ":unbound")):
				var vName = v.name;
				macro @:pos(te.pos) untyped $i{vName};

			// case TLocal():

			case TArray(e1, e2):
				var e1 = typedExprToExpr(e1);
				var e2 = typedExprToExpr(e2);
				macro @:pos(te.pos) $e1[$e2];

			case TBinop(op, e1, e2):
				var e1 = typedExprToExpr(e1);
				var e2 = typedExprToExpr(e2);
				{
					expr: EBinop(op, e1, e2),
					pos: te.pos
				};

			case TField(e, fa):
				var fName = fieldAccessName(fa);
				var e = typedExprToExpr(e);
				if (isPrivateFieldAccess(fa)) {
					macro @:pos(te.pos) @:privateAccess $e.$fName;
				} else {
					macro @:pos(te.pos) $e.$fName;
				}

			// case TTypeExpr(m:ModuleType):

			case TParenthesis(e):
				typedExprToExpr(e);

			case TObjectDecl(fields):
				var fields = [for (f in fields) {
					field: f.name,
					expr: typedExprToExpr(f.expr)
				}];
				{
					expr:EObjectDecl(fields),
					pos:te.pos
				};

			case TArrayDecl(el):
				var items = el.map(typedExprToExpr);
				macro @:pos(te.pos) $a{items};

			/*
				abstract field call
			*/
			case TCall({expr:TField({expr: TTypeExpr(TClassDecl(c))}, fa)}, el)
			if (c.get().kind.match(KAbstractImpl(_))):
				switch (c.get().kind) {
					case KAbstractImpl(a):
						var a = a.get();
						var abstp = baseTypeToTypePath(
							a,
							[for (p in a.params)
								TPType(TPath({name:p.name, pack:[""]}))]
						);
						if (a.isPrivate) {
							abstp.pack = [];
							abstp.name = abstp.sub;
							abstp.sub = null;
						}
						var abst = TPath(abstp);
						var ths = typedExprToExpr(el[0]);
						var callArgs = el.slice(1).map(typedExprToExpr);
						var fName = fieldAccessName(fa);
						if (isPrivateFieldAccess(fa))
							macro @:pos(te.pos) (@:privateAccess ($ths:$abst).$fName)($a{callArgs});
						else
							macro @:pos(te.pos) ($ths:$abst).$fName($a{callArgs});
					case _:
						throw "should be KAbstractImpl";
				}

			case TCall(e, el):
				var e = typedExprToExpr(e);
				var el = el.map(typedExprToExpr);
				macro @:pos(te.pos) $e($a{el});

			case TNew(c, params, el):
				var tp = baseTypeToTypePath(c.get(), [for (p in params) TPType(Context.toComplexType(p))]);
				var el = el.map(typedExprToExpr);
				macro @:pos(te.pos) new $tp($a{el});

			case TUnop(op, postFix, e):
				{
					expr: EUnop(op, postFix, typedExprToExpr(e)),
					pos: te.pos
				}

			case TFunction({t:t, expr:expr, args:args}):
				{
					expr: EFunction(null, {
						ret: Context.toComplexType(t),
						params: [],
						expr: typedExprToExpr(expr),
						args: [for (a in args) {
							opt: false,
							name: a.v.name,
							type: Context.toComplexType(a.v.t),
							value: a.value == null ? null : typedExprToExpr({
								expr: TConst(a.value),
								t: a.v.t,
								pos: te.pos,
							})
						}],
					}),
					pos: te.pos
				}
			case TVar(v, expr):
				var vName = v.name;
				var vType = Context.toComplexType(v.t);
				if (expr == null) {
					macro @:pos(te.pos) var $vName:$vType;
				} else {
					var expr = typedExprToExpr(expr);
					macro @:pos(te.pos) var $vName:$vType = $expr;
				}

			case TBlock(el):
				var el = el.map(typedExprToExpr);
				macro @:pos(te.pos) $b{el};

			case TFor(v, e1, e2):
				var vName = v.name;
				var e1 = typedExprToExpr(e1);
				var e2 = typedExprToExpr(e2);
				macro @:pos(te.pos) for ($i{vName} in $e1) $e2;

			case TIf(econd, eif, eelse):
				var econd = typedExprToExpr(econd);
				var eif = typedExprToExpr(eif);
				if (eelse == null) {
					macro @:pos(te.pos) if ($econd) $eif;
				} else {
					var eelse = typedExprToExpr(eelse);
					macro @:pos(te.pos) if ($econd) $eif else $eelse;
				}

			case TWhile(econd, e, normalWhile):
				var econd = typedExprToExpr(econd);
				var e = typedExprToExpr(e);
				if (normalWhile) {
					macro @:pos(te.pos) while ($econd) $e;
				} else {
					macro @:pos(te.pos) do $e while ($econd);
				}

			case TSwitch(e, cases, edef):
				{
					expr: ESwitch(typedExprToExpr(e), [for (c in cases) {
						values: c.values.map(typedExprToExpr),
						guard: null,
						expr: typedExprToExpr(c.expr)
					}], edef == null ? null : typedExprToExpr(edef)),
					pos: te.pos
				}

			case TTry(e, catches):
				var e = typedExprToExpr(e);
				{
					expr: ETry(e, [for (c in catches) {
						type: Context.toComplexType(c.v.t),
						name: c.v.name,
						expr: typedExprToExpr(c.expr)
					}]),
					pos: te.pos
				}

			case TReturn(e):
				if (e == null) {
					macro @:pos(te.pos) return;
				} else {
					var e = typedExprToExpr(e);
					macro @:pos(te.pos) return $e;
				}

			// case TBreak:

			// case TContinue:

			case TThrow(e):
				var e = typedExprToExpr(e);
				macro @:pos(te.pos) throw $e;

			case TCast(e, m):
				var e = typedExprToExpr(e);
				{
					expr: ECast(e, switch (m) {
						case null:
							null;
						case TClassDecl(c):
							TPath(baseTypeToTypePath(c.get(), [for (p in c.get().params) {
								TPType(Context.toComplexType(p.t));
							}]));
						case TEnumDecl(c):
							TPath(baseTypeToTypePath(c.get(), [for (p in c.get().params) {
								TPType(Context.toComplexType(p.t));
							}]));
						case TTypeDecl(c):
							TPath(baseTypeToTypePath(c.get(), [for (p in c.get().params) {
								TPType(Context.toComplexType(p.t));
							}]));
						case TAbstract(c):
							TPath(baseTypeToTypePath(c.get(), [for (p in c.get().params) {
								TPType(Context.toComplexType(p.t));
							}]));
					}),
					pos: te.pos
				}

			case TMeta(m, e1):
				{
					expr: EMeta(m, typedExprToExpr(e1)),
					pos: te.pos
				}

			case TEnumParameter(e1, ef, index):
				var e1 = typedExprToExpr(e1);
				var efName = ef.name;
				macro @:pos(te.pos) $e1.$efName;

			case _:
				Context.getTypedExpr(te);
		}
	}
}