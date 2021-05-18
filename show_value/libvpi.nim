import std/[strformat]
import svvpi

vpiDefine task show_value:
  compiletf:
    # Obtain a handle to the system task instance.
    let
      systfHandle = vpi_handle(vpiSysTfCall, nil)
    if systfHandle == nil:
      vpiEcho &"ERROR: {tfName} failed to obtain systf handle"
      vpiQuit()
      return

    # Obtain handles to system task arguments.
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
    if argIterator == nil:
      vpiEcho &"ERROR: {tfName} requires 1 argument"
      vpiQuit()
      return

    # Check the type of object in system task arguments.
    var
      argHandle = vpi_scan(argIterator)
    let
      argType = vpi_get(vpiType, argHandle)
    if argType notin {vpiNet, vpiReg}:
      vpiEcho &"ERROR: {tfName} arg must be a net or reg"
      discard vpi_release_handle(argIterator) # free iterator memory
      vpiQuit()
      return

    # Check that there are no more system task arguments.
    argHandle = vpi_scan(argIterator)
    if argHandle != nil:
      vpiEcho &"ERROR: {tfName} can only have 1 argument"
      discard vpi_release_handle(argIterator) # free iterator memory
      vpiQuit()
      return

  calltf:
    # Obtain a handle to the system task instance.
    let
      systfHandle = vpi_handle(vpiSysTfCall, nil)

    # Obtain handle to system task argument.  compiletf has already
    # verified only 1 arg with correct type.
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
      netHandle = vpi_scan(argIterator)
    discard vpi_release_handle(argIterator) # free iterator memory

    # Read current value.
    var
      currentValue = s_vpi_value(format: vpiBinStrVal) # read value as a string
    vpi_get_value(netHandle, addr currentValue)
    vpiEcho &"Signal {vpi_get_str(vpiFullName, netHandle)} has the value {currentValue.value.str}"

setVlogStartupRoutines(show_value)
