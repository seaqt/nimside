## A second implementation of the same interface in the same program: it records
## the calls, as a view-only test would.
import nimside, ./counter_api

type CounterStub* = ref object of Counter
  calls*: seq[string]

proc increment(o: CounterStub) =
  o.calls.add "increment()"

proc add(o: CounterStub, n: int): int =
  o.calls.add "add(" & $n & ")"
  0

proc describe(o: CounterStub, prefix: string): string =
  o.calls.add "describe(" & prefix & ")"
  ""

qimplement(Counter, CounterStub)

proc create*(T: type CounterStub): CounterStub =
  let res = T()
  QObject.create(res)
  res
