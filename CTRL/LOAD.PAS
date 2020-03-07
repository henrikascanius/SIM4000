(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : LOAD.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-27 00:39   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  
(* Load module for RC4000/8000 emulator microcode.
(**********************************************************************)

{$F+}

UNIT LOAD;


INTERFACE


PROCEDURE LoadCode;

(*#PAGE*)
IMPLEMENTATION

USES
   Dos,
   OpRoot,
   OpClone,
   Util,
   Descr,
   Vcpi,
   Intf;

CONST
   ConfigId:    STRING[10] = 'LOADDEFREC';
   CMerged  :   BOOLEAN    = FALSE;
   CCodeStart:  LONGINT    = 0;
   CCodeSize:   LONGINT    = 0;
   ConfigEnd:   BYTE       = 0;

   UCodePrefix: STRING[40] = '..\UCODE\';



(* Note: In the ucode files, the entry table is word-sized to save space
   (the size of each file is limited to 64K). When loaded, a 32-bit table is
   built
*)
   
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : LoadCodeExt
(* Function       : Loads the simulator code.
(**********************************************************************)
PROCEDURE LoadCodeExt;

TYPE
   BUFTYPE = ARRAY [0..2047] OF WORD;
   TABTYPE = ARRAY [0..4500] OF LONGINT;  (* Entry table *)

CONST
   TotalTableSize = 16384+12;  (* Must match UCHEAD.ASM *)
   Initial4KPages = (TotalTableSize+4095) DIV 4096;

VAR
   Cnt,
   I: WORD;
   Fno: BYTE;
   F:   FILE;
   Fname: STRING[80];
   Op,
   CodeAddr,
   CodeSize,
   CodeBase: LONGINT;
   Blk,
   Res,
   Rem: WORD;
   BufP: ^BUFTYPE;
   TabP: ^TABTYPE;
   S: STRING[40];

BEGIN
   S := GetEnv('UCODE8000DIR');
   IF S<>'' THEN UCodePrefix := S;
   IF UCodePrefix[Length(UCodePrefix)] <> '\'
      THEN UCodePrefix := UCodePrefix + '\';

   InitVCPI;

   IF NOT GetMemCheck(BufP,4096) THEN
      FatalError('LoadCodeExt get buffer: No heap memory');

   IF NOT GetMemCheck(TabP,TotalTableSize) THEN
      FatalError('LoadCodeExt get table: No heap memory');

   FOR I := 0 TO TotalTableSize DIV 4 DO TabP^[I] := 0;

   WITH GDT.SimCodeD DO
   BEGIN
      Init(READWRITE,0,FALSE,TRUE,TRUE);
      SetBaseAddr(VCPI.Free SHL 10);
      SetLimit($FFFFF);
   END;

   IF Avail4KPages < Initial4KPages THEN 
      FatalError('No room for entry table');

   FOR I := 1 TO Initial4KPages DO
      Allocate4K;

   CodeAddr := TotalTableSize; (* Load address for code *)
   Rem := Initial4KPages*4096 - TotalTableSize;  (* remaining bytes in last 4K page *)

   FOR Fno := 0 TO 35 DO
   BEGIN
      IF Fno > 9 
         THEN Fname := UCodePrefix + '4000_'+Chr(Fno - 10 +65)+'.ABS'
         ELSE Fname := UCodePrefix + '4000_'+Chr(Fno MOD 10 +48)+'.ABS';
      Assign(F,Fname);
{$I-}
      Reset(F,1);
{$I+}
      IF IoResult = 0 THEN
      BEGIN
         WriteLn('Loading ',Fname);
         CodeSize := FileSize(F) - TotalTableSize DIV 2;
         IF CodeSize < 0 THEN
            FatalError('Bad file size: '+Fname);

         (* Load the entry table entries *)
         
         CodeBase := CodeAddr-TotalTableSize DIV 2;

         Cnt := TotalTableSize DIV 2; 
         WHILE Cnt > 0 DO
         BEGIN
            IF Cnt < 4096 THEN Blk := Cnt ELSE Blk := 4096;
            BlockRead(F,BufP^,Blk,Res);
            IF Blk <> Res THEN
               FatalError('LoadCode: BlockRead???');

            FOR Op := 0 TO Blk DIV 2 -1 DO
            IF BufP^[Op] <> 0 
               THEN TabP^[Op + (TotalTableSize DIV 2 -Cnt) SHR 1] := BufP^[Op] + CodeBase;
            Dec(Cnt,Blk);
         END;

         (* Load the code proper *)
         WHILE CodeSize > 0 DO
         BEGIN
            IF Rem > 0 THEN
            BEGIN
               BlockRead(F,BufP^,Rem,Cnt);
               ToCode(CodeAddr,Cnt,BufP);
               Inc(CodeAddr,Cnt);
               Dec(Rem,Cnt);
               Dec(CodeSize,Cnt);
            END;

            IF CodeSize > 0 THEN
            BEGIN
               IF Avail4KPages < 1 THEN 
                  FatalError('Not enough memory to load emulator');

               Allocate4K;
               Rem := 4096;
            END;
         END;
         Close(F);
      END;

   END;

   (* All files loaded, now put the entry table in place *)
   FOR I := 0 TO 4095 DO
   IF TabP^[I] = 0 THEN TabP^[I] := Tabp^[4097];   (*******)
   ToCode(0,TotalTableSize,TabP);

   FreeMemCheck(BufP,4096);
   FreeMemCheck(TabP,TotalTableSize);

   (* Init. descriptor *)      
   WITH GDT.SimCode DO
   BEGIN
      Init(EXECREAD,0,FALSE,TRUE,TRUE);
      SetBaseAddr(GDT.SimCodeD.BaseAddr);
      SetLimit(CodeAddr);
      Intf.CodeBase := BaseAddr;  (* Used to set breakpoints *)
   END;

   WriteLn('Total code size: ',CodeAddr);
   WriteLn('Code base      : ',Intf.CodeBase);

END; (* LoadCodeExt *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : LoadCodeInt
(* Function       : 
(**********************************************************************)
PROCEDURE LoadCodeInt;
CONST
   BUFSIZE  = 32768;

VAR
   F: FILE;
   BufP: ^LONGINT;
   Rem,
   CodeAddr: LONGINT;
   PageReq,
   Cnt,
   Res,
   I: WORD;

BEGIN
   InitVCPI;

   WITH GDT.SimCodeD DO
   BEGIN
      Init(READWRITE,0,FALSE,TRUE,TRUE);
      SetBaseAddr(VCPI.Free SHL 10);
      SetLimit($FFFFF);
   END;

   PageReq := (CCodeSize+4095) SHR 12;
   IF Avail4KPages < PageReq THEN 
      FatalError('No room for emulator code');

   FOR I := 1 TO PageReq DO
      Allocate4K;

   Assign(F,ParamStr(0));
{$I-}
   Reset(F,1);
{$I+}
   IF IOResult <> 0 THEN
      FatalError('Cannot open '+ParamStr(0));

   IF NOT GetMemCheck(BufP,BufSize) THEN
      FatalError('LoadCode get buffer: No heap memory');

   Seek(F,CCodeStart);
   Rem := CCodeSize;
   CodeAddr := 0;

   WHILE Rem>0 DO
   BEGIN
      IF Rem>BUFSIZE
         THEN Cnt := BUFSIZE
         ELSE Cnt := Rem;

      BlockRead(F,BufP^,Cnt,Res);
      IF Res<>Cnt THEN
         FatalError('LoadCodeInt: cannot read (.EXE file size error)');
      ToCode(CodeAddr,Cnt,BufP);
      Dec(Rem,Cnt);
      Inc(CodeAddr,Cnt);
   END;

   Close(F);

   FreeMemCheck(BufP,BUFSIZE);

   (* Init. descriptor *)      
   WITH GDT.SimCode DO
   BEGIN
      Init(EXECREAD,0,FALSE,TRUE,TRUE);
      SetBaseAddr(GDT.SimCodeD.BaseAddr);
      SetLimit(CodeAddr);
      Intf.CodeBase := BaseAddr;  (* Used to set breakpoints *)
   END;

END; (* LoadCodeInt *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : MergeCode
(* Function       : 
(**********************************************************************)
PROCEDURE MergeCode;

CONST
   BUFSIZE  = 32768;

VAR
   F: FILE;
   BufP: ^BYTE;
   Rem,
   CodeAddr: LONGINT;
   PageReq,
   Cnt,
   Res,
   I: WORD;

BEGIN
   Assign(F,ParamStr(0));
{$I-}
   Reset(F,1);
{$I+}
   IF IOResult <> 0 THEN
      FatalError('Cannot open '+ParamStr(0));

   Seek(F,FileSize(F));

   IF NOT GetMemCheck(BufP,BufSize) THEN
      FatalError('MergeCode get buffer: No heap memory');

   CCodeStart := FileSize(F);
   CCodeSize  := GDT.Simcode.Limit + 1;
   Rem := CCodeSize;
   CodeAddr := 0;

   WHILE Rem>0 DO
   BEGIN
      IF Rem>BUFSIZE
         THEN Cnt := BUFSIZE
         ELSE Cnt := Rem;
      FromCode(CodeAddr,Cnt,BufP);
      BlockWrite(F,BufP^,Cnt,Res);
      IF Res<>Cnt THEN
         FatalError('MergeCodeInt: cannot append (disk full?)');
      Dec(Rem,Cnt);
      Inc(CodeAddr,Cnt);
   END;

   Close(F);
   FreeMemCheck(BufP,BUFSIZE);
   CMerged := TRUE;
END; (* MergeCode *)



(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : LoadCode
(* Function       : 
(**********************************************************************)
PROCEDURE LoadCode;

VAR
   Cl: Cloner;
   I: BYTE;


BEGIN
   IF CMerged THEN LoadCodeInt ELSE
   BEGIN
      LoadCodeExt;
      MergeCode;
      IF NOT Cl.InitAndFind(ParamStr(0),UpdateNone,ConfigId,SizeOf(ConfigId))
         THEN FatalError('Cannot find load config');
      Cl.StoreDefaults(Cl.GetPos,ConfigId,Ofs(ConfigEnd)-Ofs(ConfigId));
      Cl.Done;
   END;

   (* Init. break segment *)      
   WITH GDT.BreakS DO
   BEGIN
      Init(READWRITE,0,FALSE,TRUE,TRUE);
      SetBaseAddr(VCPI.Free SHL 10);
      SetLimit(16383);
      FOR I := 0 TO 3 DO Allocate4K;
   END;
   SetBreakSeg;

END; (* LoadCode *)



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
END. (* UNIT LOAD *)

