import svvpi

proc hello() =
  # The proc needs to have the signature "proc (a1: cstring): cint {.cdecl.}"
  # as that's what nimterop auto-parses the `t_vpi_systf_data.calltf` type to.
  proc calltfHello(s: cstring): cint {.cdecl.} =
    vpi_printf("Hello!\n")

  var
    taskDataObj = s_vpi_systf_data(`type`: vpiSysTask,
                                   tfname: "$hello",
                                   calltf: calltfHello,
                                   compiletf: nil,
                                   sizetf: nil)
  discard vpi_register_systf(addr taskDataObj)

# Below does the same thing as above but using the vpiDefineTask
# macro.
vpiDefineTask bye:
  vpi_printf("Bye!\n")

# Register the tasks.
setVlogStartupRoutines(hello, bye)
