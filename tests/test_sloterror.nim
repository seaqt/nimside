import nimside, seaqt/qmetaproperty, unittest2

proc failLater(): int

qobject:
  type
    Guarded = ref object of VirtualQObject
      limit {.qproperty.}: int
      errors: seq[(string, string)]
      calls: int

    Unguarded = ref object of VirtualQObject
      calls: int

  proc onSlotError(
      o: Guarded, slot: string, e: ref Exception
  ) {.slotError, raises: [].} =
    o.errors.add((slot, e.msg))

  proc boom(o: Guarded) {.slot.} =
    o.calls += 1
    raise newException(ValueError, "boom!")

  proc forwarded(o: Guarded) {.slot.} =
    # calling a forward declaration without `raises` infers `raises: [Exception]`
    o.calls += failLater()

  proc fine(o: Guarded) {.slot.} =
    o.calls += 1

  proc setLimit(o: Guarded, v: int) {.slot.} =
    if v < 0:
      raise newException(ValueError, "negative limit")
    o.limit = v

  proc boom(o: Unguarded) {.slot.} =
    o.calls += 1
    raise newException(IOError, "unguarded")

proc failLater(): int =
  raise newException(KeyError, "not yet")

template invoke(o: VirtualQObject, member: string): bool =
  QMetaObject.invokeMethod(o[], member, QGenericArgument.create())

suite "slotError":
  test "an exception from a slot reaches the handler, not Qt":
    let o = Guarded()
    QObject.create(o)
    check:
      o.invoke("boom")
      o.calls == 1
      o.errors == @[("boom", "boom!")]

  test "slots calling procs that may raise anything":
    let o = Guarded()
    QObject.create(o)
    check:
      o.invoke("forwarded")
      o.errors == @[("forwarded", "not yet")]

  test "a slot that does not raise is unaffected":
    let o = Guarded()
    QObject.create(o)
    check:
      o.invoke("fine")
      o.calls == 1
      o.errors.len == 0

  test "property writes through a user-supplied setter are guarded too":
    let
      o = Guarded()
      v = QVariant.create(cint(-1))
    QObject.create(o)
    let mo = o.metaObject()
    discard mo.property(mo.indexOfProperty("limit")).write(o[], v)
    check:
      o.limit == 0
      o.errors == @[("setLimit", "negative limit")]
    v.delete()

  test "without a handler, the exception is reported on stderr":
    let o = Unguarded()
    QObject.create(o)
    check:
      o.invoke("boom")
      o.calls == 1
