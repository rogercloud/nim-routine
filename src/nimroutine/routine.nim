import os, locks, lists

type
  BreakState = object
    isContinue: bool # tell whether this yield need to be continued later
    isSend: bool  # this yield is caused by a send operation
    msgBoxPtr: pointer # this msgBox's pointer (void*) that makes this yield

  Task = object
    isRunable: bool # if the task is runnable
    task: (iterator(tl: TaskList): BreakState{.closure.})

  TaskList = ptr TaskListObj
  TaskListObj = object
    lock: Lock
    list: DoublyLinkedRing[Task]

const threadPoolSize = 8.Natural
var taskListPool = newSeq[TaskListObj](threadPoolSize)
var threadPool= newSeq[Thread[TaskList]](threadPoolSize)

proc isEmpty(tasks: TaskList): bool=
  result = tasks.list.head == nil

proc run(taskNode: DoublyLinkedNode[Task], tasks: TaskList): BreakState {.inline.} =
  result = taskNode.value.task(tasks)

# Run a task, return false if no runnable task found
proc runTask(tasks: TaskList, tracker: var DoublyLinkedNode[Task]): bool {.gcsafe.} =
  if tracker == nil: tracker = tasks.list.head
  let start = tracker

  while not tasks.isEmpty:
    if tracker.value.isRunable:
      tasks.lock.release()
      let ret = tracker.run(tasks)
      tasks.lock.acquire()
      tracker.value.isRunable = false

      if not ret.isContinue:
        let temp = tracker.next
        tasks.list.remove(tracker)
        if tasks.isEmpty:
          tracker = nil
        else:
          tracker = temp
      else:
        tracker = tracker.next
      return true
    else:
      tracker = tracker.next
      if tracker == start:
        return false
  return false      

proc slave(tasks: TaskList) {.thread, gcsafe.} =
  var tracker:DoublyLinkedNode[Task] = nil
  tasks.lock.acquire()
  while true:
    if not runTask(tasks, tracker):
      tasks.lock.release()
      sleep(10)
      tasks.lock.acquire()

proc assignTask(iter: iterator(tl: TaskList): BreakState{.closure.}, index: int) =
  taskListPool[index].lock.acquire()
  taskListPool[index].list.append(Task(isRunable:true, task:iter))
  taskListPool[index].lock.release()

proc initThread(index: int) =
  taskListPool[index].list = initDoublyLinkedRing[Task]()
  taskListPool[index].lock.initLock()    
  createThread(threadPool[index], slave, taskListPool[index].addr)

proc setup =
  for i in 0..<threadPoolSize:
    initThread(i)

setup() 

if isMainModule:
  iterator cnt(tl: TaskList): BreakState{.closure.} =
    for i in 1 .. 5:
      echo i
      sleep(1000)
    yield BreakState(isContinue: true, isSend: false, msgBoxPtr: nil)  
  assignTask(cnt, 0)
  joinThreads(threadPool)