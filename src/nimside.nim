import
  ./nimside/[metaobjectgen, plugingen],
  seaqt/[qobject, qvariant, qmetaobject, qmetatype],
  std/[sequtils, strutils, macros]

export qobject, qvariant, qmetaobject, qmetatype, plugingen

template toOpenArrayByte(v: string): openArray[byte] =
  v.toOpenArrayByte(0, v.high()) # double v eval!

proc assignMemCpy[T](v: var T, p: pointer) =
  copyMem(addr v, p, sizeof(v))

proc assignMemCpy(v: var string, p: pointer) =
  # TODO using variant to gain access to generated types
  when compiles(QVariant.create(QBuiltinMetaType.QString.metaTypeId(), p)):
    let tmp = QVariant.create(QBuiltinMetaType.QString.metaTypeId(), p)
  else:
    let tmp = QVariant.create(QMetaType.fromName("QString".toOpenArrayByte()), p)
  v = tmp.toString()
  tmp.delete()

template declareMemCpy(T: type, v: untyped, p: pointer) =
  when T is ref gen_qobject_types.QObject:
    static:
      raiseAssert "receiving qobject pointers (ie connecting to signals that use qobject) not supported yet"
  var v: T
  assignMemCpy(v, p)

template qproperty*(write = true, notify = true) {.pragma.}
template slot*() {.pragma.}
template signal*() {.pragma.}

template titleCase(s: string): string =
  s[0].toUpperAscii() & s[1 ..^ 1]

proc extractTypeImpl(n: NimNode): NimNode =
  ## attempts to extract the type definition of the given symbol
  case n.kind
  of nnkSym: # can extract an impl
    result = n.getImpl.extractTypeImpl()
  of nnkObjectTy, nnkRefTy, nnkPtrTy:
    result = n
  of nnkBracketExpr:
    if n.typeKind == ntyTypeDesc:
      result = n[1].extractTypeImpl()
    else:
      doAssert n.typeKind == ntyGenericInst
      result = n[0].getImpl()
  of nnkTypeDef:
    result = n[2]
  else:
    error("Invalid node to retrieve type implementation of: " & $n.kind)

proc findPragma(n: NimNode, name: string): NimNode =
  case n.kind
  of nnkPragma:
    if name.eqIdent(n[0]) or n[0].kind == nnkCall and name.eqIdent(n[0][0]):
      return n
  else:
    for nn in n:
      let x = findPragma(nn, name)
      if x != nil:
        return x
  nil

proc hasPragma(n: NimNode, name: string): bool =
  findPragma(n, name) != nil

type
  NimParamDef = object
    name: NimNode
    typ: NimNode

  NimMethodDef = object
    n: NimNode
    name: NimNode
    returnType: NimNode
    params: seq[NimParamDef]

  NimPropDef = object
    n: NimNode
    name: NimNode
    typ: NimNode
    def: PropertyDef

  NimTypeDef = object
    n: NimNode
    objTyp: NimNode
    props: seq[NimPropDef]
    signals: seq[NimMethodDef]
    slots: seq[NimMethodDef]

proc isVoid(v: NimNode): bool =
  v.kind == nnkEmpty or "void".eqIdent(v)

proc toParamDef(v: NimParamDef): NimNode =
  let
    name = newLit($v.name)
    typ = v.typ
  quote:
    ParamDef(name: `name`, metaType: $QBuiltinMetaType.resolve(`typ`))

proc toMethodDef(v: NimMethodDef, isSignal: bool): NimNode =
  let
    name = newLit($v.name)
    params = nnkBracket.newTree(v.params.mapIt(it.toParamDef()))
  if isSignal:
    quote:
      MethodDef.signalDef(`name`, `params`)
  else:
    let returnType =
      if v.returnType.isVoid():
        ident("void")
      else:
        v.returnType

    quote:
      MethodDef.slotDef(`name`, $QBuiltinMetaType.resolve(`returnType`), `params`)

