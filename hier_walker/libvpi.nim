import std/[strformat, strutils, sugar]
import svvpi

vpiDefine task walk_hierarchy:
  ## Goes through the entire design's hierarchy, and prints the full
  ## names of all of the module instances.
  calltf:
    proc recursiveWalk(modHandle: VpiHandle = nil; level = 0; parentModPath = "") =
      let
        modIter = vpi_iterate(vpiModule, modHandle)
      if modIter != nil:
        while true:
          let
            subModHandle = vpi_scan(modIter)
          if subModHandle == nil:
            break
          let
            indent = "  ".repeat(level)
            modPath = $vpi_get_str(vpiFullName, subModHandle)
            pathWithoutParent = modPath.dup(removePrefix(parentModPath & "."))
          vpiEcho &"{indent}{pathWithoutParent}"
          recursiveWalk(subModHandle, level + 1, modPath)
    recursiveWalk()

setVlogStartupRoutines(walk_hierarchy)
