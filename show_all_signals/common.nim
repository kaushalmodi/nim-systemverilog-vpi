import std/[strformat, strutils]
import svvpi

proc printSignalValues*(sigHandle: VpiHandle) =
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
