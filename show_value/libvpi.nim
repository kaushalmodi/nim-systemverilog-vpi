import std/[strformat]
import svvpi

proc show_value() =
  proc compiletfShowValue(s: cstring): cint {.cdecl.} =
    # Obtain a handle to the system task instance.
    let
      systfHandle = getVpiHandle(vpiSysTfCall, nil)
    if systfHandle == nil:
      vpiEcho("ERROR: $show_value failed to obtain systf handle")
      vpiQuit()
      return

    # Obtain handles to system task arguments.
    let
      argIterator = vpiIterate(vpiArgument, systfHandle)
    if argIterator == nil:
      vpiEcho("ERROR: $show_value requires 1 argument")
      vpiQuit()
      return

    # Check the type of object in system task arguments.
    var
      argHandle = vpiScan(argIterator)
    let
      argType = vpiGet(vpiType, argHandle)
    if argType notin {vpiNet, vpiReg}:
      vpiEcho("ERROR: $show_value arg must be a net or reg")
      discard vpiFreeObject(argIterator) # free iterator memory
      vpiQuit()
      return

    # Check that there are no more system task arguments.
    argHandle = vpiScan(argIterator)
    if argHandle != nil:
      vpiEcho("ERROR: $show_value can only have 1 argument")
      discard vpiFreeObject(argIterator) # free iterator memory
      vpiQuit()
      return

  proc calltfShowValue(s: cstring): cint {.cdecl.} =
    # Obtain a handle to the system task instance.
    let
      systfHandle = getVpiHandle(vpiSysTfCall, nil)

    # Obtain handle to system task argument.  compiletf has already
    # verified only 1 arg with correct type.
    let
      argIterator = vpiIterate(vpiArgument, systfHandle)
      netHandle = vpiScan(argIterator)
    discard vpiFreeObject(argIterator) # free iterator memory

    # Read current value.
    var
      currentValue = s_vpi_value(format: vpiBinStrVal) # read value as a string
    vpiGetValue(netHandle, addr currentValue)
    vpiEcho &"Signal {vpiGet_str(vpiFullName, netHandle)} has the value {currentValue.value.str}"

  var
    taskDataObj = s_vpiSystf_data(`type`: vpiSysTask,
                                   tfname: "$show_value",
                                   compiletf: compiletfShowValue,
                                   calltf: calltfShowValue,
                                   sizetf: nil)
  discard vpiRegisterSystf(addr taskDataObj)

setVlogStartupRoutines(show_value)
