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

## Related projects

`nimside` was inspired by [`nimqml`](https://github.com/filcuc/nimqml) which offers a similar DSL based on [`DOtherSide`](https://github.com/filcuc/dotherside).

If you're a current `nimqml` user, [`nimqml-seaqt`](https://github.com/seaqt/nimqml-seaqt) offers a `seaqt`-based environment for porting `nimqml` applications to `nimside` - both can be used side-by-side in the same project.
