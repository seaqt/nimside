import nimside, ./greeter_api

proc greet(o: Greeter, name: string): string =
  o.greeted += 1
  o.greetedChanged()
  "hello " & name

qimplement(Greeter)

qimplement(Holder)
