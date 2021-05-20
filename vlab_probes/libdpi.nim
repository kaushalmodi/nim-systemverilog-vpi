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
  HookRecord = object
   allHooks_link: ref HookRecord      ## linked list pointer - all records
   changeList_link: ref HookRecord    ## linked list pointer - records awaiting processing
   on_changeList: cint                ## 1 if we're on the list, 0 if not
   check {.cursor.}: ref HookRecord              ## copy of self-pointer, for safety
   obj: VpiHandle                     ## reference to the monitored signal
   sv_key: cint                       ## unique key to help SV find this
   cb: VpiHandle                      ## VPI value-change callback object
   size: cint                         ## number of bits in the signal
   isSigned: cint                     ## is the signal signed?
   top_mask: cuint                    ## word-mask for most significant 32 bits
   top_msb: cuint                     ## MSB position within that word
  HookRecordRef = ref HookRecord

var
  # A single list of hook_records that have value changes yet to be handled
  changeList: HookRecordRef
  # A single list of all hook_records, for use when deallocating memory
  allHooks: HookRecordRef
  # VPI handle to the single bit that is toggled to notify SV of pending
  # value-changes that require service
  notifier: VpiHandle
  # VPI handle to the simulation reset callback
  reset_callback: VpiHandle


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

proc allocate_hook_record(): HookRecordRef =
  ## Get and initialize a new s_hook_record from the heap.
  ## Add it to the allHooks structure to support memory
  ## deallocation on simulator restart.
  let
    recRef = HookRecordRef(on_changeList: 0.cint,
                           obj: nil,
                           allHooks_link: allHooks)
  dbg "allocate_hook_record: recRef addr = " & $cast[int](recRef).toHex()
  recRef.check = recRef
  allHooks = recRef

  return recRef

proc free_hook_record(recRef: HookRecordRef) =
  ## Deallocate a single hook_record structure.
  ## Destroy its internal referenced VPI objects before deallocation.
  if recRef == nil:
    return
  if recRef.cb != nil:
    discard vpi_remove_cb(recRef.cb)
  if recRef.obj != nil:
    discard vpi_release_handle(recRef.obj)

proc free_all_hook_records() =
  ## Deallocate all hook record structures that exist on the allHooks list.
  while allHooks != nil:
    let
      recRef = allHooks
    allHooks = recRef.allHooks_link
    free_hook_record(recRef)

proc free_everything() =
  ## Deallocate all memory structures owned by this VPI application.
  ## This will typically be done by the VPI simulation restart callback.
  ## NOTE that the restart callback itself is NOT deallocated here,
  ## because this function is probably called from within that callback.
  if notifier != nil:
    discard vpi_release_handle(notifier)
  free_all_hook_records()

proc changeList_pop(): HookRecordRef =
  ## Get and remove the first (newest) entry from the
  ## list of signals with unserviced value changes.
  ## Return a reference to that entry.
  let
    recRef = changeList
  if recRef != nil:
    changeList = recRef.changeList_link
    recRef.on_changeList = 0
  return recRef

proc changeList_pushIfNeeded(recRef: HookRecordRef) =
  ## Add a signal to the list of unserviced value changes.
  ## But if the signal is already on that list, don't
  ## try to add it again.
  if recRef.on_changeList == 0.cint:
    recRef.on_changeList = 1
    recRef.changeList_link = changeList
    changeList = recRef

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

proc chandle_to_hook(hnd: pointer): HookRecordRef =
  ## Given a handle value obtained from an untrusted source,
  ## cast it to a HookRecordRef and do some sanity checks.
  let
    recRef = cast[HookRecordRef](hnd)
  if recRef != nil and recRef.check == recRef:
    return recRef
  else:
    stop_on_error("Bad chandle argument is not a valid created hook")
    return nil


## Static (file-local) helper functions related to simulator action callbacks

