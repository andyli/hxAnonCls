import haxe.unit.*;
import hxAnonCls.AnonCls;
import hxAnonCls.AnonCls.make in A;
using StringTools;
using Lambda;
using Std;
import haxe.Template;
import haxe.Json.*;

interface IFoo {
	public function foo():String;
}

class AFoo {
	public function foo():String return "afoo";
}

class AFooC {
	public function new():Void {}
	public function foo():String return "afoo";
}

class AFooC2 extends AFooC {

}

typedef IFoo2 = IFoo;

interface ParamFoo<T> {
	public function foo():T;
}

class AFooPrivateFieldAccess {
	function _private() return "_private";
}

abstract AbstractStr(String) from String to String {
	public function firstChar() return this.charAt(0);
	public var char(get, set):String;
	function get_char():String {
		return firstChar();
	}
	function set_char(v):String {
		return v;
	}
}

class Test extends TestCase {
	public function testInterface():Void {
		var foobar = AnonCls.make((new IFoo():{
			public function foo() return "testInterface";
			public function bar() return "bar";
		}));
		assertEquals("testInterface", foobar.foo());
		assertEquals("bar", foobar.bar());

		var foobar:IFoo = AnonCls.make({
			function foo() return "testInterface";
		});
		assertEquals("testInterface", foobar.foo());
	}

	public function testInterfaceOverrideCtr():Void {
		var foobar = AnonCls.make((new IFoo("testInterfaceOverrideCtr"):{
			var str:String;
			public function new(str:String):Void {
				this.str = str;
			}
			public function foo() return str;
		}));
		assertEquals("testInterfaceOverrideCtr", foobar.foo());
	}

	public function testClass():Void {
		var foobar = AnonCls.make((new AFoo():{
			override public function foo() return "testClass";
		}));
		assertEquals("testClass", foobar.foo());

		var foobar = AnonCls.make((new AFoo():{
			override public function foo() return super.foo() + "!";
		}));
		assertEquals("afoo!", foobar.foo());
	}

	public function testClassWithCtr():Void {
		var foobar = AnonCls.make((new AFooC():{
			override public function foo() return "testClassWithCtr";
		}));
		assertEquals("testClassWithCtr", foobar.foo());
	}

	public function testClassWithCtrOverrideCtr():Void {
		var foobar = AnonCls.make((new AFooC("testClassWithCtrOverrideCtr"):{
			var str:String;
			public function new(str:String):Void {
				super();
				this.str = str;
			}
			override public function foo() return str;
		}));
		assertEquals("testClassWithCtrOverrideCtr", foobar.foo());

		var foobar = AnonCls.make((new AFooC2("testClassWithCtrOverrideCtr"):{
			var str = "dummy";
			var dummy(default, default) = "dummmmy";
			public function new(str:String):Void {
				super();
				this.str = str;
			}
			override public function foo() return str;
		}));
		assertEquals("testClassWithCtrOverrideCtr", foobar.foo());
	}

	public function testPackedInterface():Void {
		var foobar = AnonCls.make((new pack.Packed.PackedIFoo():{
			public function foo() return "testPackedInterface";
		}));
		assertEquals("testPackedInterface", foobar.foo());
	}

	public function testTypedef():Void {
		var foobar = AnonCls.make((new IFoo2():{
			public function foo() return "testInterface";
		}));
		assertEquals("testInterface", foobar.foo());
	}

	public function testParam():Void {
		var foobar = AnonCls.make((new ParamFoo<String>():{
			public function foo() return "testInterface";
		}));
		assertEquals("testInterface", foobar.foo());

		var foobar = AnonCls.make((new ParamFoo<Array<Dynamic>>():{
			public function foo() return ["ParamFoo<Array<Dynamic>>"];
		}));
		assertEquals("ParamFoo<Array<Dynamic>>", foobar.foo()[0]);

		var foobar = AnonCls.make((new ParamFoo<Dynamic<String>>():{
			public function foo() return {bar:"ParamFoo<Dynamic<String>>"};
		}));
		assertEquals("ParamFoo<Dynamic<String>>", foobar.foo().bar);
	}

