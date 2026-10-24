## The view's interface: what QML (or a C++ replica) sees. No slot has a body here;
## `counter_backend` implements them.
import nimside

qinterface:
  type Counter* = ref object of VirtualQObject
    count* {.qproperty(write = false).}: int
    label* {.qproperty.}: string

  proc overflowed*(o: Counter, at: int) {.signal.}

  proc increment(o: Counter) {.slot.}
  proc describe(o: Counter, prefix: string): string {.slot.}
