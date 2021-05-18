import std/[strformat, strutils, sugar]
import svvpi

vpiDefine task walk_hierarchy:
  ## Goes through the entire design's hierarchy, and prints the full
  ## names of all of the module instances.
  calltf:
    proc recursiveWalk(modHandle: VpiHandle = nil; level = 0; parentModPath = "") =
      for subModHandle, subModIter in modHandle.vpiHandles2(vpiModule):
        let
          indent = "  ".repeat(level)
          modPath = $vpi_get_str(vpiFullName, subModHandle)
          pathWithoutParent = modPath.dup(removePrefix(parentModPath & "."))
        vpiEcho &"{indent}{pathWithoutParent}"
        recursiveWalk(subModHandle, level + 1, modPath)
    recursiveWalk()

setVlogStartupRoutines(walk_hierarchy)
