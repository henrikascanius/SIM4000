(**********************************************************************)
(* Unit name      : SLANGP.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-12-11 23:08   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC4000/8000 SLANG Assembler/Disassembler routines for SIM8000
(*
(**********************************************************************)

{$F+}

UNIT SLANGP;


INTERFACE

TYPE
   SlangPrintFormat  =  (W_ABS_ADDR,WO_ABS_ADDR);


FUNCTION SlangNumber (S: STRING; VAR Obj: LONGINT; VAR ErrCode: BYTE): BOOLEAN;
FUNCTION Slang(Addr: LONGINT; S: STRING; VAR Obj: LONGINT; VAR ErrCode: BYTE): BOOLEAN;
FUNCTION UnSlang(Addr,Obj: LONGINT; Format: SlangPrintFormat): STRING;
FUNCTION SlangError (Code: BYTE): STRING;

(*#PAGE*)
IMPLEMENTATION


USES
   Win,
   OpString;

CONST
   OpCodeTable : ARRAY[0..127] OF WORD =
      (Ord('a') SHL 8 + Ord('w'),    Ord('i') SHL 8 + Ord('o'),
       Ord('e') SHL 8 + Ord('l'),    Ord('h') SHL 8 + Ord('l'),
       Ord('l') SHL 8 + Ord('a'),    Ord('l') SHL 8 + Ord('o'),
       Ord('l') SHL 8 + Ord('x'),    Ord('w') SHL 8 + Ord('a'),
       Ord('w') SHL 8 + Ord('s'),    Ord('a') SHL 8 + Ord('m'),
       Ord('w') SHL 8 + Ord('m'),    Ord('a') SHL 8 + Ord('l'),
       Ord('m') SHL 8 + Ord('l'),    Ord('j') SHL 8 + Ord('l'),
       Ord('j') SHL 8 + Ord('d'),    Ord('j') SHL 8 + Ord('e'),
       Ord('x') SHL 8 + Ord('l'),    Ord('e') SHL 8 + Ord('s'),
       Ord('e') SHL 8 + Ord('a'),    Ord('z') SHL 8 + Ord('l'),
       Ord('r') SHL 8 + Ord('l'),    Ord('s') SHL 8 + Ord('p'),
       Ord('k') SHL 8 + Ord('l'),    Ord('r') SHL 8 + Ord('s'),
       Ord('w') SHL 8 + Ord('d'),    Ord('r') SHL 8 + Ord('x'),
       Ord('h') SHL 8 + Ord('s'),    Ord('x') SHL 8 + Ord('s'),
       Ord('p') SHL 8 + Ord('l'),    Ord('p') SHL 8 + Ord('s'),
       Ord('m') SHL 8 + Ord('s'),    Ord('i') SHL 8 + Ord('s'),
       Ord('c') SHL 8 + Ord('i'),    Ord('a') SHL 8 + Ord('c'),
       Ord('n') SHL 8 + Ord('s'),    Ord('n') SHL 8 + Ord('d'),
       Ord('a') SHL 8 + Ord('s'),    Ord('a') SHL 8 + Ord('d'),
       Ord('l') SHL 8 + Ord('s'),    Ord('l') SHL 8 + Ord('d'),
       Ord('s') SHL 8 + Ord('h'),    Ord('s') SHL 8 + Ord('l'),
       Ord('s') SHL 8 + Ord('e'),    Ord('s') SHL 8 + Ord('n'),
       Ord('s') SHL 8 + Ord('o'),    Ord('s') SHL 8 + Ord('z'),
       Ord('s') SHL 8 + Ord('x'),    Ord('i') SHL 8 + Ord('c'),
       Ord('f') SHL 8 + Ord('a'),    Ord('f') SHL 8 + Ord('s'),
       Ord('f') SHL 8 + Ord('m'),    Ord('k') SHL 8 + Ord('s'),
       Ord('f') SHL 8 + Ord('d'),    Ord('c') SHL 8 + Ord('f'),
       Ord('d') SHL 8 + Ord('l'),    Ord('d') SHL 8 + Ord('s'),
       Ord('a') SHL 8 + Ord('a'),    Ord('s') SHL 8 + Ord('s'),
       Ord('5') SHL 8 + Ord('8'),    Ord('5') SHL 8 + Ord('9'),
       Ord('6') SHL 8 + Ord('0'),    Ord('i') SHL 8 + Ord('x'),
       Ord('6') SHL 8 + Ord('2'),    Ord('6') SHL 8 + Ord('3'),

      (* Alternative names *)
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord('b') SHL 8 + Ord('l'),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord('b') SHL 8 + Ord('s'),
       Ord('b') SHL 8 + Ord('a'),    Ord('b') SHL 8 + Ord('z'),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' '),
       Ord(' ') SHL 8 + Ord(' '),    Ord(' ') SHL 8 + Ord(' ')

      );

(**********************************************************************)
(*Func. Name     : SlangError
(* Function       : Translates error code to text
(**********************************************************************)
FUNCTION SlangError (Code: BYTE): STRING;

VAR S: STRING;

BEGIN
   IF Code = 127 THEN S := 'Empty line' ELSE
   IF Code = 255 THEN S := 'Missing number' ELSE
   IF Code < 127 THEN
   CASE Code OF
      1: S := 'Unknown opcode';
      2: S := 'Wreg out of range';
      3: S := 'Xreg out of range';
      4: S := 'Displacement out of range';
      5: S := 'Misplaced '')''';
      6: S := 'Trailing garbage';
      ELSE S := 'SLANG Error '+Long2Str(Code);
   END ELSE
   CASE Code OF
    129: S := 'More bases in number';  
    130: S := 'Base out of range';  
    131: S := 'Bad char in number';  
    ELSE  S := 'SLANG Number Error '+Long2Str(Code);
   END;

   SlangError := S;

END; (* SlangError *)



(**********************************************************************)
(* Func. Name     : SlangNumber
(* Function       : 
(**********************************************************************)
FUNCTION SlangNumber (S: STRING; VAR Obj: LONGINT; VAR ErrCode: BYTE): BOOLEAN;

VAR
   Indx,
   Base: BYTE;
   Neg,
   Based: BOOLEAN;
   N: LONGINT;

BEGIN
   Obj := 0;
   Base := 10;
   Based := FALSE;
   SlangNumber := FALSE;
   S := Trim(S);
   IF Length(S) = 0 THEN
   BEGIN
      ErrCode := 127;
      Exit;
   END;

   Neg := S[1] = '-';
   IF Neg OR (S[1]='+') THEN Indx := 2 ELSE Indx := 1;
   IF Length(S) < Indx THEN
   BEGIN
      ErrCode := 255;
      Exit;
   END;

   WHILE Indx <= Length(S) DO
   BEGIN
      IF S[Indx] IN ['0'..'9'] THEN Obj := Obj * Base + (Ord(S[Indx])-48) ELSE
      IF S[Indx] = '.' THEN
      BEGIN
         IF Based THEN
         BEGIN
            ErrCode := 129;
            Exit;
         END;
         IF (Obj < 2) OR (Obj > 10) THEN
         BEGIN
            ErrCode := 130;
            Exit;
         END;
         Base := Obj;
         Obj := 0;
         Based := TRUE;
      END ELSE

      IF (S[Indx] = '+') OR (S[Indx] = '-') THEN
      BEGIN
         IF Neg THEN Obj := -Obj;
         Neg := FALSE;
         IF NOT SlangNumber(Copy(S,Indx,255),N,ErrCode) THEN Exit;
         Obj := Obj + N;
         SlangNumber := TRUE;
         ErrCode := 0;
         Exit;
      END ELSE
      IF S[Indx] = '_' THEN ELSE
      BEGIN
         ErrCode := 131;
         Exit;
      END;
      Inc(Indx);
   END;

   IF Neg THEN Obj := -Obj;
   SlangNumber := TRUE;
   ErrCode := 0;

END; (* SlangNumber *)



(**********************************************************************)
(* Func. Name     : Slang
(* Function       : Translate a text line to machine code
(**********************************************************************)
FUNCTION Slang (Addr: LONGINT; S: STRING; VAR Obj: LONGINT; VAR ErrCode: BYTE): BOOLEAN;

VAR
   D: LONGINT;
   OpCode: WORD;
   Indx,
   Op:  BYTE;
   Wreg,Xreg: BYTE;
   R,I,RD: BOOLEAN;

BEGIN
   S := Trim(S);
   Slang := FALSE;
   IF Length(S) = 0 THEN
   BEGIN
      ErrCode := 127;
      Exit;
   END;
   IF S[1] IN ['0'..'9','+','-'] THEN 
   BEGIN
      Slang := SlangNumber(S,Obj,ErrCode);
      Obj := Obj SHL 8;
      Exit;
   END;

   S := StLoCase(S);
   OpCode := (Ord(S[1]) SHL 8) + Ord(S[2]);
   Op := 0;
   WHILE (OpCode <> OpCodeTable[Op]) AND (Op < 127) DO Inc(Op);

   IF OpCode <> OpCodeTable[Op] THEN
   BEGIN
      ErrCode := 1;
      Exit;
   END;

   Delete(S,1,2);

   R := S[1] = '.';
   IF R THEN
      Delete(S,1,1);

   S := Trim(S);
      
   IF S[1] <> 'w' THEN Wreg := 0 ELSE
   BEGIN
      WReg := Ord(S[2]) - 48;
      IF Wreg > 3 THEN
      BEGIN
         ErrCode := 2;
         Exit;
      END;
      Delete(S,1,2);
      S := Trim(S);
   END;

   I := S[1] = '(';
   IF I THEN
   BEGIN
      Delete(S,1,1);
      S := Trim(S);
   END;

   IF S[1] <> 'x' THEN Xreg := 0 ELSE
   BEGIN
      Xreg := Ord(S[2])-48;
      IF Xreg > 3 THEN
      BEGIN
         ErrCode := 3;
         Exit;
      END;
      Delete(S,1,2);
      S := Trim(S);
   END;

   IF NOT (S[1] IN ['0'..'9','+','-']) THEN D := 0 ELSE
   BEGIN
      Indx := 2;
      WHILE (Indx <= Length(S)) AND (S[Indx] IN ['0'..'9','.','+','-']) DO Inc(Indx);
      Dec(Indx);  (* Now points to last char in "number" *)
      RD := S[Indx] = '.';      (* Relative-mark *)
      IF RD THEN Dec(Indx);

      IF NOT SlangNumber(Copy(S,1,Indx),D,ErrCode) THEN Exit;
      IF RD THEN D := D - Addr;
      IF (D < -2048) OR (D > 4095) THEN
      BEGIN
         ErrCode := 4;
         Exit;
      END;
      Delete(S,1,Indx);
      IF RD THEN Delete(S,1,1);
   END;

   IF S[1] = ')' THEN
   BEGIN
      IF NOT I THEN
      BEGIN
         ErrCode := 5;
         Exit;
      END;
      Delete(S,1,1);
   END;

   IF S <> '' THEN
   BEGIN
      ErrCode := 6;
      Exit;
   END;

   Obj := (LONGINT(Op) SHL 26) + (LONGINT(Wreg) SHL 24) +
          (LONGINT(Xreg) SHL 20) + (LONGINT(D AND $fff) SHL 8);

   IF I THEN Obj := Obj OR $00400000;
   IF R THEN Obj := Obj OR $00800000;
   Slang := TRUE;
   ErrCode := 0;

END; (* Slang *)

(**********************************************************************)
(* Func. Name     : UnSlang
(* Function       : Disassembles a machine word into SLANG code
(**********************************************************************)
FUNCTION UnSlang (Addr,Obj: LONGINT; Format: SlangPrintFormat): STRING;

VAR Wreg,Xreg: 0..3;
    Op: 0..63;
    R,I: BOOLEAN;
    D: INTEGER;
    OpName: WORD;
    Temp,
    S: STRING;

BEGIN
   Op    := Obj SHR 26;
   Wreg  := (Obj SHR 24) AND 3;
   Xreg  := (Obj SHR 20) AND 3;
   R     := (Obj AND $00800000) <> 0;
   I     := (Obj AND $00400000) <> 0;
   D     := (Obj SHR 8) AND $fff;
   IF D > 2047 THEN D := D-4096;

   OpName := OpCodeTable[Op];

   S := Chr(OpName SHR 8) + Chr(OpName AND $ff);
   IF R
      THEN S := S + '. '
      ELSE S := S + '  ';

   S := S + 'w' + Chr(Wreg+48);

   IF I
      THEN S := S + ' ('
      ELSE S := S + '  ';

   IF Xreg<>0 
      THEN S := S + 'x' + Chr(Xreg+48)
      ELSE S := S + '  ';

   IF (Xreg<>0) AND (D>=0) 
      THEN Temp := '+'
      ELSE IF D>=0
              THEN Temp := ' ' 
              ELSE Temp := '';

   Temp := Temp + Long2Str(D);
   IF I 
      THEN S := S + Pad(Temp+')',6)
      ELSE S := S + Pad(Temp,6);

   IF (Format = W_ABS_ADDR) AND R THEN
      S := S + '   (' + Long2Str(Addr+D) + ')';

   UnSlang := S;

END; (* UnSlang *)





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
END. (* UNIT SLANGP *)

