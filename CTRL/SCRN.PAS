(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : SCRN.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-12-12 19:23   HJ Remove refs to ScreenHeight,ScreenWidth in OutChar
(* 93-12-12 01:44   HJ Handle non-std. video modes
(* 93-02-08 21:32   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Virtual screen handling for RC8000 simulator (c) Henrik Jacobsen 1993.
(*
(**********************************************************************)

{$F+}

UNIT SCRN;


INTERFACE

USES
   OpWindow,
   OpFrame,
   OpCrt;

CONST
   Font8x8  =  256;
   MaxScreen=  9;
   LogCons: BOOLEAN = FALSE;

TYPE

   ScreenPtr= ^Screen;

   Screen   =  OBJECT (VirtScreen)
                  OnPhysScreen:  BOOLEAN;
                  ScreenNo:  BYTE;
                  VideoMode: WORD; (* byte-value, +256 if font8x8 *)
                  _Height,
                  _Width,
                  Row,
                  Col: BYTE;

                  CONSTRUCTOR Init(No,Height,Width: BYTE; VMode: WORD);
                  DESTRUCTOR Done; VIRTUAL;
                  PROCEDURE ToPhysScreen; VIRTUAL;
               PRIVATE
                  UseCursor: BOOLEAN;
                  PROCEDURE FromPhysScreen;  VIRTUAL;
               END;


   ConsScreenPtr= ^ConsScreen;

   ConsScreen= OBJECT (Screen)
                  ScrollFlag: BOOLEAN;

                  CONSTRUCTOR Init(No,Height,Width: BYTE; VMode: WORD);
                  PROCEDURE OutChar(C: CHAR); VIRTUAL;
               END;


CONST
   CurScreen: ScreenPtr = NIL;

VAR
   CrtBorderOn : BOOLEAN; (* True if overscan color <> 0 at prog. entry *)
   UserTextAttr: BYTE;    (* Attr. selected by user at prog. entry *)

   ScreenTab: ARRAY [0..MaxScreen] OF ScreenPtr;

   Pc2Rc,
   Rc2Pc: ARRAY [0..255] OF BYTE;

   VideoCtrl1: BYTE ABSOLUTE $40:$87;  (* Video ctrl state #1 *)
   CursorEmulAtEntry: BOOLEAN;


PROCEDURE InitUserTextAttr;
FUNCTION  CurrentVideoMode: WORD;
PROCEDURE SetCrtBorder(Attr: BYTE);


(*#PAGE*)
IMPLEMENTATION
USES
   Dos,
   OpString,
   Win,
   OpInt,
   Util,
   Audio,
   OpCmd;

CONST

   ConsLogOn: BOOLEAN = FALSE;


VAR
   ConsLog: TEXT;

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : InitUserTextAttr
(* Function       : Write a char thru DOS and get attribute used.
(*                  Makes it possible to detect a selected ANSI-attrib.
(*                  The routine is very general in the sense that the
(*                  screen contents and cursor position remain unchanged.
(**********************************************************************)
PROCEDURE InitUserTextAttr;

VAR 
   Regs: Registers;
   R,C: BYTE;
   S: STRING[1];
   Cont: CHAR;

BEGIN
   R := WhereYAbs;
   C := WhereXAbs;
   Cont := ReadCharAtCursor;

   WITH Regs DO
   BEGIN
      AH := 2;
      DL := Ord(Cont);
      MsDos(Regs);  (* Write a char. Assume that no scroll occurs (very unlikely) *)
   END;
   ReadAttribute(1,R,C,S);
   UserTextAttr := Ord(S[1]);
   GotoXYAbs(C,R);  (* Reset cursor pos. *)

   (* Get overscan attr. *)
   WITH Regs DO
   BEGIN
      AX := $1008;  (* Video fnc. 10, subfunc 8: Get overscan color *)
      Dos.Intr($10,Regs);
      CrtBorderOn := (BH<>0) AND ((Flags AND FCarry)=0);
   END;

END; (* InitUserTextAttr *)


(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : CurrentVideoMode
(* Function       : 
(**********************************************************************)
FUNCTION CurrentVideoMode: WORD;


BEGIN
   CurrentVideoMode := GetCrtMode + Ord(Font8x8Selected)*Font8x8;
END; (* CurrentVideoMode *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : SetCrtBorder
(* Function       : Stolen from OPCRT and modified (checks for mode etc.
(*                  removed)
(**********************************************************************)
PROCEDURE SetCrtBorder (Attr: BYTE);

BEGIN
    INLINE(
      $8A/$5E/<Attr/         {mov BL,[BP+<Attr]  ;get attribute}
      $B1/$04/               {mov CL,4           ;shift count}
      $D2/$EB/               {shr BL,CL          ;get background color}
      $80/$E3/$0F/           {and BL,$0F         ;make sure it's valid}
                             {Check6:}
      $80/$FB/$06/           {cmp BL,6           ;brown is a special case}
      $75/$04/               {jne ChkEga2}
      $B3/$14/               {mov BL,$14         ;BL = $14}
      $EB/$1A/               {jmp short GoEga}
                             {ChkEga2:}
      $80/$FB/$08/           {cmp BL,$08         ;Is blink bit set?}
      $72/$15/               {jb  GoEga}
      $B8/$40/$00/           {mov ax,$40         ;Is blinking enabled?}
      $8E/$C0/               {mov es,ax}
      $26/$F6/$06/>$65/$20/  {test es:[>$65],$20 ;bit 5 set if blinking on}
      $74/$05/               {jz  Intense        ;if it's on, add $30}
      $80/$E3/$07/           {and BL,$07         ;else, clear blink bit}
      $EB/$E0/               {jmp short Check6   ;and check for $06 again}
                             {Intense:}
      $80/$C3/$30/           {add BL,$30         ;select high-intensity}
                             {GoEga:}
      $B4/$10/               {mov AH,$10         ;set color palette}
      $B0/$01/               {mov AL,$01         ;set border color}
      $88/$DF/               {mov BH,BL          ;the color}
      $CD/$10);              {int $10            ;let BIOS do it}

END; (* SetCrtBorder *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Screen.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR Screen.Init(No,Height,Width: BYTE; VMode: WORD);

BEGIN
   IF NOT VirtScreen.Alloc(Height,Width)
      THEN FatalError('No memory for screen buffer');

   OnPhysScreen := FALSE;
   Col := WhereXAbs;
   Row := WhereYAbs;
   UseCursor := FALSE;

   IF ScreenTab[No] <> NIL THEN
      FatalError('Screen no. used multiple times: '+Long2Str(No));

   ScreenNo := No;
   VideoMode := VMode;
   _Height := Height;
   _Width  := Width;
   ScreenTab[No] := @Self;

END; (* Screen.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Screen.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR Screen.Done;

BEGIN
   ScreenTab[ScreenNo] := NIL;
END; (* Screen.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ToPhysScreen
(* Function       : Makes the screen the one active on the CRT
(**********************************************************************)
PROCEDURE Screen.ToPhysScreen;

VAR
   S: STRING[1];

BEGIN
   IF CurScreen <> NIL THEN CurScreen^.FromPhysScreen;
   IF (VideoMode AND $FF) <> (CurrentVideoMode AND $FF)
      THEN TextMode(VideoMode AND $FF);

   IF (VideoMode <> CurrentVideoMode)
      THEN SelectFont8x8(BOOLEAN((VideoMode DIV Font8x8) AND 1));

   {TextAttr := ColorMono(Colors.TextColor,Colors.TextMono);}
   TextAttr := UserTextAttr;  (* Reset by opcrt after mode change *)

   CopyToScreen(1,1);
   OnPhysScreen := TRUE;
   GotoXYAbs(Col,Row);
   IF UseCursor THEN NormalCursor ELSE HiddenCursor;
   IF CrtBorderOn THEN
   BEGIN  (* Set overscan color *)
      ReadAttribute(1,1,1,S);  (* Get backgr. from upper left corner *)
      SetCrtBorder(Ord(S[1]));
   END;
   CurScreen := @Self;
END; (* ToPhysScreen *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FromPhysScreen
(* Function       : Puts the screen in background, i.e. not on CRT
(**********************************************************************)
PROCEDURE Screen.FromPhysScreen;

BEGIN
   IF (NOT OnPhysScreen) OR (CurScreen <> @Self)
      THEN FatalError('FromPhysScreen: Not active');

   Col := WhereXAbs;
   Row := WhereYAbs;
   CopyFromScreen(1,1);
   OnPhysScreen := FALSE;
   CurScreen := NIL;
END; (* FromPhysScreen *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsScreen.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR ConsScreen.Init(No,Height,Width: BYTE; VMode: WORD);

BEGIN
   INHERITED Init(No,Height,Width,VMode);
   Row := 1;
   Col := 1;
   ScrollFlag := FALSE;
   UseCursor := TRUE;
   IF LogCons AND NOT ConsLogOn THEN
   BEGIN
      Assign(ConsLog,'CONS.LOG');
      Rewrite(ConsLog);
      ConsLogOn := TRUE;
   END;
END; (* ConsScreen.Init *)



(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConsScreen.OutChar
(* Function       : Writes a char to ConsScreen screen.
(*                  Primitive, preliminary verson, i.e. no RC851.
(**********************************************************************)
PROCEDURE ConsScreen.OutChar (C: CHAR);

BEGIN
   IF NOT OnPhysScreen THEN Activate;

   CASE Ord(C) OF

      32..126: BEGIN
                  FastWrite(Chr(Rc2Pc[Ord(C)]),Row,Col,
                            UserTextAttr);
                  Inc(Col);
                  IF Col > _Width THEN
                  BEGIN
                     Col := 1;
                     ScrollFlag := TRUE;
                     IF Row < _Height
                        THEN Inc(Row)
                        ELSE 
                        IF OnPhysScreen
                           THEN ScrollWindowUp(1,1,_Width,_Height,1)
                           ELSE ScrollVert(1,UserTextAttr,' ');
                  END ELSE ScrollFlag := FALSE;
               END;

      7:       IF OnPhysScreen THEN Beeper.Beep;

      8:       IF Col > 1 THEN Dec(Col);

      12,
      10:      BEGIN
                  IF NOT ScrollFlag THEN
                  BEGIN
                     IF Row < _Height
                        THEN Inc(Row)
                        ELSE 
                        IF OnPhysScreen
                           THEN ScrollWindowUp(1,1,_Width,_Height,1)
                           ELSE ScrollVert(1,UserTextAttr,' ');
                  END;
                  ScrollFlag := FALSE;
               END;

     {12:      BEGIN
                  ClearWindow(1,1,_Width,_Height,' ',UserTextAttr);
                  Row := 1;
                  Col := 1;
               END;
     }                
      13:      Col := 1;

      ELSE ;
   END;

   IF OnPhysScreen THEN GotoXYAbs(Col,Row) ELSE Deactivate;
   IF ConsLogOn THEN Write(ConsLog,Chr(Rc2Pc[Ord(C)]));

END; (* ConsScreen.OutChar *)


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
   IF ConsLogOn THEN Close(ConsLog);

   (* Reset CGA Cursor emul. flag to initial setting. It may be changed 
      by OPCRT's SelectFont8x8 when switching in and out of 8x8 mode *)
   IF CursorEmulAtEntry
      THEN VideoCtrl1 := VideoCtrl1 AND $FE
      ELSE VideoCtrl1 := VideoCtrl1 OR 1;
   Exitproc := ExitSave;
END; (* UnitExit *)



(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : UnitEntry
(* Function       : Entry procedure for unit.
(**********************************************************************)
PROCEDURE UnitEntry;

VAR 
   I: BYTE;

BEGIN
   Exitsave := Exitproc;
   Exitproc := @UnitExit;

   FOR I:=0 TO 255 DO
   BEGIN
     Rc2Pc[i] := I;
     Pc2Rc[i] := I;
     IF 127 < I THEN Pc2Rc[i] := 32;
   end;

   Rc2Pc[ Ord('[') ] := Ord( '’' );
   Rc2Pc[ Ord('\') ] := Ord( '' );
   Rc2Pc[ Ord(']') ] := Ord( '' );
   Rc2Pc[ Ord('{') ] := Ord( '‘' );
   Rc2Pc[ Ord('|') ] := Ord( '›' );
   Rc2Pc[ Ord('}') ] := Ord( '†' );

   Pc2Rc[ Ord('’') ] := Ord( '[' );
   Pc2Rc[ Ord('') ] := Ord( '\' );
   Pc2Rc[ Ord('') ] := Ord( ']' );
   Pc2Rc[ Ord('‘') ] := Ord( '{' );
   Pc2Rc[ Ord('›') ] := Ord( '|' );
   Pc2Rc[ Ord('†') ] := Ord( '}' );

   FOR I := 0 TO MaxScreen DO ScreenTab[I] := NIL;

   CursorEmulAtEntry := (VideoCtrl1 AND 1) = 0;  (* Get CGA Cursor emul. flag *)
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT SCRN *)

