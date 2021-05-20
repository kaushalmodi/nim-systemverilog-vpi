import std/[strformat, strutils]
import svdpi, svvpi

template dbg(str: typed) =
  when defined(debug):
    vpiEcho(str)

## Typedefs and private data used by the Nim procs

## The following struct is used to hold information about a
## probed signal.  Various features of the signal are cached
## here, to avoid making repeated VPI accesses to discover this
## information.  The structure sometimes appears on a linked list
## of signals that need to be serviced (the changeList), and
## struct members to support that linked list are also included.
type
  HookRecord = ref object
   allHooks_link: HookRecord      ## linked list pointer - all records
   changeList_link: HookRecord    ## linked list pointer - records awaiting processing
   on_changeList: bool            ## true if we're on the list, false if not
   check {.cursor.}: HookRecord   ## copy of self-pointer, for safety
   obj: VpiHandle                 ## reference to the monitored signal
   sv_key: cint                   ## unique key to help SV find this
   cb: VpiHandle                  ## VPI value-change callback object
   size: cint                     ## number of bits in the signal
   isSigned: bool                 ## is the signal signed?
   top_mask: cuint                ## word-mask for most significant 32 bits
   top_msb: cuint                 ## MSB position within that word

const
  vlabDpiSuccess = 1
  vlabDpiFailure = 0

var
  # A single list of hook_records that have value changes yet to be handled
  changeList: HookRecord
  # A single list of all hook_records, for use when deallocating memory
  allHooks: HookRecord
  # VPI handle to the single bit that is toggled to notify SV of pending
  # value-changes that require service
  notifier: VpiHandle


## Static (file-local) helper functions

proc report_error(message: string) =
  ## Report an error in a consistent way.  This function should be
  ## used when control will be returned to SV with an error indication
  ## the SV code will then display a more comprehensive error
  ## diagnostic.
  vpiEcho &"*E,VLAB_PROBES: {message}"

proc stop_on_error(message: string) =
  ## Interrupt the simulation because of an error.
  ## After an error, a user can continue from the stop using
  ## simulator command-line functionality.  This may help with
  ## debugging by providing additional trace information, but
  ## behaviour of the signal probe package is not guaranteed
  ## after any error.
  if message.len > 0:
    report_error(message)
  report_error("Stopping.  Continue the run to see further diagnostics")
  discard vpi_control(vpiStop, 1)

proc changeList_pop(): HookRecord =
  ## Get and remove the first (newest) entry from the
  ## list of signals with unserviced value changes.
  ## Return a reference to that entry.
  let
    hook = changeList
  if hook != nil:
    changeList = hook.changeList_link
    hook.on_changeList = false
  return hook

proc changeList_pushIfNeeded(hook: HookRecord) =
  ## Add a signal to the list of unserviced value changes.
  ## But if the signal is already on that list, don't
  ## try to add it again.
  if not hook.on_changeList:
    hook.on_changeList = true
    hook.changeList_link = changeList
    changeList = hook

proc isVerilogType(vpi_type: cint): bool =
  ## Check to see whether a vpiType value represents
  ## an appropriate Verilog type (vector, reg etc) for probing.
  ## Basically we are checking for an integral type, but
  ## there does not seem to be any VPI property for that,
  ## so instead we must exhaustively list all known
  ## integral types.
  return vpi_type in { vpiNet, vpiNetBit, vpiReg, vpiRegBit, vpiPartSelect,
                       vpiBitSelect, vpiBitVar, vpiEnumVar, vpiIntVar,
                       vpiLongIntVar, vpiShortIntVar, vpiIntegerVar, vpiByteVar }

proc chandle_to_hook(hnd: pointer): HookRecord =
  ## Given a handle value obtained from an untrusted source,
  ## cast it to a HookRecord and do some sanity checks.
  let
    hook = cast[HookRecord](hnd)
  if hook != nil and hook.check == hook:
    return hook
  else:
    stop_on_error("Bad chandle argument is not a valid created hook")
    return nil


## Static (file-local) helper functions related to value-change callbacks

