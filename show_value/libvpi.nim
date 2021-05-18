import std/[strformat]
import svvpi

vpiDefine task show_value:
  compiletf:
    systfHandle.vpiNumArgCheck(1)
    for argIndex, argHandle in systfHandle.vpiArgs:
      let
        argType = vpi_get(vpiType, argHandle)
      if argType notin {vpiNet, vpiReg}:
        vpiException &"{tfName} arg {argIndex} must be a net or reg, but its type was {argType}"

  calltf:
    for _, netHandle in systfHandle.vpiArgs:
      var
        currentValue = s_vpi_value(format: vpiBinStrVal) # read value as a string
      vpi_get_value(netHandle, addr currentValue)
      vpiEcho &"Signal {vpi_get_str(vpiFullName, netHandle)} has the value {currentValue.value.str}"


setVlogStartupRoutines(show_value)
