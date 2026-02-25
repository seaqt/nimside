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
