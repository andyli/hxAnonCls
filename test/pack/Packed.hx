package pack;
import hxAnonCls.AnonCls;

interface PackedIFoo {
	public function foo():String;
}

class Packed extends haxe.unit.TestCase {
	public function testInterface():Void {
		var foobar = AnonCls.make((new Test.IFoo():{
			public function foo() return "packed bar";
		}));
		assertEquals("packed bar", foobar.foo());
	}
	public function testPackedInterface():Void {
		var foobar = AnonCls.make((new PackedIFoo():{
			public function foo() return "testPackedInterface";
		}));
		assertEquals("testPackedInterface", foobar.foo());
	}
}