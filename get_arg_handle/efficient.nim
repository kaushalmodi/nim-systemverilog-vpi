import std/[strformat]
import svvpi
import ../common

proc getArgHandle*(systfHandle: VpiHandle; neededIndex: int): VpiHandle =
  if neededIndex < 1:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is invalid"
    return nil

  let
    vpiUserDataRef = systfHandle.getUserData()
    maxIndex = vpiUserDataRef.args.len
  if neededIndex > maxIndex:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is out of range (max index = {maxIndex})"
    return nil

  return vpiUserDataRef.args[neededIndex-1]
