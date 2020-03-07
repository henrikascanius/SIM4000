(**********************************************************************)
(* Unit name      : INTR.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-09 21:43   HJ Initial version
(* 94-02-11 23:46   HJ Bug fix in Full8254Supported
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  V86 mode interrupt handling for RC8000 simulator.
(*
(**********************************************************************)

{$F+}
{$S-}

UNIT INTR;


INTERFACE

USES
   OpRoot;

   CONST
      TenthmSecPerTick  =  256;  (* 25.6 ms tick *)
      TicksPerSec       =  39;   (* closest integer *)

      TimeConst8000     =  30545;   (* 1.193180MHz * 25.6ms ALSO INSTMACC.ASM *)
      SysTimerBase      =  $40;
      I8259_1Base       =  $20; 
      I8259_2Base       =  $A0; 

TYPE
   KeybParam   =  RECORD
                     Key   : WORD;
                     Eaten : BOOLEAN;
                  END;

   IntrHookPtr =  ^IntrHook;

   IntrHook    =  OBJECT (DoubleListNode)  (* Double lists make faster remove's! *)
                     CONSTRUCTOR Init;
                     PROCEDURE IntrAction(VAR Param); VIRTUAL;
                  END;



   IntrHandlerPtr = ^IntrHandler;

   IntrHandler =  OBJECT
                     HookList:   DoubleList;
                     CONSTRUCTOR Init;
                     PROCEDURE InsHook(VAR Hook: IntrHook);
                     PROCEDURE RemHook(VAR Hook: IntrHook);
                     PROCEDURE DoHooks(VAR Param);
                  END;


   TimeUnit    =  (Sec,MilliSec);

   TimerHook   =  OBJECT (IntrHook)
                     CONSTRUCTOR Init;
                     PROCEDURE SetTimeout(Val: WORD; Gran: TimeUnit);
                     PROCEDURE CancelTimeout;
                     FUNCTION  IsActive: BOOLEAN;
                     PROCEDURE TimeoutAction; VIRTUAL;
                     PROCEDURE IntrAction(VAR Param); VIRTUAL;
                  PRIVATE
                     _Active:   BOOLEAN;
                     _Cnt:     WORD;
                  END;


   TickHandlerPtr = ^TickHandler;

   TickHandler =  OBJECT (IntrHandler)
                  PRIVATE
                     _DosTimer:  WORD;
                     IntStackP:  POINTER;
                     CONSTRUCTOR Init;
                  END;


   KeybHandlerPtr = ^KeybHandler;

   KeybHandler =  OBJECT(IntrHandler)
                  PRIVATE
                     IntStackP:  POINTER;
                     CONSTRUCTOR Init;
                  END;


VAR
   TickHndlr:  TickHandler;   (* The one and only *)
   KeybHndlr:  KeybHandler;   (* The one and only *)

CONST
   DiskBusy:   BOOLEAN = FALSE;


FUNCTION  AllocateIntHandle (ExitOnError: BOOLEAN): BYTE;
PROCEDURE EatKeystroke;
PROCEDURE InitV (IntNumber,Handle: BYTE; UserRoutine: POINTER);
PROCEDURE InitIntHandlers;
FUNCTION  Full8254Supported: BOOLEAN;


PROCEDURE SendEOI2;
  {-Send an End Of Interrupt command to the
    secondary Programmable Interrupt Controller}
  inline(
    $B0/$20/                 {mov al,$20}
    $E6/$A0);                {out $A0,al}


(*#PAGE*)
IMPLEMENTATION

USES
   Util,
   Intf,
   Io,
   Scrn,
   Config,
   OpString,
   OpInline,
   OpInt;


CONST
   TickIntHandle    =  13;
   KeybIntHandle    =  14;
   SrvcIntHandle    =  15;
   SysIntHandle     =  16;

   FreeIntHandle: BYTE = 17;


VAR
   KeybHead: WORD ABSOLUTE $40:$1A;
   KeybTail: WORD ABSOLUTE $40:$1C;
   KeybStart:WORD ABSOLUTE $40:$80;
   KeybEnd:  WORD ABSOLUTE $40:$82;

(**********************************************************************)
(* Func. Name     : AllocateIntHandle
(* Function       : Return an OPINT handle.
(**********************************************************************)
FUNCTION AllocateIntHandle (ExitOnError: BOOLEAN): BYTE;

BEGIN
   IF FreeIntHandle > MaxISRs THEN
   BEGIN
      AllocateIntHandle := 0;
      IF ExitOnError THEN
         FatalError('Cannot allocate interrupt handler, MaxISRs exceeded');
   END ELSE
   BEGIN
      AllocateIntHandle := FreeIntHandle;
      Inc(FreeIntHandle);
   END;
END; (* AllocateIntHandle *)

{$S-}

(**********************************************************************)
(* Proc. Name     : IntrHook.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR IntrHook.Init;
BEGIN
   INHERITED Init;
END; (* IntrHook.Init *)

(**********************************************************************)
(* Proc. Name     : IntrHook.IntrAction
(* Function       : 
(**********************************************************************)
PROCEDURE IntrHook.IntrAction (VAR Param);

BEGIN
   Abstract;
END; (* IntrHook.IntrAction *)

(**********************************************************************)
(* Proc. Name     : IntrHandler.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR IntrHandler.Init;

BEGIN
   HookList.Init;
END; (* IntrHandler.Init *)

(**********************************************************************)
(* Proc. Name     : InsHook
(* Function       : 
(**********************************************************************)
PROCEDURE IntrHandler.InsHook (VAR Hook: IntrHook);

BEGIN
   HookList.Append(@Hook);
END; (* InsHook *)

(**********************************************************************)
(* Proc. Name     : IntrHandler.RemHook
(* Function       : 
(**********************************************************************)
PROCEDURE IntrHandler.RemHook (VAR Hook: IntrHook);

BEGIN
   HookList.Remove(@Hook);
END; (* IntrHandler.RemHook *)

(**********************************************************************)
(* Proc. Name     : IntrHandler.DoHooks
(* Function       : 
(**********************************************************************)
PROCEDURE IntrHandler.DoHooks (VAR Param);

VAR P: DoubleNodePtr;

BEGIN
   P := HookList.Head;
   WHILE P <> NIL DO
   BEGIN
      IntrHookPtr(P)^.IntrAction(Param);
      P := HookList.Next(P);
   END;
END; (* IntrHandler.DoHooks *)

(**********************************************************************)
(* Proc. Name     : TimerHook.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR TimerHook.Init;

BEGIN
   INHERITED Init;
   _Active := FALSE;
END; (* TimerHook.Init *)

(**********************************************************************)
(* Proc. Name     : TimerHook.SetTimeout
(* Function       : 
(**********************************************************************)
PROCEDURE TimerHook.SetTimeout(Val: WORD; Gran: TimeUnit);

BEGIN
   PushF;
   InterruptsOff;
   IF Gran = Sec
      THEN _Cnt := Val * TicksPerSec + 1
      ELSE _Cnt := (Val*10) DIV TenthmSecPerTick + 1;
   IF NOT _Active THEN TickHndlr.InsHook(Self);
   _Active := TRUE;
   PopF;
END; (* TimerHook.SetTimeout *)

(**********************************************************************)
(* Proc. Name     : TimerHook.CancelTimeout
(* Function       : 
(**********************************************************************)
PROCEDURE TimerHook.CancelTimeout;

BEGIN
   PushF;
   InterruptsOff;
   IF _Active THEN
   BEGIN
      _Active := FALSE;
      TickHndlr.RemHook(Self);
   END;
   PopF;
END; (* TimerHook.CancelTimeout *)

(**********************************************************************)
(* Func. Name     : TimerHook.IsActive
(* Function       : 
(**********************************************************************)
FUNCTION TimerHook.IsActive: BOOLEAN;

BEGIN
   IsActive := _Active;
END; (* TimerHook.IsActive *)

(**********************************************************************)
(* Proc. Name     : TimerHook.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE TimerHook.TimeoutAction;

BEGIN
   Abstract;
END; (* TimerHook.TimeoutAction *)

(**********************************************************************)
(* Proc. Name     : TimerHook.IntrAction
(* Function       : 
(**********************************************************************)
PROCEDURE TimerHook.IntrAction(VAR Param);

BEGIN
   IF _Cnt = 0 THEN
   BEGIN
      CancelTimeout;
      TimeoutAction;
   END ELSE Dec(_Cnt);
END; (* TimerHook.IntrAction *)


(**********************************************************************)
(* Proc. Name     : SrvcInt
(* Function       : Handles service request from simulator microcode
(**********************************************************************)
PROCEDURE SrvcInt (BP: WORD);
INTERRUPT;

VAR
   Regs: IntRegisters ABSOLUTE BP;
   DevNo: BYTE;

BEGIN
   WITH State8000.SrvcParam DO
   CASE ReqKind OF
      IO_OP:BEGIN
               DevNo := (EA SHR 6);
               CallIOHandler(DevNo);
            END;

      AW_OP:AWAction;

      DUMMY_OP: ;  (* Used to switch screen *)

   END;

   WITH State8000 DO
   IF NextScreen <> $FF THEN
   BEGIN
      ScreenTab[NextScreen]^.ToPhysScreen;
      CurRCScreenNo := NextScreen;
      NextScreen := $FF;
   END;

END; (* SrvcInt *)

(**********************************************************************)
(* Proc. Name     : EatKeystroke
(* Function       : Removes one keystroke from keyboard buffer
(**********************************************************************)
PROCEDURE EatKeystroke;

BEGIN
   PushF;
   InterruptsOff;
   IF KeybHead <> KeybTail THEN
   BEGIN
      Inc(KeybHead,2);
      IF KeybHead = KeybEnd THEN KeybHead := KeybStart;
   END;
   PopF;
END; (* EatKeystroke *)

(**********************************************************************)
(* Proc. Name     : _KeybInt
(* Function       : Handles keyboard hardware interrupt
(**********************************************************************)
PROCEDURE _KeybInt (VAR Regs: IntRegisters);

VAR
   ScrnNo,
   DevNo: BYTE;
   P: ^WORD;
   Par:   KeybParam;
   A: POINTER;

BEGIN 
   A := IsrArray[KeybIntHandle].OrigAddr;
   ASM
      pushf
      call dword ptr [A];
   END;
   {EmulateInt(Regs,IsrArray[KeybIntHandle].OrigAddr);}

   InterruptsOff;

   Par.Eaten := TRUE;

   WITH Par DO
   WHILE  (KeybHead <> KeybTail) AND Eaten DO
   BEGIN
      P := Ptr($40,KeybHead);
      Key := P^;

      (* Console switching, actual switching is done in SrvcIntr. 
         The protected mode part of the interrupt handler breaks
         the microcode in the same way as an interrupt.
         The "Break8000" handler examines
         the NextScreen var. and issues a service-interrupt to switch. *)

      IF ((Key AND $FF) = 0) AND (Key >= $7800) AND 
         ((Key SHR 8) < $78+MaxScreen) AND State8000.Running THEN
      BEGIN   
         ScrnNo := (Key SHR 8) - $78;
         IF (ScreenTab[ScrnNo] <> NIL) THEN State8000.NextScreen := ScrnNo;
         EatKeystroke;
      END ELSE

      BEGIN
         Eaten := FALSE;
         KeybHndlr.DoHooks(Par);
      END;
   END;
END; (* _KeybInt *)


PROCEDURE KeybInt (BP: WORD);
INTERRUPT;

VAR
   Regs: IntRegisters ABSOLUTE BP;

CONST
   IntrLevel: BYTE = 0; 

BEGIN 
   Inc(IntrLevel);
   IF IntrLevel=1
   THEN SwapStackAndCall(@_KeybInt,KeybHndlr.IntStackP,Regs)
   ELSE _KeybInt(Regs);  (* Recursive interrupts occur on ACK's from
                            Write Keybd. Data when the LED states changes *)
   Dec(IntrLevel);
END;

(**********************************************************************)
(* Proc. Name     : InitV
(* Function       : InitVector w. check
(**********************************************************************)
PROCEDURE InitV (IntNumber,Handle: BYTE; UserRoutine: POINTER);

BEGIN
   IF NOT InitVector(IntNumber,Handle,UserRoutine)
      THEN FatalError('InitVector failed: '+Long2Str(IntNumber)+' '+
                      Long2Str(Handle));

END; (* InitV *)

(**********************************************************************)
(* Proc. Name     : TickInt
(* Function       : Handles Tick hardware interrupt
(**********************************************************************)
PROCEDURE _TickInt (VAR Regs: IntRegisters);

BEGIN
   IF State8000.Running 
      THEN TickHndlr.DoHooks(Regs);

   WITH TickHndlr DO
   BEGIN
      _DosTimer := _DosTimer + TimeConst8000;
      IF _DosTimer < TimeConst8000   (* 2**16 turn-around *)
         THEN EmulateInt(Regs,IsrArray[TickIntHandle].OrigAddr)
         ELSE SendEOI;
   END;
END; (* _TickInt *)


PROCEDURE TickInt (BP: WORD);
INTERRUPT;

VAR
   Regs: IntRegisters ABSOLUTE BP;

CONST
   IntrLevel: BYTE = 0; 

BEGIN
   Inc(IntrLevel);
   IF IntrLevel=1
      THEN SwapStackAndCall(@_TickInt,TickHndlr.IntStackP,Regs)
      ELSE _TickInt(Regs);  
   Dec(IntrLevel);  (* MUST be reentrant (smartdrv) *)
END;

(**********************************************************************)
(* Proc. Name     : TickHandler.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR TickHandler.Init;

BEGIN
   INHERITED Init;
   IF NOT AllocateStack(IntStackP,1024)
      THEN FatalError('TickHandler allocate stack, no heap memory');
   InitV(8,TickIntHandle,@TickInt);
   _DosTimer := 0;
   InterruptsOff;
   Port[SysTimerBase+3] := $36;  (* Counter 0 mode=3, 16-bit R&W *)
   Port[SysTimerBase]   := TimeConst8000 AND $FF;
   Port[SysTimerBase]   := TimeConst8000 SHR 8;
   InterruptsOn;
END; (* TickHandler.Init *)

(**********************************************************************)
(* Proc. Name     : SysReqKeyPressed
(* Function       : 
(**********************************************************************)
PROCEDURE SysReqKeyPressed;

BEGIN
   IF State8000.Running THEN
   BEGIN
      State8000.Stop := TRUE;
   END;
END; (* SysReqKeyPressed *)

(**********************************************************************)
(* Proc. Name     : SysInt
(* Function       : INT15H handler.
(**********************************************************************)
PROCEDURE SysInt (BP: WORD);
INTERRUPT;

VAR
   Regs: IntRegisters ABSOLUTE BP;

BEGIN
   WITH Regs DO
   CASE AH OF
      $85:  IF AL=0 THEN SysReqKeyPressed;
      $90:  IF ConcurrentDiskMode AND (AL=0) AND State8000.Running AND
               NOT (DiskBusy) THEN
            BEGIN
            END;
      ELSE ;
   END;
   ChainInt(Regs,IsrArray[SysIntHandle].OrigAddr);
END; (* SysInt *)

(**********************************************************************)
(* Proc. Name     : KeybHandler.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR KeybHandler.Init;

BEGIN
   INHERITED Init;
   IF NOT AllocateStack(IntStackP,1024)
      THEN FatalError('KeybHandler allocate stack, no heap memory');
   InitV(9,KeybIntHandle,@KeybInt);
END; (* KeybHandler.Init *)

(**********************************************************************)
(* Proc. Name     : InitIntHandlers
(* Function       : Set up interrupt procedures for timer and keyboard.
(**********************************************************************)
PROCEDURE InitIntHandlers;

BEGIN
   KeybHndlr.Init;
   TickHndlr.Init;
   InitV(SrvcIntNo,SrvcIntHandle,@SrvcInt);
   InitV($15,SysIntHandle,@SysInt);
END; (* InitIntHandlers *)

(**********************************************************************)
(* Func. Name     : Full8254Supported
(* Function       : Check whether System Timer 0 supports the functions 
(*                  for readback of count and status. IBM PS2 models > 30
(*                  does not support readback of status, which makes it
(*                  impossible to support full precision in the emulated
(*                  clock device. 
(*                  Should be called only BEFORE the timer is reprogr.
(*                  to RC4000/8000 interval.
(**********************************************************************)
FUNCTION Full8254Supported: BOOLEAN;

VAR
   I,
   XState8254,
   State8254: BYTE;
   XRead8254,
   Read8254: WORD;

BEGIN
   Full8254Supported := FALSE;

   I := 0;

   (* The timer port must be read a multiple of 6 times, or sync. may
      be lost. *)

   REPEAT
      Port[SysTimerBase+3] := $C2;    (* Latch status&count of 8254 counter 0 *)
      XState8254 := Port[SysTimerBase];
      XRead8254 := (Port[SysTimerBase]);
      XRead8254 := XRead8254 + (WORD(Port[SysTimerBase]) SHL 8);

      Port[SysTimerBase+3] := $C2;    (* Latch status&count of 8254 counter 0 *)
      State8254 := Port[SysTimerBase];
      Read8254 := (Port[SysTimerBase]);
      Read8254 := Read8254 + (WORD(Port[SysTimerBase]) SHL 8);

      IF ((XState8254 OR $80) <> $B6) OR
         ((State8254 OR $80) <> $B6) THEN
         EXIT;  (* Status register not present *)

      Inc(I);
         
   UNTIL (XRead8254-Read8254 < 500) OR (I>2);

   Full8254Supported := I<=2;

END; (* Full8254Supported *)


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

   (* Reset system timer for normal operation (55 ms interval) *)
   InterruptsOff;
   Port[SysTimerBase+3] := $36;  (* Counter 0 mode=3, 16-bit R&W *)
   Port[SysTimerBase] := 0;
   Port[SysTimerBase] := 0;
   InterruptsOn;
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
END. (* UNIT INTR *)