proc toggle_notifier(): cint =
  ## Toggle the notifier signal
  if notifier == nil:
    # Throw an error and return FALSE if there's no notifier set up.
    stop_on_error("Value-change callback but no active notifier bit")
    return vpiCbFailure
  else:
    var
      value_s = s_vpi_value(format: vpiScalarVal)
    vpi_get_value(notifier, addr value_s)
    value_s.value.scalar = if value_s.value.scalar == vpi1:
                             vpi0
                           else:
                             vpi1
    discard vpi_put_value(notifier, addr value_s, nil, vpiNoDelay)
    return vpiCbSuccess

proc vc_callback(cbDataPtr: p_cb_data): cint {.cdecl.} =
  ## This is the function that is provided to the VPI as a
  ## value-change callback handler.  There is only one entry point.
  ## Each callback's user_data field holds a pointer to the
  ## corresponding signal's hook_record structure.
  let
    hook = chandle_to_hook(cast[pointer](cbDataPtr[].user_data))
  if hook == nil:
    return vpiCbFailure

  # At any given time, the first signal that suffers a value-change
  # callback will cause the notifier signal to be toggled.  Subsequent
  # callbacks don't toggle the notifier again, as that might prevent
  # it from being detected by SV "@notifier".  Instead, they are just
  # added to the changeList.  When SV eventually responds to the
  # notifier change, it causes the changeList to be scanned, servicing
  # each signal in turn and emptying the changeList.  The next value
  # change will then give rise to another notification.  This
  # mechanism avoids any risk of races whereby a notification might be
  # missed.

  # We detect "first signal" by noting whether the changeList is
  # currently empty.
  let
    require_notification = (changeList == nil)
  # Put this object on the changeList, if it isn't already.
  changeList_pushIfNeeded(hook)
  if require_notification:
    # Toggle the notifier bit.
    return toggle_notifier()
  else:
    return vpiCbSuccess

proc enable_cb(hook: HookRecord) =
  ## Sensitise to a signal by placing a value-change callback on it.
  ## Set up the callback so that it does not collect the signal's
  ## value or the callback time (reduces overhead).  Keep a copy
  ## of the callback handle in the signal's hook record, to simplify
  ## later removal of the callback.
  if hook.cb == nil:
    var
      cbData = s_cb_data(cb_rtn: vc_callback,
                         obj: hook.obj,
                         user_data: cast[cstring](hook),
                         reason: cbValueChange)
    hook.cb = vpi_register_cb(addr cbData)

proc disable_cb(hook: HookRecord) =
  ## Disable value-change callbacks on a signal by removing
  ## its value-change callback completely.
  if hook.cb != nil:
    discard vpi_remove_cb(hook.cb)
    hook.cb = nil

## Proc signatures of functions/tasks exported from SystemVerilog via DPI-C

proc vlab_probes_vcNotify(sv_key: cint) {.importc.}
  ## vlab_probes_processChangeList() calls this DPI export function
  ## once for each probed signal that has a pending value-change event.
  ## It uses a unique int key, rather than the signal's vpi_handle
  ## reference, to work around a tool limitation (no associative array
  ## indexed by chandle).

## Procs for DPI-C import in SystemVerilog

