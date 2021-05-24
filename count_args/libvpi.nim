import std/[strformat]
import svvpi

when defined(inefficient):
  static:
    echo "Compiling the inefficient version .."

  vpiDefine task count_args:
    ## Count the number of arguments to the calling VPI task/function.
    calltf:
      var
        argCount = 0
      for _, _ in systfHandle.vpiArgs(checkError = true):
        inc argCount
      vpiEcho &"{tfName} on line {vpi_get(vpiLineNo, systfHandle)} has {argCount} arguments."

else:
  import ../common

  vpiDefine task count_args:
    ## Count the number of arguments to the calling VPI task/function.
    calltf:
      vpiEcho &"{tfName} on line {vpi_get(vpiLineNo, systfHandle)} has {systfHandle.getUserData().args.len} arguments."


setVlogStartupRoutines(count_args)
