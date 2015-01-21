package hxAnonCls;

import haxe.macro.*;
import haxe.macro.Expr;
import haxe.macro.Type;
using StringTools;
using Lambda;
import hxAnonCls.Names.*;

class Macros {
	static public function typeToTypePath(t:Type):TypePath {
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

	static public function mapWithHint(expr:Expr):Expr {
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

	static public function unmapWithHint(expr:Expr):Expr {
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

	static public function addPriAcc(te:TypedExpr):TypedExpr {
		function isPrivateFieldAccess(fa:FieldAccess):Bool {
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

	static public function getCtor(t:ClassType):Null<ClassField> {
		if (t == null)
			return null;
		if (t.constructor != null)
			return t.constructor.get();
		if (t.superClass != null)
			return getCtor(t.superClass.t.get());
		return null;
	}

	static public function getUnbounds(te:TypedExpr):Array<TypedExpr> {
		var unbounds = [];
		function _map(te:TypedExpr):TypedExpr {
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

	static public function posEq(pos1:Position, pos2:Position):Bool {
		var pos1 = Context.getPosInfos(pos1);
		var pos2 = Context.getPosInfos(pos2);
		return pos1.file == pos2.file && pos1.min == pos2.min && pos1.max == pos2.max;
	}

	static public function mapUnbound(e:Expr, unbounds:Array<TypedExpr>):Expr {
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

	static public function getParentHint(te:TypedExpr):TypedExpr {
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

	static public function getLocalTVars():Map<String,TVar> {
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

	static public function getLocals(te:TypedExpr, tvars:Map<String,TVar>):Array<TypedExpr> {
		var tlocals = [];
		function _map(te:TypedExpr):TypedExpr {
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

	static public function mapParent(te:TypedExpr, parentHint:TypedExpr):TypedExpr {
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

	static public function mapLocals(e:Expr, locals:Array<TypedExpr>):Expr {
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
}