	public function testAlias():Void {
		var foobar = A((new IFoo():{
			public function foo() return "testInterface";
		}));
		assertEquals("testInterface", foobar.foo());
	}

	public function testUsing():Void {
		var foobar = AnonCls.make((new IFoo():{
			public function foo()
				return [1, 2, 3]
					.array()
					.join(",");
			function test():Void {
				if (true) {
					for (i in 0...10)
					if (i < 5)
					"abcde".startsWith("abc");
				}
			}
		}));
		assertEquals("1,2,3", foobar.foo());
	}

	public function testImport():Void {
		var foobar = AnonCls.make((new IFoo():{
			var v1:Template;
			var v2 = new Template("");
			var v3 = {
				var t = new Template("");
				t;
			}
			var p1(default,null):Template;
			var p2(default,null) = new Template("");
			var p3(default,null) = {
				var t = new Template("");
				t;
			}
			public function foo()
				return stringify([1, 2, 3]);
		}));
		assertEquals("[1,2,3]", foobar.foo());
	}

	#if js
	public function testUntyped():Void {
		var foobar = AnonCls.make((new IFoo():{
			public function foo()
				return untyped __js__("\"test\"");
		}));
		assertEquals("test", foobar.foo());
	}
	#end

	public function testPrivateFieldAccess():Void {
		var foo = AnonCls.make((new AFooPrivateFieldAccess():{
			inline public function test():String return _private();
		}));
		assertEquals("_private", foo.test());
	}

	public function testParentClassAccess():Void {
		var foobar = AnonCls.make((new AFoo():{
			public function new():Void {
				assertEquals("parent private field", privateField);
				parent.assertEquals("parent private field", privateField);
			}
			override public function foo() {
				assertEquals("afoo", super.foo());
				return "foobar";
			}
		}));
		assertEquals("foobar", foobar.foo());

		var parent = 123;
		var foobar = AnonCls.make((new AFoo():{
			public function new():Void {
				assertEquals("Test", Type.getClassName(Type.getClass(parent)));
				assertEquals(789, parent.parent);
				var parent = 456;
				assertEquals(456, parent);
			}
		}));
	}

	public function testLocalVarAccess():Void {
		var local = "local var";
		var foobar = AnonCls.make((new IFoo():{
			public function foo() {
				return local;
			}

			public function set():Void local = "changed";
		}));
		assertEquals("local var", foobar.foo());
		foobar.set();
		assertEquals("changed", local);

		var local = "local var";
		var foobar:IFoo = AnonCls.make({
			function foo() {
				var old = local;
				local = "changed";
				return old;
			}
		});
		assertEquals("local var", foobar.foo());
		assertEquals("changed", local);
	}

	public function testAbstract():Void {
		var a:AbstractStr = "abc";
		var foobar = AnonCls.make((new IFoo():{
			public function foo() return ("foo":AbstractStr).firstChar();
			public function prop():String return a.char;
			public function setProp():String return a.char = "A";
		}));
		assertEquals("f", foobar.foo());
		assertEquals("a", foobar.prop());
		assertEquals("A", foobar.setProp());
	}

	static function _testInStatic():IFoo {
		return AnonCls.make((new IFoo():{
			public function foo() return "testInterface";
		}));
	}
	public function testInStatic():Void {
		assertEquals("testInterface", _testInStatic().foo());
	}

	var privateField = "parent private field";
	var parent = 789;

	macro static function addBuildAllTest() {
		if (hxAnonCls.Macros.isBuildAll) {
			return macro runner.add(new BuildAllTest());
		} else {
			return macro {};
		}
	}

	#if !macro
	static function main():Void {
		var runner = new TestRunner();
		runner.add(new Test());
		runner.add(new pack.Packed());
		runner.add(new ParamTest(123));
		runner.add(new SugarTest());
		#if (haxe_ver >= 3.2)
		addBuildAllTest();
		#end
		var success = runner.run();
		#if (sys || nodejs)
		Sys.exit(success ? 0 : 1);
		#end
	}
	#end
}
