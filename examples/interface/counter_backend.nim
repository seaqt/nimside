## The implementation, in a module of its own: plain procs, then `qimplement`.
## Leave one out and the compile fails, naming the slot.
import nimside, ./counter

type Backend* = ref object of Counter
  limit: int

proc increment(o: Backend) =
  o.count += 1
  o.countChanged()
  if o.count > o.limit:
    o.overflowed(o.count)

proc describe(o: Backend, prefix: string): string =
  prefix & o.label & ": " & $o.count

qimplement(Counter, Backend)

proc create*(T: type Backend, limit: int): Backend =
  let res = T(limit: limit)
  QObject.create(res)
  res