proc toPropDef(v: NimPropDef): NimNode =
  let
    name = newLit($v.name)
    typ = v.typ
    readSlot = newLit($v.def.readSlot)
    writeSlot = newLit($v.def.writeSlot)
    notifySignal = newLit($v.def.notifySignal)
  quote:
    PropertyDef(
      name: `name`,
      metaType: $QBuiltinMetaType.resolve(`typ`),
      readSlot: `readSlot`,
      writeSlot: `writeSlot`,
      notifySignal: `notifySignal`,
    )

proc store[T](ret: T, where: var pointer) =
  when ret is ref:
    if ret == nil:
      where = nil
    else:
      store(ret[], where)
  elif ret is gen_qobject_types.QObject:
    cast[ptr pointer](where)[] = ret.h
  elif ret is gen_qvariant_types.QVariant:
    when compiles(ret.metaType()):
      discard ret.metaType().construct(where, ret.constData())
    else:
      discard QMetaType.construct($QBuiltinMetaType.resolve(T), where, ret.constData())
  else:
    let retV = QVariant.create(ret)
    when compiles(retV.metaType()):
      discard retV.metaType().construct(where, retV.constData())
    else:
      discard QMetaType.construct($QBuiltinMetaType.resolve(T), where, retV.constData())
    retV.delete()

proc genMethodCall(meth: NimMethodDef, name, obj, argv, offset: NimNode): NimNode =
  let
    readParams = nnkStmtList.newTree()
    delParams = nnkStmtList.newTree()
    call = nnkCall.newTree(name)

  if obj != nil:
    call.add(obj)

  for paramIdx, param in meth.params:
    let
      argIdxLit = newLit(paramIdx)
      argName = ident("arg" & $paramIdx)
      paramType = param.typ
    readParams.add quote do:
      declareMemCpy(`paramType`, `argName`, `argv`[`argIdxLit` + `offset`])
    call.add quote do:
      `argName`

  let caller =
    if meth.returnType.isVoid:
      call
    else:
      quote:
        store(`call`, `argv`[0])
  nnkStmtList.newTree(readParams, caller, delParams)

proc readType(n: NimNode): NimTypeDef =
  expectKind(n, {nnkTypeDef})
  let
    typName = n[0].basename()
    typ = nnkTypedef.newTree(typName, n[1], n[2])
    objTyp =
      case typ[2].kind
      of nnkRefTy:
        typ[2][0]
      of nnkObjectTy:
        typ[2]
      else:
        error("Expected type, got " & $typ[2].kind, typ)
    records = objTyp[2]

  var props: seq[NimPropDef]
  if records.kind == nnkRecList:
    for rec in records:
      rec.expectKind({nnkIdentDefs})

      if rec[0].kind == nnkPragmaExpr:
        let name = rec[0][0].basename()

        let qprop = findPragma(rec[0][1], "qproperty")
        if qprop != nil:
          var
            write = true
            notify = true

          if qprop[0].kind == nnkCall:
            for n in qprop[0][1 ..^ 1]:
              case n.kind
              of nnkExprEqExpr:
                if "write".eqIdent(n[0]):
                  write = n[1].boolVal
                elif "notify".eqIdent(n[0]):
                  notify = n[1].boolVal
                else:
                  raisEAssert "Unkown property"
              else:
                raiseAssert "unexpected param " & $n.kind

          props.add(
            NimPropDef(
              n: rec[0][0],
              name: name,
              typ: rec[1],
              def: PropertyDef(
                name: name.strVal,
                # metaType: toMetaTypeName(rec[1]),
                readSlot: name.strVal,
                writeSlot:
                  if write:
                    "set" & titleCase(name.strVal)
                  else:
                    "",
                notifySignal:
                  if notify:
                    name.strVal & "Changed"
                  else:
                    "",
              ),
            )
          )

  NimTypeDef(n: n, objTyp: objTyp, props: props)

type NimProcDef = object
  n: NimNode
  meth: MethodDef

