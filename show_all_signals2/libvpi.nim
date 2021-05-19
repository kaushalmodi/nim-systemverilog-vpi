import std/[strformat]
import svvpi
import ../show_all_signals/common

vpiDefine task show_all_signals:
  compiletf:
    systfHandle.vpiNumArgCheck(0 .. 1)
    for argIndex, argHandle in systfHandle.vpiArgs:
      let
        argType = vpi_get(vpiType, argHandle)
      case argType
      of vpiModule, vpiTask, vpiFunction, vpiNamedBegin, vpiNamedFork:
        continue
      of vpiOperation:
        let
          opType = vpi_get(vpiOpType, argHandle)
        if opType == vpiNullOp:
          continue
        vpiException &"{tfName} arg {argIndex} type was vpiOperation, but the op type was not vpiNullOp, it was {opType}"
      else:
        vpiException &"{tfName} arg {argIndex} type must be a scope instance or null, but it was {argType}"

  calltf:
    # Read current simulation time.
    var
      currentTime = s_vpi_time(`type`: vpiScaledRealTime)
    vpi_get_time(systfHandle, addr currentTime)

    for argHandle, argIter in systfHandle.vpiHandles2(vpiArgument, allowNilYield = true):
      var
        scopeHandle: VpiHandle
      if argIter == nil:
        scopeHandle = systfHandle.vpi_handle(vpiScope)
      elif argHandle == nil:
        break
      else:
        if vpi_get(vpiType, argHandle) in {vpiOperation}:
          scopeHandle = systfHandle.vpi_handle(vpiScope)
        else:
          scopeHandle = argHandle

      let
        scopeName = $vpi_get_str(vpiFullName, scopeHandle)
      vpiEcho &"\nAt time {currentTime.real:2.2f}, signals in scope {scopeName}:"

      # Obtain handles to nets in module and read current value.
      # Nets can only exist if scope is a module.
      if vpi_get(vpiType, scopeHandle) in {vpiModule}:
        for netHandle, _ in scopeHandle.vpiHandles2(vpiNet):
          netHandle.printSignalValues()

      # Note that IEEE 1800-2005 onwards, vpiVariables includes vpiReg
      # and vpiRegArrays. See section "36.12.1 VPI Incompatibilities
      # with other standard versions" of IEEE 1800-2017.
      for sigHandle, _ in scopeHandle.vpiHandles2(vpiVariables):
        sigHandle.printSignalValues()


setVlogStartupRoutines(show_all_signals)