proc action_callback(cbDataPtr: p_cb_data): cint {.cdecl.} =
  ## The callback function used to deal with simulator actions.
  ## Currently it handles only cbStartOfReset, which is caused by
  ## an interactive restart of the simulation back to time zero.
  if cbDataPtr[].reason == cbStartOfReset:
    vpiEcho "\n\n*I,VLAB_PROBE: cbStartOfReset, deallocate all internal data\n"
    free_everything()
  return 1

proc setup_reset_callback() =
  ## Set up reset/restart callbacks, removing any old callback if
  ## necessary.
  # Remove any existing callback
  if reset_callback != nil:
    discard vpi_remove_cb(reset_callback)

  var
    # Time and value objects should not be needed, but Xcelium requires them
    time_s = s_vpi_time(`type`: vpiSuppressTime)
    value_s = s_vpi_value(format: vpiSuppressVal)
    # Set up the new callback
    cb_data = s_cb_data(cb_rtn: action_callback,
                        obj: nil,
                        user_data: nil,
                        time: addr time_s,
                        value: addr value_s,
                        reason: cbStartOfReset)
  reset_callback = vpi_register_cb(addr cb_data)


## Static (file-local) helper functions related to value-change callbacks

proc toggle_notifier(): cint =
  ## Toggle the notifier signal
  if notifier == nil:
    # Throw an error and return FALSE if there's no notifier set up.
    stop_on_error("Value-change callback but no active notifier bit")
    return 0
  else:
    var
      value_s = s_vpi_value(format: vpiScalarVal)
    vpi_get_value(notifier, addr value_s)
    value_s.value.scalar = if value_s.value.scalar == vpi1:
                             vpi0
                           else:
                             vpi1
    discard vpi_put_value(notifier, addr value_s, nil, vpiNoDelay)
    return 1

proc vc_callback(cbDataPtr: p_cb_data): cint {.cdecl.} =
  ## This is the function that is provided to the VPI as a
  ## value-change callback handler.  There is only one entry point.
  ## Each callback's user_data field holds a pointer to the
  ## corresponding signal's hook_record structure.
  let
    # user_data (cstring) -$-> string -parseInt-> int -cast-> pointer
    hook = chandle_to_hook(cast[pointer](parseInt($cbDataPtr[].user_data)))

  if hook == nil:
    return 0

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
    return 1

proc enable_cb(recRef: HookRecordRef) =
  ## Sensitise to a signal by placing a value-change callback on it.
  ## Set up the callback so that it does not collect the signal's
  ## value or the callback time (reduces overhead).  Keep a copy
  ## of the callback handle in the signal's hook record, to simplify
  ## later removal of the callback.
  if recRef.cb == nil:
    let
      recRefCstring: cstring = $cast[int](recRef)
    var
      # Time and value objects should not be needed, but Xcelium requires them
      time_s = s_vpi_time(`type`: vpiSuppressTime)
      value_s = s_vpi_value(format: vpiSuppressVal)
      # Set up the new callback
      cb_data = s_cb_data(cb_rtn: vc_callback,
                          obj: recRef.obj,
                          user_data: recRefCstring, # save the stringified ref address as user_data
                          time: addr time_s,
                          value: addr value_s,
                          reason: cbValueChange)
    recRef.cb = vpi_register_cb(addr cb_data)

proc disable_cb(hook: HookRecordRef) =
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
    recRef = allocate_hook_record()
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

  recRef.obj      = obj
  recRef.isSigned = vpi_get(vpiSigned, obj)
  recRef.size     = vpi_get(vpiSize, obj)
  recRef.sv_key   = sv_key
  recRef.cb       = nil
  recRef.top_msb  = cuint(1) shl ((recRef.size-1) mod 32)
  recRef.top_mask = cuint(2) * recRef.top_msb - cuint(1)
  dbg &"recRef: size = {recRef.size}, top_msb = {recRef.top_msb:#x}, top_mask = {recRef.top_mask:#x}"
  return cast[pointer](recRef)

