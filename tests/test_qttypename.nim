import nimside, seaqt/[qmetaproperty], unittest2

type OpaqueHandle = distinct pointer
  # Stands in for a pointer to a C++ type nimside cannot name, such as `LogosAPI*`

func qtTypeName(_: type OpaqueHandle): string =
  "OpaqueHandle*"

proc `==`(a, b: OpaqueHandle): bool {.borrow.}

qobject:
  type Host = ref object of VirtualQObject
    current {.qproperty(write = false, notify = false).}: OpaqueHandle
    accepted: int

  proc accept(o: Host, h: OpaqueHandle, tag: string) {.slot.} =
    o.current = h
    o.accepted += 1

  proc handed(o: Host, h: OpaqueHandle) {.signal.}

suite "qtTypeName":
  var
    target = 42
    p = pointer(addr target)

  test "the meta-object names the type":
    let o = Host()
    QObject.create(o)
    let mo = o.metaObject()

    check:
      metaTypeName(OpaqueHandle) == "OpaqueHandle*"
      metaTypeName(string) == "QString" # built-in types are unchanged
      mo.indexOfSlot("accept(OpaqueHandle*,QString)") >= 0
      mo.indexOfSignal("handed(OpaqueHandle*)") >= 0
      mo.indexOfMethod("current()") >= 0
      $mo.methodX(mo.indexOfMethod("current()")).typeName() == "OpaqueHandle*"
      $mo.property(mo.indexOfProperty("current")).typeName() == "OpaqueHandle*"

  test "a pointer argument round-trips through invokeMethod":
    let o = Host()
    QObject.create(o)

    let tag = QVariant.create("t")
    check QMetaObject.invokeMethod(
      o[],
      "accept",
      QGenericArgument.create("OpaqueHandle*", addr p),
      QGenericArgument.create("QString", tag.constData()),
    )
    check:
      o.accepted == 1
      o.current == OpaqueHandle(p)

    var back: pointer
    check QMetaObject.invokeMethod(
      o[], "current", QGenericReturnArgument.create("OpaqueHandle*", addr back)
    )
    check back == p

  test "a signal carries the pointer":
    let o = Host()
    QObject.create(o)
    var got: seq[OpaqueHandle]
    o.onHanded(
      proc(h: OpaqueHandle) {.gcsafe, raises: [].} =
        got.add h
    )
    o.handed(OpaqueHandle(p))
    check got == @[OpaqueHandle(p)]
