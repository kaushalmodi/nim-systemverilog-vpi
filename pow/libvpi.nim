import std/[strformat]
from std/math import nil # To prevent clash between math.pow and the pow proc we define below.
import svvpi

vpiDefine function pow:
  compiletf:
    systfHandle.vpiNumArgCheck(2)
    for argIndex, argHandle in systfHandle.vpiArgs:
      let
        argType = vpi_get(vpiType, argHandle)
      if argType notin {vpiReg, vpiIntegerVar, vpiConstant}:
        vpiException &"Arg {argIndex} must be a number, variable or net, but its type was {argType}"

  calltf:
    var
      base, exp: cint
      argValue = s_vpi_value(format: vpiIntVal)

    for argIndex, argHandle in systfHandle.vpiArgs:
      vpi_get_value(argHandle, addr argValue)
      vpiCheckError() # Check the status of the previous VPI API call; vpi_get_value in this case.
      # Uncommenting the "$pow("abc", "def")" line in tb.sv will show the above proc in action.

      case argIndex
      of 0: base = argValue.value.integer
      of 1: exp = argValue.value.integer
      else: discard

    argValue.value.integer = math.pow(base.float, exp.float).cint
    discard vpi_put_value(systfHandle, addr argValue, nil, vpiNoDelay)

  sizetf: 32 # $pow returns 32-bit values

  more:
    proc startOfSim(cbDataPtr: ptr s_cb_data): cint {.cdecl.} =
      vpiEcho &"\n{tfName} PLI application is being used.\n"

    var
      cbData = s_cb_data(reason: cbStartOfSimulation,
                         cb_rtn: startOfSim)
    let
      cbHandle = vpi_register_cb(addr cbData)
    discard vpi_release_handle(cbHandle) # Don’t need callback handle


setVlogStartupRoutines(pow)
