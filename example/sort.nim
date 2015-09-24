import nimroutine\routine, math, times, sequtils, os

proc quickSort(a: ptr seq[int], lo, hi: int, deep: int) {.routine.}=
    #echo "deep: ", deep
    if hi <= lo: return
    let pivot = a[int((lo+hi)/2)]
    var (i, j) = (lo, hi)

    while i <= j:
        if a[i] < pivot:
            inc i
        elif a[j] > pivot:
            dec j
        elif i <= j:
            swap a[i], a[j]
            inc i
            dec j
    pRun quickSort, (a: a, lo: lo, hi: j, deep: deep+1)
    pRun quickSort, (a: a, lo: i, hi: hi, deep: deep+1)

proc quickSort*(a: ptr seq[int]) =
    pRun quickSort, (a: a, lo: a[].low, hi: a[].high, deep: 0)

randomize(int(epochTime()))
var a = newSeqWith(100, random(100))

echo a
quickSort a.addr
waitAllRoutine()
echo a
