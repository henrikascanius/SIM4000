(**********************************************************************)
(* Unit name      : RC851.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 95-01-07 02:32   HJ Error when addressing col. 33 on screen
(* 93-12-12 19:31   HJ Refs to ScreenWidth removed
(* 93-12-12 01:48   HJ Handle non-std. video modes
(* 93-05-09 00:21   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC851 emulator for RC4000/8000 emulator.
(*
(**********************************************************************)

{$F+}

UNIT RC851;


INTERFACE

USES
   Cons;

CONST
   LinesOnScreen = 24;
   CharsOnScreen = LinesOnScreen*80;

TYPE
   TermState   =  (NORMAL,CURSORA,CURSORB);   

   RC851DevicePtr = ^RC851Device;

   RC851Device =  OBJECT (ConsDevice)
                     CONSTRUCTOR Init(DevNo: WORD;
                                      ConsNo, IoInt,OprInt: BYTE);

{                     PROCEDURE  KeyAvail (Key: WORD); VIRTUAL;}
                     PROCEDURE  WriteChar(C: CHAR);   VIRTUAL;
                  PRIVATE
                     TState:  TermState;
                     Column:  BYTE;
                  END;

(*#PAGE*)
IMPLEMENTATION

USES
   Scrn,
   Win,
   Audio,
   Opcmd,
   Opcrt;

(**********************************************************************)
(* Proc. Name     : Rc851Device.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR Rc851Device.Init (DevNo: WORD;
                              ConsNo, IoInt,OprInt: BYTE);

BEGIN
   _Height := 25;
   _Width  := 80;
   _VideoMode := 3;
   (* 851 is always 80x25 mode. Avoid allocating more space than necessary
      for the attached VirtScreen *)
   INHERITED Init(DevNo,ConsNo,IoInt,OprInt);

   TState := NORMAL;
END; (* RC851Device.Init *)

(**********************************************************************)
(* Proc. Name     : Rc851Device.WriteChar
(* Function       : RC822 emulator.
(**********************************************************************)
PROCEDURE Rc851Device.WriteChar (C: CHAR);

VAR
   Line: BYTE;

BEGIN
   WITH Scrn DO
   IF NOT OnPhysScreen THEN Activate;

   WITH Scrn, Colors DO
   IF TState = CURSORA THEN
   BEGIN
      IF Ord(C)>=96 THEN Column := Ord(C)-95 ELSE
      IF Ord(C)>=64 THEN Column := Ord(C)-31 ELSE
                         Column := Ord(C)+33;
      TState := CURSORB;
   END ELSE

   IF TState=CURSORB THEN
   BEGIN
       Line := Ord(C)-95;
       IF Line > LinesOnScreen THEN Line := LinesOnScreen;
       IF Column > _Width THEN Column := _Width;
       Row := Line;
       Col := Column;
       ScrollFlag := FALSE;
       TState := NORMAL;
   END ELSE

   CASE Ord(C) OF
      32..126: BEGIN
                  FastWrite(Chr(Rc2Pc[Ord(C)]),Row,Col,
                            UserTextAttr);
                  Inc(Col);
                  IF Col > _Width THEN
                  BEGIN
                     Col := 1;
                     ScrollFlag := TRUE;
                     IF Row < LinesOnScreen
                        THEN Inc(Row)
                        ELSE 
                        IF OnPhysScreen
                           THEN ScrollWindowUp(1,1,_Width,LinesOnScreen,1)
                           ELSE ScrollVert(1,UserTextAttr,' ');
                  END ELSE ScrollFlag := FALSE;
               END;

      5:       BEGIN  (* Delete line *)
                  Col := 1;
                  FastFill(80,' ',Row,Col,UserTextAttr);
               END;

      6:       TState := CURSORA;

      7:       IF OnPhysScreen THEN Beeper.Beep;

      8:       IF Col > 1 THEN Dec(Col);

      9:       BEGIN  (* Tab *)
                  IF (Row=LinesOnScreen) AND (Col>76) THEN
                  BEGIN
                     IF OnPhysScreen
                        THEN ScrollWindowUp(1,1,_Width,LinesOnScreen,1)
                        ELSE ScrollVert(1,UserTextAttr,' ');
                  END ELSE
                  BEGIN
                     Col := Col + 4 - ((Col-1) AND 3);
                     IF Col > 80 THEN
                     BEGIN
                        Dec(Col,80);
                        Inc(Row);
                     END;
                  END;
               END;


      10:      BEGIN
                  IF NOT ScrollFlag THEN
                  BEGIN
                     IF Row < LinesOnScreen
                        THEN Inc(Row)
                        ELSE 
                        IF OnPhysScreen
                           THEN ScrollWindowUp(1,1,_Width,LinesOnScreen,1)
                           ELSE ScrollVert(1,UserTextAttr,' ');
                  END;
                  ScrollFlag := FALSE;
               END;

      12:      BEGIN
                  FastFill(LinesOnScreen*80,' ',1,1,UserTextAttr);
                  Row := 1;
                  Col := 1;
               END;
                
      13:      Col := 1;

      15:      ;  (* Set protect, not impl. *)

      24:      BEGIN  (* Cursor fwd. *)
                  IF (Row=LinesOnScreen) AND (Col=80) THEN
                  BEGIN
                     IF OnPhysScreen
                        THEN ScrollWindowUp(1,1,_Width,LinesOnScreen,1)
                        ELSE ScrollVert(1,UserTextAttr,' ');
                     Col := 1;
                  END ELSE
                  BEGIN
                     Inc(Col);
                     IF Col>80 THEN
                     BEGIN
                        Col := 1;
                        Inc(Row);
                     END;
                  END;
               END;

      26:      BEGIN  (* Cursor up *)
                  IF Row>1 THEN Dec(Row);
               END;

      28:      ;  (* Reset, not ompl. *)

      29:      BEGIN  (* Home *)
                  Row := 1;
                  Col := 1;
                  ScrollFlag := FALSE;
               END;

      30:      BEGIN  (* EEOL *)
                  FastFill(80-Col+1,' ',Row,Col,UserTextAttr);
               END;

      31:      BEGIN  (* EEOS *)
                  FastFill((80-Col+1)+80*(LinesOnScreen-Row),
                           ' ',Row,Col,UserTextAttr);
               END;



      ELSE ;
   END;

   WITH Scrn DO
   IF OnPhysScreen THEN GotoXYAbs(Col,Row) ELSE Deactivate;

END; (* Rc851Device.WriteChar *)


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
END. (* UNIT RC851 *)

