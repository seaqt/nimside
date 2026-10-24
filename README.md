# nimside

`nimside` is [Nim](https://nim-lang.org) binding for `Qt` and `QML` allowing convenient interaction between Nim and the [Qt Meta-Object System](https://doc.qt.io/qt-6/metaobjects.html).

`nimside` is a companion and extension for [`nim-seaqt`](https://github.com/seaqt/nim-seaqt), offering a convenient way of exposing seaqt-based code to QML, [plugins](https://doc.qt.io/qt-6/plugins-howto.html) and other meta-object consumers.

`nimside` replaces [`moc`](https://doc.qt.io/qt-6/moc.html) and similar support macros on the C++ side, avoiding the separate build step using compile-time code generation and macros.

The DSL is still going through significant changes, including in naming and structure - this repository is a preview intended for feedback.

The code may occasionally be **rebased** before the dust settles on a generally useful initial release.

## Using `nimside`

`nimside` is available from `nimble` with each supported Qt version in its own branch:

```nim
# You need to depend on both `nimside` and `nim-seaqt` of an appropriate version
requires "https://github.com/seaqt/nimside.git", "https://github.com/seaqt/nim-seaqt.git@#qt-6.4"
```

With that and a copy of Qt itself in place, you're good to go for your first `QObject` that exposes signals and slots:

```nim
import nimside, seaqt/[qapplication, qvariant, qqmlcontext, qqmlapplicationengine]

qobject:
  type MyObject = ref object of VirtualQObject
    name {.qproperty.}: string

  proc run(m: MyObject) {.slot, raises: [].} =
    echo "Hello ", m.name

  proc create(T: type MyObject, name: string): MyObject =
    let res = T(name: name)
    QObject.create(res)
    res

const qml = """
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    visible: true
    width: 640
    height: 480
    title: "Hello " + qsTr(myobject.name)
    onFrameSwapped: myobject.run()
}
"""

let
  _ = QApplication.create()
  myobject = MyObject.create("world")
  engine = QQmlApplicationEngine.create()

engine.rootContext().setContextProperty("myobject", myobject[])
engine.loadData(qml.toOpenArrayByte(0, qml.high))

discard QApplication.exec()
```

See [`nim-seaqt`](https://github.com/seaqt/nim-seaqt) for more information.

### What else goes in a `qobject:` block

Anything in the block that is not a type, a signal or a slot - procs, templates, constants, forward declarations, other statements - is passed through unchanged, in the order written. The macro expands to:

1. the block's type sections;
2. for each type: its meta-object, its signals (declared and generated `xChanged`, in both the `ref` and the `ptr` form), the `onX` signal connectors, `setup`, and the generated property accessors;
3. the rest of the block - slots and everything else - in source order;
4. for each type: the generated `qt_metacall` that dispatches to the slots.

So any code in the block can use what the macro generates for a type, a slot sees whatever is declared above it as usual in Nim, and a slot or proc may be forward-declared and implemented further down the block or later in the module:

```nim
qobject:
  type MyObject = ref object of VirtualQObject
    name {.qproperty.}: string

  proc loadImpl(m: MyObject, path: string) {.raises: [].} # implemented elsewhere

  proc load(m: MyObject, path: string) {.slot, raises: [].} =
    m.loadImpl(path)

  proc newMyObject(): MyObject =
    result = MyObject()
    result.setup()
    result.onNameChanged(
      proc() {.gcsafe, raises: [].} =
        echo "renamed"
    )

proc loadImpl(m: MyObject, path: string) =
  m.setName(path)
```

Give a forward declaration its `raises` list: Nim assumes a forward-declared proc without one may raise anything, so a `{.raises: [].}` slot cannot call it.

## Related projects

`nimside` was inspired by [`nimqml`](https://github.com/filcuc/nimqml) which offers a similar DSL based on [`DOtherSide`](https://github.com/filcuc/dotherside).

If you're a current `nimqml` user, [`nimqml-seaqt`](https://github.com/seaqt/nimqml-seaqt) offers a `seaqt`-based environment for porting `nimqml` applications to `nimside` - both can be used side-by-side in the same project.
