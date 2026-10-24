import
  nimside,
  seaqt/[
    qcoreapplication, qmetaproperty, qqmlengine, qqmlcomponent, qqmlcontext, qurl,
    qvariant,
  ],
  unittest2

qobject:
  type
    Counter = ref object of VirtualQObject
      value {.qproperty.}: int
      label {.qproperty(write = false).}: string
      fixed {.qproperty(write = false, notify = false).}: string

      resets: int

    Explicit = ref object of VirtualQObject
      value {.qproperty.}: int
      setterCalls: int

  proc reset(c: Counter) {.slot, raises: [].} =
    c.resets += 1
    c.setValue(0)

  proc setValue(e: Explicit, v: int) {.slot, raises: [].} =
    # A setter declared as a slot by the user becomes a meta-method, as with moc
    e.setterCalls += 1
    if e.value != v:
      e.value = v
      e.valueChanged()

proc create(T: type Counter): Counter =
  let res = T(label: "counter", fixed: "fixed")
  QObject.create(res)
  res

proc create(T: type Explicit): Explicit =
  let res = T()
  QObject.create(res)
  res

proc signatures(mo: QMetaObject): seq[string] =
  for i in mo.methodOffset() ..< mo.methodCount():
    let sig = mo.methodX(cint i).methodSignature()
    var s = newString(sig.len)
    for j, c in sig:
      s[j] = char(c)
    result.add s

let app = QCoreApplication.create()

suite "qobject metaobject":
  test "accessors are not meta-methods":
    let mo = Counter.create().metaObject()

    # notify signals + declared slots, as moc would produce
    check:
      mo.signatures() == @["valueChanged()", "labelChanged()", "reset()"]
      mo.methodCount() - mo.methodOffset() == 3
      mo.indexOfSlot("value()") == -1
      mo.indexOfSlot("setValue(int)") == -1
      mo.indexOfMethod("label()") == -1
      mo.indexOfMethod("fixed()") == -1
      mo.indexOfSlot("reset()") >= 0

  test "nim accessors are still generated":
    let c = Counter.create()
    var notified = 0
    c.onValueChanged(
      proc() =
        notified += 1
    )
    c.setValue(3)
    c.setValue(3)
    check:
      c.value() == 3
      notified == 1
      c.label() == "counter"
      not compiles(c.setFixed("x"))

  test "QMetaProperty read, write and notify":
    let
      c = Counter.create()
      mo = c.metaObject()
      valueProp = mo.property(mo.indexOfProperty("value"))
      labelProp = mo.property(mo.indexOfProperty("label"))
      fixedProp = mo.property(mo.indexOfProperty("fixed"))

    var notified = 0
    c.onValueChanged(
      proc() =
        notified += 1
    )

    check:
      valueProp.isReadable()
      valueProp.isWritable()
      valueProp.hasNotifySignal()
      valueProp.notifySignalIndex() == mo.indexOfSignal("valueChanged()")
      valueProp.write(c[], QVariant.create(clonglong 42))
      c.value == 42
      notified == 1
      valueProp.read(c[]).toInt() == 42

      labelProp.isReadable()
      not labelProp.isWritable()
      labelProp.hasNotifySignal()
      not labelProp.write(c[], QVariant.create("x"))
      labelProp.read(c[]).toString() == "counter"

      not fixedProp.isWritable()
      not fixedProp.hasNotifySignal()
      fixedProp.isConstant()
      fixedProp.read(c[]).toString() == "fixed"

  test "a setter declared as a slot is a meta-method and serves the property":
    let
      e = Explicit.create()
      mo = e.metaObject()
      valueProp = mo.property(mo.indexOfProperty("value"))

    check:
      mo.signatures() == @["valueChanged()", "setValue(qlonglong)"]
      mo.indexOfSlot("value()") == -1
      valueProp.write(e[], QVariant.create(clonglong 7))
      e.value == 7
      e.setterCalls == 1

  test "QML bindings follow the property":
    const qml = """
import QtQml
QtObject {
  property int seen: counter.value
  property string seenLabel: counter.label
  property bool hasSetter: typeof counter.setValue === "function"
  property bool hasReset: typeof counter.reset === "function"
  Component.onCompleted: counter.value = 5
}
"""
    let
      c = Counter.create()
      engine = QQmlEngine.create()
      component = QQmlComponent.create(engine)

    engine.rootContext().setContextProperty("counter", c[])
    component.setData(qml.toOpenArrayByte(0, qml.high), QUrl.create())
    checkpoint component.errorString()
    check not component.isError()
    let root = component.createObject()
    require root.h != nil
    check:
      c.value == 5 # written from QML through WriteProperty
      root.property("seen").toInt() == 5
      root.property("seenLabel").toString() == "counter"
      not root.property("hasSetter").toBool()
      root.property("hasReset").toBool()

    c.setValue(9)
    check root.property("seen").toInt() == 9
    c.label = "renamed"
    c.labelChanged()
    check root.property("seenLabel").toString() == "renamed"
