(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : CONFIG.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-20 17:51   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Read & interpret hardware configuration file.
(*
(**********************************************************************)

{$F+}

UNIT CONFIG;


INTERFACE

CONST
   ConfigName: STRING[16] = 'RC4000.CFG';

   CoreMin:    LONGINT  =  131072;
   CoreMax:    LONGINT  =  8388607;

   ConcurrentDiskMode: BOOLEAN = FALSE;

PROCEDURE MakeConfig;
PROCEDURE ConfigMenu;


(*#PAGE*)
IMPLEMENTATION

USES
   Io,
   Reader,
   Punch,
   Cons,
   Rc851,
   Clock,
   RC4818,
   DosDev,
   Util,
   Dos,
   OpCrt,
   OpString;


CONST
   LineNo: WORD = 0;

   IntTable: ARRAY [3..23] OF BOOLEAN =
   (FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,
    FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,FALSE,
    FALSE);

   CoreSizeDefined: BOOLEAN = FALSE;

   
VAR
   F: TEXT;
   CurrLine: STRING;
   DevTable: ARRAY [0..MaxDev] OF BOOLEAN;


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Err
(* Function       : 
(**********************************************************************)
PROCEDURE Err (S: STRING);

BEGIN
   WriteLn('*** ERROR IN ',ConfigName,' AT LINE ',LineNo,':');
   WriteLn(CurrLine);
   WriteLn(S);
   NormalCursor;
   Halt(1);
END; (* Err *)


(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : IsDelim
(* Function       : 
(**********************************************************************)
FUNCTION IsDelim(C: CHAR): BOOLEAN;
BEGIN
   IsDelim := (C='=') OR (C=',') OR (C=' ');
END; (* IsDelim *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : CheckAss
(* Function       : 
(**********************************************************************)
PROCEDURE CheckAss (C: CHAR);

BEGIN
   IF C <> '=' THEN
      Err('Missing ''=''');
END; (* CheckAss *)


(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : NormaliseLine
(* Function       : Removes lead & trail whitespace, multiple blanks etc.
(**********************************************************************)
FUNCTION NormaliseLine (S: STRING): STRING;

VAR
   Temp: STRING;
   P,Q,R: BYTE;

BEGIN
   Temp := StUpcase(Trim(S));

   IF Pos(';',Temp)>0 THEN Delete(Temp,Pos(';',Temp),255);

   REPEAT
      P := Pos(#9,Temp);
      IF P>0 THEN Temp[P] := ' ';
   UNTIL P=0;

   Q := 1;
   REPEAT
      P := Pos(' ',Copy(Temp,Q,255));
      IF P>0 THEN
      BEGIN
         R := Q+P-1;
         IF IsDelim(Temp[R-1]) OR IsDelim(Temp[R+1]) THEN
         BEGIN
            Delete(Temp,R,1);
         END ELSE Q := Q+P;
      END;
   UNTIL P=0;

   NormaliseLine := Temp;

END; (* NormaliseLine *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : NextToken
(* Function       : 
(**********************************************************************)
FUNCTION NextToken (VAR S: STRING; VAR Delim: CHAR): STRING;

VAR
   Temp: STRING;

BEGIN
   Temp := '';
   Delim := ' ';
   IF S = '' THEN
   BEGIN
      NextToken := '';
      EXIT;
   END;

   IF IsDelim(S[1]) THEN
   BEGIN
      Delim := S[1];
      NextToken := '';
      EXIT;
   END;

   WHILE (Length(S) > 0) AND NOT IsDelim(S[1]) DO
   BEGIN
      Temp := Temp + S[1];
      Delete(S,1,1);
   END;

   IF Length(S) > 0 THEN
   BEGIN
      Delim := S[1];
      Delete(S,1,1);
   END ELSE Delim := ' ';

   NextToken := Temp;

END; (* NextToken *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : CheckEOL
(* Function       : 
(**********************************************************************)
PROCEDURE CheckEOL (VAR S: STRING);

VAR
   Delim: CHAR;

BEGIN
   IF (NextToken(S,Delim) <> '') OR (Delim <> ' ')
      THEN Err('Trailing garbage on line');
END; (* CheckEOL *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : GetLine
(* Function       : 
(**********************************************************************)
FUNCTION GetLine (VAR S,RawString: STRING): BOOLEAN;

VAR
   Temp: STRING;

BEGIN
   GetLine := FALSE;
   REPEAT
      IF Eof(F) THEN EXIT;
      Inc(LineNo);
      ReadLn(F,RawString);
      Temp := NormaliseLine(RawString);
   UNTIL (Length(Temp) > 0);

   S := Temp;
   GetLine := TRUE;

END; (* GetLine *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GetDevno
(* Function       : 
(**********************************************************************)
PROCEDURE GetDevno (VAR S: STRING; Delim: CHAR; VAR Dev: INTEGER);

VAR
   Token: STRING;
   L: LONGINT;

BEGIN
   IF Dev>=0 THEN Err('More than one DEVNO parameter on line');
   CheckAss(Delim);
   Token := NextToken(S,Delim);
   IF NOT (Str2Long(Token,L)) OR (Delim <> ' ') 
      THEN Err('Error at DEVNO');

   IF (L<0) OR (L>MaxDev)
      THEN Err('Device number out of range');

   Dev := L;
   IF DevTable[Dev] THEN Err('Device no. '+Long2Str(Dev)+' already defined');
   DevTable[Dev] := TRUE;

END; (* GetDevno *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : GetIntno
(* Function       : 
(**********************************************************************)
PROCEDURE GetIntno (VAR S: STRING; Delim: CHAR; No: BYTE; VAR Int: ARRAY OF BYTE);

VAR
   Cnt: BYTE;
   Token: STRING;
   L: LONGINT;

BEGIN
   IF Int[0] > 0 THEN Err('More than one INTNO parameter on line');
   CheckAss(Delim);
   Cnt := 0;
   REPEAT
      Inc(Cnt);
      Token := NextToken(S,Delim);
      IF NOT (Str2Long(Token,L)) OR
         ((Cnt=No) <> (Delim=' ')) OR ((Cnt<No) <> (Delim=','))
         THEN Err('Error at INTNO (probably wrong no. of parameters,'+
                  ' there should be '+Long2Str(No)+')');

      IF (L<3) OR (L>23)
         THEN Err('Interrupt no. out of range');

      IF IntTable[L] THEN Err('Interrupt no. '+Long2Str(L)+' already used');

      IntTable[L] := TRUE;
      Int[Cnt-1] := L;
   UNTIL Cnt = No;
END; (* GetIntno *)



(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineReader
(* Function       : 
(**********************************************************************)
PROCEDURE DefineReader (VAR S: STRING);

VAR
   Dev:  INTEGER;
   Int:  ARRAY [0..0] OF BYTE;

   Token: STRING;
   Delim: CHAR;
   RdPtr: ReaderDevicePtr;

BEGIN
   Int[0] := 0;
   Dev    := -1;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,1,Int) ELSE
      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');
   RdPtr := New(ReaderDevicePtr,Init(Dev,Int[0]));
   IF RdPtr = NIL
      THEN Err('Could not create Reader, device no. '+Long2Str(Dev));
   
   Token := GetEnv('RC2000');
   IF Token <> '' THEN
   WITH RdPtr^ DO
   BEGIN
      MountTape(Token);
      IF NOT TapePresent THEN
         Err('Could not assign tape reader file: '+Token);
   END;
END; (* DefineReader *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefinePunch
(* Function       : 
(**********************************************************************)
PROCEDURE DefinePunch (VAR S: STRING);

VAR
   Dev:  INTEGER;
   Int:  ARRAY [0..0] OF BYTE;

   Token: STRING;
   Delim: CHAR;
   RdPtr: PunchDevicePtr;

BEGIN
   Int[0] := 0;
   Dev    := -1;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,1,Int) ELSE
      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');
   RdPtr := New(PunchDevicePtr,Init(Dev,Int[0]));
   IF RdPtr = NIL
      THEN Err('Could not create Punch, device no. '+Long2Str(Dev));
   
   Token := GetEnv('RC150');
   IF Token <> '' THEN
   WITH RdPtr^ DO
   BEGIN
      MountTape(Token);
      IF NOT TapePresent THEN
         Err('Could not assign tape punch file: '+Token);
   END;
END; (* DefinePunch *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineConsole
(* Function       : 
(**********************************************************************)
PROCEDURE DefineConsole (VAR S: STRING; Option851: BOOLEAN);

CONST
   VirtConsNo: BYTE = 0;

VAR
   Dev:  INTEGER;
   Int:  ARRAY [0..1] OF BYTE;

   Token: STRING;
   Delim: CHAR;

BEGIN
   Int[0] := 0;
   Int[1] := 0;
   Dev    := -1;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,2,Int) ELSE
      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');

   IF Option851 THEN 
   BEGIN
      IF New(RC851DevicePtr,Init(Dev,VirtConsNo,Int[0],Int[1])) = NIL
         THEN Err('Could not create RC851, device no. '+Long2Str(Dev));
   END ELSE
   IF New(ConsDevicePtr,Init(Dev,VirtConsNo,Int[0],Int[1])) = NIL
      THEN Err('Could not create console, device no. '+Long2Str(Dev));

   Inc(VirtConsNo);
      
END; (* DefineConsole *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineComTerminal
(* Function       : 
(**********************************************************************)
PROCEDURE DefineComTerminal (VAR S: STRING);

CONST
   MaxRates = 19;

   RateTable: ARRAY[1..MaxRates] OF WORD = 
      (75,110,150,300,600,1200,2400,4800,9600,19200,  (* Real baudrates *)
          11, 15, 30, 60, 12,  24,  48,  96,  19);    (* DOS abbrieviations *)

   DivTable: ARRAY[1..MaxRates] OF WORD = 
      (1536,1047,768,384,192,96,48,24,12,6,
            1047,768,384,192,96,48,24,12,6);

VAR
   RateNdx : 1..MaxRates;

   IoBase,
   BaudRate: WORD;
   Parity,
   StopBits,
   CharLen : CHAR;
   IrqNo,
   ComNo: BYTE;
   Dev:  INTEGER;
   Int:  ARRAY [0..1] OF BYTE;

   Token: STRING;
   Delim: CHAR;
   L    : LONGINT;

   ComTable: ARRAY[1..4] OF WORD ABSOLUTE $40:0;

   DevP: ComDevicePtr;

BEGIN
   Baudrate := 0;
   CharLen  := '7';
   Parity   := 'E';
   StopBits := '1';
   Int[0]   := 0;
   Int[1]   := 0;
   Dev      := -1;
   ComNo    := 0;
   IrqNo    := 0;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,2,Int) ELSE
      IF Token = 'COM'   THEN
      BEGIN
         IF ComNo>0 THEN Err('More than one COM parameter on line');
         CheckAss(Delim);
         Token := NextToken(S,Delim);
         IF NOT (Str2Long(Token,L)) OR (Delim <> ' ') 
            THEN Err('Error at COM-parameter');

         IF (L<1) OR (L>4)
            THEN Err('Device number for Com out of range');

         IF ComTable[L] = 0 
            THEN Err('COM'+Long2Str(L)+' not present in BIOS');

         ComNo := L;
      END ELSE

      IF Token = 'MODE'   THEN
      BEGIN
         IF BaudRate>0 THEN Err('More than one MODE parameter on line');
         CheckAss(Delim);
         Token := NextToken(S,Delim);
         IF NOT (Str2Long(Token,L))
            THEN Err('Error at MODE-parameter');

         RateNdx := 1;
         REPEAT
            IF L <> RateTable[RateNdx] THEN Inc(RateNdx);
         UNTIL (L = RateTable[RateNdx]) OR (RateNdx = MaxRates);
         IF L <> RateTable[RateNdx] 
            THEN Err('Baudrate not supported');

         BaudRate := L;

         IF Delim = ',' THEN
         BEGIN
            Token := NextToken(S,Delim);
            IF (Length(Token)<>1) OR NOT (Token[1] IN ['E','O','N'])
               THEN Err('Char. length must be 7 or 8');
            Parity := Token[1];

            IF Delim = ',' THEN
            BEGIN
               Token := NextToken(S,Delim);
               IF (Length(Token)<>1) OR NOT (Token[1] IN ['7','8'])
                  THEN Err('Char. length must be 7 or 8');
               CharLen := Token[1];
            END;

            IF Delim = ',' THEN
            BEGIN
               Token := NextToken(S,Delim);
               IF (Length(Token)<>1) OR NOT (Token[1] IN ['2','1'])
                  THEN Err('No. of stop bits must be 1 or 2');
               StopBits := Token[1];
            END;
         END;

         IF Delim <> ' '
            THEN Err('Error at MODE parameter');
      END ELSE

      IF Token = 'IRQ'   THEN
      BEGIN
         IF IrqNo>0 THEN Err('More than one IRQ parameter on line');
         CheckAss(Delim);
         Token := NextToken(S,Delim);
         IF NOT (Str2Long(Token,L)) OR (Delim <> ' ') 
            THEN Err('Error at IRQ-parameter');

         IF NOT (L IN [3,4,5,7])
            THEN Err('Only IRQ 3,4,5 and 7 is supported');

         IrqNo := L;
      END ELSE

      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');
   IF ComNo = 0 THEN Err('COM port no. not defined');

   IF IrqNo = 0 THEN
   CASE ComNo OF
      1,3: IrqNo := 4;
      2,4: IrqNo := 3;
   END;

   DevP := New(ComDevicePtr,Init(Dev,ComTable[ComNo],IrqNo,Int[0],Int[1]));
   IF  DevP = NIL
      THEN Err('Could not create COM Terminal, device no. '+Long2Str(Dev));

   (* Make line settings: *)

   IF BaudRate > 0 THEN
      DevP^.MakeLineSettings(DivTable[RateNdx],CharLen,Parity,StopBits);

END; (* DefineComTerminal *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineClock
(* Function       : 
(**********************************************************************)
PROCEDURE DefineClock (VAR S: STRING);


VAR
   Dev:  INTEGER;
   Int:  ARRAY [0..0] OF BYTE;

   Token: STRING;
   Delim: CHAR;

BEGIN
   Int[0] := 0;
   Dev    := -1;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,1,Int) ELSE
      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');

   IF New(ClockDevicePtr,Init(Dev,Int[0])) = NIL
      THEN Err('Could not create clock, device no. '+Long2Str(Dev));
      
END; (* DefineClock *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineDFC403
(* Function       : 
(**********************************************************************)
PROCEDURE DefineDFC403 (VAR S: STRING);

VAR
   Dev:  INTEGER;
   Int:  ARRAY [0..1] OF BYTE;

   Token: STRING;
   Delim: CHAR;

BEGIN
   Int[0] := 0;
   Int[1] := 0;
   Dev    := -1;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,2,Int) ELSE
      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');

   IF New(DFC403DevicePtr,Init(Dev,Int[0],Int[1])) = NIL
      THEN Err('Could not create DFC403 disc controller, device no. '+Long2Str(Dev));

END; (* DefineDFC403 *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineRC4819
(* Function       : 
(**********************************************************************)
PROCEDURE DefineRC4819 (VAR S: STRING; RamDisc: BOOLEAN);

VAR
   UnitNo:  BYTE;
   DFCDev:  INTEGER;
   Path:    STRING;
   NoOfCyl: LONGINT;
   Token:   STRING;
   Delim:   CHAR;
   UnitP:   RC4819Ptr;
   L:       LONGINT;

BEGIN
   UnitNo := 255;
   DFCDev := -1;
   Path := '';
   NoOfCyl := 0;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);

      IF Token = 'DFC' THEN
      BEGIN
         IF DFCDev>=0 THEN Err('More than one DFC parameter on line');
         CheckAss(Delim);
         Token := NextToken(S,Delim);
         IF NOT (Str2Long(Token,L)) OR (Delim <> ' ') 
            THEN Err('Error at DFC-parameter');

         IF (L<0) OR (L>MaxDev)
            THEN Err('Device number for DFC out of range');

         DFCDev := L;
         IF TypeOf(IOMap[DFCDev]^) <> TypeOf(DFC403Device)
            THEN Err('Device no. '+Long2Str(DFCDev)+' is not a DFC403 disc controller');
      END ELSE

      IF Token = 'UNITNO' THEN
      BEGIN
         IF UnitNo <> 255 THEN Err('More than one Unitno parameter on line');
         CheckAss(Delim);
         Token := NextToken(S,Delim);
         IF NOT (Str2Long(Token,L)) OR (Delim <> ' ') 
            THEN Err('Error at Unitno-parameter');

         IF (L<0) OR (L>7)
            THEN Err('Disc unit no. out of range');

         Unitno := L;
      END ELSE

      IF Token = 'DOSFILE' THEN
      BEGIN
         IF RamDisc THEN Err('Dosfile not applicable for RC4819RAM');
         IF Path<>'' THEN Err('More than one Dosfile param. on line');
         CheckAss(Delim);
         Path := NextToken(S,Delim);
         IF Delim <> ' '
            THEN Err('Error at Dosfile parameter');
         (* Further checking done by RC4819.Init *)
      END ELSE

      IF Token = 'CYLS' THEN
      BEGIN
         IF NOT RamDisc THEN Err('Cyls only applicable for RC4819RAM');
         IF NoOfCyl<>0 THEN Err('More than one Cyls param. on line');
         CheckAss(Delim);
         Path := NextToken(S,Delim);
         IF Delim <> ' '
            THEN Err('Error at Cyls parameter');
         IF NOT Str2Long(Path,NoOfCyl) OR (NoOfCyl < 5) OR
                (NoOfCyl > 204)
            THEN Err('Cyls parameter must be in the range 5..204');

      END ELSE

      IF Token = '' THEN Err('Bad syntax at '''+Delim+'''')
                    ELSE Err('Unknown parameter: '+Token);
            
   END;

   IF DFCDev < 0 THEN
      Err('DFC device no. not defined');
   IF UnitNo = 255 THEN
      Err('Unitno. not defined');
   IF (Path='') AND NOT RamDisc THEN
      Err('Dosfile not defined');
   IF (NoOfCyl = 0) AND RamDisc THEN
      Err('Cyls not defined');


   IF RamDisc
      THEN UnitP := New(RC4819RamPtr,Init(NoOfCyl,DFC403DevicePtr(IOMap[DFCDev])))
      ELSE UnitP := New(RC4819Ptr,Init(Path,DFC403DevicePtr(IOMap[DFCDev])));
   IF UnitP = NIL THEN
      Err('Could not create RC4819 disc, unit no. '+Long2Str(UnitNo));

   IF NOT DFC403DevicePtr(IOMap[DFCDev])^.IncludeDrive(UnitNo,UnitP)
      THEN Err('Could not connect disc to controller (More discs with same unit no?)');

END; (* DefineRC4819 *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineDos
(* Function       : 
(**********************************************************************)
PROCEDURE DefineDos (VAR S: STRING);

VAR
   Dev:  INTEGER;
   Int:  ARRAY [0..0] OF BYTE;

   Token: STRING;
   Delim: CHAR;
   RdPtr: DosDevicePtr;

BEGIN
   Int[0] := 0;
   Dev    := -1;

   WHILE Length(S) > 0 DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Token = 'DEVNO' THEN GetDevno(S,Delim,Dev) ELSE
      IF Token = 'INTNO' THEN GetIntno(S,Delim,1,Int) ELSE
      IF Token = ''      THEN Err('Bad syntax at '''+Delim+'''')
                         ELSE Err('Unknown parameter: '+Token);
   END;

   IF Dev < 0 THEN Err('Device no. not defined');
   IF Int[0] = 0 THEN Err('Interrupt not defined');
   RdPtr := New(DosDevicePtr,Init(Dev,Int[0]));
   IF RdPtr = NIL
      THEN Err('Could not create Dos-device, device no. '+Long2Str(Dev));
   
END; (* DefineDos *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineDevice
(* Function       : 
(**********************************************************************)
PROCEDURE DefineDevice (VAR S: STRING);

VAR
   Token: STRING;
   Delim: CHAR;

BEGIN
   Token := NextToken(S,Delim);
   IF Delim <> ' ' THEN Err('Misplaced '''+Delim+'''');
   
   IF Token = 'READER'     THEN DefineReader(S) ELSE
   IF Token = 'PUNCH'      THEN DefinePunch(S) ELSE
   IF Token = 'CONSOLE'    THEN DefineConsole(S,FALSE) ELSE
   IF Token = 'COMTERM'    THEN DefineComTerminal(S) ELSE
   IF Token = 'RC851'      THEN DefineConsole(S,TRUE) ELSE
   IF Token = 'CLOCK'      THEN DefineClock(S) ELSE
   IF Token = 'DFC403'     THEN DefineDFC403(S) ELSE
   IF Token = 'RC4819'     THEN DefineRC4819(S,FALSE) ELSE
   IF Token = 'RC4819RAM'  THEN DefineRC4819(S,TRUE) ELSE
   IF Token = 'DOS'        THEN DefineDos(S) ELSE
      Err('Unkown device kind: '+Token);
END; (* DefineDevice *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DefineCoresize
(* Function       : 
(**********************************************************************)
PROCEDURE DefineCoresize (VAR S: STRING);

VAR
   Token: STRING;
   Delim: CHAR;

BEGIN
   IF CoreSizeDefined
      THEN Err('Coresize already defined');

   Token := NextToken(S,Delim);
   IF NOT Str2Long(Token,CoreMin)
      THEN Err('Error in number: '+Token);
   IF Delim = ',' THEN
   BEGIN
      Token := NextToken(S,Delim);
      IF Delim <> ' '
         THEN Err('Misplaced '+Delim);
      IF NOT Str2Long(Token,CoreMax)
         THEN Err('Error in number: '+Token);
   END ELSE CoreMax := CoreMin;

   CheckEOL(S);

   IF CoreMin < 0 THEN
      Err('Min. core size < 0');
   IF CoreMin < 16384 THEN CoreMin := 16384;
   IF CoreMax > 8388607 THEN CoreMax := 8388607;
   IF CoreMax < CoreMin THEN 
      Err('Coresize: Min>Max'+Long2str(CoreMin)+' '+Long2Str(CoreMax));

   CoreSizeDefined := TRUE;
END; (* DefineCoresize *)



(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : MakeConfig
(* Function       : 
(**********************************************************************)
PROCEDURE MakeConfig;

VAR
   SaveFileMode: BYTE;

   S,
   Token: STRING;
   Delim: CHAR;


BEGIN
   S := GetEnv('RC4000CFG');
   IF S <> '' THEN ConfigName := S;

   SaveFileMode := FileMode;
   FileMode := 0;
   Assign(F,ConfigName);
{$I-}
   Reset(F);
   IF IoResult <> 0 THEN
   BEGIN
      S := JustPathname(ParamStr(0)) + '\' + ConfigName;
      Assign(F,S);
      Reset(F);

{$I+}
      IF IoResult <> 0
         THEN FatalError('Configuration file '+ConfigName+' not found');
   END;
   FileMode := SaveFileMode;

   WHILE GetLine(S,CurrLine) DO
   BEGIN
      Token := NextToken(S,Delim);
      IF Delim <> ' ' THEN Err('Misplaced '''+Delim+'''');
      
      IF Token = 'DEFINE' THEN DefineDevice(S) ELSE
      IF Token = 'CORESIZE' THEN DefineCoresize(S) ELSE
         Err('Unknown keyword: '+Token);
   END;
   Close(F);
END; (* MakeConfig *)


(*#PAGE*)
(**********************************************************************)
(*****
(*****                      Online config part
(*****
(**********************************************************************)
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ConfigMenu
(* Function       : 
(**********************************************************************)
PROCEDURE ConfigMenu;

BEGIN
   IF IOMap[0] <> NIL
      THEN IOMap[0]^.Configure;
END; (* ConfigMenu *)




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

VAR I: WORD;

BEGIN
   Exitsave := Exitproc;
   Exitproc := @UnitExit;

   FOR I := 0 TO MaxDev DO DevTable[I] := FALSE;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT CONFIG *)

