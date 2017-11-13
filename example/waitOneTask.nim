import nimroutine/routine, os

proc task() {.routine.} =
  sleep(1000)

var watcher = pRun(task)

wait(watcher)
echo("done")