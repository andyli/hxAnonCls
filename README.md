# hxAnonCls [![Build Status](https://travis-ci.org/andyli/hxAnonCls.svg?branch=master)](https://travis-ci.org/andyli/hxAnonCls)

Java style [Anonymous Classes](http://docs.oracle.com/javase/tutorial/java/javaOO/anonymousclasses.html) in Haxe.

## Motivation

When using the Haxe Java target, it is common to use the Java API. This is how we create a `java.lang.Thread` using anonymous class in Java:

```java
class JavaThreadExample {
	public static void main(String[] args) {
		final String msg = "running in a separated thread";
		Thread thread = new Thread() {
			public void run() {
				System.out.println(msg);
			}
		};
		thread.run();
	}
}
```

It would be very verbose doing the same thing in Haxe:

```haxe
class JavaThreadExample {
	static function main():Void {
		/*
			If we need to use local variables, they have to
			be passed as constructor arguments.
		*/
		var msg = "running in a separated thread";
		var thread = new CustomThread(msg);
		thread.start();
	}
}

/*
	We have to subclass manually.
	The class definition location is faraway from the usage.
*/
class CustomThread extends java.lang.Thread {
	var msg:String;
	public function new(msg:String):Void {
		super();
		this.msg = msg;
	}
	@:overload override function run():Void {
		trace(msg);
	}
}
```

As you can see, creating a class for one-time usage is troublesome. Also when reading the code, it requires us to scroll more frequently.

## hxAnonCls to the rescue

With *hxAnonCls*, we can now create anonymous class in Haxe similar to Java.
It supports two types of syntax, namely *block syntax* and *type-check syntax*, illustrated as follows.

```haxe
/*
	Use a build macro as follows, or 
	add `--macro "hxAnonCls.Macros.buildAll()"` to our hxml.
*/
@:build(hxAnonCls.Macros.build())
class JavaThreadExample {
	static function main():Void {
		/*
			Block Syntax

			When using this syntax, we provide a code block that contains
			variable or function declarations to somewhere an instance
			of a class/interface is expected.
			The block can be given to a `var` expression as follows,
			or to a function call as an argument.

			hxAnonCls automatically adds `@:overload`/`override`
			when needed when using this syntax.
		*/
		var msg = "running in a separated thread";
		var thread:java.lang.Thread = {
			function run():Void {
				trace(msg);
			}
		};
		thread.start();

		/*
			Type-Check Syntax

			The type-check expression is in the form of `(variable:Type)`.
			The (extra) parentheses are required.

			It allows higher customizability than block syntax.
			It lets us declare things that are not allowed with
			block syntax. For example, `public`, `inline`,
			`static`, metadata, and constructor.

			hxAnonCls doen't automatically adds `@:overload`/
			`override` - we have to be explicit when using this
			syntax.
		*/
		var msg = "running";
		var thread = (new java.lang.Thread("my thread"):{
			var name:String;
			public function new(name:String):Void {
				super();
				this.name = name;
			}
			@:overload override function run():Void {
				trace(name + ": " + msg);
			}
		});
		thread.start();
	}
}
```

Notice that:
 * Similar to Java, hxAnonCls is able to create anonymous class for both class and interface. A default constructor is added implicitly if it is not provided.
 * Similar to Java, anonymous classes created by hxAnonCls can access the properties and methods of their enclosing classes, including those are private. Use `parent` to reference the enclosing instance. Use `parent.field` or simply `field` to reference the enclosing instance field.
 * Anonymous classes created by hxAnonCls can read/write local variables in the enclosing block, unlike Java, which only allows reading final variables.

## Dependancies

 * Haxe 3.2.1+
 * tink_macro 0.5.0+ 

# Like hxAnonCls?

Support me to maintain it -> http://www.patreon.com/andyli
