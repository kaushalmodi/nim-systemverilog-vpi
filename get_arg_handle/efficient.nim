import std/[strformat]
import svvpi

proc createArgArray*(systfHandle: VpiHandle): ptr UncheckedArray[VpiHandle] =
  ## Create a sequence of arg handles and save it to VPI userdata.
  var
    argSeq: seq[VpiHandle]

  for _, argHandle in systfHandle.vpiArgs(checkError = true):
    argSeq.add(argHandle)

  let
    argArrayPtr = cast[ptr UncheckedArray[VpiHandle]](alloc(sizeof(VpiHandle) * (argSeq.len + 1)))
  argArrayPtr[][0] = cast[VpiHandle](argSeq.len)
  for argIndex, argHandle in argSeq:
    argArrayPtr[][argIndex+1] = argHandle

  # Store pointer to the VpiHandle array in simulator-allocated
  # user_data storage that is unique for each task/func instance.
  discard systfHandle.vpi_put_userdata(cast[pointer](argArrayPtr))
  return argArrayPtr

proc getArgHandle*(systfHandle: VpiHandle; neededIndex: int): VpiHandle =
  if neededIndex < 1:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is invalid"
    return nil

  # Retrieve pointer to the argument handles array.
  var
    argArrayPtr = cast[ptr UncheckedArray[VpiHandle]](systfHandle.vpi_get_userdata())
  if argArrayPtr == nil:
    # Argument handles array doesn't exist, create it.
    argArrayPtr = systfHandle.createArgArray()

  let
    maxIndex = cast[int](argArrayPtr[][0])

  if neededIndex > maxIndex:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is out of range (max index = {maxIndex})"
    return nil

  return argArrayPtr[][neededIndex]
