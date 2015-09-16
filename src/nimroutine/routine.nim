import os, locks, lists, tables

const debug = true
proc print[T](data: T) =
  when debug:
    echo data

# Thread
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
    recvWaiter: Table[pointer, seq[ptr Task]]
    sendWaiter: Table[pointer, seq[ptr Task]]

const threadPoolSize = 8.Natural
var taskListPool = newSeq[TaskListObj](threadPoolSize)
var threadPool= newSeq[Thread[TaskList]](threadPoolSize)

proc isEmpty(tasks: TaskList): bool=
  result = tasks.list.head == nil

proc run(taskNode: DoublyLinkedNode[Task], tasks: TaskList): BreakState {.inline.} =
  result = taskNode.value.task(tasks)

proc registerSend(tl: TaskList, msgBox: pointer, task: ptr Task) =
  if not tl.sendWaiter.hasKey(msgBox):
    tl.sendWaiter[msgBox] = newSeq[ptr Task]()
  tl.sendWaiter.mget(msgBox).add(task)

proc registerRecv(tl: TaskList, msgBox: pointer, task: ptr Task) =
  if not tl.recvWaiter.hasKey(msgBox):
    tl.recvWaiter[msgBox] = newSeq[ptr Task]()
  tl.recvWaiter.mget(msgBox).add(task)

proc notifySend(tl: TaskList, msgBox: pointer) =
  if not tl.sendWaiter.hasKey(msgBox):
    return
  for tsk in tl.sendWaiter.mget(msgBox):
    tsk.isRunable = true
  tl.sendWaiter.mget(msgBox).reset()

proc notifyRecv(tl: TaskList, msgBox: pointer) =
  if not tl.recvWaiter.hasKey(msgBox):
    return
  for tsk in tl.recvWaiter.mget(msgBox):
    tsk.isRunable = true
  tl.recvWaiter.mget(msgBox).reset()

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
      else: # not ret.isContinue
        if ret.isSend:
          registerSend(tasks, ret.msgBoxPtr, tracker.value.addr)
        else:
          registerRecv(tasks, ret.msgBoxPtr, tracker.value.addr)
        tracker = tracker.next
      return true
    else: # tracker.value.isRunable
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
      #print("task list is empty:" & $(tasks.isEmpty))
      sleep(10)
      tasks.lock.acquire()

proc assignTask(iter: iterator(tl: TaskList): BreakState{.closure.}, index: int) =
  taskListPool[index].lock.acquire()
  taskListPool[index].list.append(Task(isRunable:true, task:iter))
  taskListPool[index].sendWaiter = initTable[pointer, seq[ptr Task]]()
  taskListPool[index].recvWaiter = initTable[pointer, seq[ptr Task]]()
  taskListPool[index].lock.release()

proc initThread(index: int) =
  taskListPool[index].list = initDoublyLinkedRing[Task]()
  taskListPool[index].lock.initLock()    
  createThread(threadPool[index], slave, taskListPool[index].addr)

proc setup =
  for i in 0..<threadPoolSize:
    initThread(i)

setup() 

# MsgBox
type
  MsgBox[T] = ptr MsgBoxObject[T]
  MsgBoxObject[T] = object
    cap: int  # capability of this MsgBox, if < 0, unlimited
    lock: Lock  # MsgBox protection lock
    data: seq[T]  # data holder
    recvWaiter: seq[TaskList]  # recv waiter's TaskList
    sendWaiter: seq[TaskList]  # send waiter's TaskList

proc createMsgBox[T](cap:int = 0): MsgBox[T] =
  result = cast[MsgBox[T]](allocShared0(sizeof(MsgBoxObject[T])))
  result.cap = cap 
  result.lock.initLock()
  result.data = newSeq[T]()
  result.recvWaiter = newSeq[TaskList]()
  result.sendWaiter = newSeq[TaskList]()

proc deleteMsgBox[T](msgBox: MsgBox[T]) =
  msgBox.lock.deinitLock()
  msgBox.deallocShared()    

proc registerSend[T](tl: TaskList, msgBox: MsgBox[T]) =   
  msgBox.sendWaiter.add(tl)

proc registerRecv[T](tl: TaskList, msgBox: MsgBox[T]) =   
  msgBox.recvWaiter.add(tl)

proc notifySend[T](msgBox: MsgBox[T]) =
  for tl in msgBox.sendWaiter:
    tl.notifySend(cast[pointer](msgBox))
  msgBox.sendWaiter.reset()

proc notifyRecv[T](msgBox: MsgBox[T]) =
  for tl in msgBox.recvWaiter:
    tl.notifyRecv(cast[pointer](msgBox))
  msgBox.recvWaiter.reset()

template send[T](msgBox: MsgBox[T], msg: T):stmt {.immediate.}=
  msgBox.lock.acquire()
  while true:
    if msgBox.cap < 0 or msgBox.data.len < msgBox.cap:
      msgBox.data.add(msg)
      notifyRecv(msgBox)
      break
    else:  
      registerSend(tl, msgBox)
      msgBox.lock.release()
      yield BreakState(isContinue: false, isSend: true, msgBoxPtr: cast[pointer](msgBox))
      msgBox.lock.acquire()
  msgBox.lock.release()

template recv[T](msgBox: MsgBox[T], msg: T): stmt {.immediate.} =
  msgBox.lock.acquire()
  while true:
    if msgBox.data.len > 0:
      msg = msgBox.data[0]
      msgBox.data.delete(0)  # O(n)
      notifySend(msgBox)
      break
    else:  
      registerRecv(tl, msgBox)
      msgBox.lock.release()
      yield BreakState(isContinue: false, isSend: false, msgBoxPtr: cast[pointer](msgBox))
      msgBox.lock.acquire()
  msgBox.lock.release()

if isMainModule:
  var msg = createMsgBox[int]()

  iterator cnt1(tl: TaskList): BreakState{.closure.} =
    var value: int
    for i in 1 .. 5:
      send(msg, i)
      recv(msg, value)
      assert(value == i)
    echo "cnt1 done"
    yield BreakState(isContinue: true, isSend: false, msgBoxPtr: nil)  

  iterator cnt2(tl: TaskList): BreakState{.closure.} =
    var value: int
    for i in 1 .. 5:
      recv(msg, value)
      assert(value == i)
      send(msg, i)
    echo "cnt2 done"
    yield BreakState(isContinue: true, isSend: false, msgBoxPtr: nil)  

  assignTask(cnt1, 0)
  assignTask(cnt2, 0)
  joinThreads(threadPool)