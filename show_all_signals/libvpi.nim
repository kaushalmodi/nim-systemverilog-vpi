import std/[strformat]
import svvpi
import common

vpiDefine task show_all_signals:
  compiletf:
    systfHandle.vpiNumArgCheck(1)
    for argIndex, argHandle in systfHandle.vpiArgs:
      let
        argType = vpi_get(vpiType, argHandle)
      if argType notin {vpiModule}:
        vpiException &"Arg {argIndex} must be a module instance, but its type was {argType}"

  calltf:
    # Read current simulation time.
    var
      currentTime = s_vpi_time(`type`: vpiScaledRealTime)
    vpi_get_time(systfHandle, addr currentTime)

    for _, moduleHandle in systfHandle.vpiArgs:
      let
        instPath = $vpi_get_str(vpiFullName, moduleHandle)
        moduleName = $vpi_get_str(vpiDefName, moduleHandle)
      vpiEcho &"\nAt time {currentTime.real:2.2f}, signals in module {instPath} ({moduleName}):"
      # Obtain handles to signals in module and read current value.
      # Note that IEEE 1800-2005 onwards, vpiVariables includes vpiReg
      # and vpiRegArrays. See section "36.12.1 VPI Incompatibilities
      # with other standard versions" of IEEE 1800-2017.
      for sigHandle, _ in moduleHandle.vpiHandles2([vpiNet, vpiVariables]):
        sigHandle.printSignalValues()


setVlogStartupRoutines(show_all_signals)
