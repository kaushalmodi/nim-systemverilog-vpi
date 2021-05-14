import std/[strformat]
from std/math import nil # To prevent clash between math.pow and the pow proc we define below.
import svvpi

type
  VpiTfError = object of Exception

proc quitOnException(systfHandle: VpiHandle) =
  let
    lineNo = vpi_get(vpiLineNo, systfHandle)
  vpiEcho &"ERROR: Line {lineNo}: {getCurrentExceptionMsg()}"
  vpiQuit()

vpiDefine function pow:
  compiletf:
    var
      systfHandle: VpiHandle
    try:
      systfHandle = vpi_handle(vpiSysTfCall, nil)
      let
        argIterator = vpi_iterate(vpiArgument, systfHandle)
      if argIterator == nil:
        raise newException(VpiTfError, "$pow requires 2 arguments; has none")

      for i in 1 .. 3:
        var
          argHandle = vpi_scan(argIterator)

        if i <= 2:
          if argHandle == nil:
            raise newException(VpiTfError, &"$pow requires arg {i}")
        else:
          if argHandle != nil:
            discard vpi_release_handle(argIterator) # free iterator memory
            raise newException(VpiTfError, "$pow requires 2 arguments; has too many")
          break

        let
          argType = vpi_get(vpiType, argHandle)
        if argType notin {vpiReg, vpiIntegerVar, vpiConstant}:
          raise newException(VpiTfError, &"$pow arg {i} must be a number, variable or net; its type was instead {argType}")
    except VpiTfError:
      systfHandle.quitOnException()

  calltf:
    var
      systfHandle: VpiHandle
    try:
      systfHandle = vpi_handle(vpiSysTfCall, nil)
      let
        argIterator = vpi_iterate(vpiArgument, systfHandle)
      var
        base, exp: cint
        argValue = s_vpi_value(format: vpiIntVal)

      for i in 0 .. 1:
        var
          argHandle = vpi_scan(argIterator)
        if i == 1:
          # Release the memory after the last arg is scanned.
          discard vpi_release_handle(argIterator)

        vpi_get_value(argHandle, addr argValue)
        if i == 0:
          base = argValue.value.integer
        else:
          exp = argValue.value.integer

      # Write result to simulation as return value $pow
      argValue.value.integer = math.pow(base.float, exp.float).cint
      discard vpi_put_value(systfHandle, addr argValue, nil, vpiNoDelay)
    except VpiTfError:
      systfHandle.quitOnException()

  sizetf: 32 # $pow returns 32-bit values

setVlogStartupRoutines(pow)
