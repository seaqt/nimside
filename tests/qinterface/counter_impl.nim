import nimside, ./counter_api

type CounterImpl* = ref object of Counter
  limit: int

proc increment(o: CounterImpl) =
  o.count += 1
  o.countChanged()
  if o.count > o.limit:
    o.overflowed(o.count)

proc add(o: CounterImpl, n: int): int =
  o.count += n
  o.countChanged()
  o.count

proc describe(o: CounterImpl, prefix: string): string =
  prefix & o.label & "=" & $o.count

qimplement(Counter, CounterImpl)

proc create*(T: type CounterImpl, limit: int): CounterImpl =
  let res = T(limit: limit)
  QObject.create(res)
  res
