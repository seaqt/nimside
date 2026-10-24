import
  nimside,
  seaqt/[qguiapplication, qqmlcontext, qqmlapplicationengine],
  ./counter_backend

const qml = """
import QtQuick

QtObject {
    property Connections c: Connections {
        target: counter
        function onOverflowed(at) { console.log("overflowed at", at) }
    }
    Component.onCompleted: {
        counter.label = "clicks"
        for (let i = 0; i < 3; i++) counter.increment()
        console.log(counter.describe("QML sees "))
        Qt.callLater(Qt.quit)
    }
}
"""

let
  _ = QGuiApplication.create()
  counter = Backend.create(limit = 2)
  engine = QQmlApplicationEngine.create()

engine.rootContext().setContextProperty("counter", counter[])
engine.loadData(qml.toOpenArrayByte(0, qml.high))

discard QGuiApplication.exec()
