import nimside, seaqt/[qmetaclassinfo, qmetaproperty], unittest2

const greeterSignature = "0123456789abcdef"

qobject:
  type
    Greeter* {.
      qclassinfo("RemoteObject Type", "Greeter"),
      qclassinfo("RemoteObject Signature", greeterSignature)
    .} = ref object of VirtualQObject
      greeting {.qproperty.}: string
      pokes: int

    Plain = ref object of VirtualQObject

  proc poke(g: Greeter) {.slot, raises: [].} =
    g.pokes += 1

suite "qclassinfo":
  test "type pragma becomes classinfo":
    let g = Greeter()
    QObject.create(g)
    let
      mo = g.metaObject()
      offset = mo.classInfoOffset()

    check:
      mo.classInfoCount() - offset == 2
      $mo.classInfo(offset).name() == "RemoteObject Type"
      $mo.classInfo(offset).value() == "Greeter"
      $mo.classInfo(mo.indexOfClassInfo("RemoteObject Signature")).value() ==
        greeterSignature
      mo.indexOfSlot("poke()") >= 0
      mo.indexOfProperty("greeting") >= 0

    let prop = mo.property(mo.indexOfProperty("greeting"))
    check:
      prop.write(g[], QVariant.create("hello"))
      g.greeting == "hello"

  test "no pragma, no classinfo":
    let p = Plain()
    QObject.create(p)
    let mo = p.metaObject()
    check mo.classInfoCount() == mo.classInfoOffset()
