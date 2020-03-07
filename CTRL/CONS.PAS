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
(* 96-09-28 21:02 HJ "RC8000-like" version
(* 97-01-11 01:16 HJ Vers. 2.1: Extend from 2 to 4 multiport4 cards
(**********************************************************************)

{$F+}
{$S-}

UNIT CONS;


INTERFACE

USES
   Io,
   Intr,
   Expander,
   ConvTabs,
   Scrn;

TYPE
   Multiport4ID = (HIGH_ADDR,LOW_ADDR,HIGHX_ADDR,LOWX_ADDR);


CONST
   KeyBufSize     =  102;

   (* Hardware handshake lines *)
   CTS            = $10;
   DSR            = $20;
   DCD            = $80;

   Multiport4AddrMap: ARRAY [Multiport4ID,1..4] OF WORD =
      (($2A0,$2A8,$2B0,$2B8),    (* HIGH_ADDR  *)
       ($1A0,$1A8,$1B0,$1B8),    (* LOW_ADDR   *)
       ($2C0,$2C8,$2D0,$2D8),    (* HIGHX_ADDR *)
       ($1C0,$1C8,$1D0,$1D8));   (* LOWX_ADDR  *)

   Multiport4VectorMap: ARRAY[Multiport4ID] OF WORD =
      ($2BF,$1BF,$2DF,$1DF);


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
                           PROCEDURE   RemoveLast;
                           PROCEDURE   Flush;
                     END;

   (* ComDisconnectTimer is used to time the toggling of DTR
      caused by disconnect request *)

   ComDisconnectTimerP = ^ComDisconnectTimer;

   ComDisconnectTimer = OBJECT (IoTimer)
                           PROCEDURE TimeoutAction; VIRTUAL;
                        END;
                           


   (* ABSTRACT CONSOLE DEVICE: *)

   GenericConsDevicePtr  =  ^GenericConsDevice;

   GenericConsDevice=OBJECT (IoDevice)
                        _OprInt,
                        _IoInt:  BYTE;

                        _OprIntBit,
                        _IoIntBit: LONGINT;

                        _OprIntExpander,
                        _IoIntExpander:InterruptExpanderPtr;

                        _ExpanderBit: LONGINT;     (* Id bit in expanders *)

                        _TimeoutVal: WORD;

                        _WrIntrPending,             (* only ComDevice *)
                        _InpBusy:     BOOLEAN;
                        _Status:      LONGINT;
                        _InKey:       BYTE;
                        _RdModif:     BYTE;
                        _EchoOnSense: BOOLEAN;
                        _InpEnabled:  BOOLEAN;
                        _Prompt:      CHAR;
                        _InpConvTabNo: BYTE;
                        _InpConvTab:  InpConvTableP;

                        KeybQ:  KeyboardQueue;
                        DisconectTimer: ComDisconnectTimer;

                        CONSTRUCTOR Init(DevNo: WORD;
                                         IoInt,OprInt: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;

                        PROCEDURE  MakeIoInt;
                        PROCEDURE  MakeOprInt;

                        FUNCTION   Disconnected: BOOLEAN; VIRTUAL;
                        PROCEDURE  WriteChar(C: CHAR);    VIRTUAL;
                        PROCEDURE  SetAttributes;         VIRTUAL;
                        PROCEDURE  GetAttributes;         VIRTUAL;
                        PROCEDURE  DisconnectRequest;     VIRTUAL;

                        PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                        PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                        PROCEDURE  Rd(Modif: BYTE);       VIRTUAL;
                        PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                        PROCEDURE  KeyAvail (Key: WORD);  VIRTUAL;
                        PROCEDURE  TimeoutAction;         VIRTUAL;
                        PROCEDURE  DisconnectTimeoutAction;VIRTUAL;

                        PROCEDURE  HandleInputConversion; VIRTUAL;

                     END;


   (* CONSOLE ON PC KEYBOARD/CRT: *)

   ConsDevicePtr  =  ^ConsDevice;

   ConsDevice     =  OBJECT (GenericConsDevice)
                        _Height,
                        _Width    : BYTE;
                        _VideoMode: WORD;
                        _PrintFlag: BOOLEAN;

                        Scrn      : ConsScreen;

                        CONSTRUCTOR Init(DevNo: WORD;
                                         ConsNo, IoInt,OprInt: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;

                        FUNCTION   Disconnected: BOOLEAN; VIRTUAL;
                        PROCEDURE  WriteChar(C: CHAR); VIRTUAL;

                        PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                        FUNCTION   DeviceID: STRING;      VIRTUAL;

                        FUNCTION   InForeground: BOOLEAN;
                        PROCEDURE  KeyAvail (Key: WORD); VIRTUAL;
                        PROCEDURE  TimeoutAction;         VIRTUAL;
                        PROCEDURE  IntrAction(VAR Param); VIRTUAL;

                     END;


   (* TERMINAL ON COM PORT: *)
   
   ComDevicePtr   =  ^ComDevice;

   ComDevice      =  OBJECT (GenericConsDevice)
                        _IntHandle,
                        _ISRMask,
                        _IRQ       : BYTE;

                        _TxActive,
                        _InService : BOOLEAN;

                        _IoBase    : WORD;

                        _ConnectLine,
                        _ReadyLine : BYTE;  (* use DSR/CTS/DCD for connect/handshake *)

                        _LSRMirror,
                        _MSRMirror,
                        _IERMirror : BYTE;

                        _TxHold    : BOOLEAN;

                        TxQueue    : KeyboardQueue;

                        CONSTRUCTOR Init(DevNo: WORD;
                                         IoBase: WORD;
                                         IRQ,IoInt,OprInt: BYTE;
                                         ConnectLine,ReadyLine: BYTE);
                        DESTRUCTOR Done;                  VIRTUAL;

                        FUNCTION   Disconnected: BOOLEAN; VIRTUAL;
                        PROCEDURE  WriteChar(C: CHAR);    VIRTUAL;
                        PROCEDURE  DisconnectRequest;     VIRTUAL;

                        PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                        FUNCTION   DeviceID: STRING;      VIRTUAL;

                        PROCEDURE  KeyAvail (Key: WORD);  VIRTUAL;
                        PROCEDURE  TimeoutAction;         VIRTUAL;
                        PROCEDURE  DisconnectTimeoutAction;VIRTUAL;
                        PROCEDURE  IntrAction(VAR Param); VIRTUAL;

                        PROCEDURE  MakeLineSettings(Divisor: WORD; 
                                                    CharLen,
                                                    Parity,
                                                    StopBits: CHAR);
                     END;



   (* HANDLER FOR MULTIPORT SERIAL CARD: *)

   Multiport4HandlerPtr = ^Multiport4Handler;

   Multiport4Handler= OBJECT (IntrHandler)
                        _Id         : Multiport4ID;
                        _IntHandle,
                        _ISRMask,
                        _IRQ        : BYTE;
                        _PortUsed   : ARRAY[1..4] OF BOOLEAN;

                        CONSTRUCTOR Init(Id: Multiport4ID; IRQ: BYTE);
                        DESTRUCTOR  Done;               VIRTUAL;
                        PROCEDURE   InsHook(VAR Hook: ComDevice);
                        FUNCTION    PortUsed (Port: BYTE): BOOLEAN;
                        PROCEDURE   DoHooks(VAR Param);  VIRTUAL;
                     END;


PROCEDURE ConsPostInit;

VAR
   MultiPort4Handlers: ARRAY[Multiport4ID] OF Multiport4HandlerPtr;


IMPLEMENTATION

USES
   OpCrt,
   OpInt,
   OpRoot,
   Util,
   Intf;

CONST
   (* Statusword: *)

   INTERVENTION = LONGINT(1) SHL 23;
   PARITY_ERROR = LONGINT(1) SHL 22;
   TIMEOUT      = LONGINT(1) SHL 21;
   TERMINATE    = LONGINT(1) SHL 20;  (* Simulator specific *)
   BLIND_CHAR   = LONGINT(1) SHL 19;  (* Simulator specific *)
   BACKSPACE    = LONGINT(1) SHL 18;  (* Simulator specific *)
   CANCEL       = LONGINT(1) SHL 17;  (* Simulator specific *)
   ATTENTION    = LONGINT(1) SHL 16;  (* Simulator specific *)


   (* Read modifier bits (all are simulator specific): *)

   BLIND_MODE   = 1;
   NO_BS_ECHO   = 2;


   (* Write modifier values (all are simulator specific): *)

   WRITE_PROMPT = 1;


   (* Control modifier values (all are simulator specific): *)

   SET_ATTR     = 0;
   GET_ATTR     = 1;
   DISCONN_REQ  = 15;



   DATE_HOTKEY  = $2000;  (* Alt-D *)
   PRINT_HOTKEY = $1900;  (* Alt-P *)

   (*  addr. of 82x50 regs: *)

   UARTthr   =     0;
   UARTrbr   =     0;
   UARTier   =     1;
   UARTiir   =     2;
   UARTlcr   =     3;
   UARTmcr   =     4;
   UARTlsr   =     5;
   UARTmsr   =     6;


   (* UseComTxBuffer = TRUE -> Write operations are buffered in
      the TxQueue 32-byte buffer. This causes status reporting
      (disconnected/timeout) to be inaccurate. When FALSE, TxQueue
      is still needed to e.g. buffer input echo.
      TRUE is not tested!
   *)
   UseComTxBuffer: BOOLEAN = FALSE;


TYPE
   ComIntrHandlerPtr = ^ComIntrHandler;

   ComIntrHandler =  OBJECT (IntrHandler)
                        PROCEDURE DoHooks(VAR Param);  VIRTUAL;
                     END;


VAR
   ComIntrHndlr: ComIntrHandler;   (* Common for all COM devices *)


(**********************************************************************)
(* Proc. Name     : KeyboardQueue.Init
(* Function       : 
(**********************************************************************)
PROCEDURE KeyboardQueue.Init;

BEGIN
   _Head := 0;
   _Tail := 0;
END; (* KeyboardQueue.Init *)

(**********************************************************************)
(* Func. Name     : KeyboardQueue.IsEmpty
(* Function       : 
(**********************************************************************)
FUNCTION KeyboardQueue.IsEmpty: BOOLEAN;

BEGIN
   IsEmpty := _Head = _Tail;
END; (* KeyboardQueue.IsEmpty *)

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
   IF T = _Head THEN 
      Exit;  (* Buffer full *)
   _Buf[T] := K;
   _Tail := T;
END; (* KeyboardQueue.InsKey *)

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


(**********************************************************************)
(* Proc. Name     : KeyboardQueue.RemoveLast
(* Function       : Remove youngest element from queue
(**********************************************************************)
PROCEDURE KeyboardQueue.RemoveLast;

BEGIN
   IF _Head <> _Tail THEN
   BEGIN
      IF _Tail = 0 THEN _Tail := KeyBufSize-1 ELSE Dec(_Tail);
   END;
END; (* KeyboardQueue.RemoveLast *)


(**********************************************************************)
(* Proc. Name     : KeyboardQueue.Flush
(* Function       : 
(**********************************************************************)
PROCEDURE KeyboardQueue.Flush;

BEGIN
   _Head := _Tail;
END; (* KeyboardQueue.Flush *)

(**********************************************************************)
(* Proc. Name     : ComDisconnectTimer.IntrAction
(* Function       : 
(**********************************************************************)
PROCEDURE ComDisconnectTimer.TimeoutAction;

BEGIN
   GenericConsDevicePtr(_Owner)^.DisconnectTimeoutAction;
END; (* ComDisconnectTimer.IntrAction *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR GenericConsDevice.Init (DevNo: WORD;
                              IoInt,OprInt: BYTE);

BEGIN
   INHERITED Init(DevNo);
   KeybQ.Init;
   DisconectTimer.Init(Self);

   IF IoInt > 63 THEN
   BEGIN  (* Device on TMX, Intno = 64 + <devno of interrupt expander> *)
      _OprIntExpander := InterruptExpanderPtr(IOMap[OprInt AND 63]);
      _OprInt := _OprIntExpander^.IntNumber;
      _IoIntExpander  := InterruptExpanderPtr(IOMap[IoInt AND 63]);
      _IoInt := _IoIntExpander^.IntNumber;
      _ExpanderBit := LONGINT(1) SHL (32-(DevNo-(OprInt AND 63)));
   END ELSE
   BEGIN
      _IoInt := IoInt;
      _OprInt := OprInt;
      _OprIntExpander := NIL;
      _IoIntExpander := NIL;
      _ExpanderBit := 0;
   END;

   _OprIntBit := LONGINT(1) SHL (31-_OprInt);
   _IoIntBit := LONGINT(1) SHL (31-_IoInt);
   _WrIntrPending := FALSE;
   _InpBusy := FALSE;
   _TimeoutVal := 1;
   _EchoOnSense := FALSE;
   _InpEnabled := FALSE;
   _Prompt := #7;
   _InpConvTabNo := 1;
   _InpConvTab := InpConvTables[_InpConvTabNo];
END; (* GenericConsDevice.Init *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR GenericConsDevice.Done;

BEGIN
END; (* GenericConsDevice.Done *)


(**********************************************************************)
(* Proc. Name     : GenericConsDevice.MakeIoInt
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.MakeIoInt;

BEGIN
   IF _ExpanderBit <> 0 THEN
   WITH _IoIntExpander^ DO 
      Register := Register OR _ExpanderBit;
   WITH State8000 DO
      IR := IR OR _IoIntBit;
END; (* GenericConsDevice.MakeIoInt *)


(**********************************************************************)
(* Proc. Name     : GenericConsDevice.MakeOprInt
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.MakeOprInt;

BEGIN
   IF _ExpanderBit <> 0 THEN
   WITH _OprIntExpander^ DO 
      Register := Register OR _ExpanderBit;
   WITH State8000 DO
      IR := IR OR _OprIntBit;
END; (* GenericConsDevice.MakeOprInt *)



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

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Sense (Modif: BYTE);

VAR
   I: BYTE;

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := Ord(Disconnected);
      Ex23 := Ord(_InpBusy);
      IF BOOLEAN(Ex22 OR Ex23) THEN Exit;

      SrvcParam.Wreg := _Status SHL 8;
      IF _EchoOnSense THEN
      BEGIN
         IF BYTE(_Status) > 31 THEN WriteChar(Chr(_Status)) ELSE
         WITH _InpConvTab^[BYTE(_InKey)] DO
         BEGIN
            FOR I := 1 TO Ord(Echo[0]) DO WriteChar(Echo[I]);
         END;
      END;
      _EchoOnSense := FALSE;
   END;
END; (* GenericConsDevice.Sense *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Control
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Control (Modif: BYTE);

BEGIN
   CASE Modif OF
      SET_ATTR:    SetAttributes;
      GET_ATTR:    GetAttributes;
      DISCONN_REQ: DisconnectRequest;
   END;
END; (* GenericConsDevice.Control *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Rd
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Rd (Modif: BYTE);

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := Ord(Disconnected);
      Ex23 := Ord(_InpBusy);
      IF BOOLEAN(Ex22 OR Ex23) THEN Exit;
   END;

   _RdModif := Modif;
   _InpEnabled := TRUE;

   PushF;
   InterruptsOff;

   WITH KeybQ DO
   IF IsEmpty THEN
   BEGIN
      _InpBusy := TRUE;
      Timer.SetTimeout(_TimeoutVal,SEC);
   END ELSE KeyAvail(GetKey);
   PopF;
END; (* GenericConsDevice.Rd *)


(**********************************************************************)
(* Func. Name     : GenericConsDevice.Disconnected
(* Function       : 
(**********************************************************************)
FUNCTION GenericConsDevice.Disconnected: BOOLEAN;

BEGIN
{  Abstract;}   
END; (* GenericConsDevice.Disconnected *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.WriteChar
(* Function       : Writes a character to screen. (Can be overridden)
(**********************************************************************)
PROCEDURE GenericConsDevice.WriteChar (C: CHAR);

BEGIN
{  Abstract;}
END; (* GenericConsDevice.WriteChar *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.Wr (Modif: BYTE);

BEGIN
{  Abstract;}   
END; (* GenericConsDevice.Wr *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.KeyAvail
(* Function       : Called when a keystroke is available for RC8000
(**********************************************************************)
PROCEDURE GenericConsDevice.KeyAvail (Key: WORD);

BEGIN
{  Abstract;}
END; (* GenericConsDevice.KeyAvail *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.TimeoutAction;

BEGIN
   {Abstract;}   
END; (* GenericConsDevice.TimeoutAction *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.DisconnectTimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.DisconnectTimeoutAction;

BEGIN
   { Do nothing }   
END; (* GenericConsDevice.DisconnectTimeoutAction *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.SetAttributes
(* Function       : Only handle "type" and "prompt" attributes
(**********************************************************************)
PROCEDURE GenericConsDevice.SetAttributes;

VAR
  Msg: ARRAY [1..8] OF LONGINT;
  Typ: WORD;

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;  (* Allow operation even if disconnected *)
      Ex23 := Ord(_InpBusy);

      IF NOT _InpBusy THEN
      BEGIN
         FromCore(State8000.SrvcParam.Wreg SHR 8,8,@Msg);
         Typ := (Msg[2] SHR 8) AND $3FF;
         IF  Typ <= MAXINPTABLENO THEN
         BEGIN
            _InpConvTabNo := Typ;
            _InpConvTab   := InpConvTables[Typ];
         END ELSE Ex23 := 1;

         IF Ex23 = 0 THEN _Prompt := Chr(Msg[4] SHR 16);
      END;
   END;
END; (* GenericConsDevice.SetAttributes *)

(**********************************************************************)
(* Proc. Name     : GenericConsDevice.GetAttributes
(* Function       : Only handle "type" and "prompt" attributes
(**********************************************************************)
PROCEDURE GenericConsDevice.GetAttributes;

VAR
   Answ: ARRAY [1..8] OF LONGINT;
   I: WORD;

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;  (* Allow operation even if disconnected *)
      Ex23 := Ord(_InpBusy);

      IF NOT _InpBusy THEN
      BEGIN
         FOR I := 1 TO 8 DO Answ[I] := 0;
         Answ[2] := (_InpConvTabNo SHL 8) + (1 SHL 19);  (* echo.yes *)
         Answ[4] := LONGINT(Ord(_Prompt)) SHL 16;
         ToCore(State8000.SrvcParam.Wreg SHR 8,8,@Answ);
      END;
   END;
END; (* GenericConsDevice.GetAttributes *)


(**********************************************************************)
(* Proc. Name     : GenericConsDevice.DisconnectRequest
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.DisconnectRequest;

BEGIN
   { Do nothing }
END; (* GenericConsDevice.DisconnectRequest *)


(**********************************************************************)
(* Proc. Name     : GenericConsDevice.HandleInputConversion
(* Function       : 
(**********************************************************************)
PROCEDURE GenericConsDevice.HandleInputConversion;

BEGIN
   IF (_Status AND BLIND_CHAR) = 0 THEN
   BEGIN
      IF (_Status > 31) THEN _EchoOnSense := ((_RdModif AND BLIND_MODE) = 0) ELSE
      WITH _InpConvTab^[BYTE(_Status)] DO
      BEGIN
         IF ((NOT (BS_CHAR IN Attr) OR ((_RdModif AND NO_BS_ECHO) = 0))) AND
            ((_RdModif AND BLIND_MODE) = 0) THEN
            _EchoOnSense := Echo[0] > #0;
         _Status := ChVal;
         IF ATTENTION_CHAR IN Attr THEN _Status := _Status OR ATTENTION;
         IF BS_CHAR IN Attr THEN _Status := _Status OR BACKSPACE;
         IF CAN_CHAR IN Attr THEN _Status := _Status OR CANCEL;
         IF TERMINATING IN Attr THEN
         BEGIN
            _Status := _Status OR TERMINATE;
            _InpEnabled := FALSE;
         END;
      END;
   END;
END; (* GenericConsDevice.HandleInputConversion *)


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
   _PrintFlag := FALSE;
END; (* ConsDevice.Init *)

FUNCTION GetLptStatus(LPTNo : Word) : WORD;
  Inline(
    $5A/                   {  pop   dx}
    $B4/$02/               {  mov   ah,2}
    $CD/$17/               {  int   $17}     
    $86/$C4/               {  xchg  ah,al}
    $30/$E4);              {  xor   ah,ah} 


FUNCTION LptReady(ErrorCode : Word) : BOOLEAN;
  {-Printer ready test, verifies SELECTTED, not PAPER OUT, not IO ERROR,
    not BUSY }
Inline(
  $58/                   {  pop     ax}
  $34/$90/               {  xor     al,$90 ; invert SELECTED, NOT BUSY}
  $A8/$B8/               {  test    al,$B8}
  $75/$04/               {  jnz     PrnError}
  $B0/$01/               {  mov     al,1}
  $EB/$02/               {  jmp     short ExitPoint}
                         {PrnError:}
  $30/$C0);              {  xor     al,al}
                         {ExitPoint:}

FUNCTION Int17Out(Ch : Char; LPTNo : Word) : BYTE;
{ send a character to LPTNo via ROM BIOS int 17h func 0h }
Inline(
  $5A/                   {  pop  dx        ; get printer number}
  $58/                   {  pop  ax        ; get character}
  $30/$E4/               {  xor  ah,ah     ; set AH for func 0}
  $CD/$17/               {  int  $17       ; printer bios function call}
  $86/$E0);              {  xchg al,ah     ; put byte result in AL}



(**********************************************************************)
(* Func. Name     : ConsDevice.Disconnected
(* Function       : 
(**********************************************************************)
FUNCTION ConsDevice.Disconnected: BOOLEAN;

BEGIN
   Disconnected := FALSE;  (* Local console cannot be disconnected *)
END; (* ConsDevice.Disconnected *)


(**********************************************************************)
(* Proc. Name     : ConsDevice.WriteChar
(* Function       : Writes a character to screen. (Can be overridden)
(**********************************************************************)
PROCEDURE ConsDevice.WriteChar (C: CHAR);

BEGIN
   Scrn.OutChar(C);
   IF _PrintFlag AND (C<>#127) THEN
   BEGIN
      WHILE NOT LptReady(GetLptStatus(0)) DO;
      Int17Out(C,0);
   END;
END; (* ConsDevice.WriteChar *)

(**********************************************************************)
(* Proc. Name     : ConsDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE ConsDevice.Wr (Modif: BYTE);

BEGIN
   IF _InpBusy THEN Timer.CancelTimeout;
   _InpEnabled := FALSE;
   _InpBusy := FALSE;
   InterruptsOn;

   IF Modif = WRITE_PROMPT
      THEN _Status := Ord(_Prompt)
      ELSE _Status := (State8000.SrvcParam.Wreg SHR 8) AND $7F;
   IF _Status<>0 THEN WriteChar(Chr(_Status));
   WITH State8000 DO
   BEGIN
      MakeIoInt;
      Ex22 := 0;
      Ex23 := 0;
   END;
END; (* ConsDevice.Wr *)

(**********************************************************************)
(* Func. Name     : ConsDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION ConsDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'CONSOLE';
END; (* ConsDevice.DeviceID *)



(**********************************************************************)
(* Func. Name     : ConsDevice.InForeground
(* Function       : 
(**********************************************************************)
FUNCTION ConsDevice.InForeground: BOOLEAN;

BEGIN
   InForeground := Scrn.OnPhysScreen;
END; (* ConsDevice.InForeground *)

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

   IF BYTE(Key) = 0
      THEN _Status := CompKeyTable[Key SHR 8] ELSE
   BEGIN
      _Status := Ord(Pc2Rc[BYTE(Key)]);
      IF (BYTE(Key) > 127) AND (_Status = 32) THEN
         _Status := CompKeyTable[Key SHR 8];  (* Magic! *)
   END;

   IF _Status = 0 THEN  _Status := BLIND_CHAR;

   IF _Status = 127 THEN _Status := 0;
   _InKey := _Status;  (* Save for echo *)
   HandleInputConversion;

   MakeIoInt;

END; (* ConsDevice.KeyAvail *)


(**********************************************************************)
(* Proc. Name     : ConsDevice.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE ConsDevice.TimeoutAction;

BEGIN
   PushF;
   InterruptsOff;
   IF _InpBusy THEN
   BEGIN
      _InpBusy := FALSE;
      _InpEnabled := FALSE;
      _Status := TIMEOUT;
      MakeIoInt;
   END;
   PopF;
END; (* ConsDevice.TimeoutAction *)


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
      IF ((Key AND $FF) = 27) AND NOT _InpBusy THEN
      BEGIN
         Flush;
         MakeOprInt;
      END ELSE

{$IFDEF ALTPHARDCPY}
      IF Key = PRINT_HOTKEY THEN _PrintFlag := NOT _PrintFlag ELSE
{$ENDIF}
      BEGIN
         IF _InpBusy AND IsEmpty
            THEN KeyAvail(Key)
            ELSE InsKey(Key);
         _InpBusy := FALSE;
      END;
      EatKeystroke;
      Eaten := TRUE;
   END;
END; (* ConsDevice.IntrAction *)


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

(**********************************************************************)
(* Proc. Name     : ComDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR ComDevice.Init (DevNo: WORD;
                            IoBase: WORD;
                            IRQ,IoInt,OprInt: BYTE;
                            ConnectLine,ReadyLine: BYTE);

(* IRQ: If std. COM port = Interrupt request no. (0-7).
        If multiport device: (Ord(MultiportID)+1) SHL 4 + (portno-1);
*)


VAR
   Dummy: BYTE;
   Multiport: BOOLEAN;

BEGIN
   INHERITED Init(DevNo,IoInt,OprInt);

   Multiport      := IRQ>15;

   _IoBase        := IoBase;
   _IRQ           := IRQ;
   _ISRMask       := 1 SHL (IRQ AND $F);
   _InService     := FALSE;
   _TxActive      := FALSE;
   _ConnectLine   := ConnectLine;
   _ReadyLine     := ReadyLine;

   TxQueue.Init;

   IF NOT Multiport THEN
   BEGIN
      _IntHandle     := AllocateIntHandle(TRUE);
      ComIntrHndlr.InsHook(Self);
      InitV(IRQ+8,_IntHandle,@ComInterrupt);
   END;

   (* HW Init: *)
   InterruptsOff;
   Port[_IoBase+UARTlcr] := Port[_IoBase+UARTlcr] AND $7F;  (* Reset Div.Access Latch *)
   Dummy := Port[_IoBase+UARTrbr];  (* read any pending char *)
   _LSRMirror := Port[_IoBase+UARTlsr];  (* read LSR to clear error *)
   _MSRMirror := Port[_IoBase+UARTmsr];

   IF (_ConnectLine AND _MSRMirror) <> _ConnectLine THEN _IERMirror := 8 ELSE
   IF (_ConnectLine OR _ReadyLine) <> 0
      THEN _IERMirror := 8+1  (* MSR + RX *)
      ELSE _IERMirror := 1;   (* RX *)
   Port[_IoBase+UARTier] := _IERMirror;

   _TxHold := (_MSRMirror AND _ReadyLine) <> _ReadyLine;

   Port[_IoBase+UARTmcr] := Port[_IoBase+UARTmcr] OR $B; (* DTR,RTS,OUT2 ON *)

   IF NOT Multiport THEN
      Port[I8259_1Base+1] := Port[I8259_1Base+1] AND NOT _ISRMask;  (* Enable on 8259 *)

   InterruptsOn;

END; (* ComDevice.Init *)

(**********************************************************************)
(* Proc. Name     : ComDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR ComDevice.Done;

VAR Multiport: BOOLEAN;

BEGIN
   Multiport := _IRQ>15;

   IF NOT Multiport THEN
      Port[I8259_1Base+1] := Port[I8259_1Base+1] OR _ISRMask;  (* Disable on 8259 *)
   Port[_IoBase+UARTier] := 0; (* Disable interrupts on 8250 *)
   Port[_IoBase+UARTmcr] := Port[_IoBase+UARTmcr] AND NOT $B; (* DTR,RTS,OUT2 OFF *)
   INHERITED Done;
END; (* ComDevice.Done *)


(**********************************************************************)
(* Func. Name     : ComDevice.Disconnected
(* Function       : 
(**********************************************************************)
FUNCTION ComDevice.Disconnected: BOOLEAN;

BEGIN
   Disconnected := (_MSRMirror AND _ConnectLine) <> _ConnectLine;
END; (* ComDevice.Disconnected *)

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
      IF _TxActive OR _TxHold THEN InsKey(Ord(C)) ELSE
      BEGIN  (* Start UART Tx *)
         Port[_IoBase+UARTthr] := Ord(C);
         _IERMirror := _IERMirror OR 2; (* Enable Tx interrupts on 8250 *)
         Port[_IoBase+UARTier] := _IERMirror; 
         _TxActive := TRUE;
      END;
   END;
   PopF;
END; (* ComDevice.WriteChar *)

(**********************************************************************)
(* Proc. Name     : ComDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE ComDevice.Wr (Modif: BYTE);

BEGIN
   IF _InpBusy OR _WrIntrPending THEN Timer.CancelTimeout;
   _InpEnabled := FALSE;
   _InpBusy := FALSE;

   WITH State8000 DO
   BEGIN
      Ex22 := Ord(Disconnected);
      Ex23 := Ord(TxQueue.IsFull);
      IF BOOLEAN(Ex22 OR Ex23) THEN Exit;
   END;

   PushF;
   InterruptsOff;

   IF Modif = WRITE_PROMPT
      THEN _Status := Ord(_Prompt)
      ELSE _Status := (State8000.SrvcParam.Wreg SHR 8) AND $7F;

   IF _Status=0 THEN MakeIoInt ELSE
   BEGIN
      WriteChar(Chr(_Status));

      WITH State8000 DO
      BEGIN
         IF NOT UseComTxBuffer THEN _WrIntrPending := TRUE ELSE
         IF TxQueue.IsFull
            THEN _WrIntrPending := TRUE
            ELSE MakeIoInt;
         Ex22 := 0;
         Ex23 := 0;
      END;

      WITH Timer DO
         IF _WrIntrPending THEN SetTimeout(_TimeoutVal,SEC);
   END;
   PopF;
END; (* ComDevice.Wr *)

(**********************************************************************)
(* Proc. Name     : ComDevice.DisconnectRequest
(* Function       : 
(**********************************************************************)
PROCEDURE ComDevice.DisconnectRequest;

BEGIN
   Port[_IoBase+UARTmcr] := Port[_IoBase+UARTmcr] AND NOT 1; (* DTR OFF *)
   DisconectTimer.SetTimeout(1,SEC);
END; (* ComDevice.DisconnectRequest *)

(**********************************************************************)
(* Func. Name     : ComDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION ComDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'TERMINAL';
END; (* ComDevice.DeviceID *)

(**********************************************************************)
(* Proc. Name     : ComDevice.KeyAvail
(* Function       : Called when a keystroke is available for RC8000
(**********************************************************************)
PROCEDURE ComDevice.KeyAvail (Key: WORD);

BEGIN
   Timer.CancelTimeout;
   _Status := Key AND $7F;
   IF _Status = 0 THEN  _Status := BLIND_CHAR;
   IF _Status = 127 THEN _Status := 0;
   _InKey := _Status;  (* Save for echo *)
   HandleInputConversion;

   MakeIoInt;
END; (* ComDevice.KeyAvail *)


(**********************************************************************)
(* Proc. Name     : ComDevice.TimeoutAction
(* Function       : 
(**********************************************************************)
PROCEDURE ComDevice.TimeoutAction;

BEGIN
   PushF;
   InterruptsOff;
   IF _InpBusy OR _WrIntrPending THEN
   BEGIN
      _InpBusy := FALSE;
      _InpEnabled := FALSE;
      IF _WrIntrPending THEN TxQueue.RemoveLast;
      _WrIntrPending := FALSE;
      _Status := TIMEOUT; (* Status = timeout *)
      MakeIoInt;
   END;
   PopF;
END; (* ComDevice.TimeoutAction *)


(**********************************************************************)
(* Proc. Name     : ComDevice.DisconnectTimeoutAction
(* Function       : Set DTR high, 1 sec. has passed
(**********************************************************************)
PROCEDURE ComDevice.DisconnectTimeoutAction;

BEGIN
   Port[_IoBase+UARTmcr] := Port[_IoBase+UARTmcr] OR 1; (* DTR ON *)
END; (* ComDevice.DisconnectTimeoutAction *)


(**********************************************************************)
(* Proc. Name     : ComDevice.IntrAction
(* Function       : 
(* Note           : Must run in disable mode.
(**********************************************************************)
PROCEDURE ComDevice.IntrAction (VAR Param);

VAR
   Key,
   IntrIdent: BYTE;

BEGIN
   IntrIdent := Port[_IoBase+UARTiir] AND $0F;

   IF IntrIdent = 4 THEN
   WITH State8000, KeybQ DO
   BEGIN  (* Rx char avail *)
      _LSRMirror := Port[_IoBase+UARTlsr];
      Key := Port[_IoBase+UARTrbr] AND $7F;
      IF (_LSRMirror AND 12) <> 0
         THEN Key := 26;  (* Parity or framing error *)

      IF (Key = 27) AND NOT _InpBusy THEN
      BEGIN
         Flush;
         TxQueue.Flush;
         MakeOprInt;
      END ELSE

      BEGIN
         IF _InpBusy AND IsEmpty
            THEN KeyAvail(Key)
            ELSE InsKey(Key);
         _InpBusy := FALSE;
      END;
   END ELSE

   IF IntrIdent = 2 THEN
   BEGIN
      WITH State8000, TxQueue DO
      IF (Port[_IoBase+UARTlsr] AND $20) <> 0 THEN  (* 8250 bug *)
      BEGIN  (* Txhr empty *)
         IF IsEmpty OR _TxHold THEN
         BEGIN  (* Stop Tx *)
            _IERMirror := _IERMirror AND NOT 2; (* Disable Tx interrupts on 8250 *)
            _TxActive := FALSE;
         END ELSE
         BEGIN
            Port[_IoBase+UARTthr] := GetKey AND $7F;
            _TxActive := TRUE;
         END;

         IF _WrIntrPending AND (NOT UseComTxBuffer OR IsEmpty) THEN
         BEGIN
            Timer.CancelTimeout;
            MakeIoInt;
            _WrIntrPending := FALSE;
         END;
      END;
   END ELSE
   
   IF IntrIdent = 0 THEN
   BEGIN  (* MSR changed *)
      _MSRMirror := Port[_IOBase+UARTmsr];

      IF ((_ConnectLine SHR 4) AND _MSRMirror) <> 0 THEN
      BEGIN  (* Connect status changed *)

         IF (_ConnectLine AND _MSRMirror) = 0 THEN
         BEGIN  (* Now disconnected *)
            WITH State8000 DO
            IF _WrIntrPending OR _InpBusy      
               THEN MakeIoInt;

            _WrIntrPending := FALSE;
            _InpBusy := FALSE;
            _InpEnabled := FALSE;
            TxQueue.Flush;
            KeybQ.Flush;
            _IERMirror := 8;  (* Only MSR *)
         END ELSE

         BEGIN  (* Now connected *)
            Key := Port[_IoBase+UARTrbr];  (* Dummy read *)
            _LSRMirror := Port[_IoBase+UARTlsr]; (* Clear error *)
            _IERMirror := 8+2+1;  (* MSR+RX+TX *)
         END;
      END;

      IF ((_ReadyLine SHR 4) AND _MSRMirror) <> 0 THEN
      BEGIN  (* Ready/Busy handshake input changed *)
         IF (_ReadyLine AND _MSRMirror) = 0 THEN
         BEGIN  (* Now busy *)
            _TxHold := TRUE;
         END ELSE
         BEGIN  (* Now ready *)
            _TxHold := FALSE;
            IF (NOT TXQueue.IsEmpty) AND
               ((_MSRMirror AND _ConnectLine) = _ConnectLine) THEN
               _IERMirror := _IERMirror OR 2;  (* Enable TX *)
         END;
      END;
   END;

   (* Trig interrupt: *)
   Port[_IoBase+UARTier] := 0;
   Port[_IoBase+UARTier] := _IERMirror;
         
END; (* ComDevice.IntrAction *)

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


(**********************************************************************)
(* Proc. Name     : Multiport4Interrupt
(* Function       : Common Multiport handler
(**********************************************************************)
PROCEDURE Multiport4Interrupt (HandlerP: Multiport4HandlerPtr);

VAR
   ISR: BYTE;

BEGIN
   WITH HandlerP^ DO
   IF _IRQ > 7 THEN
   BEGIN  (* On 2nd interrupt controller *)
      Port[I8259_2Base] := $0B;  (* Read ISR *)
      ISR := Port[I8259_2Base];

      IF ((ISR AND _ISRMask) <> 0) THEN DoHooks(ISR);

      InterruptsOn;
      SendEOI2;
      SendEOI;
   END ELSE

   BEGIN (* On primary interrupt controller *)
      Port[I8259_1Base] := $0B;  (* Read ISR *)
      ISR := Port[I8259_1Base];

      IF ((ISR AND _ISRMask) <> 0) THEN DoHooks(ISR);

      InterruptsOn;
      SendEOI;
   END;
END; (* Multiport4Interrupt *)


(**********************************************************************)
(* Proc. Name     : Multiport4XXInterrupt
(* Function       : Handlers for each possible multiport card
(**********************************************************************)

PROCEDURE Multiport4HInterrupt(BP: WORD);
INTERRUPT;

BEGIN
   Multiport4Interrupt(MultiPort4Handlers[HIGH_ADDR]);
END;

PROCEDURE Multiport4LInterrupt(BP: WORD);
INTERRUPT;

BEGIN
   Multiport4Interrupt(MultiPort4Handlers[LOW_ADDR]);
END;

PROCEDURE Multiport4HXInterrupt(BP: WORD);
INTERRUPT;

BEGIN
   Multiport4Interrupt(MultiPort4Handlers[HIGHX_ADDR]);
END;

PROCEDURE Multiport4LXInterrupt(BP: WORD);
INTERRUPT;

BEGIN
   Multiport4Interrupt(MultiPort4Handlers[LOWX_ADDR]);
END;


(**********************************************************************)
(* Proc. Name     : Multiport4Handler.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR Multiport4Handler.Init (Id: Multiport4ID; IRQ: BYTE);

VAR
   I: WORD;
   Vect: BYTE;

BEGIN
   INHERITED Init;

   _Id            := Id;
   _IntHandle     := AllocateIntHandle(TRUE);
   _IRQ           := IRQ;
   _ISRMask       := 1 SHL (IRQ AND $7);

   IF IRQ > 7 THEN
   BEGIN
      Vect := IRQ-8+$70;
      Port[I8259_2Base+1] := Port[I8259_2Base+1] OR _ISRMask; (* Disable on 8259 *)
   END ELSE

   BEGIN
      Vect := IRQ+8;
      Port[I8259_1Base+1] := Port[I8259_1Base+1] OR _ISRMask; (* Disable on 8259 *)
   END;

   CASE Id OF
      HIGH_ADDR : InitV(Vect,_IntHandle,@Multiport4HInterrupt);
      LOW_ADDR  : InitV(Vect,_IntHandle,@Multiport4LInterrupt);
      HIGHX_ADDR: InitV(Vect,_IntHandle,@Multiport4HXInterrupt);
      LOWX_ADDR : InitV(Vect,_IntHandle,@Multiport4LXInterrupt);
   END;

   FOR I := 1 TO 4 DO
   BEGIN
      _PortUsed[I] := FALSE;
      Port[Multiport4AddrMap[Id,I]+UARTier] := 0;  (* Disable all *)
   END;

   (* Seems like disabling "global interrupt" on the multicard draws the
      interrupt line *active*... generate a trigger edge by enabling and
      disabling while all IER's are =0.
      The "ISA" version of Multiport4 does not implement disabling of
      "global interrupt", so this problem will not arise, and the following 
      has no effect.
   *)
   Port[Multiport4VectorMap[Id]] := $80;   (* Enable global int. *)
   Port[Multiport4VectorMap[Id]] := $00;   (* Disable global int. *)

   MultiPort4Handlers[Id] := @Self;

END; (* Multiport4Handler.Init *)


(**********************************************************************)
(* Proc. Name     : Multiport4Handler.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR Multiport4Handler.Done;

VAR
   I: WORD;

BEGIN
   IF _IRQ > 7
      THEN Port[I8259_2Base+1] := Port[I8259_2Base+1] OR _ISRMask   (* Disable on 8259 *)
      ELSE Port[I8259_1Base+1] := Port[I8259_1Base+1] OR _ISRMask;  (* Disable on 8259 *)
   Port[Multiport4VectorMap[_Id]] := 0;   (* Disable global int. *)
   FOR I := 1 TO 4 DO
   BEGIN
      _PortUsed[I] := FALSE;
      Port[Multiport4AddrMap[_Id,I]+UARTier] := 0;  (* Disable all *)
   END;
END; (* Multiport4Handler.Done *)


(**********************************************************************)
(* Proc. Name     : Multiport4Handler.InsHook
(* Function       : 
(**********************************************************************)
PROCEDURE Multiport4Handler.InsHook (VAR Hook: ComDevice);

BEGIN
   INHERITED InsHook(Hook);
   _PortUsed[(Hook._IRQ AND $F)+1] := TRUE;
END; (* Multiport4Handler.InsHook *)


(**********************************************************************)
(* Func. Name     : Multiport4Handler.PortUsed
(* Function       : 
(**********************************************************************)
FUNCTION Multiport4Handler.PortUsed (Port: BYTE): BOOLEAN;

BEGIN
   PortUsed := _PortUsed[Port];
END; (* Multiport4Handler.PortUsed *)


(**********************************************************************)
(* Proc. Name     : Multiport4Handler.DoHooks
(* Function       : 
(**********************************************************************)
PROCEDURE Multiport4Handler.DoHooks (VAR Param);

VAR
   P: DoubleNodePtr;
   Vector: BYTE;

BEGIN
   REPEAT
      Vector := Port[Multiport4VectorMap[_Id]];
      P := HookList.Head;
      WHILE P <> NIL DO
      WITH ComDevicePtr(P)^ DO
      BEGIN
         IF (((NOT Vector) AND _ISRMask) <> 0) AND NOT _InService THEN
         BEGIN
            _InService := TRUE;
            IntrAction(Param);
            _InService := FALSE;
         END;
         P := HookList.Next(P);
      END;
   UNTIL (Vector AND $F) = $F;
END; (* Multiport4Handler.DoHooks *)


(**********************************************************************)
(* Proc. Name     : ConsPostInit
(* Function       : Enable global & 8259 interrupts for multiport cards
(**********************************************************************)
PROCEDURE ConsPostInit;

VAR Id: BYTE;

BEGIN
   FOR Id := 0 TO 3 DO
   IF (MultiPort4Handlers[Multiport4ID(Id)] <> NIL) THEN
   WITH MultiPort4Handlers[Multiport4ID(Id)]^ DO
   BEGIN
      IF _IRQ > 7
         THEN Port[I8259_2Base+1] := Port[I8259_2Base+1] AND NOT _ISRMask   (* Enable on 8259 *)
         ELSE Port[I8259_1Base+1] := Port[I8259_1Base+1] AND NOT _ISRMask;  (* Enable on 8259 *)
      Port[Multiport4VectorMap[_Id]] := $80;   (* Enable global int. *)
   END;
END; (* ConsPostInit *)


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
   IF MultiPort4Handlers[HIGH_ADDR] <> NIL THEN MultiPort4Handlers[HIGH_ADDR]^.Done;
   IF MultiPort4Handlers[LOW_ADDR] <> NIL THEN MultiPort4Handlers[LOW_ADDR]^.Done;
   IF MultiPort4Handlers[HIGHX_ADDR] <> NIL THEN MultiPort4Handlers[HIGHX_ADDR]^.Done;
   IF MultiPort4Handlers[LOWX_ADDR] <> NIL THEN MultiPort4Handlers[LOWX_ADDR]^.Done;
END; (* UnitExit *)




(**********************************************************************)
(* Proc. Name     : UnitEntry
(* Function       : Entry procedure for unit.
(**********************************************************************)
PROCEDURE UnitEntry;

BEGIN
   Exitsave := Exitproc;
   Exitproc := @UnitExit;

   ComIntrHndlr.Init;
   MultiPort4Handlers[HIGH_ADDR]  := NIL;
   MultiPort4Handlers[LOW_ADDR]   := NIL;
   MultiPort4Handlers[HIGHX_ADDR] := NIL;
   MultiPort4Handlers[LOWX_ADDR]  := NIL;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT CONS *)

