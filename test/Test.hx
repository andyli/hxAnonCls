import haxe.unit.*;
import hxAnonCls.AnonCls;

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

typedef IFoo2 = IFoo;

interface ParamFoo<T> {
	public function foo():T;
}

class Test extends TestCase {
	public function testInterface():Void {
		var foobar = AnonCls.make((new IFoo():{
			public function foo() return "testInterface";
		}));
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

	static function main():Void {
		var runner = new TestRunner();
		runner.add(new Test());
		runner.add(new pack.Packed());
		var success = runner.run();
		#if sys
		Sys.exit(success ? 0 : 1);
		#end
	}
}