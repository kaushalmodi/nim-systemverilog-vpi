import std/[strformat]
import svvpi
when defined(inefficient):
  import inefficient
  static:
    echo "Compiling the inefficient version .."
else:
  import efficient

vpiDefine task get_arg_handle_test:
  ## Index for the first arg is 1, and so on.
  ## So the index value of 0 is invalid.
  calltf:
    let
      validArgs = [(1, "a"), (3, "sum")]
      invalidArgs = [(0, "0 (NULL)"), (6, "0 (NULL)")]

    vpiEcho "\nTesting getArgHandle() with valid index values .."
    for arg in validArgs:
      let
        argHandle = systfHandle.getArgHandle(arg[0])
      vpiEcho &"  Handle to arg {arg[0]} is {argHandle.vpi_get_str(vpiName)}: EXPECTED {arg[1]}"

    vpiEcho "\nTesting getArgHandle() with invalid index values .."
    for arg in invalidArgs:
      let
        argHandle = systfHandle.getArgHandle(arg[0])
      vpiEcho &"  Handle to arg {arg[0]} is {cast[int](argHandle)}: EXPECTED {arg[1]}"

    vpiEcho "\n*** All Tests Completed ***"


setVlogStartupRoutines(get_arg_handle_test)
