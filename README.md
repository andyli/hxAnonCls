# hxAnonCls [![Build Status](https://travis-ci.org/andyli/hxAnonCls.svg?branch=master)](https://travis-ci.org/andyli/hxAnonCls)

Java style [Anonymous Classes](http://docs.oracle.com/javase/tutorial/java/javaOO/anonymousclasses.html) in Haxe.

## Motivation

When using the Haxe Java target, it is common to use the Java API, which the event system makes use of listener classes extensively. For example this is how we create and attach a `KeyListener` using anonymous class in Java:

```
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

```
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

```
import hxAnonCls.AnonCls;
import java.awt.event.*;

typingArea = new JTextField(20);
typingArea.addKeyListener(AnonCls.make((new KeyListener():{
    public function keyTyped(e:KeyEvent):Void {
        //handle keyTyped
    }

    public function keyPressed(e:KeyEvent):Void {
        //handle keyPressed
    }

    public function keyReleased(e:KeyEvent):Void {
        //handle keyReleased
    }
})));
```

Notice that:
 * The argument to `AnonCls.make` should be an `ECheckType` expression, which is in the form of `(variable:Type)`. The (extra) parentheses are required.
 * Similar to Java, **hxAnonCls** is able to create anonymous class for both class and interface.
 * A default constructor is added implicitly if it is not provided.

[![Support via Gittip](https://rawgithub.com/twolfson/gittip-badge/0.2.1/dist/gittip.png)](https://www.gittip.com/AndyLi/)