proc readProc(n: NimNode, types: var openArray[NimTypeDef]) =
  let
    name = n.name
    pragma = n.pragma

    isSlot = pragma.hasPragma("slot")
    isSignal = pragma.hasPragma("signal")

  if isSlot == isSignal:
    if isSlot:
      error("Can't be both signal and slot at the same time!", n)
    return # neither signal nor slot - ignore

  if isSignal:
    if n.body.kind != nnkEmpty:
      error("Signal should not have a body", n)

  let params = n.params
  if params.len < 2:
    error("First parameter must be a QObject-derived type", n)

  let typIndex = block:
    var typIndex = -1
    for i in 0 ..< types.len:
      let typName = types[i].n[0].basename()

      if typName.eqIdent(params[1][1]):
        typIndex = i
        break
    if typIndex == -1:
      error(
        "First parameter must be a QObject-derived type in the same qobject block", n
      )
    typIndex

  var paramDefs: seq[NimParamDef]
  for param in params[2 ..< params.len]:
    for name in param[0 ..< param.len - 2]:
      paramDefs.add NimParamDef(name: name, typ: param[^2])

  let def = NimMethodDef(n: n, name: name, returnType: params[0], params: paramDefs)
  if isSignal:
    types[typIndex].signals.add(def)
  else:
    types[typIndex].slots.add(def)

proc canConstruct(m: NimMethodDef): bool =
  true # not anyIt(m.params, toMetaTypeName(it.typ) == QMetaTypeTypeEnum.QObjectStar)

