(**********************************************************************)
(* Unit name      : AUDIO.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 94-05-15 23:23   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Beeper for RC4000/8000 emulator
(*
(**********************************************************************)

{$F+}

UNIT AUDIO;


INTERFACE

USES
   Intr;

TYPE
   BeeperObjP  = ^BeeperObj;
   BeeperObj   = OBJECT (TimerHook)
                    _BeepCnt   : BYTE;
                    _On        : BOOLEAN;
                    CONSTRUCTOR Init;
                    PROCEDURE   TimeoutAction;  VIRTUAL;
                    PROCEDURE   Beep;
                    PROCEDURE   Kill;
                 END;


VAR
   Beeper     : BeeperObj;


(*#PAGE*)
IMPLEMENTATION

USES
   Util,
   OpInt;
   

CONST
   BeepConst = 1193;                   (*  1 193 180 / 1000 Hz *)

(**********************************************************************)
(* Proc. Name     : SoundOn
(* Function       : 
(**********************************************************************)
PROCEDURE SoundOn;

BEGIN
   PushF;
   InterruptsOff;
   Port[$43] := 182;
   Port[$42] := BeepConst AND 255;
   Port[$42] := BeepConst SHR 8;
   Port[$61] := Port[$61] OR 3;
   PopF;
END; (* SoundOn *)

(**********************************************************************)
(* Proc. Name     : SoundOff
(* Function       : 
(**********************************************************************)
PROCEDURE SoundOff;

BEGIN
   PushF;
   InterruptsOff;
   Port[$61] := Port[$61] AND $FC;
   PopF;
END; (* SoundOff *)


(**********************************************************************)
(* Proc. Name     : BeeperObj.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR BeeperObj.Init;

BEGIN
   INHERITED Init;
   _BeepCnt := 0;
   _On := FALSE;
END; (* BeeperObj.Init *)

(**********************************************************************)
(* Proc. Name     : BeeperObj.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE BeeperObj.TimeoutAction;

BEGIN
   PushF;
   InterruptsOff;
   IF _On THEN
   BEGIN
      Dec(_BeepCnt);
      IF _BeepCnt = 0 THEN
      BEGIN
         SoundOff;
         _On := FALSE;
      END ELSE SetTimeout(0,MilliSec);
   END ELSE 
   BEGIN
      SoundOn;
      _On := TRUE;
      SetTimeout(0,MilliSec);
   END;
   PopF;
END; (* BeeperObj.TimeoutAction *)

(**********************************************************************)
(* Proc. Name     : BeeperObj.Beep
(* Function       : 
(**********************************************************************)
PROCEDURE BeeperObj.Beep;

BEGIN
   PushF;
   InterruptsOff;
   IF _BeepCnt < 20 THEN Inc(_BeepCnt);
   IF _BeepCnt = 1 THEN SetTimeout(0,MilliSec);
   PopF;
END; (* BeeperObj.Beep *)

(**********************************************************************)
(* Proc. Name     : BeeperObj.Kill
(* Function       : 
(**********************************************************************)
PROCEDURE BeeperObj.Kill;

BEGIN
   PushF;
   InterruptsOff;
   SoundOff;
   CancelTimeout;
   _On := FALSE;
   _BeepCnt := 0;
   PopF;
END; (* BeeperObj.Kill *)


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

   Beeper.Init;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT AUDIO *)

