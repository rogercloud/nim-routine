import nimroutine\routine, locks

var msgBox1 = createMsgBox[int]()
var msgBox2 = createMsgBox[int]()

proc ping(a, b: MsgBox[int]) {.routine.} =
  var value: int
  for i in 1 .. 10:
    echo "ping: ", i
    send(a, i)
    recv(b, value)
    assert(value == i)
  echo "ping done"

proc pong(a, b: MsgBox[int]) {.routine.} =
  var value: int
  for i in 1 .. 10:
    recv(a, value)
    assert(value == i)
    echo "pong: ", i
    send(b, i)
  echo "pong done"

pRun ping, (a: msgBox1, b: msgBox2)
pRun pong, (a: msgBox1, b: msgBox2)

waitAllRoutine()

msgBox1.deleteMsgBox()
msgBox2.deleteMsgBox()
