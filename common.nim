import svvpi

type
  VpiUserData* = object
    args*: seq[Vpihandle]
  VpiUserDataRef* = ref VpiUserData

proc getUserData*(systfHandle: VpiHandle): VpiUserDataRef =
  ## Get ref of VpiUserData object from VPI userdata. If the userdata
  ## is empty, create a new VpiUserData object and return its ref.
  var
    vpiUserDataRef = cast[VpiUserDataRef](systfHandle.vpi_get_userdata())
  if vpiUserDataRef == nil:
    # If ref to a VpiUserData object doesn't exist, create it.
    vpiUserDataRef = VpiUserDataRef()
    # Do not garbage-collect this object as we need it for the entire
    # simulation.
    GC_ref(vpiUserDataRef)

    for _, argHandle in systfHandle.vpiArgs:
      vpiUserDataRef.args.add(argHandle)

    # Store ref to VpiUserData object in simulator-allocated user_data
    # storage that is unique for each task/func instance.
    discard systfHandle.vpi_put_userdata(cast[pointer](vpiUserDataRef))
  return vpiUserDataRef
