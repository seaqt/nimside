import
  nimside,
  seaqt/[qcoreapplication, qqmlengine, qqmlcomponent, qqmlcontext, qmetaproperty, qurl],
  std/strutils,
  unittest2

qobject:
  type
    Status = ref object of VirtualQObject
      health {.qproperty(write = false).}: string
      constant {.qproperty(write = false, notify = false).}: string

    Custom = ref object of VirtualQObject
      value {.qproperty(write = false).}: string
      customSets: int

  proc setValue(o: Custom, v: string) =
    # Declared in the block: the generated setter steps aside
    o.customSets += 1
    o.value = v
    o.valueChanged()

let app {.used.} =
  if QCoreApplication.instance().h == nil:
    QCoreApplication.create()
  else:
    QCoreApplication.instance()

suite "write = false with notify":
  test "QML and QMetaProperty cannot write; Nim can":
    let o = Status(health: "starting")
    QObject.create(o)

    let
      mo = o.metaObject()
      prop = mo.property(mo.indexOfProperty("health"))

    check:
      not prop.isWritable()
      prop.hasNotifySignal()
      mo.indexOfMethod("setHealth(QString)") < 0
      not prop.write(o[], QVariant.create("from meta"))
      o.health == "starting"

    var seen: seq[string]
    o.onHealthChanged(
      proc() {.gcsafe, raises: [].} =
        seen.add o.health
    )

    o.setHealth("ok")
    o.setHealth("ok") # no change, no notify
    o.setHealth("degraded")

    check:
      seen == @["ok", "degraded"]
      prop.read(o[]).toString() == "degraded"

  test "QML reads and binds, but cannot assign":
    let o = Status(health: "starting")
    QObject.create(o)

    const qml = """
import QtQml
QtObject {
  property string bound: status.health
  function tryWrite() {
    try { status.health = "from qml"; return "" } catch (e) { return String(e) }
  }
}
"""
    let engine = QQmlEngine.create()
    engine.rootContext().setContextProperty("status", o[])
    let component = QQmlComponent.create(engine)
    component.setData(qml.toOpenArrayByte(0, qml.high), QUrl.create())
    checkpoint component.errorString()
    check not component.isError()

    let root = component.createX(engine.rootContext())
    check root.property("bound").toString() == "starting"

    o.setHealth("ok")
    check root.property("bound").toString() == "ok"

    let err = QVariant.create()
    check QMetaObject.invokeMethod(
      root, "tryWrite", QGenericReturnArgument.create("QVariant", err.data())
    )
    check:
      "read-only" in err.toString()
      o.health == "ok"

  test "write = false without notify stays constant, with no setter":
    let o = Status(constant: "c")
    QObject.create(o)
    let
      mo = o.metaObject()
      prop = mo.property(mo.indexOfProperty("constant"))
    check:
      prop.isConstant()
      not compiles(o.setConstant("d"))

  test "a setter declared in the block wins":
    let o = Custom()
    QObject.create(o)
    var notified = 0
    o.onValueChanged(
      proc() {.gcsafe, raises: [].} =
        notified += 1
    )
    o.setValue("x")
    check:
      o.customSets == 1
      notified == 1
      o.metaObject().indexOfMethod("setValue(QString)") < 0
