import nimside, seaqt/qmetaproperty, unittest2

qobject:
  type Recorder = ref object of VirtualQObject
    name {.qproperty.}: string
    calls: seq[string]
    pings: int
    greeted: string

  proc record(o: Recorder, slot: string) {.slotHook, raises: [].} =
    o.calls.add slot

  proc pinged(o: Recorder) {.signal.}

  proc ping(o: Recorder) {.slot, raises: [].} =
    o.pings += 1

  proc greet(o: Recorder, who: string) {.slot, raises: [].} =
    o.greeted = who

proc newRecorder(): Recorder =
  result = Recorder()
  QObject.create(result)

template invoke(o: Recorder, member: string): bool =
  QMetaObject.invokeMethod(o[], member, QGenericArgument.create())

suite "slotHook":
  test "runs before a slot invoked through the meta-object":
    let o = newRecorder()
    check:
      o.invoke("ping")
      o.pings == 1
      o.calls == @["ping"]

  test "sees slots with arguments":
    let
      o = newRecorder()
      who = QVariant.create("Ada")
    check:
      QMetaObject.invokeMethod(
        o[], "greet", QGenericArgument.create("QString", who.constData())
      )
      o.greeted == "Ada"
      o.calls == @["greet"]
    who.delete()

  test "sees slots called through a signal connection":
    let
      o = newRecorder()
      mo = o.metaObject()
    discard QObject.connect(
      o[],
      mo.methodX(mo.indexOfSignal("pinged()")),
      o[],
      mo.methodX(mo.indexOfSlot("ping()")),
    )
    o.pinged()
    check:
      o.pings == 1
      o.calls == @["ping"] # emitting the signal itself is not a slot call

  test "is bypassed by direct Nim calls":
    let o = newRecorder()
    o.ping()
    o.greet("Bob")
    check:
      o.pings == 1
      o.calls.len == 0

  test "sees property accessors only when invoked as methods":
    let
      o = newRecorder()
      mo = o.metaObject()
      prop = mo.property(mo.indexOfProperty("name"))
      v = QVariant.create("x")
    check:
      prop.write(o[], v)
      o.calls.len == 0
      o.invoke("name")
      o.calls == @["name"]
    v.delete()
