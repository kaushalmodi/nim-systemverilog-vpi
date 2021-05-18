import svvpi

template returnInt(userData: cstring) =
  var
    argValue = s_vpi_value(format: vpiIntVal)
  argValue.value.integer = case $userData
                           of "1-bit": 1
                           of "2-bits": 3
                           of "8-bits": 255
                           of "32-bits": 1_000_000
                           else: 0
  discard vpi_put_value(systfHandle, addr argValue, nil, vpiNoDelay)

proc returnSize(userData: cstring): cint =
  return case $userData
         of "1-bit": 1
         of "2-bits": 2
         of "8-bits": 8
         else: 32

# The sizetf routine is only used with system functions that are
# registered with the sysfunctype as vpiSizedFunc or
# vpiSizedSignedFunc.
vpiDefine function returns_1bit_val:
  sizetf: returnSize(userData)  # If sizetf is used and functype is not set explicitly,
  # functype: vpiSizedFunc      # it defaults to vpiSizedFunc.
  calltf: returnInt(userData)
  userdata: "1-bit"

vpiDefine function returns_2bit_val:
  sizetf: returnSize(userData) # The order of using sizetf and functype keywords
  functype: vpiSizedFunc       # does not matter.
  calltf: returnInt(userData)
  userdata: "2-bits"

vpiDefine function returns_8bit_val:
  functype: vpiSizedFunc
  sizetf: returnSize(userData)
  calltf: returnInt(userData)
  userdata: "8-bits"

vpiDefine function returns_8bitsigned_val:
  functype: vpiSizedSignedFunc
  sizetf: returnSize(userData)
  calltf: returnInt(userData)
  userdata: "8-bits"

vpiDefine function returns_32bit_val:
  functype: vpiSizedFunc
  sizetf: returnSize(userData)
  calltf: returnInt(userData)
  userdata: "32-bits"

# Register the tasks.
setVlogStartupRoutines(returns_1bit_val,
                       returns_2bit_val,
                       returns_8bit_val,
                       returns_8bitsigned_val,
                       returns_32bit_val)
