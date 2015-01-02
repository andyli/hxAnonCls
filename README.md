# hxAnonCls [![Build Status](https://travis-ci.org/andyli/hxAnonCls.svg?branch=master)](https://travis-ci.org/andyli/hxAnonCls)

Java style [Anonymous Classes](http://docs.oracle.com/javase/tutorial/java/javaOO/anonymousclasses.html) in Haxe.

## Motivation

When using the Haxe Java target, it is common to use the Java API, which the event system makes use of listener classes extensively. For example this is how we create and attach a `KeyListener` using anonymous class in Java:

```java
typingArea = new JTextField(20);
typingArea.addKeyListener(new KeyListener(){
    public void keyTyped(KeyEvent e) {
        //handle keyTyped
    }

    public void keyPressed(KeyEvent e) {
        //handle keyPressed
    }

    public void keyReleased(KeyEvent e) {
        //handle keyReleased
    }
});
```

In Haxe, usually we have to implement the `KeyListener` interface explicitly somewhere:

```haxe
import java.awt.event.*;
class MyKeyListener implements KeyListener{
    public function new():Void {}
    
    public function keyTyped(e:KeyEvent):Void {
        //handle keyTyped
    }

    public function keyPressed(e:KeyEvent):Void {
        //handle keyPressed
    }

    public function keyReleased(e:KeyEvent):Void {
        //handle keyReleased
    }
}

//later in some place
typingArea = new JTextField(20);
typingArea.addKeyListener(new MyKeyListener());
```

As you can see, creating a class for one-time usage is troublesome. Also when reading the code, it requires us to scroll more frequently.

## hxAnonCls to the rescue

With **hxAnonCls**, we can now create anonymous class in Haxe similar to Java:

```haxe
import hxAnonCls.AnonCls;
import java.awt.event.*;

typingArea = new JTextField(20);
typingArea.addKeyListener(AnonCls.make((new KeyListener():{
    public function keyTyped(e:java.awt.event.KeyEvent):Void {
        //handle keyTyped
    }

    public function keyPressed(e:java.awt.event.KeyEvent):Void {
        //handle keyPressed
    }

    public function keyReleased(e:java.awt.event.KeyEvent):Void {
        //handle keyReleased
    }
})));
```

Notice that:
 * The argument to `AnonCls.make` should be an `ECheckType` expression, which is in the form of `(variable:Type)`. The (extra) parentheses are required.
 * You may use `import hxAnonCls.AnonCls.make in A;`, such that you can create anonymous class with shorter syntax: `A((new Type():{/*... */}))`.
 * Similar to Java, **hxAnonCls** is able to create anonymous class for both class and interface.
 * A default constructor is added implicitly if it is not provided.

## Limitations (possible future improvements)

 * `import` statements in the outer context have no effect in the anonymous class definition. However, `using` works as expected. We have to either *always* use fully qualified type names as shown in the above example (`java.awt.event.KeyEvent`), or to use `using` which implies `import`. To correctly support `import`, we have to wait for [haxe issue #3560](https://github.com/HaxeFoundation/haxe/issues/3560) to be resolved.
 * It is not a Java inner class. It is not allowed to access the instance members of its "parent" object implicitly. However we can define a constructor to pass the parent object to it:

```haxe
AnonCls.make((new KeyListener(this):{
    var parent:MyParent;
    public function new(parent:MyParent):Void {
        this.parent = parent;
    }
    /* other methods */
}));
```

# Like hxAnonCls?

Support me to maintain it -> http://www.patreon.com/andyli