proc processType(p: var NimTypeDef): (NimNode, NimNode) =
  let
    n = p.n
    props = p.props
    typName = n[0].basename()
    className = typName.strVal
    pre = nnkStmtList.newTree()
    post = nnkStmtList.newTree()

  template findSignal(n: string): int =
    var idx = -1
    for i in 0 ..< p.signals.len:
      if n.eqIdent(p.signals[i].name):
        idx = i
        break
    idx

  template findSlot(n: string): int =
    var idx = -1
    for i in 0 ..< p.slots.len:
      if n.eqIdent(p.slots[i].name):
        idx = i
        break
    idx

  let
    voidTyp = ident"void"
    staticMetaObject = ident("staticMetaObject")

  for i, prop in props:
    let
      propName = prop.name
      propType = prop.typ
      signalNameLit =
        if prop.def.notifySignal.len > 0:
          let signalIndex =
            if (let signalIndex = findSignal(prop.def.notifySignal); signalIndex >= 0):
              signalIndex
            else:
              let
                name = ident(prop.def.notifySignal)
                n = quote:
                  proc `name`*(o: `typName`)

              p.signals.add NimMethodDef(
                n: n, name: name, returnType: voidTyp, params: @[]
              )
              pre.add n
              p.signals.high()

          p.signals[signalIndex].name
        else:
          nil

    if prop.def.writeSlot.len > 0 and findSlot(prop.def.writeSlot) < 0:
      p.slots.add NimMethodDef(
        name: ident prop.def.writeSlot,
        returnType: voidTyp,
        params: @[NimParamDef(name: ident "newValue", typ: prop.typ)],
      )

      let writeSlotLit = p.slots[^1].name

      if signalNameLit != nil:
        pre.add quote do:
          proc `writeSlotLit`*(o: `typName`, v: `propType`) =
            if o.`propName` != v:
              o.`propName` = v
              o.`signalNameLit`()

      else:
        pre.add quote do:
          proc `writeSlotLit`*(o: `typName`, v: `propType`) =
            o.`propName` = v

    if prop.def.readSlot.len > 0 and findSlot(prop.def.readSlot) < 0:
      p.slots.add NimMethodDef(
        name: ident(prop.def.readSlot), returnType: propType, params: @[]
      )
      let slotName = p.slots[^1].name
      pre.add quote do:
        proc `slotName`*(o: `typName`): lent `propType` =
          o.`propName`

  for signalIndex, signal in p.signals:
    let signalIndexLit = newLit(signalIndex)
    # TODO skip qvariant - we use it only to get access to the autogenerated
    #      type conversion

    let
      variants = nnkStmtList.newTree()
      delvariants = nnkStmtList.newTree()
      args = ident("args")
      argCount = newLit(signal.params.len())
    for i, param in signal.params:
      let
        idx = newLit(i)
        id = ident("arg" & $i)
        name = param.name
      variants.add quote do:
        let `id` =
          when `name` is ref gen_qobject_types.QObject:
            gen_qvariant_types.QVariant.fromValue(`name`[])
          else:
            gen_qvariant_types.QVariant.create(`name`)
        `args`[`idx` + 1] = `id`.constData()
      delvariants.add quote do:
        `id`.delete()

    let self = signal.n.params[1][0]

    signal.n.body =
      if signal.params.len > 0:
        quote:
          var `args`: array[`argCount` + 1, pointer]
          `variants`
          gen_qobjectdefs_types.QMetaObject.activate(
            `self`[],
            `staticMetaObject`(`typName`),
            cint `signalIndexLit`,
            addr `args`[0],
          )
          `delvariants`
      else:
        quote:
          gen_qobjectdefs_types.QMetaObject.activate(
            `self`[], `staticMetaObject`(`typName`), cint `signalIndexLit`, nil
          )
    post.add signal.n

  # Multi-threading version that takes a `ptr` instead of a `ref`
  # TODO a bit ugly as far as approaches go - the user is supposed to pass
  #      pointers to ref objects and deal with the lifetime issues that ensue
  # TODO maybe not copy-paste the body generation :)
  for signalIndex, signal in p.signals:
    let
      signalNameLit = signal.name
      signalIndexLit = newLit(signalIndex)
    # TODO skip qvariant - we use it only to get access to the autogenerated
    #      type conversion

    let
      variants = nnkStmtList.newTree()
      delvariants = nnkStmtList.newTree()
      args = ident("args")
      argCount = newLit(signal.params.len())
    for i, param in signal.params:
      let
        idx = newLit(i)
        id = ident("arg" & $i)
        name = param.name
      variants.add quote do:
        let `id` =
          when `name` is ref gen_qobject_types.QObject:
            gen_qvariant_types.QVariant.fromValue(`name`[])
          else:
            gen_qvariant_types.QVariant.create(`name`)
        `args`[`idx` + 1] = `id`.constData()
      delvariants.add quote do:
        `id`.delete()

    let
      self = ident("self")

      body =
        if signal.params.len > 0:
          quote:
            var `args`: array[`argCount` + 1, pointer]
            `variants`
            gen_qobjectdefs_types.QMetaObject.activate(
              `self`[],
              `staticMetaObject`(`typName`),
              cint `signalIndexLit`,
              addr `args`[0],
            )
            `delvariants`
        else:
          quote:
            gen_qobjectdefs_types.QMetaObject.activate(
              `self`[], `staticMetaObject`(`typName`), cint `signalIndexLit`, nil
            )
      selfPtrParam = nnkIdentDefs.newTree(
        self,
        quote do:
          ptr typeof(`typName`()[]),
        newEmptyNode(),
      )

    post.add newProc(
      signalNameLit,
      @[newEmptyNode(), selfPtrParam] &
        signal.params.mapIt(nnkIdentDefs.newTree(it.name, it.typ, newEmptyNode())),
      body,
    )

  let
    signalsLit = nnkBracket.newTree(p.signals.mapIt(it.toMethodDef(isSignal = true)))
    slotsLit = nnkBracket.newTree(p.slots.mapIt(it.toMethodDef(isSignal = false)))
    propsLit = nnkBracket.newTree(p.props.mapIt(it.toPropDef()))
    typNameLit = newLit(className)
    metaObjectInst = ident(className & "MetaObjectInstance")

    metaObjectNode = quote:
      var `metaObjectInst` {.global.}: pointer
      proc `staticMetaObject`*(_: type `typName`): gen_qobjectdefs_types.QMetaObject =
        const (data, stringdata, metaTypes) =
          genMetaObjectData(`typNameLit`, `signalsLit`, `slotsLit`, `propsLit`)
        if `metaObjectInst` == nil:
          var tmp = createMetaObject(
            gen_qobject.staticMetaObject(gen_qobject_types.QObject),
            data,
            stringdata,
            metaTypes,
          )
          tmp.owned = false
          `metaObjectInst` = tmp.h
        let x = gen_qobjectdefs_types.QMetaObject(h: `metaObjectInst`, owned: false)
        x

      method metaObject*(self: `typName`): gen_qobjectdefs_types.QMetaObject =
        `staticMetaObject`(`typName`)

  pre.insert(0, metaObjectNode)

  let
    id = ident("id")
    argv = ident("argv")
    self = ident("self")
    invokeCase = nnkCaseStmt.newTree(id)
    readPropCase = nnkCaseStmt.newTree(id)
    writePropCase = nnkCaseStmt.newTree(id)

  for i, s in p.signals:
    let signalIdxLit = newLit(i)
    invokeCase.add nnkOfBranch.newTree(
      signalIdxLit,
      nnkStmtList.newTree(
        quote do:
          gen_qobjectdefs_types.QMetaObject.activate(
            `self`[], cint `signalIdxLit`, `argv`
          )
      ),
    )

  for i, s in p.slots:
    if canConstruct(s):
      invokeCase.add nnkOfBranch.newTree(
        newLit(i + p.signals.len), genMethodCall(s, s.name, self, argv, newLit(1))
      )
    else:
      warning "TODO Cannot receive QObject parameters, skipping metacall: " &
        s.name.strVal, s.name

  invokeCase.add nnkElse.newTree(
    nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))
  )

  for i, prop in props:
    if prop.def.readSlot.len > 0:
      let slot = p.slots[findSlot(prop.def.readSlot)]
      if canConstruct(slot):
        readPropCase.add nnkOfBranch.newTree(
          newLit(i), genMethodCall(slot, slot.name, self, argv, newLit(1))
        )
      else:
        warning "TODO Cannot receive QObject parameters, skipping metacall: " &
          slot.name.strVal, slot.name

    if prop.def.writeSlot.len > 0:
      let slot = p.slots[findSlot(prop.def.writeSlot)]
      if canConstruct(slot):
        writePropCase.add nnkOfBranch.newTree(
          newLit(i), genMethodCall(slot, slot.name, self, argv, newLit(0))
        )
      else:
        warning "TODO Cannot receive QObject parameters, skipping metacall: " &
          slot.name.strVal, slot.name

  readPropCase.add nnkElse.newTree(
    nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))
  )
  writePropCase.add nnkElse.newTree(
    nnkStmtList.newTree(nnkDiscardStmt.newTree(newEmptyNode()))
  )

  let
    methodCountLit = newLit(p.signals.len + p.slots.len)
    propCountLit = newLit(props.len)
    metacall = ident("metacall")
  post.add quote do:
    method `metacall`(`self`: `typName`, c: cint, id: cint, a: pointer): cint =
      var `id` = gen_qobject.QObjectmetacall(`self`[], c, id, a)
      if `id` < 0:
        return `id`

      const propEnums =
        when declared(QueryPropertyDesignable):
          {
            QMetaObjectCallEnum.ResetProperty,
            QMetaObjectCallEnum.RegisterPropertyMetaType,
            QMetaObjectCallEnum.QueryPropertyDesignable,
            QMetaObjectCallEnum.QueryPropertyScriptable,
            QMetaObjectCallEnum.QueryPropertyStored,
            QMetaObjectCallEnum.QueryPropertyEditable,
            QMetaObjectCallEnum.QueryPropertyUser,
          }
        else:
          {
            QMetaObjectCallEnum.ResetProperty, QMetaObjectCallEnum.BindableProperty,
            QMetaObjectCallEnum.RegisterPropertyMetaType,
          }

      let `argv` = cast[ptr UncheckedArray[pointer]](a)
      case c
      of gen_qobjectdefs.QMetaObjectCallEnum.InvokeMetaMethod:
        `invokeCase`
        `id` - cint(`methodCountLit`)
      of gen_qobjectdefs.QMetaObjectCallEnum.RegisterMethodArgumentMetaType:
        `id` - cint(`methodCountLit`)
      of gen_qobjectdefs.QMetaObjectCallEnum.ReadProperty:
        `readPropCase`
        `id` - cint(`propCountLit`)
      of gen_qobjectdefs.QMetaObjectCallEnum.WriteProperty:
        `writePropCase`
        `id` - cint(`propCountLit`)
      of propEnums:
        `id` - cint(`propCountLit`)
      else:
        `id`

  post.add quote do:
    proc setup*(o: `typName`) =
      gen_qobject_types.QObject.create(o)

  for signal in p.signals:
    if not canConstruct(signal):
      warning "TODO Cannot receive QObject parameters, skipping signal connector: " &
        signal.name.strVal, signal.name
      continue

    let
      sigDef = signal.toMethodDef(isSignal = true)
      onSignal = ident("on" & titleCase(signal.name.strVal))
      signature = quote:
        block:
          const sig = cstring(`sigDef`.signature())
          sig
      params = nnkFormalParams.newTree(newEmptyNode())
      callback = ident("callback")
      argv = ident("argv")
      callCallback = genMethodCall(signal, callback, nil, argv, newLit(1))
      callbackTy = nnkProcTy.newTree(
        params,
        nnkPragma.newTree(
          ident"gcsafe",
          nnkExprColonExpr.newTree(newIdentNode("raises"), nnkBracket.newTree()),
        ),
      )

    for p in signal.params:
      params.add(nnkIdentDefs.newTree(p.name, p.typ, newEmptyNode()))

    post.add quote do:
      proc `onSignal`*(sender: `typName`, `callback`: `callbackTy`) =
        proc inner(args: pointer) =
          let `argv` {.used.} = cast[ptr UncheckedArray[pointer]](args)
          `callCallback`

        discard QObject.connectRaw(
          sender[], `signature`, sender[], inner, 0, `typName`.staticMetaObject()
        )

  (pre, post)

