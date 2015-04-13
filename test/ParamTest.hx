import hxAnonCls.AnonCls;
import haxe.unit.*;
import Test;
using Std;

class ParamTest<T> extends TestCase {
	var t:T;
	public function new(t:T) {
		super();
		this.t = t;
	}
	public function test():Void {
		var foobar = AnonCls.make((new IFoo():{
			public function foo() return t.string();
		}));
		assertEquals(t.string(), foobar.foo());
	}
}