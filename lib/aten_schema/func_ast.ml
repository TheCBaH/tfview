type base_ty =
  | Generator
  | ScalarType
  | Tensor
  | Int
  | Dimname
  | DimVector
  | Float
  | Str
  | Bool
  | Layout
  | Device
  | DeviceIndex
  | Scalar
  | MemoryFormat
  | QScheme
  | Storage
  | Stream
  | SymInt
  | SymBool
  | GraphModule

type ty = Base of base_ty | Optional of ty | List of ty * int option

(* Annotation mirrors torchgen: alias_set of letters, is_write flag,
   alias_set_after for "a -> *" / "a -> b" forms (rare). *)
type annotation = {
  alias_set : string list;
  is_write : bool;
  alias_set_after : string list;
}

type default_val =
  | DefaultNone
  | DefaultBool of bool
  | DefaultInt of int
  | DefaultFloat of string (* kept as string to preserve exact representation *)
  | DefaultStr of string
  | DefaultIntList of int list
  | DefaultIdent of string (* e.g. contiguous_format, Mean, long *)

type argument = {
  name : string;
  ty : ty;
  annotation : annotation option;
  default : default_val option;
}

type return_val = {
  name : string option;
  ty : ty;
  annotation : annotation option;
}

type op_name = { base : string; overload : string option }

(* positional args come before *, kwarg_only between * and out, out are
   kwarg-only args that carry a write annotation (the Tensor(a!) convention). *)
type arguments = {
  positional : argument list;
  kwarg_only : argument list;
  out : argument list;
}

type func_schema = {
  name : op_name;
  arguments : arguments;
  returns : return_val list;
}