proc vlab_probes_create(name: cstring; sv_key: cint): pointer {.exportc, dynlib.} =
  ## Create an access hook on the signal whose absolute pathname is `name`.
  ## Use `sv_key` as the key shared between SV and C that will be used as
  ## the unique identifier for the created probe object.
  ## This function returns a pointer to a hook_record structure (see
  ## below), which is returned from C as void* and passed to SV as
  ## a "chandle".  It should be saved for use in future operations
  ## on this signal.  In practice the SV code will do this by maintaining
  ## an array of chandle indexed by their unique sv_key.
  ## An access hook freshly created by this function has no properties,
  ## i.e. it does nothing.  To make the access hook useful, it must be
  ## enabled by a suitable call to vlab_probes_setVcEnable (see below).
  let
    obj = vpi_handle_by_name(name, nil)    # Locate the chosen object

  # If there was a problem, return nil to report it.
  if obj == nil:
    vpiEcho &"*W,VLAB_PROBES: create(\"{name}\") could not locate requested signal"
    return nil
  # Check the object is indeed a vector variable or net; error if not.
  let
    objType = vpi_get(vpiType, obj)

  if not isVerilogType(objType):
    vpiEcho &"Unable to create probe on '{name}' with key {sv_key}, type={objType}"
    vpiEcho &"*W,VLAB_PROBES: create(\"{name}\"): object is not a variable or net of integral type"
    return nil

  let
    hook = HookRecord(on_changeList: false,
                      obj: obj,
                      isSigned: vpi_get(vpiSigned, obj) == 1,
                      size: vpi_get(vpiSize, obj),
                      sv_key: sv_key,
                      # Linking all the hooks prevents the GC from collecting those prematurely.
                      # If the GC is changed for arc or any other GC to none, the auto garbage
                      # collection stops entirely and then this allHooks_link is not needed.
                      allHooks_link: allHooks)
  hook.top_msb = cuint(1) shl ((hook.size-1) mod 32)
  hook.top_mask = cuint(2) * hook.top_msb - cuint(1)
  hook.check = hook
  allHooks = hook

  dbg "hook addr = " & $cast[int](hook).toHex()
  dbg &"hook: size = {hook.size}, top_msb = {hook.top_msb:#x}, top_mask = {hook.top_mask:#x}"
  return cast[pointer](hook)

proc vlab_probes_setVcEnable(hnd: pointer; enable: cint) {.exportc, dynlib.} =
  ## Enable or disable value-changed callback on the signal referenced
  ## by HookRecord `hnd`.  If `enable` is true (non-zero), value-change
  ## monitoring is enabled for the signal.  If `enable` is false (zero),
  ## it is disabled.  If monitoring is already enabled and this function
  ## is called with `enable` true, the function has no effect.  Similarly,
  ## if monitoring is disabled and the function is called with `enable`
  ## false, it has no effect.
  let
    hook = chandle_to_hook(hnd)
  if hook == nil:
    return
  if enable == 1:
    enable_cb(hook)
  else:
    disable_cb(hook)

proc vlab_probes_getVcEnable(hnd: pointer): cint {.exportc, dynlib.} =
  ## Find the current enabled/disabled state of value-change callback
  ## on the signal accessed by the hook record referenced by `hnd`.
  ## Returns 0 (disabled) or 1 (enabled).
  let
    hook = chandle_to_hook(hnd)
  if hook == nil:
    return 0
  if hook[].cb != nil:
    return 1

