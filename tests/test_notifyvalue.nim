import
  nimside,
  seaqt/[qcoreapplication, qqmlengine, qqmlcomponent, qqmlcontext, qmetaproperty, qurl],
  unittest2

qobject:
  type Status = ref object of VirtualQObject
    health {.qproperty(notifyValue = true).}: string
    count {.qproperty(notifyValue = true).}: int
    name {.qproperty.}: string
    explicit {.qproperty(write = true, notify = true, notifyValue = false).}: string

let app {.used.} =
  if QCoreApplication.instance().h == nil:
    QCoreApplication.create()
  else:
    QCoreApplication.instance()

proc toString(b: openArray[byte]): string =
  for c in b:
    result.add char(c)

proc notifySignature(o: Status, prop: string): string =
  let mo = o.metaObject()
  toString(mo.property(mo.indexOfProperty(prop)).notifySignal().methodSignature())

suite "notify signals that carry the value":
  test "the meta-object's notify signals":
    let o = Status()
    QObject.create(o)
    let
      mo = o.metaObject()
      health = mo.property(mo.indexOfProperty("health"))

    check:
      o.notifySignature("health") == "healthChanged(QString)"
      o.notifySignature("count") == "countChanged(qlonglong)" # a Nim int
      o.notifySignature("name") == "nameChanged()" # the default is unchanged
      o.notifySignature("explicit") == "explicitChanged()"
      mo.property(mo.indexOfProperty("explicit")).isWritable()
      health.notifySignalIndex() == mo.indexOfSignal("healthChanged(QString)")
      health.notifySignal().parameterNames()[0].toString() == "health"

  test "a Nim listener receives the new value":
    let o = Status()
    QObject.create(o)

    var
      healths: seq[string]
      counts: seq[int]
      names = 0
    o.onHealthChanged(
      proc(v: string) {.gcsafe, raises: [].} =
        healths.add v
    )
    o.onCountChanged(
      proc(v: int) {.gcsafe, raises: [].} =
        counts.add v
    )
    o.onNameChanged(
      proc() {.gcsafe, raises: [].} =
        names += 1
    )

    o.setHealth("ok")
    o.setHealth("ok") # no change, no notify
    o.setCount(3)
    o.setName("n")

    # Through the meta-object, as QML writes it
    let mo = o.metaObject()
    check mo.property(mo.indexOfProperty("health")).write(
      o[], QVariant.create("degraded")
    )

    check:
      healths == @["ok", "degraded"]
      counts == @[3]
      names == 1

  test "QML bindings and handlers still update":
    let o = Status(health: "starting")
    QObject.create(o)

    const qml = """
import QtQml
QtObject {
  property string bound: status.health
  property string handled: ""
  property int nameChanges: 0
  property Connections c: Connections {
    target: status
    function onHealthChanged(health) { handled = health }
    function onNameChanged() { nameChanges += 1 }
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
    o.setName("n")
    check:
      root.property("bound").toString() == "ok"
      root.property("handled").toString() == "ok"
      root.property("nameChanges").toInt() == 1