macro qobject*(body: untyped): untyped =
  result = nnkStmtList.newTree()

  # Process all types first so as to avoid code ordering issues
  var typeDefs: seq[NimTypeDef]
  for n in body:
    case n.kind
    of nnkTypeSection:
      for i in 0 ..< n.len:
        typeDefs.add readType(n[i])
        n[i] = typeDefs[^1].n
      result.add n
    else:
      discard # result.add n

  # Next come user-supplied signals and slots
  for i in 0 ..< body.len:
    let n = body[i]
    case n.kind
    of nnkProcDef:
      readProc(n, typeDefs)
    else:
      discard

  var post = nnkStmtList.newTree()

  # Finally, process all types and write out their helpers / metadata
  for typDef in typeDefs.mitems():
    let (a, b) = processType(typDef)
    result.add a
    post.add b

  for n in body:
    case n.kind
    of nnkTypeSection:
      discard
    else:
      # Other stuff comes after auto-generated helpers
      result.add n

  result.add post

  #debugEcho repr(result)

when isMainModule:
  import seaqt/[qstringlistmodel, qobject as qo, qmetaobject, qmetamethod]

  qobject:
    type
      OtherObject = ref object of VirtualQObject

      Object = ref object of VirtualQObject
        stringProp {.qproperty.}: string
        stringListProp {.qproperty.}: seq[string]
        stringListModelProp {.qproperty(write = false, notify = false).}:
          QStringListModel
        otherProp {.qproperty(write = false, notify = false).}: OtherObject

        slotNoParamCalls: int

    proc slotNoParam(v: Object) {.slot.} =
      v.slotNoParamCalls += 1

  let o = Object()
  QObject.create(o)

  doAssert QMetaObject.invokeMethod(o[], "slotNoParam")
  doAssert o.slotNoParamCalls == 1

  doAssert o.otherProp() == nil

  let
    mo = o.metaObject()
    sp = mo.property(mo.indexOfProperty("stringProp"))

  doAssert sp.write(o[], QVariant.create("test"))

  let v = sp.read(o[])
  doAssert v.toString() == "test"
