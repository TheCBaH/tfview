(* Stub for Melange compatibility.
   tfview only uses the String buffer path; Bigstring is never reached at runtime. *)

type t = bytes

let create n = Bytes.create n
let get t i = Bytes.get t i
let substring t ~off ~len = Bytes.sub_string t off len

let[@warning "-21"] get_int16_le _t _i : int =
  failwith "bigstringaf stub: get_int16_le"

let[@warning "-21"] get_int32_le _t _i : int32 =
  failwith "bigstringaf stub: get_int32_le"

let[@warning "-21"] get_int64_le _t _i : int64 =
  failwith "bigstringaf stub: get_int64_le"

let[@warning "-21"] blit_from_bytes _src ~src_off:_ _dst ~dst_off:_ ~len:_ :
    unit =
  failwith "bigstringaf stub: blit_from_bytes"
