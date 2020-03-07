(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : UTIL.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-05-11 21:26   HJ Initial version
(* 94-06-02 19:54   HJ FatalError: 'RC8000 simulator' -> 'RC4000 emulator'
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Common utility procedures for SIM8000
(*
(**********************************************************************)

{$F+}

UNIT UTIL;


INTERFACE

PROCEDURE FatalError(S: STRING);
PROCEDURE WaitKey;

PROCEDURE PushF;
INLINE ($9C);

PROCEDURE PopF;
INLINE ($9D);



(*#PAGE*)
IMPLEMENTATION
USES OpCrt;

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FatalError
(* Function       : 
(**********************************************************************)
PROCEDURE FatalError (S: STRING);

BEGIN
   WriteLn('*** RC4000 emulator fatal error: ',S);
   NormalCursor;
   Halt(1);
END; (* FatalError *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : WaitKey
(* Function       : 
(**********************************************************************)
PROCEDURE WaitKey;

VAR Ch: CHAR;

BEGIN
   Ch := ReadKey;
END; (* WaitKey *)



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
END. (* UNIT UTIL *)

