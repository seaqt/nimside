## The interface: the QObject's properties, signals and slot signatures, with no
## slot bodies. `counter_impl` and `counter_stub` implement it.
import nimside

qinterface:
  type Counter* = ref object of VirtualQObject
    count* {.qproperty(write = false).}: int
    label* {.qproperty.}: string

  proc overflowed*(o: Counter, at: int) {.signal.}

  proc increment(o: Counter) {.slot.}
  proc add(o: Counter, n: int): int {.slot.}
  proc describe(o: Counter, prefix: string): string {.slot.}
