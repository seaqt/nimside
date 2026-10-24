import
  std/[compilesettings, os, osproc, strutils],
  nimside,
  seaqt/[qmetamethod, qmetaproperty],
  unittest2,
  ./qinterface/[counter_api, counter_impl, counter_stub, greeter_api, greeter_impl]

# The same object declared in one module, for comparison
qobject:
  type Counter = ref object of VirtualQObject
    count {.qproperty(write = false).}: int
    label {.qproperty.}: string

  proc overflowed(o: Counter, at: int) {.signal.}

  proc increment(o: Counter) {.slot.} =
    discard

  proc add(o: Counter, n: int): int {.slot.} =
    n

  proc describe(o: Counter, prefix: string): string {.slot.} =
    prefix

type
  Full = ref object of counter_api.Counter
  Partial = ref object of counter_api.Counter
  WrongReturn = ref object of counter_api.Counter

proc increment(o: Full | Partial | WrongReturn) =
  discard

proc add(o: Full | WrongReturn, n: int): int =
  n

proc describe(o: Full | Partial, prefix: string): string =
  prefix

proc describe(o: WrongReturn, prefix: string): int =
  0

proc signatures(mo: QMetaObject): seq[string] =
  for i in mo.methodOffset() ..< mo.methodCount():
    let m = mo.methodX(i)
    result.add $m.methodType() & " " & $m.typeName() & " " &
      cast[string](m.methodSignature())
  for i in mo.propertyOffset() ..< mo.propertyCount():
    let p = mo.property(i)
    result.add $p.name() & ": " & $p.typeName() & " " & $p.isWritable() & " " &
      $p.hasNotifySignal()

proc callSlot(o: QObject, sig: string, ret: pointer, args: varargs[pointer]): bool =
  let idx = o.metaObject().indexOfMethod(sig)
  if idx < 0:
    return false
  var argv = @[ret] & @args
  discard QMetaObject.metacall(
    o, cint QMetaObjectCallEnum.InvokeMetaMethod, idx, addr argv[0]
  )
  true

proc readQString(p: pointer): string =
  let v = QVariant.create(QMetaType.fromName("QString".toOpenArrayByte(0, 6)), p)
  result = v.toString()
  v.delete()

suite "qinterface":
  test "the metaobject is the interface's, whichever module implements it":
    let
      impl = CounterImpl.create(10)
      stub = CounterStub.create()
      mo = counter_api.Counter.staticMetaObject()
    check:
      impl.metaObject().h == mo.h
      stub.metaObject().h == mo.h
      impl[].metaObject().className() == "Counter"
      # Index for index what the single-module `qobject:` form builds
      mo.signatures() == test_qinterface.Counter.staticMetaObject().signatures()

  test "slots dispatch to the implementing module":
    let c = CounterImpl.create(limit = 6)
    var overflowedAt = -1
    c.onOverflowed(
      proc(at: int) {.gcsafe, raises: [].} =
        overflowedAt = at
    )
    var
      r = 0
      n = 5
    check:
      c[].callSlot("increment()", nil)
      c.count == 1
      c[].callSlot("add(qlonglong)", pointer(addr r), pointer(addr n))
      r == 6
      overflowedAt == -1
      c[].callSlot("increment()", nil)
      overflowedAt == 7

    c.label = "c"
    let prefix = QVariant.create("count of ")
    var buf: array[64, byte]
    check:
      c[].callSlot("describe(QString)", pointer(addr buf[0]), prefix.constData())
      readQString(pointer(addr buf[0])) == "count of c=7"

  test "two implementations of one interface in one program":
    let
      impl = CounterImpl.create(10)
      stub = CounterStub.create()
    var
      r = -1
      n = 3
    check:
      stub[].callSlot("increment()", nil)
      stub[].callSlot("add(qlonglong)", pointer(addr r), pointer(addr n))
      stub.calls == @["increment()", "add(3)"]
      r == 0
      impl[].callSlot("increment()", nil)
      impl.count == 1

  test "properties go through the implementation's metacall":
    let
      c = CounterImpl.create(10)
      mo = c[].metaObject()
    c.label = "x"
    check:
      mo.property(mo.indexOfProperty("label")).read(c[]).toString() == "x"
      mo.property(mo.indexOfProperty("label")).write(c[], QVariant.create("y"))
      c.label == "y"
      # READONLY: QML cannot write it
      not mo.property(mo.indexOfProperty("count")).write(
        c[], QVariant.create(clonglong 3)
      )

  test "an interface implemented on its own type":
    let g = Greeter()
    QObject.create(g)
    var buf: array[64, byte]
    let name = QVariant.create("nim")
    check:
      g[].callSlot("greet(QString)", pointer(addr buf[0]), name.constData())
      readQString(pointer(addr buf[0])) == "hello nim"
      g.greeted == 1

  test "an interface with no slots":
    let h = Holder()
    QObject.create(h)
    let mo = h[].metaObject()
    check:
      mo.property(mo.indexOfProperty("value")).write(h[], QVariant.create("v"))
      h.value == "v"

  test "a missing slot or a wrong return type does not compile":
    check:
      compiles(qcheckImplementation(counter_api.Counter, Full))
      not compiles(qcheckImplementation(counter_api.Counter, Partial))
      not compiles(qcheckImplementation(counter_api.Counter, WrongReturn))

  test "the compile error names the slot":
    var cmd =
      getCurrentCompilerExe().quoteShell & " c --compileOnly --hints:off --nimcache:" &
      (getTempDir() / "nimside_missing_slot").quoteShell
    for p in querySettingSeq(searchPaths):
      cmd.add " --path:" & p.quoteShell
    cmd.add " " &
      (currentSourcePath.parentDir / "qinterface" / "missing_slot.nim").quoteShell
    let (output, code) = execCmdEx(cmd)
    checkpoint output
    check:
      code != 0
      "counter_api.nim(13, 3) Error: Counter: slot add(o: Counter, n: int): int is not implemented" in
        output
      "missing_slot.nim(16, 11) template/generic instantiation of `qimplement` from here" in
        output
