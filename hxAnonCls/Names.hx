package hxAnonCls;

class Names {
	static public var namePrefix(default, never)     = "_hxAnonCls";
	static public var parentIdent(default, never)    = "parent";
	static public var parentObjName(default, never)  = namePrefix + "_" + parentIdent;
	static public var contextObjName(default, never) = namePrefix + "_context";
	static public var superObjName(default, never)   = namePrefix + "_super";
	static public var superCtorName(default, never)  = namePrefix + "_superNew";
	static public var thisObjName(default, never)    = namePrefix + "_this";
	static public var setterArgName(default, never)  = namePrefix + "_v";
	static public function getterName(prop:String):String {
		return "get_" + prop;
	}
	static public function setterName(prop:String):String {
		return "set_" + prop;
	}
}