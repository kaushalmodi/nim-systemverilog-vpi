import std/[strformat, strutils]
import svvpi

vpiDefine task show_all_signals:
  compiletf:
    systfHandle.vpiNumArgCheck(1)
    for argIndex, argHandle in systfHandle.vpiArgs:
      let
        argType = vpi_get(vpiType, argHandle)
      if argType notin {vpiModule}:
        vpiException &"{tfName} arg {argIndex} must be a module instance, but its type was {argType}"

  calltf:
    proc printSignalValues(sigHandle: VpiHandle) =
      let
        sigType = vpi_get(vpiType, sigHandle)
        sigName = $vpi_get_str(vpiName, sigHandle)
      var
        currentValue = s_vpi_value()

      case sigType
      of vpiNet, vpiReg:
        let
          str = if sigType == vpiNet:
                  "net"
                else:
                  "reg"
        currentValue.format = vpiBinStrVal;
        vpi_get_value(sigHandle, addr currentValue);
        vpiEcho &"  {str}     {sigName:<10}  value is  {currentValue.value.str} (binary)"
      of vpiIntegerVar:
        currentValue.format = vpiIntVal;
        vpi_get_value(sigHandle, addr currentValue);
        vpiEcho &"  integer {sigName:<10}  value is  {currentValue.value.integer} (decimal)"
      of vpiRealVar:
        currentValue.format = vpiRealVal;
        vpi_get_value(sigHandle, addr currentValue);
        vpiEcho &"  real    {sigName:<10}  value is  {currentValue.value.real:0.2f}"
      of vpiTimeVar:
        currentValue.format = vpiTimeVal;
        vpi_get_value(sigHandle, addr currentValue);
        let
          timeHighStr = currentValue.value.time.high.toHex(8) # return 8 char wide hex string
          timeLowStr = currentValue.value.time.low.toHex(8)
        vpiEcho &"  time    {sigName:<10}  value is  {timeHighStr}{timeLowStr}"
      else:
        discard

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
