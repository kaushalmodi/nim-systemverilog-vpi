import std/[strformat]
import svvpi

vpiDefine task show_all_nets:
  compiletf:
    systfHandle.vpiNumArgCheck(1)
    for argIndex, argHandle in systfHandle.vpiArgs:
      let
        argType = vpi_get(vpiType, argHandle)
      if argType notin {vpiModule}:
        vpiException &"{tfName} arg {argIndex} must be a module instance, but its type was {argType}"

  calltf:
    # Read current simulation time.
    var
      currentTime = s_vpi_time(`type`: vpiScaledRealTime)
    vpi_get_time(systfHandle, addr currentTime)

    for _, moduleHandle in systfHandle.vpiArgs:
      let
        instPath = $vpi_get_str(vpiFullName, moduleHandle)
        moduleName = $vpi_get_str(vpiDefName, moduleHandle)
      vpiEcho &"\nAt time {currentTime.real:2.2f}, nets in module {instPath} ({moduleName}):"
      # Obtain handles to nets in module and read current value.
      for netHandle, netIter in moduleHandle.vpiHandles2(vpiNet, allowNilYield = true):
        if netIter == nil:
          vpiEcho "  no nets found in this module"
        elif netHandle == nil:
          break
        else:
          var
            currentValue = s_vpi_value(format: vpiBinStrVal) # read values as a string
          vpi_get_value(netHandle, addr currentValue)
          vpiEcho &"  net {$vpi_get_str(vpiName, netHandle):<10} value is {currentValue.value.str} (binary)"


setVlogStartupRoutines(show_all_nets)
