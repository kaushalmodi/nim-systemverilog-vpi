import std/[strformat]
import svvpi

proc getArgHandle*(systfHandle: VpiHandle; neededIndex: int): VpiHandle =
  if neededIndex < 1:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is invalid"
    return nil

  for argIndex, argHandle, argIter in systfHandle.vpiHandles3(vpiArgument, checkError = true):
    if argIndex+1 == neededIndex: # Because argIndex begins with 0, while neededIndex is 1 for first arg.
      if argHandle != nil:
        discard argIter.vpi_release_handle()
      return argHandle

  # If the control reaches at this point, it means that neededIndex was too large.
  vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is out of range"
  return nil
