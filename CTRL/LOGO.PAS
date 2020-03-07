(**********************************************************************)
(* Unit name      : LOGO.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-04-18 00:33   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Logo for RC4000/8000 simulator.
(*
(**********************************************************************)

{$F+}

UNIT LOGO;


INTERFACE

PROCEDURE PopUpLogo(Attr: BYTE);
{$I VERSION.INC}


(*#PAGE*)
IMPLEMENTATION
USES
   Popup,
   Win,
   OpFrame,
   OpWIndow,
   OpString,
   OpColor,
   OpCrt;



(**********************************************************************)
(* Proc. Name     : PopUpLogo
(* Function       : 
(**********************************************************************)
PROCEDURE PopUpLogo(Attr: BYTE);

CONST
   Frame1    : FrameArray = '…»ªºÕÕ∫∫';  (* Window Frame def. *)

VAR
   XSize,
   YSize,
   V,X1,X2,Y1,Y2 : BYTE;

BEGIN
   XSize := 60;
   YSize := 8;

   V := ScreenWidth-XSize;
   X1 := 1+(V DIV 2);
   X2 := X1+XSize-1;

   V := ScreenHeight-YSize;
   Y1 := 1+(V DIV 2);
   Y2 := Y1+YSize-1;

   WITH PopW, Colors DO
   BEGIN
      IF PopActive THEN PopUpDone;
      InitCustom(X1,Y1,X2,Y2,
                 Colors, wBordered+wClear+wSaveContents);

      wFrame.SetFrameType(Frame1);
      wFrame.SetFrameAttr(Attr,Attr);
      PopW.SetTextAttr(Attr,Attr);
      SetCursor(CUHidden);
      Draw;

      wFastCenter('RC4000 Computer emulator',1,Attr);
      wFastCenter('Designed & programmed by Henrik A. Jacobsen',2,Attr);
      wFastCenter('All rights reserved by HJ Data',3,Attr);
      wFastCenter(VersString,5,Attr);
   END;
   PopActive := TRUE;
END; (* PopUpLogo *)



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
END. (* UNIT LOGO *)