proc vlab_probes_setVcEnable(hnd: pointer; enable: cint) {.exportc, dynlib.} =
  ## Enable or disable value-changed callback on the signal referenced
  ## by HookRecordRef `hnd`.  If `enable` is true (non-zero), value-change
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
  ## Returns 1 if success, 0 if failure (bad handle, chunk
  ## out-of-bounds).
  var
    chunk = chunk
  let
    recRef = chandle_to_hook(hnd)
    chunk_lsb = chunk * 32

  if recRef == nil:
    stop_on_error("vlab_probes_getValue32: bad handle")
    return 0

  if chunk < 0:
    report_error("vlab_probes_getValue32: negative chunk index")
    return 0

  if chunk_lsb >= recRef.size:
    chunk = (recRef.size - 1) shr 5 # div by 32

  # Get the whole vector value from VPI
  var
    value_s = s_vpi_value(format: vpiVectorVal)
  vpi_get_value(recRef.obj, addr value_s)

  # Copy the relevant aval/bval bits into the output argument.
  let
    vecPtr = value_s.value.vector # type ptr t_vpi_vecval
    # vecPtrp1 = cast[ptr svLogicVecVal](cast[cint](vecPtr) + sizeof(svLogicVecVal)*1)
  # resultPtr = vecPtr[chunk] # This does not compile in Nim
  dbg &"size {recRef.size}, chunk {chunk}: vector[0]: aval = {vecPtr[].aval:#x}, bval = {vecPtr[].aval:#x}"
  # dbg &"size {recRef.size}, chunk {chunk}: vector[1]: aval = {vecPtrp1[].aval:#x}, bval = {vecPtrp1[].aval:#x}"
  resultPtr[] = cast[ptr svLogicVecVal](cast[cint](vecPtr) + chunk*sizeof(svLogicVecVal))[]

  # Perform sign extension if appropriate.
  if (chunk_lsb + 32) > recRef.size:
    # We're working on the most significant word, and it is not full.
    dbg &"size {recRef.size}: result before: aval = {resultPtr[].aval:#x}, bval = {resultPtr[].aval:#x}"
    resultPtr[].aval = resultPtr[].aval and recRef.top_mask
    resultPtr[].bval = resultPtr[].bval and recRef.top_mask
    if recRef.isSigned == 1:
      if resultPtr[].bval == 1 and recRef.top_msb == 1:
        resultPtr[].bval = resultPtr[].bval or not recRef.top_mask
      if resultPtr[].aval == 1 and recRef.top_msb == 1:
        resultPtr[].aval = resultPtr[].aval or not recRef.top_mask
    dbg &"size {recRef.size}: result after: aval = {resultPtr[].aval:#x}, bval = {resultPtr[].aval:#x}"

  return 1

proc vlab_probes_getSize(hnd: pointer): cint {.exportc, dynlib.} =
  ## Get the number of bits in the signal referenced by `hnd`.
  ## Returns zero if the handle is bad.
  let
    recRef = chandle_to_hook(hnd)
  if recRef == nil:
    return 0
  return recRef.size

proc vlab_probes_getSigned(hnd: pointer): cint {.exportc, dynlib.} =
  ## Get a flag indicating whether the signal referenced by `hnd`
  ## is signed (0=unsigned, 1=signed).
  let
    recRef = chandle_to_hook(hnd)
  if recRef == nil:
    return 0
  return recRef.isSigned

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
    return 0

  # Check the object is indeed a variable of type bit; error if not.
  if vpi_get(vpiType, obj) != vpiBitVar:
    report_error("vlab_probes_specifyNotifier(): object is not a bit variable")
    return 0

  notifier = obj
  setup_reset_callback()
  return 1

proc vlab_probes_processChangeList() {.exportc, dynlib.} =
  ## When the SV notifier signal is toggled, the SV code must immediately
  ## call this function.  It will service all pending value-change events,
  ## notifying each affected probe object in turn by calling exported
  ## function vlab_probes_vcNotify for that signal.
  while changeList != nil:
    let
      recRef = changeList_pop()
    vlab_probes_vcNotify(recRef.sv_key)
