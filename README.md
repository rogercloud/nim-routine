# nim-routine
A go routine like nim implementation

## Features
+ Light-weight task.
+ Go channel like message box (communication between tasks).
+ Support recursive task creating, that is to create new task in task itself.

## How to define a routine?
It looks like normal proc, adding **routine** proc. For example:
```Nim
proc foo(x: int) {.routine.} =
  echo "routine foo: ", x
```

## How to run routine?
`pRun` is the proc run routine, followed by routine name and a tuple. The tuple contains the routine's parameters. For example:
```Nim
pRun foo, (x: 1)
```

## What about generic type?
```Nim
proc foo[T](x: T) {.routine.} =
  echo "routine foo: ", x
pRun foo[int], (x: 1)
```

## Limitation
+ Not support var param in task. Walkaround: ptr.
+ No return value is support