proc vlab_probes_getValue32(hnd: pointer; resultPtr: ptr svLogicVecVal; chunk: cint): cint {.exportc, dynlib.} =
  ## Get the current value of the signal referenced by `hnd`.
  ## The result is placed into the vector pointed by `resultPtr`,
  ## which must be a 32-bit logic or equivalent type.  `chunk`
  ## indicates which 32-bit slice of the signal is to be read:
  ##   chunk=0 gets the least significant 32 bits
  ##   chunk=1 gets bits [63:32],
  ## and in general the function reads bits [32*chunk+:32].
  ## If the specified chunk is completely beyond the end of the vector
  ## (i.e. the signal's size is less than 32*chunk bits) then the
  ## function yields an error.  If the signal does not completely fill
  ## the chunk (for example, a 48-bit signal and chunk=1) then the
  ## result is zero-extended if the signal is unsigned, and
  ## sign-extended in the standard Verilog 4-state way if the signal
  ## is signed.
  var
    chunk = chunk
  let
    hook = chandle_to_hook(hnd)
    chunk_lsb = chunk * 32

  if hook == nil:
    stop_on_error("vlab_probes_getValue32: bad handle")
    return vlabDpiFailure

  if chunk < 0:
    report_error("vlab_probes_getValue32: negative chunk index")
    return vlabDpiFailure

  if chunk_lsb >= hook.size:
    chunk = (hook.size - 1) shr 5 # div by 32

  # Get the whole vector value from VPI
  var
    value_s = s_vpi_value(format: vpiVectorVal)
  vpi_get_value(hook.obj, addr value_s)

  # Copy the relevant aval/bval bits into the output argument.
  let
    vecPtr = value_s.value.vector # type ptr t_vpi_vecval
    # vecPtrp1 = cast[ptr svLogicVecVal](cast[cint](vecPtr) + sizeof(svLogicVecVal)*1)
  # resultPtr = vecPtr[chunk] # This does not compile in Nim
  dbg &"size {hook.size}, chunk {chunk}: vector[0]: aval = {vecPtr[].aval:#x}, bval = {vecPtr[].aval:#x}"
  # dbg &"size {hook.size}, chunk {chunk}: vector[1]: aval = {vecPtrp1[].aval:#x}, bval = {vecPtrp1[].aval:#x}"
  resultPtr[] = cast[ptr svLogicVecVal](cast[cint](vecPtr) + chunk*sizeof(svLogicVecVal))[]

  # Perform sign extension if appropriate.
  if (chunk_lsb + 32) > hook.size:
    # We're working on the most significant word, and it is not full.
    dbg &"size {hook.size}: result before: aval = {resultPtr[].aval:#x}, bval = {resultPtr[].aval:#x}"
    resultPtr[].aval = resultPtr[].aval and hook.top_mask
    resultPtr[].bval = resultPtr[].bval and hook.top_mask
    if hook.isSigned:
      let
        msbBval = resultPtr[].bval and hook.top_msb
      # aval/bval encoding: 00=0, 10=1, 11=X, 01=Z
      #                                  ^     ^
      # There is no point to sign-extend if the MSB bit is X or Z i.e. if MSB bit's bval is 1.
      if msbBval == 0:
        let
          msbAval = resultPtr[].aval and hook.top_msb
        # We need to sign-extend only if the MSB bit is negative i.e. == 1 (aval/bval = 10)
        if msbAval == 1:
          resultPtr[].aval = resultPtr[].aval or (not hook.top_mask)
    dbg &"size {hook.size}: result after: aval = {resultPtr[].aval:#x}, bval = {resultPtr[].aval:#x}"
  return vlabDpiSuccess

proc vlab_probes_getSize(hnd: pointer): cint {.exportc, dynlib.} =
  ## Get the number of bits in the signal referenced by `hnd`.
  let
    hook = chandle_to_hook(hnd)
  if hook == nil:
    return 0 # return size as 0 if hook is nil
  return hook.size

proc vlab_probes_getSigned(hnd: pointer): cint {.exportc, dynlib.} =
  ## Get a flag indicating whether the signal referenced by `hnd`
  ## is signed (0=unsigned, 1=signed).
  let
    hook = chandle_to_hook(hnd)
  if hook == nil:
    return 0 # return unsigned by default if hook is nil
  return hook.isSigned.cint

proc vlab_probes_specifyNotifier(fullname: cstring): cint {.exportc, dynlib.} =
  ## Here's how we get the value change information back in to SV.
  ## First we pass the name of a single-bit signal to this function.
  ## That signal will be toggled by the VPI whenever it requires
  ## attention from SV because one of the probed signals has changed.
  let
    obj = vpi_handle_by_name(fullname, nil) # Locate the chosen notifier signal

  # If there was a problem, return nil to report it.
  if obj == nil:
    report_error("vlab_probes_specifyNotifier() could not locate requested signal")
    return vlabDpiFailure

  # Check the object is indeed a variable of type bit; error if not.
  if vpi_get(vpiType, obj) != vpiBitVar:
    report_error("vlab_probes_specifyNotifier(): object is not a bit variable")
    return vlabDpiFailure

  notifier = obj
  return vlabDpiSuccess

proc vlab_probes_processChangeList() {.exportc, dynlib.} =
  ## When the SV notifier signal is toggled, the SV code must immediately
  ## call this function.  It will service all pending value-change events,
  ## notifying each affected probe object in turn by calling exported
  ## function vlab_probes_vcNotify for that signal.
  while changeList != nil:
    let
      hook = changeList_pop()
    vlab_probes_vcNotify(hook.sv_key)
