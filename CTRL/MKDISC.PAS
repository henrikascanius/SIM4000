(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Program name   : MKDISC.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-03-21 00:26   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC4819 disc image maker!
(*
(**********************************************************************)

PROGRAM MKDISC;


USES
   OpDos,
   Util;


(*#PAGE*)
(**********************************************************************)
(* Procedure Name    : main { main procedure of program }
(* Called Procedures :
(**********************************************************************)
PROCEDURE Main;

CONST TrSize = 9*768;

VAR
   F: FILE;
   Buf: ARRAY[0..TrSize-1] OF BYTE;
   N,Res: WORD;

BEGIN
   IF ParamCount<>1 THEN
   BEGIN
      WriteLn('USE: MKDISC <FILENAME>');
      Halt(1);
   END;

   IF ExistFile(ParamStr(1)) THEN
      FatalError('File already exists, must be explicitly deleted');
   Assign(F,ParamStr(1));
   Rewrite(F,1);

   FOR N := 0 TO TrSize-1 DO Buf[N] := 0;

   FOR N := 0 TO 19 DO
   BEGIN
      BlockWrite(F,Buf,TrSize,Res);
      IF Res <> TrSize THEN FatalError('Write error');
   END;
   Close(F);
END; (* Main *)




 { Main Program }
 BEGIN main END.


