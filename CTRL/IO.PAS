(**********************************************************************)
(* Unit name      : IO.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-14 18:22   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC4000 IO emulation.
(*
(**********************************************************************)

{$F+}
{$S-}

UNIT IO;


INTERFACE

USES
   Intr;

CONST
   MaxDev   =  63;   (* must be 2**n-1 *)


TYPE
   IoTimerPtr  =  ^IoTimer;

   IoTimer     =  OBJECT (TimerHook)
                     _Owner: POINTER;  (* IODevicePtr *)

                     CONSTRUCTOR Init(VAR Owner);
                     PROCEDURE TimeoutAction; VIRTUAL;
                  END;


   IODevicePtr =  ^IODevice;

   IODevice    =  OBJECT (IntrHook)
                     _DevNo:  WORD;
                     Timer:   IoTimer;
                     CONSTRUCTOR Init(DevNo: WORD);
                     DESTRUCTOR Done;                  VIRTUAL;
                     PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                     PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                     PROCEDURE  Rd(Modif: BYTE);       VIRTUAL;
                     PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;
                     PROCEDURE  AutoloadWord;          VIRTUAL;

                     FUNCTION   DeviceID: STRING;      VIRTUAL;
                     FUNCTION   Configurable: BOOLEAN; VIRTUAL;
                     PROCEDURE  Configure;             VIRTUAL;
                     PROCEDURE  MenuConfig;            VIRTUAL;

                     PROCEDURE  TimeoutAction;         VIRTUAL;
                  END;
VAR
   IOMap:   ARRAY [0..MaxDev] OF IODevicePtr;

PROCEDURE CallIOHandler(DevNo: WORD);
PROCEDURE AWAction;

(*#PAGE*)
IMPLEMENTATION

USES
   OpRoot,
   OpString,
   Util,
   Intf;


VAR
   DummyIO  :  IODevice;

(**********************************************************************)
(* Proc. Name     : IOTimer.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR IOTimer.Init (VAR Owner);

BEGIN
   INHERITED Init;
   _Owner := @Owner;
END; (* IOTimer.Init *)

(**********************************************************************)
(* Proc. Name     : IOTimer.IntrAction
(* Function       : 
(**********************************************************************)
PROCEDURE IOTimer.TimeoutAction;

BEGIN
   IODevicePtr(_Owner)^.TimeoutAction;
END; (* IOTimer.IntrAction *)

(**********************************************************************)
(* Proc. Name     : IODevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR IODevice.Init (DevNo: WORD);

BEGIN
   INHERITED Init;
   _DevNo := DevNo;
   IOMap[DevNo] := @Self;
   Timer.Init(Self);
END; (* IODevice.Init *)

(**********************************************************************)
(* Proc. Name     : IODevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR IODevice.Done;
BEGIN
   IOMap[_DevNo] := NIL;
END; (* IODevice.Done *)

(**********************************************************************)
(* Proc. Name     : IODevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.Sense (Modif: BYTE);
BEGIN
   State8000.Ex22 := 1;  (* status disconnected *)
   State8000.Ex23 := 0;
END; (* IODevice.Sense *)

(**********************************************************************)
(* Proc. Name     : IODevice.Control
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.Control (Modif: BYTE);
BEGIN
   State8000.Ex22 := 1;  (* status disconnected *)
   State8000.Ex23 := 0;
END; (* IODevice.Control *)

(**********************************************************************)
(* Proc. Name     : IODevice.Rd
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.Rd (Modif: BYTE);
BEGIN
   State8000.Ex22 := 1;  (* status disconnected *)
   State8000.Ex23 := 0;
END; (* IODevice.Rd *)

(**********************************************************************)
(* Proc. Name     : IODevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.Wr (Modif: BYTE);
BEGIN
   State8000.Ex22 := 1;  (* status disconnected *)
   State8000.Ex23 := 0;
END; (* IODevice.Wr *)

(**********************************************************************)
(* Proc. Name     : IODevice.AutoloadWord
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.AutoloadWord;

BEGIN
   State8000.Stop := TRUE;  (* Should not occur *)
END; (* IODevice.AutoloadWord *)

(**********************************************************************)
(* Func. Name     : IODevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION IODevice.DeviceID: STRING;

BEGIN
   DeviceID := 'UNDEF';
END; (* IODevice.DeviceID *)

(**********************************************************************)
(* Func. Name     : IODevice.Configurable
(* Function       : 
(**********************************************************************)
FUNCTION IODevice.Configurable: BOOLEAN;

BEGIN
   Configurable := FALSE;
END; (* IODevice.Configurable *)

(**********************************************************************)
(* Proc. Name     : Device.Configure
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.Configure;
BEGIN
   Abstract;
END; (* Device.Configure *)

(**********************************************************************)
(* Proc. Name     : IODevice.MenuConfig
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.MenuConfig;

BEGIN
   Abstract;
END; (* IODevice.MenuConfig *)

(**********************************************************************)
(* Proc. Name     : IODevice.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE IODevice.TimeoutAction;

BEGIN
   Abstract;
END; (* IODevice.TimeoutAction *)

(**********************************************************************)
(* Proc. Name     : CallIOHandler
(* Function       : 
(**********************************************************************)
PROCEDURE CallIOHandler (DevNo: WORD);

VAR
   Modif,
   Op:   BYTE;

BEGIN
   WITH State8000.SrvcParam DO
   BEGIN
      Op := EA AND 63;
      Modif := (EA SHR 2) AND $F;

      WITH IoMap[DevNo AND MaxDev]^ DO
      CASE Op AND 3 OF
         0: Sense(Modif);
         1: Control(Modif);
         2: Rd(Modif);
         3: Wr(Modif);
      END;
   END;
END; (* CallIOHandler *)

(**********************************************************************)
(* Proc. Name     : AWAction
(* Function       : 
(**********************************************************************)
PROCEDURE AWAction;

BEGIN
   WITH State8000 DO
   IF SrvcParam.EA = -1000 THEN
   BEGIN
      Stop := TRUE;
      Halt := TRUE;
   END ELSE IOMap[0]^.AutoloadWord;
END; (* AWAction *)


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

VAR I: WORD;

BEGIN
   FOR I := 0 TO MaxDev DO IoMap[I]^.Done;
   Exitproc := ExitSave;
END; (* UnitExit *)




(**********************************************************************)
(* Proc. Name     : UnitEntry
(* Function       : Entry procedure for unit.
(**********************************************************************)
PROCEDURE UnitEntry;

VAR I: WORD;

BEGIN
   Exitsave := Exitproc;
   Exitproc := @UnitExit;

   DummyIO.Init(0);
   FOR I := 0 TO MaxDev DO IoMap[I] := @DummyIO;

END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT IO *)

