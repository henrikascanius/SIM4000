(**********************************************************************)
(* Unit name      : EXPANDER.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 96-11-04 19:39   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC4000 Interrupt Expander
(*
(**********************************************************************)

{$F+}

UNIT EXPANDER;


INTERFACE

USES
   Io;

TYPE
   InterruptExpanderPtr = ^InterruptExpander;

   InterruptExpander = OBJECT (IoDevice)
      _Dummy,
      _IntNo:     BYTE;
      Register:   LONGINT;
      _DevExists: LONGINT;  (* Bit pattern *)

      CONSTRUCTOR Init(DevNo: WORD; IntNo: BYTE);
      
      PROCEDURE Sense(Modif: BYTE);       VIRTUAL;

      PROCEDURE IncludeDevice(DevNoRel: BYTE);
      FUNCTION  DeviceUsed(DevNoRel: BYTE): BOOLEAN;
      FUNCTION  IntNumber: BYTE;
   END;

(*#PAGE*)
IMPLEMENTATION

USES
   Intf;

(**********************************************************************)
(* Proc. Name     : InterruptExpander.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR InterruptExpander.Init (Devno: WORD; IntNo: BYTE);

BEGIN
   INHERITED Init(DevNo);
   _IntNo := IntNo;
   Register := 0;
   _DevExists := 0;
END; (* InterruptExpander.Init *)


(**********************************************************************)
(* Proc. Name     : InterruptExpander.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE InterruptExpander.Sense (Modif: BYTE);

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;
      Ex23 := 0;
      SrvcParam.Wreg := Register;
      Register := 0;
   END;
END; (* InterruptExpander.Sense *)



(**********************************************************************)
(* Proc. Name     : InterruptExpander.IncludeDevice
(* Function       : 
(**********************************************************************)
PROCEDURE InterruptExpander.IncludeDevice(DevNoRel: BYTE);

BEGIN
   _DevExists := _DevExists OR (LONGINT(1) SHL (32-DevNoRel));
END; (* InterruptExpander.IncludeDevice *)



(**********************************************************************)
(* Func. Name     : InterruptExpander.DeviceUsed
(* Function       : 
(**********************************************************************)
FUNCTION InterruptExpander.DeviceUsed (DevNoRel: BYTE): BOOLEAN;

BEGIN
   DeviceUsed := BOOLEAN((Register SHR (32-DevNoRel)) AND 1);
END; (* InterruptExpander.DeviceUsed *)


(**********************************************************************)
(* Func. Name     : InterruptExpander.IntNumber
(* Function       : 
(**********************************************************************)
FUNCTION InterruptExpander.IntNumber: BYTE;

BEGIN
   IntNumber := _IntNo;
END; (* InterruptExpander.IntNumber *)


(**********************************************************************)
(*****              UNIT ENTRY AND EXIT PROCEDURES
(**********************************************************************)

VAR

   ExitSave  : pointer;

(**********************************************************************)
(* Proc. Name     : UnitExit
(* Function       : Exit procedure.
(**********************************************************************)
PROCEDURE UnitExit;

BEGIN
   Exitproc := ExitSave;
END; (* UnitExit *)




(**********************************************************************)
(* Proc. Name     : UnitEntry
(* Function       : Entry procedure for unit.
(**********************************************************************)
PROCEDURE UnitEntry;

BEGIN
   Exitsave := Exitproc;
   Exitproc := @UnitExit;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT EXPANDER *)

