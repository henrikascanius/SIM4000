(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : POPUP.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-12-13 16:07   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Pop up windows for SIM8000.
(*
(**********************************************************************)

{$F+}

UNIT POPUP;


INTERFACE

USES
   OpFrame,
   OpWindow,
   OpCrt,
   OpColor;

CONST
   PopActive: BOOLEAN = FALSE;
   
VAR
   PopW : StackWindow;

PROCEDURE PopErr(Mess: STRING);
PROCEDURE PopInf(Mess: STRING);


FUNCTION  PopUpError(Mess: STRING; NoParams: BYTE; 
                     VAR Params; Prompt: STRING): CHAR;
FUNCTION  PopUpMessage(Mess: STRING; NoParams: BYTE; 
                       VAR Params; Prompt: STRING): CHAR;
PROCEDURE PopUpInfo(Mess: STRING; NoParams: BYTE; 
                       VAR Params; Prompt: STRING);
FUNCTION PopUpYN (Mess: STRING; NoParams: BYTE; 
                  VAR Params; Prompt: STRING): BOOLEAN;
PROCEDURE PopUpDone;

(*#PAGE*)
IMPLEMENTATION
USES
   Win;



(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : PopUpPrim
(* Function       : 
(**********************************************************************)
FUNCTION  PopUpPrim(Mess: STRING; NoParams: BYTE; 
                    VAR Params; Prompt: STRING;
                    ColorAttr,MonoAttr: BYTE;
                    Shadows, Expl, Inp: BOOLEAN;
                    Options: LONGINT): CHAR;

VAR
   Par: ARRAY [1..255] OF STRING ABSOLUTE Params;
   Pr,S: STRING;
   SA: ARRAY [1..25] OF STRING;
   CPos,
   CPos1,
   LineNo,
   Lines,
   Width,
   XSize,
   YSize,
   PrLine,
   V,X1,X2,Y1,Y2 : BYTE;
   Ch: CHAR;
   


BEGIN
   IF Mess<>'' THEN
   BEGIN
      S := Mess;
      Width := Length(S);
      Lines := 1;  (* Only one-line messages supported for now *)
      YSize := Lines+1;
      PrLine := Lines+2;
   END ELSE
   BEGIN
      S := '';
      Width := 0;
      Lines := 0;
      YSize := 0;
      PrLine := 1;
   END;

   FOR LineNo := 1 TO Lines DO
   BEGIN  (* Get lines and substitute parameters *)
      CPos := 0;
      REPEAT
         CPos1 := CPos;
         CPos := CPos + Pos('%',Copy(S,CPos+1,Length(S)-Cpos-1));
         IF (CPos>CPos1) AND (Ord(S[CPos+1])>48) AND
            (Ord(S[CPos+1])-48 <= NoParams) THEN
         BEGIN
            Insert(Par[Ord(S[CPos+1])-48],S,CPos+2);
            Delete(S,CPos,2);
            IF Length(S)>Width THEN Width := Length(S);
         END;
      UNTIL CPos=Cpos1;
      SA[LineNo] := Copy(S,1,78);
(*    IF LineNo<Lines THEN S := TNext; *)
   END;

   IF Prompt='' THEN Pr := ''
                ELSE Pr := Prompt;
   IF Pr<>'' THEN IF YSize>0 THEN YSize := Ysize+2 ELSE YSize := 1;
   IF Length(Pr)>Width THEN Width := Length(Pr);

   IF Width>78 THEN Width := 78;
   XSize := Width+2;
  
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
                 Colors, wBordered+wClear+wSaveContents OR Options);
      IF Expl THEN EnableExplosions(10);
      IF Shadows
         THEN wFrame.AddShadow(shBR, shSeeThru);

      wFrame.SetFrameType(Frame1);
      wFrame.SetFrameAttr(ColorAttr, MonoAttr);
      PopW.SetTextAttr(ColorAttr, MonoAttr);
      SetCursor(CUHidden);
      Draw;

      FOR LineNo := 1 TO Lines DO
         wFastCenter(SA[LineNo],LineNo,
                     ColorMono(ColorAttr, MonoAttr));
      IF Pr<>'' THEN
      BEGIN
         wFastCenter(Pr,PrLine,ColorMono(ColorAttr, MonoAttr));
      END;

      EnableNormalOpen; (* No explosions on close *)

      IF Inp THEN
      BEGIN
         Ch := ReadKey;
         PopUpPrim := Ch;
         IF Ch = Chr(0) THEN Ch := ReadKey;  (* Read 2 chars if compound *)
         PopW.Done;
         PopActive := FALSE;
      END ELSE
      BEGIN
         PopUpPrim := #0;
         PopActive := TRUE;
      END;

   END;
END; (* PopUpPrim *)
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : PopErr
(* Function       : 
(**********************************************************************)
PROCEDURE PopErr (Mess: STRING);

BEGIN
   IF PopUpError(Mess,0,Mess,'Press any key') = ' ' THEN ;
END; (* PopErr *)



(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : PopUpError
(* Function       : 
(**********************************************************************)
FUNCTION  PopUpError(Mess: STRING; NoParams: BYTE; 
                     VAR Params; Prompt: STRING): CHAR;

BEGIN
   WITH Colors DO
   PopUpError := PopUpPrim(Mess,NoParams,Params,Prompt,
                           HighlightColor,HighlightMono,
                           FALSE,TRUE,TRUE,wSoundEffects);
END; (* PopUpError *)



(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : PopUpMessage
(* Function       : 
(**********************************************************************)
FUNCTION  PopUpMessage(Mess: STRING; NoParams: BYTE; 
                       VAR Params; Prompt: STRING): CHAR;

BEGIN
   WITH Colors DO
   PopUpMessage := PopUpPrim(Mess,NoParams,Params,Prompt,
                             TextColor,TextMono,
                             TRUE,TRUE,TRUE,0);
END; (* PopUpMessage *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : PopInf
(* Function       : 
(**********************************************************************)
PROCEDURE PopInf (Mess: STRING);

BEGIN
   PopUpInfo(Mess,0,Mess,'');
END; (* PopInf *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : PopUpInfo
(* Function       : 
(**********************************************************************)
PROCEDURE PopUpInfo(Mess: STRING; NoParams: BYTE; 
                       VAR Params; Prompt: STRING);

VAR Ch: CHAR;

BEGIN
   WITH Colors DO
   Ch := PopUpPrim(Mess,NoParams,Params,Prompt,
                             WhiteOnCyan,TextMono,
                             TRUE,FALSE,FALSE,0);
END; (* PopUpInfo *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : PopUpYN
(* Function       : 
(**********************************************************************)
FUNCTION PopUpYN (Mess: STRING; NoParams: BYTE; 
                  VAR Params; Prompt: STRING): BOOLEAN;

VAR Y,N: STRING;
    Ch: CHAR;

BEGIN
   Y := 'Y';
   N := 'N';

   WITH Colors DO
   Ch := PopUpPrim(Mess,NoParams,Params,Prompt,
                             WhiteOnCyan,TextMono,
                             TRUE,FALSE,FALSE,0);
   REPEAT
      Ch := ReadKey;
   UNTIL (UpCase(Ch)=UpCase(Y[1])) OR (UpCase(Ch)=UpCase(N[1]));
   PopUpDone;
   PopUpYN := UpCase(Ch)=UpCase(Y[1]);
END; (* PopUpYN *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : PopUpDone
(* Function       : 
(**********************************************************************)
PROCEDURE PopUpDone;

BEGIN
   IF PopActive THEN
   BEGIN
      PopW.Select;
      PopW.Done;
   END;
   PopActive := FALSE;
END; (* PopUpDone *)



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
END. (* UNIT POPUP *)

