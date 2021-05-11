import std/[strformat]
import svvpi

proc show_value() =
  proc compiletfShowValue(s: cstring): cint {.cdecl.} =
    # Obtain a handle to the system task instance.
    let
      systfHandle = vpi_handle(vpiSysTfCall, nil)
    if systfHandle == nil:
      vpiEcho("ERROR: $show_value failed to obtain systf handle")
      # FIXME: -- Mon May 10 02:17:38 EDT 2021 - kmodi
      # vpi_control doesn't seem to work
      # return vpi_control(vpiFinish, 1)
      return tf_dofinish()

    # Obtain handles to system task arguments.
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
    if argIterator == nil:
      vpiEcho("ERROR: $show_value requires 1 argument")
      # FIXME: -- Mon May 10 02:17:38 EDT 2021 - kmodi
      # vpi_control doesn't seem to work
      # return vpi_control(vpiFinish, 1)
      return tf_dofinish()

    # Check the type of object in system task arguments.
    var
      argHandle = vpi_scan(argIterator)
    let
      argType = vpi_get(vpiType, argHandle)
    if argType notin {vpiNet, vpiReg}:
      vpiEcho("ERROR: $show_value arg must be a net or reg")
      discard vpi_free_object(argIterator) # free iterator memory
      # FIXME: -- Mon May 10 02:17:38 EDT 2021 - kmodi
      # vpi_control doesn't seem to work
      # return vpi_control(vpiFinish, 1)
      return tf_dofinish()

    # Check that there are no more system task arguments.
    argHandle = vpi_scan(argIterator)
    if argHandle != nil:
      vpiEcho("ERROR: $show_value can only have 1 argument")
      discard vpi_free_object(argIterator) # free iterator memory
      # FIXME: -- Mon May 10 02:17:38 EDT 2021 - kmodi
      # vpi_control doesn't seem to work
      # return vpi_control(vpiFinish, 1)
      return tf_dofinish()

  proc calltfShowValue(s: cstring): cint {.cdecl.} =
    # Obtain a handle to the system task instance.
    let
      systfHandle = vpi_handle(vpiSysTfCall, nil)

    # Obtain handle to system task argument.  compiletf has already
    # verified only 1 arg with correct type.
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
      netHandle = vpi_scan(argIterator)
    discard vpi_free_object(argIterator) # free iterator memory

    # Read current value.
    var
      currentValue = s_vpi_value(format: vpiBinStrVal) # read value as a string
    vpi_get_value(netHandle, addr currentValue)
    vpiEcho &"Signal {vpi_get_str(vpiFullName, netHandle)} has the value {currentValue.value.str}"

  var
    taskDataObj = s_vpi_systf_data(`type`: vpiSysTask,
                                   tfname: "$show_value",
                                   compiletf: compiletfShowValue,
                                   calltf: calltfShowValue,
                                   sizetf: nil)
  discard vpi_register_systf(addr taskDataObj)

setVlogStartupRoutines(show_value)
