import std/[strformat]
from std/math import nil # To prevent clash between math.pow and the pow proc we define below.
import svvpi

vpiDefine function pow:
  setup:
    const
      numArgs = 2

  compiletf:
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
    if argIterator == nil:
      vpiException &"{tfName} requires {numArgs} arguments; has none"

    for i in 1 .. numArgs+1:
      var
        argHandle = vpi_scan(argIterator)

      if i <= numArgs:
        if argHandle == nil:
          vpiException &"{tfName} requires arg {i}"
      else:
        if argHandle != nil:
          discard vpi_release_handle(argIterator) # free iterator memory
          vpiException &"{tfName} requires {numArgs} arguments; has too many"
        break

      let
        argType = vpi_get(vpiType, argHandle)
      if argType notin {vpiReg, vpiIntegerVar, vpiConstant}:
        vpiException &"{tfName} arg {i} must be a number, variable or net; its type was instead {argType}"

  calltf:
    let
      argIterator = vpi_iterate(vpiArgument, systfHandle)
    var
      base, exp: cint
      argValue = s_vpi_value(format: vpiIntVal)

    for i in 1 .. numArgs:
      var
        argHandle = vpi_scan(argIterator)
      if i == numArgs:
        # Release the memory after the last arg is scanned.
        discard vpi_release_handle(argIterator)

      vpi_get_value(argHandle, addr argValue)
      case i
      of 1: base = argValue.value.integer
      of 2: exp = argValue.value.integer
      else: discard

    # Write result to simulation as return value $pow
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
