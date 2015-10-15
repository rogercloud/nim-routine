import nimroutine\routine, locks

var msgBox = createSyncMsgBox[int]()

proc ping(a: MsgBox[int]) {.routine.} =
  var value: int
  for i in 1 .. 10:
    echo "ping: ", i
    send(a, i)
    recv(a, value)
    assert(value == i)
  echo "ping done"

proc pong(a: MsgBox[int]) {.routine.} =
  var value: int
  for i in 1 .. 10:
    recv(a, value)
    assert(value == i)
    echo "pong: ", i
    send(a, i)
  echo "pong done"

pRun ping, (msgBox)
pRun pong, (msgBox)

waitAllRoutine()

msgBox.deleteMsgBox()
