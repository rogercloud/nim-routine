# nim-routine
A go routine like nim implementation

## Features
+ Light-weight task.
+ Go channel like message box (communication between tasks).
+ Support recursive task creating, that is to create new task in task itself.

## Routine (Task)
+ How to define a routine?

It looks like normal proc, adding **routine** proc. For example:
```Nim
proc foo(x: int) {.routine.} =
  echo "routine foo: ", x
```

+ How to run routine?

`pRun` is the proc run routine, followed by routine name and a tuple. The tuple contains the routine's parameters. For example:
```Nim
pRun foo, (x: 1)
```

+ What about generic type?
```Nim
proc foo[T](x: T) {.routine.} =
  echo "routine foo: ", x
pRun foo[int], (x: 1)
```

+ If the parameter is void?
```Nim
proc foo() {.routine.} =
  echo "routine void param"
pRun foo
```

+ How to wait a task?
```Nim
var watcher = pRun(foo)
wait(watcher)
```

+ How to wait all tasks?
```Nim
waitAllRoutine()
```

## MsgBox (Channel)
There're two kinds of MsgBox: sync and async. For sync msgbox, sender wait until there's a receiver get the message. For async msgbox, send continues running withoug waiting except msgbox is full (holding message count == capacity). Msgbox's capacity is determined while creating.

+ Create sync MsgBox
```Nim
var msgBox = createSyncMsgBox[int]()
```

+ Create async MsgBox
```Nim
var msgBox = createMsgBox[int]()  # msgBox's capacity is -1, which means unlimited.
var sizedMsgBox = createMsgBox[int](10) # msgBox that can hold 10 message
```

+ Send message
```Nim
send(msgBox, 1) # 1 is the data to be sent
```

+ Receive mssage
```Nim
var data: int
recv(msgBox, data) # data is assigned to msg value
```

## Limitation
+ Not support var param in task. Walkaround: ptr.
+ No return value is support
