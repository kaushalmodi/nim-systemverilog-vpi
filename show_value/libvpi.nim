import std/[strformat]
import svvpi

vpiDefine task show_value:
  compiletf:
    # Obtain handles to system task arguments.
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
    if argIterator == nil:
      vpiException &"{tfName} requires 1 argument"

    # Check the type of object in system task arguments.
    var
      argHandle = vpi_scan(argIterator)
    let
      argType = vpi_get(vpiType, argHandle)
    if argType notin {vpiNet, vpiReg}:
      discard vpi_release_handle(argIterator) # free iterator memory
      vpiException &"{tfName} arg must be a net or reg"

    # Check that there are no more system task arguments.
    argHandle = vpi_scan(argIterator)
    if argHandle != nil:
      discard vpi_release_handle(argIterator) # free iterator memory
      vpiException &"{tfName} can only have 1 argument"

  calltf:
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
