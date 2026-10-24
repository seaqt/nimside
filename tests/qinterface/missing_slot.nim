## Expected to fail to compile: `add` is not implemented.
import nimside, ./counter_api

type Partial = ref object of Counter

proc increment(o: Partial) =
  discard

proc describe(o: Partial, prefix: string): string =
  prefix

# An unrelated `add` must not stand in for the slot
proc add(o: string, n: int): int =
  n

qimplement(Counter, Partial)
