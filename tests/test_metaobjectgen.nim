import nimside/metaobjectgen, seaqt/[qobject], unittest2

suite "genMetaObject Tests":
  test "Simple signal":
    let sigs = @[MethodDef.signalDef("signalA", @[])]
    let mo = genMetaObject(QObject.staticMetaObject, "TestSignal", sigs, [], [])

    check mo.className() == "TestSignal"
    check(mo.methodCount() - mo.methodOffset() == 1)
    check(mo.indexOfSignal("signalA()") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Simple slot":
    let slots = @[MethodDef.slotDef("slotA", "void", @[])]
    let mo = genMetaObject(QObject.staticMetaObject, "TestSlot", [], slots, [])

    check mo.className() == "TestSlot"
    check(mo.methodCount() - mo.methodOffset() == 1)
    check(mo.indexOfSlot("slotA()") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Signal with parameter":
    let sigs = @[
      MethodDef.signalDef(
        "valueChanged", @[ParamDef(name: "newValue", metaType: "int")]
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestSignalParam", sigs, [], [])

    check mo.className() == "TestSignalParam"
    check(mo.methodCount() - mo.methodOffset() == 1)
    check(mo.indexOfSignal("valueChanged(int)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Slot with parameters":
    let slots = @[
      MethodDef.slotDef(
        "setValue",
        "void",
        @[
          ParamDef(name: "value", metaType: "int"),
          ParamDef(name: "flag", metaType: "bool"),
        ],
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestSlotParams", [], slots, [])

    check mo.className() == "TestSlotParams"
    check(mo.methodCount() - mo.methodOffset() == 1)
    check(mo.indexOfSlot("setValue(int,bool)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Slot with return type":
    let slots = @[MethodDef.slotDef("getValue", "QString", @[])]
    let mo = genMetaObject(QObject.staticMetaObject, "TestSlotReturn", [], slots, [])

    check mo.className() == "TestSlotReturn"
    check(mo.methodCount() - mo.methodOffset() == 1)
    check(mo.indexOfMethod("getValue()") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Simple property":
    let slots = @[
      MethodDef.slotDef("value", "int", @[]),
      MethodDef.slotDef("setValue", "void", @[ParamDef(name: "v", metaType: "int")]),
    ]
    let props = @[
      PropertyDef(
        name: "value",
        metaType: "int",
        readSlot: "value",
        writeSlot: "setValue",
        notifySignal: "",
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestProperty", [], slots, props)

    check mo.className() == "TestProperty"
    check(mo.propertyCount() - mo.propertyOffset() == 1)
    check(mo.indexOfProperty("value") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Property with notify signal":
    let sigs = @[
      MethodDef.signalDef(
        "valueChanged", @[ParamDef(name: "newValue", metaType: "QString")]
      )
    ]
    let slots = @[
      MethodDef.slotDef("value", "QString", @[]),
      MethodDef.slotDef("setValue", "void", @[ParamDef(name: "v", metaType: "QString")]),
    ]
    let props = @[
      PropertyDef(
        name: "value",
        metaType: "QString",
        readSlot: "value",
        writeSlot: "setValue",
        notifySignal: "valueChanged",
      )
    ]
    let mo =
      genMetaObject(QObject.staticMetaObject, "TestPropertyNotify", sigs, slots, props)

    check mo.className() == "TestPropertyNotify"
    check(mo.propertyCount() - mo.propertyOffset() == 1)
    check(mo.indexOfProperty("value") >= 0)
    check(mo.indexOfSignal("valueChanged(QString)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Multiple signals":
    let sigs = @[
      MethodDef.signalDef("signalA", @[]),
      MethodDef.signalDef("signalB", @[ParamDef(name: "x", metaType: "int")]),
      MethodDef.signalDef(
        "signalC",
        @[
          ParamDef(name: "str", metaType: "QString"),
          ParamDef(name: "num", metaType: "int"),
        ],
      ),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestMultiSignals", sigs, [], [])

    check mo.className() == "TestMultiSignals"
    check(mo.methodCount() - mo.methodOffset() == 3)
    check(mo.indexOfSignal("signalA()") >= 0)
    check(mo.indexOfSignal("signalB(int)") >= 0)
    check(mo.indexOfSignal("signalC(QString,int)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Multiple slots":
    let slots = @[
      MethodDef.slotDef("slotA", "void", @[]),
      MethodDef.slotDef("slotB", "int", @[ParamDef(name: "x", metaType: "int")]),
      MethodDef.slotDef(
        "slotC",
        "QString",
        @[
          ParamDef(name: "a", metaType: "QString"), ParamDef(name: "b", metaType: "int")
        ],
      ),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestMultiSlots", [], slots, [])

    check mo.className() == "TestMultiSlots"
    check(mo.methodCount() - mo.methodOffset() == 3)
    check(mo.indexOfSlot("slotA()") >= 0)
    check(mo.indexOfSlot("slotB(int)") >= 0)
    check(mo.indexOfSlot("slotC(QString,int)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Multiple properties":
    let slots = @[
      MethodDef.slotDef("propA", "int", @[]),
      MethodDef.slotDef("setPropA", "void", @[ParamDef(name: "v", metaType: "int")]),
      MethodDef.slotDef("propB", "QString", @[]),
      MethodDef.slotDef("setPropB", "void", @[ParamDef(name: "v", metaType: "QString")]),
      MethodDef.slotDef("propC", "bool", @[]),
      MethodDef.slotDef("setPropC", "void", @[ParamDef(name: "v", metaType: "bool")]),
    ]
    let props = @[
      PropertyDef(
        name: "propA",
        metaType: "int",
        readSlot: "propA",
        writeSlot: "setPropA",
        notifySignal: "",
      ),
      PropertyDef(
        name: "propB",
        metaType: "QString",
        readSlot: "propB",
        writeSlot: "setPropB",
        notifySignal: "",
      ),
      PropertyDef(
        name: "propC",
        metaType: "bool",
        readSlot: "propC",
        writeSlot: "setPropC",
        notifySignal: "",
      ),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestMultiProps", [], slots, props)

    check mo.className() == "TestMultiProps"
    check(mo.propertyCount() - mo.propertyOffset() == 3)
    check(mo.indexOfProperty("propA") >= 0)
    check(mo.indexOfProperty("propB") >= 0)
    check(mo.indexOfProperty("propC") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Complex combination":
    let sigs = @[
      MethodDef.signalDef(
        "nameChanged", @[ParamDef(name: "newName", metaType: "QString")]
      ),
      MethodDef.signalDef("ageChanged", @[ParamDef(name: "newAge", metaType: "int")]),
    ]
    let slots = @[
      MethodDef.slotDef("name", "QString", @[]),
      MethodDef.slotDef(
        "setName", "void", @[ParamDef(name: "name", metaType: "QString")]
      ),
      MethodDef.slotDef("age", "int", @[]),
      MethodDef.slotDef("setAge", "void", @[ParamDef(name: "age", metaType: "int")]),
      MethodDef.slotDef("info", "QString", @[]),
    ]
    let props = @[
      PropertyDef(
        name: "name",
        metaType: "QString",
        readSlot: "name",
        writeSlot: "setName",
        notifySignal: "nameChanged",
      ),
      PropertyDef(
        name: "age",
        metaType: "int",
        readSlot: "age",
        writeSlot: "setAge",
        notifySignal: "ageChanged",
      ),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestComplex", sigs, slots, props)

    check mo.className() == "TestComplex"
    check(mo.methodCount() - mo.methodOffset() == 7)
    check(mo.propertyCount() - mo.propertyOffset() == 2)
    check(mo.indexOfSignal("nameChanged(QString)") >= 0)
    check(mo.indexOfSignal("ageChanged(int)") >= 0)
    check(mo.indexOfSlot("name()") >= 0)
    check(mo.indexOfSlot("setName(QString)") >= 0)
    check(mo.indexOfSlot("age()") >= 0)
    check(mo.indexOfSlot("setAge(int)") >= 0)
    check(mo.indexOfMethod("info()") >= 0)
    check(mo.indexOfProperty("name") >= 0)
    check(mo.indexOfProperty("age") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Various parameter types":
    let sigs = @[
      MethodDef.signalDef("sig1", @[ParamDef(name: "p1", metaType: "bool")]),
      MethodDef.signalDef("sig2", @[ParamDef(name: "p2", metaType: "double")]),
      MethodDef.signalDef("sig3", @[ParamDef(name: "p3", metaType: "QStringList")]),
    ]
    let slots = @[
      MethodDef.slotDef("slot1", "void", @[ParamDef(name: "p", metaType: "float")]),
      MethodDef.slotDef(
        "slot2", "long", @[ParamDef(name: "p", metaType: "unsigned int")]
      ),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestTypes", sigs, slots, [])

    check mo.className() == "TestTypes"
    check(mo.methodCount() - mo.methodOffset() == 5)
    check(mo.indexOfSignal("sig1(bool)") >= 0)
    check(mo.indexOfSignal("sig2(double)") >= 0)
    check(mo.indexOfSignal("sig3(QStringList)") >= 0)
    check(mo.indexOfSlot("slot1(float)") >= 0)
    check(mo.indexOfMethod("slot2(uint)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Empty class":
    let mo = genMetaObject(QObject.staticMetaObject, "TestEmpty", [], [], [])

    check mo.className() == "TestEmpty"
    check(mo.methodCount() - mo.methodOffset() == 0)
    check(mo.propertyCount() - mo.propertyOffset() == 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Read-only property":
    let slots = @[MethodDef.slotDef("value", "QString", @[])]
    let props = @[
      PropertyDef(
        name: "value",
        metaType: "QString",
        readSlot: "value",
        writeSlot: "",
        notifySignal: "",
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestReadOnly", [], slots, props)

    check mo.className() == "TestReadOnly"
    check(mo.propertyCount() - mo.propertyOffset() == 1)
    check(mo.indexOfProperty("value") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Write-only property":
    let slots = @[
      MethodDef.slotDef("setValue", "void", @[ParamDef(name: "val", metaType: "int")])
    ]
    let props = @[
      PropertyDef(
        name: "value",
        metaType: "int",
        readSlot: "",
        writeSlot: "setValue",
        notifySignal: "",
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestWriteOnly", [], slots, props)

    check mo.className() == "TestWriteOnly"
    check(mo.propertyCount() - mo.propertyOffset() == 1)
    check(mo.indexOfProperty("value") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Signal with multiple parameters":
    let sigs = @[
      MethodDef.signalDef(
        "complexSignal",
        @[
          ParamDef(name: "str", metaType: "QString"),
          ParamDef(name: "num", metaType: "int"),
          ParamDef(name: "flag", metaType: "bool"),
          ParamDef(name: "val", metaType: "double"),
        ],
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestComplexSig", sigs, [], [])

    check mo.className() == "TestComplexSig"
    check(mo.methodCount() - mo.methodOffset() == 1)
    check(mo.indexOfSignal("complexSignal(QString,int,bool,double)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Signal and slot with related functionality":
    let sigs = @[MethodDef.signalDef("triggered", @[])]
    let slots = @[MethodDef.slotDef("trigger", "void", @[])]
    let mo = genMetaObject(QObject.staticMetaObject, "TestSigSlot", sigs, slots, [])

    check mo.className() == "TestSigSlot"
    check(mo.methodCount() - mo.methodOffset() == 2)
    check(mo.indexOfSignal("triggered()") >= 0)
    check(mo.indexOfSlot("trigger()") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Class with only signals":
    let sigs = @[
      MethodDef.signalDef("sig1", @[]),
      MethodDef.signalDef("sig2", @[ParamDef(name: "x", metaType: "int")]),
      MethodDef.signalDef("sig3", @[ParamDef(name: "s", metaType: "QString")]),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestOnlySigs", sigs, [], [])

    check mo.className() == "TestOnlySigs"
    check(mo.methodCount() - mo.methodOffset() == 3)
    check(mo.propertyCount() - mo.propertyOffset() == 0)
    check(mo.indexOfSignal("sig1()") >= 0)
    check(mo.indexOfSignal("sig2(int)") >= 0)
    check(mo.indexOfSignal("sig3(QString)") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Class with only properties":
    let slots = @[
      MethodDef.slotDef("a", "int", @[]),
      MethodDef.slotDef("setA", "void", @[ParamDef(name: "v", metaType: "int")]),
      MethodDef.slotDef("b", "QString", @[]),
      MethodDef.slotDef("setB", "void", @[ParamDef(name: "v", metaType: "QString")]),
    ]
    let props = @[
      PropertyDef(
        name: "a", metaType: "int", readSlot: "a", writeSlot: "setA", notifySignal: ""
      ),
      PropertyDef(
        name: "b",
        metaType: "QString",
        readSlot: "b",
        writeSlot: "setB",
        notifySignal: "",
      ),
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestOnlyProps", [], slots, props)

    check mo.className() == "TestOnlyProps"
    check(mo.methodCount() - mo.methodOffset() == 4)
    check(mo.propertyCount() - mo.propertyOffset() == 2)
    check(mo.indexOfProperty("a") >= 0)
    check(mo.indexOfProperty("b") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Contact model":
    let sigs = @[
      MethodDef.signalDef(
        "nameChanged", @[ParamDef(name: "firstName", metaType: "QString")]
      )
    ]
    let slots = @[
      MethodDef.slotDef("name", "QString", @[]),
      MethodDef.slotDef(
        "setName", "void", @[ParamDef(name: "name", metaType: "QString")]
      ),
    ]
    let props = @[
      PropertyDef(
        name: "name",
        metaType: "QString",
        readSlot: "name",
        writeSlot: "setName",
        notifySignal: "nameChanged",
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "Contact", sigs, slots, props)

    check mo.className() == "Contact"
    check(mo.methodCount() - mo.methodOffset() == 3)
    check(mo.propertyCount() - mo.propertyOffset() == 1)
    check(mo.indexOfSignal("nameChanged(QString)") >= 0)
    check(mo.indexOfSlot("name()") >= 0)
    check(mo.indexOfMethod("setName(QString)") >= 0)
    check(mo.indexOfProperty("name") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Property with QObject pointer":
    let slots = @[
      MethodDef.slotDef("parent", "QObject*", @[]),
      MethodDef.slotDef(
        "setParent", "void", @[ParamDef(name: "p", metaType: "QObject*")]
      ),
    ]
    let props = @[
      PropertyDef(
        name: "parent",
        metaType: "QObject*",
        readSlot: "parent",
        writeSlot: "setParent",
        notifySignal: "",
      )
    ]
    let mo = genMetaObject(QObject.staticMetaObject, "TestQObj", [], slots, props)

    check mo.className() == "TestQObj"
    check(mo.propertyCount() - mo.propertyOffset() == 1)
    check(mo.indexOfProperty("parent") >= 0)
    check mo.inherits(QObject.staticMetaObject)

  test "Method offset verification":
    let sigs = @[MethodDef.signalDef("sig1", @[])]
    let mo = genMetaObject(QObject.staticMetaObject, "TestOffset", sigs, [], [])

    let offset = mo.methodOffset()
    let totalCount = mo.methodCount()
    check(offset >= 0)
    check(totalCount > 0)
    check(totalCount >= offset + 1)
