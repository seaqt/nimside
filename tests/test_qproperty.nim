import
  std/[compilesettings, os, strutils],
  nimside,
  seaqt/[qmetaobject, qmetaproperty],
  unittest2

qobject:
  type
    Defaults = ref object of VirtualQObject
      value {.qproperty.}: string

    Explicit = ref object of VirtualQObject
      value {.qproperty(write = true, notify = true).}: string

    Disabled = ref object of VirtualQObject
      value {.qproperty(write = false, notify = false).}: string

proc valueProp(mo: QMetaObject): QMetaProperty =
  mo.property(mo.indexOfProperty("value"))

proc checkFixture(name: string): tuple[output: string, exitCode: int] =
  # Compile a file that is expected to fail in the qobject macro - `nim check`
  # would skip the `gorge` that finds the Qt version
  var cmd =
    getCurrentCompilerExe().quoteShell & " c --compileOnly --hints:off --nimcache:" &
    quoteShell(querySetting(nimcacheDir) / "fixtures" / name)
  for p in querySettingSeq(searchPaths):
    cmd.add " --path:" & p.quoteShell
  gorgeEx(cmd & " " & (currentSourcePath.parentDir / "fixtures" / name).quoteShell)

suite "qproperty arguments":
  test "write = true, notify = true behave like the defaults":
    for mo in [Defaults.staticMetaObject(), Explicit.staticMetaObject()]:
      let p = mo.valueProp()
      check:
        p.isReadable()
        p.isWritable()
        p.hasNotifySignal()
        p.notifySignal().methodSignature() == @(
          toOpenArrayByte("valueChanged()", 0, 13)
        )

    check:
      compiles(Explicit().setValue("x"))
      compiles(Explicit().valueChanged())

  test "write = false, notify = false":
    let p = Disabled.staticMetaObject().valueProp()
    check:
      p.isReadable()
      not p.isWritable()
      not p.hasNotifySignal()
      not compiles(Disabled().setValue("x"))

  test "unknown argument is a compile error naming it":
    const res = checkFixture("qproperty_unknown_arg.nim")
    check:
      res.exitCode != 0
      "Unknown qproperty argument `writable`" in res.output

  test "non-boolean value is a compile error":
    const res = checkFixture("qproperty_bad_bool.nim")
    check:
      res.exitCode != 0
      "Expected true or false, got yes" in res.output
