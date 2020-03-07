(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : CLOCK.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-19 23:05   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Interval timer device for RC4000/8000.
(*
(**********************************************************************)

{$F+}
{$S-}

UNIT CLOCK;


INTERFACE

USES
   Io;


TYPE

   ClockDevicePtr =  ^ClockDevice;

   ClockDevice    =  OBJECT (IoDevice)
                        _Int:    BYTE;
                        _Cnt:    WORD;
                        CONSTRUCTOR Init(DevNo: WORD; Int: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;
                        PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;

                        FUNCTION   DeviceID: STRING;      VIRTUAL;

                        PROCEDURE  IntrAction(VAR Param); VIRTUAL;
                     END;



(*#PAGE*)
IMPLEMENTATION
USES
   OpInt,
   Vcpi,
   Util,
   Intf,
   Intr;

CONST
   ConvFactor  =  120;  (* Round(1193180/10000)+1,
                           MUST FULFILL: TimeConst8000 DIV ConvFactor < 256 *)
                        (* ALSO FOUND IN INSTMACC.ASM *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ClockDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR ClockDevice.Init(DevNo: WORD; Int: BYTE);

BEGIN
   INHERITED Init(DevNo);
   _Int := Int;
   _Cnt := 0;
   WITH State8000, ClockCntP DO
   BEGIN  (* Insert inf. to protected mode clock handler *)
      ClockSense := DevNo SHL 6;  (* EA of sense operation *)
      Selector := VCPIDS;
      Offset:= PtrToHuge(@_Cnt);    (* Pointer to tick counter *)
   END;
   TickHndlr.InsHook(Self);
END; (* ClockDevice.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ClockDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR ClockDevice.Done;

BEGIN
   TickHndlr.RemHook(Self);
   (* Should release interrupts here *)
END; (* ClockDevice.Done *)



(* ClockDevice.Sense is performed directly in the microcode. The following
   procedure is kept for reference. It will, however, be called if
   more than one clock device is defined on the machine.
*)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ClockDevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE ClockDevice.Sense (Modif: BYTE);

VAR
   XIRR,
   IRR,
   XState8254,
   State8254: BYTE;
   Cnt,
   Cnt8254,
   XRead8254,
   Read8254: WORD;

BEGIN
   IF State8000.FullAccuracy THEN
   BEGIN

      (* Timer0 runs in mode 3, i.e. counter decr. by two at each clock .
         MSB of "counter" value if found from OUT status *)

      PushF;

      Port[I8259_1Base] := $0A;  (* 8259_1 read IRR *)
      IRR := Port[I8259_1Base]; (* Int. Req. Reg. *)
      Port[SysTimerBase+3] := $C2;    (* Latch status&count of 8254 counter 0 *)
      State8254 := Port[SysTimerBase];
      Read8254 := (Port[SysTimerBase]);
      Read8254 := Read8254 + (WORD(Port[SysTimerBase]) SHL 8);
      REPEAT
         XState8254 := State8254;
         XRead8254 := Read8254;

         InterruptsOn;
         XIRR := IRR;
         InterruptsOff;

         Port[I8259_1Base] := $0A;  (* 8259_1 read IRR *)
         IRR := Port[I8259_1Base]; (* Int. Req. Reg. *)
         Port[SysTimerBase+3] := $C2;    (* Latch status&count of 8254 counter 0 *)
         State8254 := Port[SysTimerBase];
         Read8254 := (Port[SysTimerBase]);
         Read8254 := Read8254 + (WORD(Port[SysTimerBase]) SHL 8);
      UNTIL (XRead8254-Read8254 < 500) AND (XState8254=State8254) AND
            (XIRR=IRR);

      PopF;

      IF BOOLEAN(State8254 SHR 7)     (* OUT=1 *)
         THEN Cnt8254 := (TimeConst8000 - Read8254) SHR 1
         ELSE Cnt8254 := (TimeConst8000 + TimeConst8000 - Read8254) SHR 1;

      Cnt := _Cnt;

      (* Check for unprocessed interrupt,
         allow appr. 100 us skew betw. 8254 latch & 8259 poll *)
      IF BOOLEAN(IRR AND 1) AND    (* Timer0 IRR *)
         (Cnt8254<(TimeConst8000 - 100))
         THEN Inc(Cnt);

      State8000.SrvcParam.WReg := LONGINT ((Cnt AND $3F) SHL 8 +
                                           Cnt8254 DIV ConvFactor) SHL 8;

   END ELSE
      State8000.SrvcParam.WReg := LONGINT (_Cnt AND $3F) SHL 16;
END; (* ClockDevice.Sense *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : ClockDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION ClockDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'CLOCK';
END; (* ClockDevice.DeviceID *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ClockDevice.IntrAction
(* Function       : 
(**********************************************************************)
PROCEDURE ClockDevice.IntrAction (VAR Param);

BEGIN
   Inc(_Cnt);
   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_Int));
END; (* ClockDevice.IntrAction *)

(*#CPAGE 20*)
(**********************************************************************)
(*****              UNIT ENTRY AND EXIT PROCEDURES
(**********************************************************************)

VAR

   ExitSave  : pointer;

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : UnitExit
(* Function       : Exit procedure.
(**********************************************************************)
PROCEDURE UnitExit;

BEGIN
   Exitproc := ExitSave;
END; (* UnitExit *)




(*#CPAGE 20*)
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
END. (* UNIT CLOCK *)

