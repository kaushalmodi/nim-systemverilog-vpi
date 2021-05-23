import std/[strformat]
import svvpi

type
  VpiUserData = object
    num: int
    argHandles: seq[Vpihandle]
  VpiUserDataRef = ref VpiUserData

proc createUserData*(systfHandle: VpiHandle): VpiUserDataRef =
  ## Create an object of user data, save it to VPI userdata and return
  ## its ref.
  let
    vpiUserDataRef = VpiUserDataRef()
  # Do not garbage-collect this object as we need it for the entire
  # simulation.
  GC_ref(vpiUserDataRef)

  for _, argHandle in systfHandle.vpiArgs(checkError = true):
    vpiUserDataRef.argHandles.add(argHandle)

  # Store ref to VpiUserData object in simulator-allocated user_data
  # storage that is unique for each task/func instance.
  discard systfHandle.vpi_put_userdata(cast[pointer](vpiUserDataRef))
  return vpiUserDataRef

proc getArgHandle*(systfHandle: VpiHandle; neededIndex: int): VpiHandle =
  if neededIndex < 1:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is invalid"
    return nil

  # Retrieve VpiUserDataRef from userdata.
  var
    userDataRef = cast[VpiUserDataRef](systfHandle.vpi_get_userdata())
  if userDataRef == nil:
    # If ref to a VpiUserData object doesn't exist, create it.
    userDataRef = systfHandle.createUserData()

  let
    maxIndex = userDataRef[].argHandles.len
  if neededIndex > maxIndex:
    vpiEcho &"ERROR: getArgHandle() arg index of {neededIndex} is out of range (max index = {maxIndex})"
    return nil

  return userDataRef.argHandles[neededIndex-1]
