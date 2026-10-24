## An interface implemented on the interface type itself: `qimplement(Greeter)`.
import nimside

qinterface:
  type Greeter* = ref object of VirtualQObject
    greeted* {.qproperty(write = false).}: int

  proc greet(o: Greeter, name: string): string {.slot.}

qinterface:
  type Holder* = ref object of VirtualQObject
    value* {.qproperty.}: string
