(**********************************************************************)
(* Unit name      : WIN.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-12-08 21:24   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Window handling for RC8000 simulator  92-12-08 21:25 HJ 
(*
(**********************************************************************)

{$F+}

UNIT WIN;


INTERFACE

USES
   Opcrt,
   OpColor,
   OpRoot,
   OpFrame,
   OpCmd,
   OpString,
   OpWindow,
   OpSedit;


{$I COLOR.DEF}


CONST
  AutoAutoload: BOOLEAN = FALSE; 
  AutoStart   : BOOLEAN = FALSE; 

  Frame1    : FrameArray = '⁄¿øŸƒƒ≥≥';  (* Window Frame def. *)
  Frame2    : FrameArray = '…»ªºÕÕ∫∫';  (* Window Frame def. *)

  ccExit    =  ccUser0;
  ccFormat  =  ccUser1;
  ccZoom    =  ccUser2;
  ccRun     =  ccUser3;
  ccStep    =  ccUser4;
  ccTrace   =  ccUser5;
  ccSetBrp  =  ccUser6;
  ccSetWBrp =  ccUser7;
  ccEnInt   =  ccUser8;
  ccDisInt  =  ccUser9;
  ccJmpIC   =  ccUser10;
  ccSetIC   =  ccUser11;
  ccStart   =  ccUser12;
  ccAutoload=  ccUser13;
  ccConfig  =  ccUser14;
  ccReset   =  ccUser15;


  {Keystroke to command mapping}
  WinKeyMax       = 146;
  WinKeySet       : ARRAY[0..WinKeyMax] OF BYTE = (

  {length keys         command type      key sequence}

  3,      $00, $48,    ccUp,             {Up}
  3,      $00, $50,    ccDown,           {Down}
  3,      $00, $49,    ccPageUp,         {PgUp}
  3,      $00, $51,    ccPageDn,         {PgDn}
  3,      $00, $4B,    ccLeft,           {Left}
  3,      $00, $4D,    ccRight,          {Right}
  3,      $00, $47,    ccHome,           {Home}
  3,      $00, $4F,    ccEnd,            {End}
  2,      $1B,         ccQuit,           {Esc}
  2,      $0D,         ccSelect,         {Enter}
  2,      $09,         ccTab,            {Tab}
  3,      $00, $0F,    ccBackTab,        {BackTab}
  2,      $15,         ccScrollUp,       {Ctrl-U}
  2,      $04,         ccScrollDn,       {Ctrl-D}

  3,      $00, $52,    ccIns,            {Ins}
  3,      $00, $53,    ccDel,            {Del}

  3,      $00, $3C,    ccSaveFile,       {F2}
  3,      $00, $3D,    ccNewFile,        {F3}
  3,      $00, $22,    ccJmpLine,        {Alt-G}
  3,      $00, $2D,    ccExit,           {Alt-X}
  3,      $00, $21,    ccFormat,         {Alt-F}
  3,      $00, $20,    ccDisInt,         {Alt-D}
  3,      $00, $12,    ccEnInt,          {Alt-E}
  3,      $00, $3F,    ccZoom,           {F5}
  3,      $00, $43,    ccRun,            {F9}
  3,      $00, $42,    ccStep,           {F8}
  3,      $00, $41,    ccTrace,          {F7}
  3,      $00, $65,    ccSetBrp,         {Ctrl-F8}
  3,      $00, $6F,    ccSetWBrp,        {Alt-F8}
  2,      $07,         ccJmpIC,          {Ctrl-I}
  3,      $00, $17,    ccSetIC,          {Alt-I}
  3,      $00, $13,    ccReset,          {Alt-R}
  3,      $00, $1F,    ccStart,          {Alt-S}
  3,      $00, $1E,    ccAutoload,       {Alt-A}
  3,      $00, $2E,    ccConfig,         {Alt-C}

  {$IFDEF UseMouse}
  3,      $00, $EF,    ccMouseSel,       {Click left}
  3,      $00, $EE,    ccQuit,           {Click right}
  3,      $00, $ED,    ccHelp,           {Click both}
  {$ELSE}
                             0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0,
  {$ENDIF}

  0                                      {End of table}
  );


TYPE
   EDIT_MODE_TYPE = (BLANK_INIT,NUM_INIT,SLANG_INIT);

   WinSysPtr=  ^WinSys;
   WinSys   =  OBJECT(CircularList)
                  _Command: WORD;
                  CurrentWin: DoubleNodePtr;

                  CONSTRUCTOR Init;
                  PROCEDURE Process;
                  FUNCTION GetLastCommand: WORD;
                  PROCEDURE DrawAll;
                  PROCEDURE Start8000;
                  PROCEDURE ResetButton;
                  PROCEDURE StartButton;
                  PROCEDURE AutoloadButton;
               END;

   Win8000Ptr=  ^Win8000;
   Win8000  =  OBJECT(DoubleListNode)
                  _Command: WORD;     (* Set by Edit *)
                  WSPtr: WinSysPtr;
                  W: CommandWindow;
                  Width,Height: BYTE;

                  CONSTRUCTOR Init(X1,Y1,X2,Y2: BYTE; WSRef: WinSysPtr);
                  FUNCTION IsCurrent: BOOLEAN;
                  PROCEDURE Process; VIRTUAL;
                  PROCEDURE Draw;    VIRTUAL;
                  PROCEDURE Edit(Mode: EDIT_MODE_TYPE); VIRTUAL;
                  PROCEDURE ZoomToggle; VIRTUAL;
                  PROCEDURE AdjustToIC;  VIRTUAL;
                  DESTRUCTOR Done;  VIRTUAL;
               END;

   CoreWin  =  OBJECT(Win8000)
                  RefAddr: LONGINT;    (* Core address at 1st line *)
                  BinDisp: BOOLEAN;
                  CONSTRUCTOR Init(X1,Y1,X2,Y2: BYTE; WSRef: WinSysPtr);
                  PROCEDURE AdjustRefAddr;
                  FUNCTION  GetJumpAddr: LONGINT;
                  PROCEDURE Process; VIRTUAL;
                  PROCEDURE Draw;    VIRTUAL;
                  PROCEDURE Edit(Mode: EDIT_MODE_TYPE); VIRTUAL;
                  PROCEDURE ZoomToggle; VIRTUAL;
                  PROCEDURE AdjustToIC;  VIRTUAL;
               END;
 
   WRegsWin =  OBJECT(Win8000)
                  PROCEDURE Process; VIRTUAL;
                  PROCEDURE Draw;    VIRTUAL;
                  PROCEDURE Edit(Mode: EDIT_MODE_TYPE); VIRTUAL;
               END;

   IRegsWin =  OBJECT(Win8000)
                  PROCEDURE Process; VIRTUAL;
                  PROCEDURE Draw;    VIRTUAL;
                  PROCEDURE Edit(Mode: EDIT_MODE_TYPE); VIRTUAL;
               END;



VAR
   WS       :  WinSys;
   CoreW1,
   CoreW2   :  CoreWin;
   Wregs    :  WRegsWin;
   Iregs    :  IRegsWin;

PROCEDURE InitWindows;

(*#PAGE*)
IMPLEMENTATION

USES
   PopUp,
   SlangP,
   Intf,
   Util,
   Vcpi,
   Scrn,
   Fil,
   Config;


CONST
   CurrCoreEditMode: EDIT_MODE_TYPE = SLANG_INIT;

VAR 
   WinCommands: CommandProcessor;
   CtrlScreen:  Screen;


(**********************************************************************)
(* Func. Name     : ChrFunc
(* Function       : Conv. byte to ISO-char
(**********************************************************************)
FUNCTION ChrFunc(B: BYTE): CHAR;
BEGIN
   CASE B OF
      0..31,
      127..255     :   ChrFunc := ' ';
      Ord('{')     :   ChrFunc := 'ë';
      Ord('|')     :   ChrFunc := 'õ';
      Ord('}')     :   ChrFunc := 'Ü';
      Ord('[')     :   ChrFunc := 'í';
      Ord('\')     :   ChrFunc := 'ù';
      Ord(']')     :   ChrFunc := 'è';
      ELSE             ChrFunc := Chr(B);
   END;
END; (* ChrFunc *)

(**********************************************************************)
(* Proc. Name     : WinSys.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR WinSys.Init;

BEGIN
   INHERITED Init;
   CurrentWin := NIL;
END; (* WinSys.Init *)


(**********************************************************************)
(* Proc. Name     : WinSys.Process
(* Function       : Run the window system, handle walk-around betw. windows
(**********************************************************************)
PROCEDURE WinSys.Process;

BEGIN
   IF CurrentWin = NIL THEN CurrentWin := DoubleListPtr(@Self)^.Head;
   IF AutoAutoload THEN AutoloadButton ELSE
   IF AutoStart THEN StartButton;

   IF State8000.Halt THEN Exit;

   REPEAT
      WITH Win8000Ptr(CurrentWin)^ DO
      BEGIN
         Process;
         Self._Command := W.GetLastCommand;
   
         CASE Self._Command OF
            ccTab       : IF NOT W.IsZoomed THEN
                              CurrentWin := DoubleListPtr(@Self)^.Next(CurrentWin);

            ccBackTab   : IF NOT W.IsZoomed THEN
                              CurrentWin := DoubleListPtr(@Self)^.Prev(CurrentWin);

            ccZoom      : ZoomToggle;

            ccRun       : Start8000;

            ccStep      : BEGIN
                             State8000.Step := TRUE;
                             Start8000;
                          END;

            ccTrace     : BEGIN
                             State8000.Trace := TRUE;
                             Start8000;
                          END;

            ccEnInt     : State8000.IntEn := TRUE;
            ccDisInt    : State8000.IntEn := FALSE;


            ccNewFile   : LoadFile;
            ccSaveFile  : SaveFile;

            ccReset     : ResetButton;
            ccStart     : StartButton;
            ccAutoload  : AutoloadButton;

            ccConfig    : ConfigMenu;

            ELSE ;
         END;
      END;
   UNTIL (_Command IN [ccExit]) OR (State8000.Halt);

END; (* WinSys.Process *)

(**********************************************************************)
(* Func. Name     : WinSys.GetLastCommand
(* Function       : Returns the command that caused Process to exit
(**********************************************************************)
FUNCTION WinSys.GetLastCommand: WORD;

BEGIN
   GetLastCommand := _Command;
END; (* WinSys.GetLastCommand *)

(**********************************************************************)
(* Proc. Name     : WinSys.DrawAll
(* Function       : Draws all windows in system
(**********************************************************************)
PROCEDURE WinSys.DrawAll;

VAR P: DoubleNodePtr;
    VS: VirtScreen;

BEGIN
   VS.Alloc(ScreenHeight,ScreenWidth);
   VS.CopyFromScreen(1,1);
   VS.Activate;

   P := DoubleList.Head;
   IF NOT Win8000Ptr(CurrentWin)^.W.IsZoomed THEN  (* save time *)
   WHILE P <> NIL DO
   BEGIN
      IF P <> CurrentWin THEN Win8000Ptr(P)^.Draw;
      P := DoubleList.Next(P);
   END;

   Win8000Ptr(CurrentWin)^.Draw;  (* end w. current to avoid flicker *)
   VS.Deactivate;
   VS.CopyToScreen(1,1);
   VS.Done;

END; (* WinSys.DrawAll *)

(**********************************************************************)
(* Proc. Name     : BreakSound
(* Function       : Makes a sound...
(**********************************************************************)
PROCEDURE BreakSound;

VAR I: WORD;

BEGIN
   FOR I := 1 TO 30 DO
   BEGIN
      Sound(1320-Round(Sqrt(49000.0*I)));
      Delay(4);
   END;
   NoSound;
END; (* BreakSound *)


(**********************************************************************)
(* Proc. Name     : WinSys.Start8000
(* Function       : Run/Step/Trace handling
(**********************************************************************)
PROCEDURE WinSys.Start8000;

VAR
   SwopCrt: BOOLEAN;

BEGIN
   {PopInf('CPU Running');}

   WITH State8000 DO
   BEGIN
      SwopCrt := NOT Trace;
      IF SwopCrt THEN ScreenTab[CurRCScreenNo]^.ToPhysScreen;
      Stop := FALSE;
      Run8000;
      IF SwopCrt THEN ScreenTab[MaxScreen]^.ToPhysScreen;
      PopUpDone;
      IF NOT (Trace OR Stop) THEN BreakSound;
      Trace := FALSE;
      Step  := FALSE;
      Stop  := FALSE;
   END;
   Win8000Ptr(CurrentWin)^.AdjustToIC;
END; (* WinSys.Start8000 *)

(**********************************************************************)
(* Proc. Name     : WinSys.ResetButton
(* Function       : 
(**********************************************************************)
PROCEDURE WinSys.ResetButton;

BEGIN
   Reset8000;
END; (* WinSys.ResetButton *)


(**********************************************************************)
(* Proc. Name     : WinSys.StartButton
(* Function       : 
(**********************************************************************)
PROCEDURE WinSys.StartButton;

VAR L: LONGINT;

BEGIN
   FromCore(14,1,@L);
   State8000.IC := (L SHR 9) AND $7FFFFF;
   Start8000;
END; (* WinSys.StartButton *)

(**********************************************************************)
(* Proc. Name     : WinSys.AutoloadButton
(* Function       : 
(**********************************************************************)
PROCEDURE WinSys.AutoloadButton;

VAR L: LONGINT;

BEGIN
   L := 0;
   ToCore(0,1,@L);
   WITH State8000 DO
   BEGIN
      IC := 0;
      Trace := TRUE;
      Stop := FALSE;
      Run8000;
      Trace := FALSE;
      IF Stop THEN
      BEGIN
         Stop := FALSE;
         EXIT;
      END;
      Stop := FALSE;
      IC := 0;
      Start8000;
   END;
END; (* WinSys.AutoloadButton *)

(**********************************************************************)
(* Proc. Name     : Win8000.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR Win8000.Init (X1,Y1,X2,Y2: BYTE; WSRef: WinSysPtr);

BEGIN
   WITH W DO
   BEGIN
      InitCustom(X1,Y1,X2,Y2,
               Colors,
               wBordered+wClear+wSaveContents+wAltFrame+wResizeable, {Window options}
               WinCommands,
               ucNone);

      wFrame.SetFrameType(Frame2);
      aFrame.SetFrameType(Frame1);
      SetCursor(CUHidden);
      wGotoXY(1,1);
   END;

   Width  := X2-X1+1;
   Height := Y2-Y1+1;

   DoubleListNode.Init;
   WSPtr := WSRef;
   IF WSRef <> NIL THEN
      WSRef^.Append(DoubleNodePtr(@Self));

END; (* Win8000.Init *)

(**********************************************************************)
(* Func. Name     : Win8000.IsCurrent
(* Function       : TRUE if this window is current in the WinSys it
(*                  belongs to (or if it belongs to no WinSys)
(**********************************************************************)
FUNCTION Win8000.IsCurrent: BOOLEAN;

BEGIN
   IF WSPtr = NIL THEN IsCurrent := TRUE ELSE
   IsCurrent := WSPtr^.CurrentWin = @Self;
END; (* Win8000.IsCurrent *)

(**********************************************************************)
(* Proc. Name     : Win8000.Process
(* Function       : 
(**********************************************************************)
PROCEDURE Win8000.Process;
BEGIN
   Abstract;
END; (* Win8000.Process *)


(**********************************************************************)
(* Proc. Name     : Win8000.Draw;
(* Function       : 
(**********************************************************************)
PROCEDURE Win8000.Draw;
BEGIN
   Abstract;
END; (* Win8000.Draw; *)



(**********************************************************************)
(* Proc. Name     : Win8000.Edit
(* Function       : 
(**********************************************************************)
PROCEDURE Win8000.Edit (Mode: EDIT_MODE_TYPE);

BEGIN
   Abstract;
END; (* Win8000.Edit *)

(**********************************************************************)
(* Proc. Name     : Win8000.ZoomToggle
(* Function       : Does nothing unless overwritten
(**********************************************************************)
PROCEDURE Win8000.ZoomToggle;
BEGIN
END; (* Win8000.ZoomToggle *)

(**********************************************************************)
(* Proc. Name     : Win8000.AdjustToIC
(* Function       : Does nothing unless overwritten
(**********************************************************************)
PROCEDURE Win8000.AdjustToIC;
BEGIN
END; (* Win8000.AdjustToIC *)


(**********************************************************************)
(* Proc. Name     : Win8000.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR Win8000.Done;

BEGIN
   W.Select;
   W.Done;
   DoubleListNode.Done;
END; (* Win8000.Done *)


(**********************************************************************)
(* Proc. Name     : CoreWin.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR CoreWin.Init (X1,Y1,X2,Y2: BYTE; WSRef: WinSysPtr);

BEGIN
   Win8000.Init (X1,Y1,X2,Y2,WSRef);
   RefAddr := 8;
   BinDisp := FALSE;
   AdjustToIC;
END; (* CoreWin.Init *)

(**********************************************************************)
(* Proc. Name     : CoreWin.AdjustRefAddr
(* Function       : Puts RefAddr within range
(**********************************************************************)
PROCEDURE CoreWin.AdjustRefAddr;

BEGIN
   IF RefAddr < 0 THEN RefAddr := 0 ELSE
   IF RefAddr+Height+Height > CoreSize
      THEN RefAddr := CoreSize-Height-Height;
END; (* CoreWin.AdjustRefAddr *)

(**********************************************************************)
(* Func. Name     : CoreWin.GetJumpAddr
(* Function       : Get response to Alt-G
(**********************************************************************)
FUNCTION CoreWin.GetJumpAddr: LONGINT;


CONST
   S: STRING[10] = '';

VAR
   E: SimpleLineEditor;
   Addr: LONGINT;
   Err:  BYTE;

BEGIN
   WITH E DO
   BEGIN
      Init(EntryColors);
      seOptionsOff(seHouseCursorAtEnd);
      seOptionsOn(seWindowRelative);
      ReadString('Goto: ',Height+1,1,10,10,S);
      IF SlangNumber(S,Addr,Err) THEN GetJumpAddr := Addr + (Addr AND 1) ELSE
      BEGIN
         GetJumpAddr := -1;
         RingBell;
      END;
      Done;
      W.wFrame.Draw;
   END;

END; (* CoreWin.GetJumpAddr *)



(**********************************************************************)
(* Proc. Name     : CoreWin.Process
(* Function       : 
(**********************************************************************)
PROCEDURE CoreWin.Process;

VAR
   X,Y: INTEGER;
   Addr: LONGINT;
   Exitos: BOOLEAN;

BEGIN
   WSPtr^.DrawAll;
   Exitos := FALSE;
   REPEAT
      W.wWhereXY(X,Y);
      W.Select;
      W.GetNextCommand;
      CASE W.GetLastCommand OF
         ccUp:       IF Y = 1
                        THEN IF RefAddr > 0 THEN Dec(RefAddr,2) ELSE
                        ELSE W.wGotoXY(X,Y-1);

         ccDown:     IF Y = Height
                        THEN IF (RefAddr+Height+Height) < CoreSize THEN Inc(RefAddr,2) ELSE
                        ELSE W.wGotoXY(X,Y+1);

         ccScrollUp: BEGIN
                        IF (RefAddr+Height+Height) < CoreSize THEN
                        BEGIN
                           Inc(RefAddr,2);
                           IF Y > 1 THEN Dec(Y);
                           W.wGotoXY(X,Y);
                        END;
                     END;

         ccScrollDn: BEGIN
                        IF RefAddr > 0 THEN
                        BEGIN
                           Dec(RefAddr,2);
                           IF Y < Height THEN Inc(Y);
                           W.wGotoXY(X,Y);
                        END;
                     END;

         ccPageUp:   IF Height+Height < RefAddr
                        THEN Dec(RefAddr,Height+Height)
                        ELSE RefAddr := 0;

         ccPageDn:   IF RefAddr+Height+Height < CoreSize-Height-Height
                        THEN Inc(RefAddr,Height+Height)
                        ELSE RefAddr := CoreSize-Height-Height;

         ccHome:     BEGIN
                        RefAddr := 0;
                        W.wGotoXY(X,1);
                     END;

         ccEnd:      BEGIN
                        RefAddr := CoreSize-Height-Height;
                        W.wGotoXY(X,Height);
                     END;

         ccSelect:   BEGIN
                        Edit(CurrCoreEditMode);
                        WSPtr^.DrawAll;
                     END;

         ccIns:      BEGIN
                        REPEAT
                           Edit(BLANK_INIT);
                           IF _Command <> ccQuit THEN
                           BEGIN
                              W.wWhereXY(X,Y);
                              IF Y < Height THEN W.wGotoXY(X,Y+1) ELSE Inc(RefAddr,2);
                              IF RefAddr + Height + Height >= CoreSize 
                                 THEN _Command := ccQuit;
                           END;
                           WSPtr^.DrawAll;
                        UNTIL _Command = ccQuit;
                     END;

         ccJmpLine:  BEGIN
                        Addr := GetJumpAddr;
                        IF Addr >= 0 THEN
                        BEGIN
                           IF Addr >= CoreSize THEN Addr := CoreSize-2;
                           RefAddr := Addr-Y-Y+2;
                           AdjustRefAddr;
                           Y := ((Addr-RefAddr) SHR 1) + 1;  (* if near 0 or coresize *)
                           W.wGotoXY(X,Y);
                        END;
                     END;

         ccJmpIC:    AdjustToIC;

         ccSetIC:    BEGIN
                        State8000.IC := (RefAddr SHR 1) + (Y-1);
                        WSPtr^.DrawAll;
                     END;


         ccSetBrp:   BEGIN
                        Addr := (RefAddr SHR 1) + Y-1;
                        WITH State8000 DO
                        IF Addr = (BreakPoint AND $003FFFFF)
                           THEN BreakPoint := -1
                           ELSE BreakPoint := Addr;
                           WSPtr^.DrawAll;
                     END;

         ccSetWBrp:  BEGIN
                        Addr := (RefAddr SHR 1) + Y-1;
                        WITH State8000 DO
                        IF Addr = (BreakPoint AND $003FFFFF)
                           THEN BreakPoint := -1
                           ELSE BreakPoint := Addr OR $10000000;
                           WSPtr^.DrawAll;
                     END;

         ccFormat:   BinDisp := NOT BinDisp;

         ELSE Exitos := TRUE;
      END;
      Draw;
   UNTIL Exitos;
END; (* CoreWin.Process *)
(**********************************************************************)
(* Func. Name     : ToBin
(* Function       : Returns 24-char 01-string
(**********************************************************************)
FUNCTION ToBin (L: LONGINT): STRING;

VAR
   I: BYTE;
   S: STRING;

BEGIN
   S := '';
   FOR I := 31 DOWNTO 8 DO
   BEGIN
      IF ((L SHR I) AND 1) <> 0 
         THEN S := S + '1'
         ELSE S := S + '0';
      IF I = 20 THEN S := S + '_';
   END;
   ToBin := S;
END; (* ToBin *)

(**********************************************************************)
(* Proc. Name     : CoreFormat
(* Function       : 
(**********************************************************************)
PROCEDURE CoreFormat (Addr,Cont: LONGINT; VAR S: STRING; BinDisp: BOOLEAN);

VAR
   Sl: STRING;

FUNCTION ChrFunc(B: BYTE): CHAR;
BEGIN
   CASE B OF
      0..31,
      127..255     :   ChrFunc := ' ';
      Ord('{')     :   ChrFunc := 'ë';
      Ord('|')     :   ChrFunc := 'õ';
      Ord('}')     :   ChrFunc := 'Ü';
      Ord('[')     :   ChrFunc := 'í';
      Ord('\')     :   ChrFunc := 'ù';
      Ord(']')     :   ChrFunc := 'è';
      ELSE             ChrFunc := Chr(B);
   END;
END;
      
BEGIN
   S := LeftPad(Long2Str(Addr),7);
   S := S + ' ' + ChrFunc(Cont SHR 24) +
                  ChrFunc((Cont SHR 16) AND $ff) +
                  ChrFunc((Cont SHR 8) AND $ff) +
            ' ';

   S := S + LeftPad(Long2Str(Cont DIV 256),9) + ' ';
   IF BinDisp THEN S := S + ToBin(Cont);
   IF Addr = State8000.IC SHL 1
      THEN S := S + ' >'
      ELSE S := S + '  ';
   Sl := Unslang(Addr,Cont,W_ABS_ADDR);
   S := S + Sl;
END; (* CoreFormat *)



(**********************************************************************)
(* Proc. Name     : CoreWin.Draw
(* Function       : Draws contents.
(**********************************************************************)
PROCEDURE CoreWin.Draw;

TYPE Buffer = ARRAY [0..10000] OF LONGINT;

VAR
   BufP : ^Buffer;
   Addr : LONGINT;
   Line:  BYTE;
   Indx:  WORD;
   Attr:  BYTE;
   X,Y:   INTEGER;
   S   :  STRING;
   VS: VirtScreen;

BEGIN
   VS.Alloc(ScreenHeight,ScreenWidth);  (* Only to avoid a little flicker! *)
   VS.CopyFromScreen(1,1);
   VS.Activate;

   IF NOT GetMemCheck(BufP,Height*4) THEN FatalError('CoreWin.Draw: GetMem');
   FromCore(RefAddr,Height,BufP);

   Addr := RefAddr;
   Indx := 0;
   W.Select;
   W.wWhereXY(X,Y);
   WITH W,Colors DO
   FOR Line := 1 TO Height DO
   BEGIN
      CoreFormat(Addr,BufP^[Indx],S,BinDisp);
      IF Self.IsCurrent AND (Line = Y)
         THEN Attr := ColorMono(SelItemColor,SelItemMono)
         ELSE IF (Addr SHR 1) = (State8000.BreakPoint AND $003FFFFF)
                 THEN Attr := ColorMono(HighLightColor,HighLightMono)
                 ELSE Attr := ColorMono(TextColor,TextMono);
      W.wFastWrite(Pad(S,Width),Line,1,Attr);
      Inc(Addr,2);
      Inc(Indx);
   END;

   FreeMemCheck(BufP,Height*4);

   VS.Deactivate;
   VS.CopyToScreen(1,1);
   VS.Done;

END; (* CoreWin.Draw *)

(**********************************************************************)
(* Proc. Name     : CoreWin.Edit
(* Function       : Edits a word in core
(**********************************************************************)
PROCEDURE CoreWin.Edit (Mode: EDIT_MODE_TYPE);

VAR
   E: SimpleLineEditor;
   Addr: LONGINT;
   X,Y: INTEGER;
   S: STRING;
   Buf : LONGINT;
   Ok  : BOOLEAN;
   ErrCode: BYTE;


BEGIN
   W.Select;
   W.wWhereXY(X,Y);
   Addr := RefAddr + (Y-1)*2;
   FromCore(Addr,1,@Buf);

   WITH E DO
   BEGIN
      Init(EntryColors);
      seOptionsOff(seHouseCursorAtEnd);
      seOptionsOn(seWindowRelative);
      CASE Mode OF
         BLANK_INIT: S := '';
         NUM_INIT  : IF BinDisp
                        THEN S := ToBin(Buf)
                        ELSE S := Long2Str(Buf DIV 256);
         SLANG_INIT: IF BinDisp
                        THEN S := '2.'+ToBin(Buf)
                        ELSE S := TrimTrail(UnSlang(Addr,Buf,WO_ABS_ADDR));
      END;
      IF Mode = NUM_INIT
         THEN X := 10
         ELSE IF BinDisp THEN X := 21 ELSE X := 25;

      REPEAT
         ReadString('',Y,X,Width-X,Width-X,S);
         Ok := (GetLastCommand = ccQuit) OR Slang(Addr,S,Buf,ErrCode);
         IF NOT Ok THEN
            IF PopUpError(SlangError(ErrCode),0,Buf,'Press any key') = '' THEN;
      UNTIL Ok;

      IF GetLastCommand <> ccQuit THEN ToCore(Addr,1,@Buf);
      _Command := GetLastCommand;
      Done;
   END;

END; (* CoreWin.Edit *)
(**********************************************************************)
(* Proc. Name     : CoreWin.ZoomToggle
(* Function       : Zoom/unzoom core window
(**********************************************************************)
PROCEDURE CoreWin.ZoomToggle;

VAR
   X,Y: INTEGER;
   X1,Y1,X2,Y2: BYTE;
   VS: VirtScreen;

BEGIN
   VS.Alloc(ScreenHeight,ScreenWidth);  (* Only to avoid a little flicker! *)
   VS.CopyFromScreen(1,1);
   VS.Activate;
   WITH W DO
   BEGIN
      wWhereXY(X,Y);
      IF IsZoomed THEN UnZoom ELSE Zoom;
      Coordinates(X1,Y1,X2,Y2);
   END;
   Width := X2-X1+1;
   Height := Y2-Y1+1;
   IF Y > Height THEN
   BEGIN
      Inc(RefAddr,2*(Y-Height));
      Y := Height;
   END;
   W.wGotoXY(X,Y);
   AdjustRefAddr;
   Draw;
   VS.Deactivate;
   VS.CopyToScreen(1,1);
   VS.Done;
END; (* CoreWin.ZoomToggle *)

(**********************************************************************)
(* Proc. Name     : CoreWin.AdjustToIC
(* Function       : 
(**********************************************************************)
PROCEDURE CoreWin.AdjustToIC;

VAR
   ICAddr: LONGINT;
   X,Y: INTEGER;

BEGIN
   W.wWhereXY(X,Y);
   WITH State8000 DO
   BEGIN
      ICAddr := IC*2;
      IF (ICAddr < RefAddr) OR (ICAddr-RefAddr >= Height*2) THEN
      BEGIN
         RefAddr := ICAddr-2;
         AdjustRefAddr;
      END;
      Y := ((ICAddr-RefAddr) SHR 1) + 1;
      W.wGotoXY(X,Y);
   END;
END; (* CoreWin.AdjustToIC *)


(**********************************************************************)
(* Proc. Name     : WRegsWin.Process
(* Function       : Edits a reg. value
(**********************************************************************)
PROCEDURE WRegsWin.Process;

VAR
   X,Y: INTEGER;
   Addr: LONGINT;
   Exitos: BOOLEAN;

BEGIN
   WSPtr^.DrawAll;
   Exitos := FALSE;
   REPEAT
      W.wWhereXY(X,Y);
      W.Select;
      W.GetNextCommand;
      CASE W.GetLastCommand OF
         ccUp:       IF Y > 1
                        THEN W.wGotoXY(X,Y-1);

         ccDown:     IF Y < Height
                        THEN W.wGotoXY(X,Y+1);

         ccHome:     BEGIN
                        W.wGotoXY(X,1);
                     END;

         ccEnd:      BEGIN
                        W.wGotoXY(X,Height);
                     END;

         ccSelect:   BEGIN
                        Edit(NUM_INIT);
                        WSPtr^.DrawAll;
                     END;


         ELSE Exitos := TRUE;
      END;
      Draw;
   UNTIL Exitos;

END; (* WRegsWin.Process *)

(**********************************************************************)
(* Proc. Name     : WRegFormat
(* Function       : 
(**********************************************************************)
PROCEDURE WRegFormat (RegNo: BYTE; Cont: LONGINT; VAR S: STRING);

VAR
   Sl: STRING;
      
BEGIN
   S := 'W'+Chr(RegNo+48) + ': ' +
                  ChrFunc(Cont SHR 16) +
                  ChrFunc((Cont SHR 8) AND $ff) +
                  ChrFunc(Cont AND $ff) +
            ' ';

   S := S + LeftPad(Long2Str(Cont DIV 256),9) + ' ' + ToBin(Cont);
END; (* WRegFormat *)

(**********************************************************************)
(* Proc. Name     : WRegsWin.Draw
(* Function       : 
(**********************************************************************)
PROCEDURE WRegsWin.Draw;

VAR
   Buf  : ARRAY [0..4] OF LONGINT;
   Reg  : BYTE;
   Attr:  BYTE;
   X,Y:   INTEGER;
   S   :  STRING;

BEGIN
   FromCore(0,4,@Buf);

   W.Select;
   W.wWhereXY(X,Y);
   WITH W,Colors DO
   FOR Reg := 0 TO 3 DO
   BEGIN
      WRegFormat(Reg,Buf[Reg],S);
      IF Self.IsCurrent AND (Reg = Y-1)
         THEN Attr := ColorMono(SelItemColor,SelItemMono)
         ELSE Attr := ColorMono(TextColor,TextMono);
      W.wFastWrite(Pad(S,Width),Reg+1,1,Attr);
   END;

END; (* WRegsWin.Draw *)

(**********************************************************************)
(* Proc. Name     : WRegsWin.Edit
(* Function       : Edits a word in WRegs
(**********************************************************************)
PROCEDURE WRegsWin.Edit (Mode: EDIT_MODE_TYPE);

VAR
   E: SimpleLineEditor;
   Reg: LONGINT;
   X,Y: INTEGER;
   S: STRING;
   Buf : LONGINT;
   Ok  : BOOLEAN;
   ErrCode: BYTE;


BEGIN
   W.Select;
   W.wWhereXY(X,Y);
   Reg := Y-1;
   FromCore(Reg*2,1,@Buf);

   WITH E DO
   BEGIN
      Init(EntryColors);
      seOptionsOff(seHouseCursorAtEnd);
      seOptionsOn(seWindowRelative);
      S := LeftPad(Long2Str(Buf DIV 256),9);
      X := 9;

      REPEAT
         ReadString('',Y,X,Width-X,Width-X,S);
         Ok := (GetLastCommand = ccQuit) OR Slang(Reg*2,S,Buf,ErrCode);
         IF NOT Ok THEN
            IF PopUpError(SlangError(ErrCode),0,Buf,'Press any key') = '' THEN;
      UNTIL Ok;

      IF GetLastCommand <> ccQuit THEN ToCore(Reg*2,1,@Buf);
      Done;
   END;

END; (* WRegsWin.Edit *)

(**********************************************************************)
(* Proc. Name     : IRegsWin.Process
(* Function       : Edits a reg. value
(**********************************************************************)
PROCEDURE IRegsWin.Process;

VAR
   X,Y: INTEGER;
   Addr: LONGINT;
   Exitos: BOOLEAN;

BEGIN
   WSPtr^.DrawAll;
   Exitos := FALSE;
   REPEAT
      W.wWhereXY(X,Y);
      W.Select;
      W.GetNextCommand;
      CASE W.GetLastCommand OF
         ccUp:       IF Y > 1
                        THEN W.wGotoXY(X,Y-1);

         ccDown:     IF Y < Height
                        THEN W.wGotoXY(X,Y+1);

         ccHome:     BEGIN
                        W.wGotoXY(X,1);
                     END;

         ccEnd:      BEGIN
                        W.wGotoXY(X,Height);
                     END;

         ccSelect:   BEGIN
                        Edit(NUM_INIT);
                        WSPtr^.DrawAll;
                     END;


         ELSE Exitos := TRUE;
      END;
      Draw;
   UNTIL Exitos;

END; (* IRegsWin.Process *)

(**********************************************************************)
(* Proc. Name     : IRegsWin.Draw
(* Function       : 
(**********************************************************************)
PROCEDURE IRegsWin.Draw;

CONST
   ResetText = 'Reset mode';

VAR
   X1,X2,Y1,Y2,
   RTx,RTy,
   Reg,
   Attr:  BYTE;
   X,Y:   INTEGER;
   S   :  STRING;

BEGIN
   W.Select;
   W.wWhereXY(X,Y);

   WITH W,Colors,State8000 DO
   FOR Reg := 0 TO 3 DO
   BEGIN
      CASE Reg OF
         0: S := 'IC:  ' + Long2Str(IC*2);
         1: BEGIN
               S := 'IM:  ' + ToBin(IM);
               IF IntEn
                  THEN S := S + ' E'
                  ELSE S := S + ' D';
            END;
         2: S := 'IR:  ' + ToBin(IR);
         3: BEGIN
               S := 'EX:  ';
               IF Ex22 = 1
                  THEN S := S + '1'
                  ELSE S := S + '0';
               IF Ex23  = 1
                  THEN S := S + '1'
                  ELSE S := S + '0';
            END;
      END;

      IF Self.IsCurrent AND (Reg = Y-1)
         THEN Attr := ColorMono(SelItemColor,SelItemMono)
         ELSE Attr := ColorMono(TextColor,TextMono);
      W.wFastWrite(Pad(S,Width),Reg+1,1,Attr);
   END;

   W.Coordinates(X1,Y1,X2,Y2);
   RTy := 4;
   RTx := (X2-X1)-Length(ResetText);
   
   WITH Colors DO
   IF State8000.ResetMode
      THEN W.wFastWrite(ResetText,RTy,RTx,ColorMono(WhiteOnRed,HeaderMono))
      ELSE W.wFastWrite(CharStr(' ',Length(ResetText)),RTy,RTx,
                        ColorMono(TextColor,TextMono));

END; (* IRegsWin.Draw *)

(**********************************************************************)
(* Proc. Name     : IRegsWin.Edit
(* Function       : Edits a word in IRegs
(**********************************************************************)
PROCEDURE IRegsWin.Edit (Mode: EDIT_MODE_TYPE);

VAR
   E: SimpleLineEditor;
   Reg: LONGINT;
   X,Y: INTEGER;
   S: STRING;
   Buf : LONGINT;
   Ok  : BOOLEAN;
   ErrCode: BYTE;


BEGIN
   W.Select;
   W.wWhereXY(X,Y);
   Reg := Y-1;

   WITH E, State8000 DO
   BEGIN
      Init(EntryColors);
      seOptionsOff(seHouseCursorAtEnd);
      seOptionsOn(seWindowRelative);
      CASE Reg OF
         0: S := Long2Str(IC SHL 1);
         1: S := '2.'+ToBin(IM);
         2: S := '2.'+ToBin(IR);
         3: S := '2.'+Chr(Ex22+48) + Chr(Ex23+48);
      END;

      X := 4;

      REPEAT
         ReadString('',Y,X,Width-X,Width-X,S);
         WHILE Pos(' ',S) <> 0 DO Delete(S,Pos(' ',S),1);
         Ok := (GetLastCommand = ccQuit) OR SlangNumber(S,Buf,ErrCode);
         IF NOT Ok THEN
         BEGIN
            IF PopUpError(SlangError(ErrCode),0,Buf,'Press any key') = '' THEN;
         END ELSE
         IF GetLastCommand <> ccQuit THEN
         CASE Reg OF
            0: IC := Buf SHR 1;
            1: IM := (Buf SHL 8) OR $80000000;
            2: IR := Buf SHL 8;
            3: BEGIN
                  Ok := (Buf SHR 2) = 0;
                  IF Ok THEN
                  BEGIN
                     Ex23 := Buf AND 1;
                     Ex22 := (Buf AND 2) SHR 1;
                  END ELSE
                     IF PopUpError('Out of range',0,Buf,
                                   'Press any key') = '' THEN;
               END;
         END;
      UNTIL Ok;

      Done;
   END;

END; (* IRegsWin.Edit *)


(**********************************************************************)
(* Proc. Name     : InitWindows
(* Function       : Init the "debug" windows
(**********************************************************************)
PROCEDURE InitWindows;

VAR
   X1,X2,Y1,Y2: BYTE;

BEGIN
   WITH CtrlScreen, Colors DO
   BEGIN
      Init(MaxScreen,ScreenHeight,ScreenWidth,CurrentVideoMode);
      (* If ScreenWidth>80, it looks awfull if the spare area has a
         color different from the background color of the windows.
      *)
      Activate;
      FastFill(ScreenHeight*ScreenWidth,' ',1,1,ColorMono(TextColor,TextMono));
      Deactivate;

      ToPhysScreen;
   END;
   WinCommands.Init(@WinKeySet,WinKeyMax);
   WS.Init;

   IF ScreenWidth < 80
      THEN FatalError('Min. 80 character per line on CRT required');

   X1 := 2 + (ScreenWidth-80) DIV 2;
   Y1 := 2;
   X2 := X1 + 44;
   Y2 := 5;
   WRegs.Init(X1,Y1,X2,Y2,@WS);

   X1 := X2+2;
   X2 := X1 + 31;
   IRegs.Init(X1,Y1,X2,Y2,@WS);

   X1 := 2 + (ScreenWidth-80) DIV 2;
   X2  := X1 + 77;
   Y1 := Y2+2;
   Y2 := (ScreenHeight-3) DIV 2 + 2;
   CoreW1.Init(X1,Y1,X2,Y2,@WS);

   Y1 := Y2+2;
   Y2 := ScreenHeight-1;
   CoreW2.Init(X1,Y1,X2,Y2,@WS);

   WS.CurrentWin := @CoreW1;

END; (* InitWindows *)




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
END. (* UNIT WIN *)

