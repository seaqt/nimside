import nimside

qobject:
  type Bad = ref object of VirtualQObject
    value {.qproperty(writable = false).}: string
