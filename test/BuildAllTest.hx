import haxe.unit.*;
import Test;

class BuildAllTest extends TestCase {
	public function test():Void {
		var foobar = (new IFoo():{
			public function foo() return "testInterface";
		});
		assertEquals("testInterface", foobar.foo());
	}

	public function testNormalCheckType():Void {
		assertEquals("abc", ("abc":String));
		assertEquals("", (new Array():Array<Int>).join(""));
	}
}