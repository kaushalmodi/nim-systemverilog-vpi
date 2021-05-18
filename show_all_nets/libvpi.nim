import std/[strformat]
import svvpi

type
  VpiTfError = object of Exception

proc quitOnException(systfHandle: VpiHandle) =
  let
    lineNo = vpi_get(vpiLineNo, systfHandle)
  vpiEcho &"ERROR: Line {lineNo}: {getCurrentExceptionMsg()}"
  vpiQuit()

vpiDefine task show_all_nets:
  setup:
    const
      numArgs = 1

  compiletf:
    var
      systfHandle: VpiHandle
    try:
      systfHandle = vpi_handle(vpiSysTfCall, nil)
      let
        argIter = vpi_iterate(vpiArgument, systfHandle)
      if argIter == nil:
        raise newException(VpiTfError, &"$show_all_nets requires {numArgs} arguments; has none")

      for i in 1 .. numArgs+1:
        var
          argHandle = vpi_scan(argIter)

        if i <= numArgs:
          if argHandle == nil:
            raise newException(VpiTfError, &"$show_all_nets requires arg {i}")
        else:
          if argHandle != nil:
            discard vpi_release_handle(argIter) # free iterator memory
            raise newException(VpiTfError, &"$show_all_nets requires {numArgs} arguments; has too many")
          break

        let
          argType = vpi_get(vpiType, argHandle)
        if argType notin {vpiModule}:
          raise newException(VpiTfError, &"$show_all_nets arg {i} must be a module instance; its type was instead {argType}")
    except VpiTfError:
      systfHandle.quitOnException()

  calltf:
    let
      systfHandle = vpi_handle(vpiSysTfCall, nil)
    let
      argIter = vpi_iterate(vpiArgument, systfHandle)
      moduleHandle = vpi_scan(argIter)
    discard vpi_release_handle(argIter) # free iterator memory

    # Read current simulation time.
    var
      currentTime = s_vpi_time(`type`: vpiScaledRealTime)
    vpi_get_time(systfHandle, addr currentTime)

    let
      instPath = $vpi_get_str(vpiFullName, moduleHandle)
      moduleName = $vpi_get_str(vpiDefName, moduleHandle)
    vpiEcho &"\nAt time {currentTime.real:2.2f}, nets in module {instPath} ({moduleName}):"
    # Obtain handles to nets in module and read current value.
    let
      netIter = vpi_iterate(vpiNet, moduleHandle)
    if netIter == nil:
      vpiEcho "  no nets found in this module"
    else:
      var
        currentValue = s_vpi_value(format: vpiBinStrVal) # read values as a string
      while true:
        let
          netHandle = vpi_scan(netIter)
        if netHandle == nil:
          break
        vpi_get_value(netHandle, addr currentValue)
        vpiEcho &"  net {$vpi_get_str(vpiName, netHandle):<10} value is {currentValue.value.str} (binary)"

setVlogStartupRoutines(show_all_nets)
