import svvpi

proc hello() =
  # The proc needs to have the signature "proc (a1: cstring): cint {.cdecl.}"
  # as that's what nimterop auto-parses the `t_vpi_systf_data.calltf` type to.
  proc calltfHello(s: cstring): cint {.cdecl.} =
    vpiEcho "Hello!"

  var
    taskDataObj = s_vpi_systf_data(`type`: vpiSysTask,
                                   tfname: "$hello",
                                   compiletf: nil,
                                   calltf: calltfHello,
                                   sizetf: nil,
                                   userdata: nil)
  discard vpi_register_systf(addr taskDataObj)

# Below does a similar thing as above but using the vpiDefine macro.
vpiDefine task bye:
  compiletf:
    systfHandle.vpiNumArgCheck(0)
  calltf:
    vpiEcho "Bye!"

# Register the tasks.
setVlogStartupRoutines(hello, bye)
