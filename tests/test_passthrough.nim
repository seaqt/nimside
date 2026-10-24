import nimside, seaqt/qmetaproperty, unittest2

proc implementedAfter(n: int): int {.raises: [].}

func toString(b: seq[byte]): string =
  for c in b:
    result.add char(c)

qobject:
  type Counter = ref object of VirtualQObject
    count {.qproperty.}: int
    label {.qproperty.}: string
    log: seq[string]

  const step = 2

  var created {.global.}: int

  template note(o: Counter, s: string) =
    o.log.add s

  # a forward declaration, implemented further down in the block
  proc implementedBelow(o: Counter): int {.raises: [].}

  # a forward-declared slot, implemented further down in the block
  proc reset(o: Counter) {.slot, raises: [].}

  # declaring the notify signal of a qproperty yourself
  proc labelChanged(o: Counter) {.signal.}

  # a non-generic proc in the block using what the macro generates for the type
  proc newCounter(): Counter =
    result = Counter()
    result.setup()
    let o = result
    o.onCountChanged(
      proc() {.gcsafe, raises: [].} =
        o.note("countChanged")
    )
    created += 1

  proc bump(o: Counter) {.slot, raises: [].} =
    o.setCount(o.count + step + o.implementedBelow() + implementedAfter(0))
    o.note("bump")

  proc implementedBelow(o: Counter): int =
    0

  proc reset(o: Counter) {.slot, raises: [].} =
    o.setCount(0)

  # `slot` need not be the first pragma
  proc relabel(o: Counter, s: string) {.raises: [], slot.} =
    o.setLabel(s)

proc implementedAfter(n: int): int =
  n

template invoke(o: Counter, member: string): bool =
  QMetaObject.invokeMethod(o[], member, QGenericArgument.create())

suite "qobject passthrough":
  test "procs, templates, constants and globals in the block pass through":
    let o = newCounter()
    check:
      created == 1
      o.invoke("bump")
      o.count == step
      o.log == @["countChanged", "bump"]

  test "a forward-declared slot is registered once":
    let
      o = newCounter()
      mo = o.metaObject()
    var n = 0
    for i in mo.methodOffset() ..< mo.methodCount():
      if mo.methodX(i).name().toString() == "reset":
        n += 1
    check:
      n == 1
      o.invoke("bump")
      o.invoke("reset")
      o.count == 0

  test "a declared notify signal is the property's notify signal":
    let
      o = newCounter()
      mo = o.metaObject()
      prop = mo.property(mo.indexOfProperty("label"))
    check:
      prop.hasNotifySignal()
      prop.notifySignal().name().toString() == "labelChanged"
    var changed = 0
    o.onLabelChanged(
      proc() {.gcsafe, raises: [].} =
        changed += 1
    )
    let v = QVariant.create("x")
    check:
      QMetaObject.invokeMethod(
        o[], "relabel", QGenericArgument.create("QString", v.constData())
      )
      o.label == "x"
      changed == 1
    v.delete()
