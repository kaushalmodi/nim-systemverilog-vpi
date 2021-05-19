import std/[strformat]
import svvpi

vpiDefine task count_args:
  ## Count the number of arguments to the calling VPI task/function.
  calltf:
    var
      argCount = 0
    for _, argHandle in systfHandle.vpiArgs(checkError = true):
      # I am not sure if the below vpi_release_handle call is needed,
      # but adding it anyways as the original C code has it.
      discard argHandle.vpi_release_handle()
      inc argCount
    vpiEcho &"{tfName} on line {vpi_get(vpiLineNo, systfHandle)} has {argCount} arguments."


setVlogStartupRoutines(count_args)
