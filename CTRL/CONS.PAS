(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : CONS.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-14 18:35   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Console device simulator
(*
(**********************************************************************)

{$F+}
{$S-}

UNIT CONS;


INTERFACE

USES
   Io,
   Scrn;

CONST
   KeyBufSize     =  32;

TYPE

   (* KeyboardQueue is actually a general queue object also used for
      COM port Tx queing *)

   KeyboardQueuePtr  =  ^KeyboardQueue;

   KeyboardQueue  =  OBJECT
                        PRIVATE
                           _Head,
                           _Tail:   BYTE;
                           _Buf:    ARRAY[0..KeyBufSize-1] OF WORD;
                        PUBLIC
                           PROCEDURE   Init;
                           FUNCTION    IsEmpty:  BOOLEAN;
                           FUNCTION    IsFull:   BOOLEAN;
                           PROCEDURE   InsKey(K: WORD);
                           FUNCTION    GetKey:   WORD;
                           PROCEDURE   Flush;
                     END;


   (* ABSTRACT CONSOLE DEVICE: *)

   GenericConsDevicePtr  =  ^GenericConsDevice;

   GenericConsDevice=OBJECT (IoDevice)
                        _OprInt,
                        _IoInt:  BYTE;

                        _TimeoutVal: WORD;

                        _Busy:   BOOLEAN;
                        _Status: LONGINT;
                        _EchoOnSense: BOOLEAN;

                        KeybQ:  KeyboardQueue;

                        CONSTRUCTOR Init(DevNo: WORD;
                                         IoInt,OprInt: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;

                        PROCEDURE  WriteChar(C: CHAR); VIRTUAL;

                        PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                        PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                        PROCEDURE  Rd(Modif: BYTE);       VIRTUAL;
                        PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                        PROCEDURE  KeyAvail (Key: WORD);  VIRTUAL;
                        PROCEDURE  TimeoutAction;         VIRTUAL;

                     END;


   (* CONSOLE ON PC KEYBOARD/CRT: *)

   ConsDevicePtr  =  ^ConsDevice;

   ConsDevice     =  OBJECT (GenericConsDevice)
                        _Height,
                        _Width    : BYTE;
                        _VideoMode: WORD;

                        Scrn      : ConsScreen;

                        CONSTRUCTOR Init(DevNo: WORD;
                                         ConsNo, IoInt,OprInt: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;

                        PROCEDURE  WriteChar(C: CHAR); VIRTUAL;

                        PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                        FUNCTION   DeviceID: STRING;      VIRTUAL;

                        FUNCTION   InForeground: BOOLEAN;
                        PROCEDURE  KeyAvail (Key: WORD); VIRTUAL;
                        PROCEDURE  IntrAction(VAR Param); VIRTUAL;

                     END;


   (* CONSOLE ON COM PORT: *)
   
   ComDevicePtr   =  ^ComDevice;

   ComDevice      =  OBJECT (GenericConsDevice)
                        _IntHandle,
                        _ISRMask,
                        _IRQ       : BYTE;

                        _TxActive,
                        _WrIntrPending,
                        _InService : BOOLEAN;

                        _IoBase    : WORD;

                        TxQueue   : KeyboardQueue;

                        CONSTRUCTOR Init(DevNo: WORD;
                                         IoBase: WORD;
                                         IRQ,IoInt,OprInt: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;

                        PROCEDURE  WriteChar(C: CHAR);    VIRTUAL;

                        PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                        FUNCTION   DeviceID: STRING;      VIRTUAL;

                        PROCEDURE  KeyAvail (Key: WORD);  VIRTUAL;
                        PROCEDURE  IntrAction(VAR Param); VIRTUAL;

                        PROCEDURE  MakeLineSettings(Divisor: WORD; 
                                                    CharLen,
                                                    Parity,
                                                    StopBits: CHAR);
                     END;

(*#PAGE*)
IMPLEMENTATION

USES
   OpCrt,
   OpInt,
   OpRoot,
   Util,
   Intr,
   Intf;

CONST
   DATE_HOTKEY  = $2000;  (* Alt-D *)

   (*  addr. of 8250 regs: *)

   UARTthr   =     0;
   UARTrbr   =     0;
   UARTier   =     1;
   UARTiir   =     2;
   UARTlcr   =     3;
   UARTmcr   =     4;
   UARTlsr   =     5;
   UARTmsr   =     6;



TYPE
   ComIntrHandlerPtr = ^ComIntrHandler;

   ComIntrHandler =  OBJECT (IntrHandler)
                        PROCEDURE DoHooks(VAR Param);  VIRTUAL;
                     END;


VAR
   ComIntrHndlr: ComIntrHandler;   (* Common for all COM devices *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : KeyboardQueue.Init
(* Function       : 
(**********************************************************************)
PROCEDURE KeyboardQueue.Init;

BEGIN
   _Head := 0;
   _Tail := 0;
END; (* KeyboardQueue.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : KeyboardQueue.IsEmpty
(* Function       : 
(**********************************************************************)
FUNCTION KeyboardQueue.IsEmpty: BOOLEAN;

BEGIN
   IsEmpty := _Head = _Tail;
END; (* KeyboardQueue.IsEmpty *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : KeyboardQueue.IsFull
(* Function       : 
(**********************************************************************)
FUNCTION KeyboardQueue.IsFull: BOOLEAN;

VAR
   T: BYTE;
BEGIN
   T := _Tail + 1;
   IF T >= KeyBufSize THEN T := 0;
   IsFull := _Head = T;
END; (* KeyboardQueue.IsFull *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : KeyboardQueue.InsKey
(* Function       : 
(**********************************************************************)
PROCEDURE KeyboardQueue.InsKey(K: WORD);

VAR
   T: BYTE;
BEGIN
   T := _Tail + 1;
   IF T >= KeyBufSize THEN T := 0;
   IF T = _Head THEN Exit;  (* Buffer full *)
   _Buf[T] := K;
   _Tail := T;
END; (* KeyboardQueue.InsKey *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : KeyboardQueue.GetKey
(* Function       : 
(**********************************************************************)
FUNCTION KeyboardQueue.GetKey: WORD;

BEGIN
   IF _Head = _Tail THEN GetKey := 0 ELSE
   BEGIN
      Inc(_Head);
      IF _Head >= KeyBufSize THEN _Head := 0;
      GetKey := _Buf[_Head];
   END;
END; (* KeyboardQueue.GetKey *)
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : KeyboardQueue.Flush
(* Function       : 
(**********************************************************************)
PROCEDURE KeyboardQueue.Flush;

BEGIN
   _Head := _Tail;
END; (* KeyboardQueue.Flush *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR GenericConsDevice.Init (DevNo: WORD;
                              IoInt,OprInt: BYTE);

BEGIN
   INHERITED Init(DevNo);
   KeybQ.Init;
   _IoInt := IoInt;
   _OprInt := OprInt;
   _Busy := FALSE;
   _TimeoutVal := 1;
   _EchoOnSense := FALSE;
END; (* GenericConsDevice.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR GenericConsDevice.Done;

BEGIN
END; (* GenericConsDevice.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR ConsDevice.Done;

BEGIN
   INHERITED Done;
   Scrn.Done;
   KeybHndlr.RemHook(Self);
   (* Should release interrupts here *)
END; (* ConsDevice.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Sense (Modif: BYTE);

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;
      Ex23 := Ord(_Busy);
      IF NOT _Busy THEN
      BEGIN
         SrvcParam.Wreg := _Status SHL 8;
         IF _EchoOnSense AND (_Status <> 27) THEN WriteChar(Chr(_Status));
         _EchoOnSense := FALSE;
      END;
   END;
END; (* GenericConsDevice.Sense *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Control
(* Function       : Causes an interrupt, as defined in the device manual.
(**********************************************************************)
PROCEDURE GenericConsDevice.Control (Modif: BYTE);

BEGIN
   WITH State8000 DO
      IR := IR OR (LONGINT(1) SHL (31-_IoInt));
END; (* GenericConsDevice.Control *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Rd
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Rd (Modif: BYTE);

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;
      Ex23 := Ord(_Busy);
   END;
   IF _Busy THEN Exit;

   WITH KeybQ DO
   IF IsEmpty THEN
   BEGIN
      _Busy := TRUE;
      Timer.SetTimeout(_TimeoutVal,SEC);
   END ELSE KeyAvail(GetKey);
END; (* GenericConsDevice.Rd *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.WriteChar
(* Function       : Writes a character to screen. (Can be overridden)
(**********************************************************************)
PROCEDURE GenericConsDevice.WriteChar (C: CHAR);

BEGIN
{  Abstract;}
END; (* GenericConsDevice.WriteChar *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Wr (Modif: BYTE);

BEGIN
{  Abstract;}   
END; (* GenericConsDevice.Wr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.KeyAvail
(* Function       : Called when a keystroke is available for RC8000
(**********************************************************************)
PROCEDURE GenericConsDevice.KeyAvail (Key: WORD);

VAR
   S,Sx: STRING[20];
   N,
   B: BYTE;

BEGIN
{  Abstract;}
END; (* GenericConsDevice.KeyAvail *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GenericConsDevice.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.TimeoutAction;

BEGIN
   PushF;
   InterruptsOff;
   IF _Busy THEN
   BEGIN
      _Busy := FALSE;
      _Status := $00200000; (* Status = timeout *)
      WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_IoInt));
   END;
   PopF;
END; (* GenericConsDevice.TimeoutAction *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR ConsDevice.Init (DevNo: WORD;
                             ConsNo, IoInt,OprInt: BYTE);

BEGIN
   IF TypeOf(Self) = TypeOf(ConsDevice) THEN
   BEGIN  (* Already set of descendent type *)
      _Height    := ScreenHeight;
      _Width     := ScreenWidth;
      _VideoMode := CurrentVideoMode;
   END;
   INHERITED Init(DevNo,IoInt,OprInt);
   Scrn.Init(ConsNo,_Height,_Width,_VideoMode);
   KeybHndlr.InsHook(Self);
END; (* ConsDevice.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsDevice.WriteChar
(* Function       : Writes a character to screen. (Can be overridden)
(**********************************************************************)
PROCEDURE ConsDevice.WriteChar (C: CHAR);

BEGIN
   Scrn.OutChar(C);
END; (* ConsDevice.WriteChar *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE ConsDevice.Wr (Modif: BYTE);

BEGIN
   InterruptsOn;
   _Status := (State8000.SrvcParam.Wreg SHR 8) AND $7F;
   WriteChar(Chr(_Status));
   WITH State8000 DO
   BEGIN
      IR := IR OR (LONGINT(1) SHL (31-_IoInt));
      Ex22 := 0;
      Ex23 := 0;
   END;
   IF _Busy THEN Timer.CancelTimeout;
   _Busy := FALSE;
END; (* ConsDevice.Wr *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : ConsDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION ConsDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'CONSOLE';
END; (* ConsDevice.DeviceID *)



(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : ConsDevice.InForeground
(* Function       : 
(**********************************************************************)
FUNCTION ConsDevice.InForeground: BOOLEAN;

BEGIN
   InForeground := Scrn.OnPhysScreen;
END; (* ConsDevice.InForeground *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsDevice.KeyAvail
(* Function       : Called when a keystroke is available for RC8000
(**********************************************************************)
PROCEDURE ConsDevice.KeyAvail (Key: WORD);

VAR
   S,Sx: STRING[20];
   N,
   B: BYTE;

BEGIN
   Timer.CancelTimeout;
   IF Key = DATE_HOTKEY THEN
   BEGIN  (* Get date & time string, read from CMOS. 
             DOS is unavailable as we may be part of the keybd. interrupt proc. *)
      S := '';
      PushF;
      InterruptsOff;
      REPEAT
         Sx := S;
         S := '';
         FOR N := 9 DOWNTO 0 DO
         IF N IN [0,2,4,7,8,9] THEN
         BEGIN
            Port[$70] := N;
            B := Port[$71];
            S := S + Chr((B SHR 4) + Ord('0')) + Chr((B AND $F)+Ord('0')) + ' ';
         END;
         S[Length(S)] := #13;  (* repl. last ' ' w. CR *)
      UNTIL S=Sx;  (* Get same value twice to avoid roll-over problems *)

      FOR N := 2 TO Length(S) DO KeybQ.InsKey(Ord(S[N]));
      Key := Ord(S[1]);
      PopF;
   END;
   _Status := Ord(Pc2Rc[Key AND $FF]);
   _EchoOnSense := TRUE;   (* DONT echo here, this is part of an interrupt routine *)
   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_IoInt));
END; (* ConsDevice.KeyAvail *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsDevice.IntrAction
(* Function       : 
(**********************************************************************)
PROCEDURE ConsDevice.IntrAction (VAR Param);

VAR
   KP:   KeybParam ABSOLUTE Param;

BEGIN
   IF InForeground AND (NOT KP.Eaten) THEN
   WITH State8000, KP, KeybQ DO
   BEGIN
      IF ((Key AND $FF) = 27) AND NOT _Busy THEN
      BEGIN
         Flush;
         IR := IR OR (LONGINT(1) SHL (31-_OprInt));
      END ELSE

      BEGIN
         IF _Busy AND IsEmpty
            THEN KeyAvail(Key)
            ELSE InsKey(Key);
         _Busy := FALSE;
      END;
      EatKeystroke;
      Eaten := TRUE;
   END;
END; (* ConsDevice.IntrAction *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComInterrupt
(* Function       : 
(**********************************************************************)
PROCEDURE ComInterrupt (BP: WORD);
INTERRUPT;

VAR
   Regs: IntRegisters ABSOLUTE BP;

BEGIN
   ComIntrHndlr.DoHooks(Regs);
   InterruptsOn;
   SendEOI;
END; (* ComInterrupt *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR ComDevice.Init (DevNo: WORD;
                            IoBase: WORD;
                            IRQ,IoInt,OprInt: BYTE);
 
VAR
   Dummy: BYTE;

BEGIN
   INHERITED Init(DevNo,IoInt,OprInt);

   _IntHandle     := AllocateIntHandle(TRUE);
   _IoBase        := IoBase;
   _IRQ           := IRQ;
   _ISRMask       := 1 SHL IRQ;
   _InService     := FALSE;
   _TxActive      := FALSE;
   _WrIntrPending := FALSE;

   TxQueue.Init;
   ComIntrHndlr.InsHook(Self);
   InitV(IRQ+8,_IntHandle,@ComInterrupt);

   (* HW Init: *)
   Port[_IoBase+UARTlcr] := Port[_IoBase+UARTlcr] AND $7F;  (* Reset Div.Access Latch *)
   Dummy := Port[_IoBase+UARTrbr];  (* read any pending char *)
   Dummy := Port[_IoBase+UARTlsr];  (* read LSR to clear error *)
   Port[_IoBase+UARTier] := 1; (* Enable Rx interrupts on 8250 *)
   Port[_IoBase+UARTmcr] := Port[_IoBase+UARTmcr] OR $B; (* DTR,RTS,OUT2 ON *)

   Port[I8259_1Base+1] := Port[I8259_1Base+1] AND NOT _ISRMask;  (* Enable on 8259 *)

END; (* ComDevice.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR ComDevice.Done;

BEGIN
   Port[I8259_1Base+1] := Port[I8259_1Base+1] OR _ISRMask;  (* Disable on 8259 *)
   Port[_IoBase+UARTier] := 0; (* Disable interrupts on 8250 *)
   Port[_IoBase+UARTmcr] := Port[_IoBase+UARTmcr] AND NOT $B; (* DTR,RTS,OUT2 OFF *)
   INHERITED Done;
END; (* ComDevice.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.WriteChar
(* Function       : 
(**********************************************************************)
PROCEDURE ComDevice.WriteChar (C: CHAR);

BEGIN
   PushF;
   InterruptsOff;
   WITH TxQueue DO
   BEGIN
      IF _TxActive THEN InsKey(Ord(C)) ELSE
      BEGIN  (* Start UART Tx *)
         Port[_IoBase+UARTthr] := Ord(C);
         Port[_IoBase+UARTier] := Port[_IoBase+UARTier] OR 2; (* Enable Tx interrupts on 8250 *)
         _TxActive := TRUE;
      END;
   END;
   PopF;
END; (* ComDevice.WriteChar *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE ComDevice.Wr (Modif: BYTE);

BEGIN
   IF TxQueue.IsFull THEN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;
      Ex23 := 1;
   END ELSE
   BEGIN
      _Status := (State8000.SrvcParam.Wreg SHR 8) AND $7F;
      WriteChar(Chr(_Status));
      WITH State8000 DO
      BEGIN
         IF TxQueue.IsFull
            THEN _WrIntrPending := TRUE
            ELSE IR := IR OR (LONGINT(1) SHL (31-_IoInt));
         Ex22 := 0;
         Ex23 := 0;
      END;

      IF _Busy THEN Timer.CancelTimeout;
      _Busy := FALSE;
   END;
END; (* ComDevice.Wr *)


(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : ComDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION ComDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'TERMINAL';
END; (* ComDevice.DeviceID *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.KeyAvail
(* Function       : Called when a keystroke is available for RC8000
(**********************************************************************)
PROCEDURE ComDevice.KeyAvail (Key: WORD);

BEGIN
   Timer.CancelTimeout;
   _Status := Key AND $7F;
   _EchoOnSense := TRUE;   (* DONT echo here, this is part of an interrupt routine *)
   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_IoInt));
END; (* ComDevice.KeyAvail *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.IntrAction
(* Function       : 
(* Note           : Must run in disable mode.
(**********************************************************************)
PROCEDURE ComDevice.IntrAction (VAR Param);

VAR
   IER,
   Key,
   LineState,
   IntrIdent: BYTE;

BEGIN
   IntrIdent := Port[_IoBase+UARTiir] AND $0F;

   IF IntrIdent = 4 THEN
   WITH State8000, KeybQ DO
   BEGIN  (* Rx char avail *)
      LineState := Port[_IoBase+UARTlsr];
      IF (LineState AND 12) <> 0
         THEN Key := 26  (* Parity or framing error *)
         ELSE Key := Port[_IoBase+UARTrbr] AND $7F;

      IF (Key = 27) AND NOT _Busy THEN
      BEGIN
         Flush;
         TxQueue.Flush;
         IR := IR OR (LONGINT(1) SHL (31-_OprInt));
      END ELSE

      BEGIN
         IF _Busy AND IsEmpty
            THEN KeyAvail(Key)
            ELSE InsKey(Key);
         _Busy := FALSE;
      END;
   END ELSE

   IF IntrIdent = 2 THEN
   WITH State8000, TxQueue DO
   BEGIN  (* Tx empty *)
      IF IsEmpty THEN
      BEGIN  (* Stop Tx *)
         Port[_IoBase+UARTier] := Port[_IoBase+UARTier] AND NOT 2; (* Disable Tx interrupts on 8250 *)
         _TxActive := FALSE;
      END ELSE
         Port[_IoBase+UARTthr] := GetKey AND $7F;
      IF _WrIntrPending
         THEN IR := IR OR (LONGINT(1) SHL (31-_IoInt));
      _WrIntrPending := FALSE;
   END;

   (* Trig interrupt: *)
   IER := Port[_IoBase+UARTier];
   Port[_IoBase+UARTier] := 0;
   Port[_IoBase+UARTier] := IER;
         
END; (* ComDevice.IntrAction *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComDevice.MakeLineSettings
(* Function       : 
(**********************************************************************)
PROCEDURE ComDevice.MakeLineSettings (Divisor: WORD; 
                                      CharLen,Parity,StopBits: CHAR);

VAR
   LCPar : BYTE;

BEGIN
   Port[_IoBase+UARTlcr] := $80;  (* Enable div. access *)
   Port[_IoBase+UARTthr] := Divisor AND $FF;
   Port[_IoBase+UARTier] := Divisor SHR 8;

   IF CharLen = '7' THEN LCPar := 2 ELSE LCPar := 3;
   IF Parity = 'E' THEN LCPar := LCPar + $18 ELSE
   IF Parity = 'O' THEN LCPar := LCPar + $10;

   IF StopBits = '2' THEN LCPar := LCPar + 4;

   Port[_IoBase+UARTlcr] := LCPar;

END; (* ComDevice.MakeLineSettings *)




(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ComIntrHandler.DoHooks
(* Function       : 
(**********************************************************************)
PROCEDURE ComIntrHandler.DoHooks (VAR Param);

VAR P: DoubleNodePtr;
    ISR: BYTE;

BEGIN
   Port[I8259_1Base] := $0B;  (* Read ISR *)
   ISR := Port[I8259_1Base];

   P := HookList.Head;
   WHILE P <> NIL DO
   WITH ComDevicePtr(P)^ DO
   BEGIN
      IF ((ISR AND _ISRMask) <> 0) AND NOT _InService THEN
      BEGIN
         _InService := TRUE;
         IntrAction(Param);
         _InService := FALSE;
      END;
      P := HookList.Next(P);
   END;
END; (* ComIntrHandler.DoHooks *)


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

   ComIntrHndlr.Init;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT CONS *)

