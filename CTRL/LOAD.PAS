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
   TABTYPE = ARRAY [0..4095] OF LONGINT;  (* Entry table *)

CONST
   BadOpcodeEntry = $4100;  (* Must match 8000.ASM *)

VAR
   Cnt,
   I: WORD;
   Fno: BYTE;
   F:   FILE;
   Fname: STRING[16];
   Op,
   CodeAddr,
   CodeSize,
   CodeBase: LONGINT;
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

   IF NOT GetMemCheck(TabP,16384) THEN
      FatalError('LoadCodeExt get table: No heap memory');

   FOR I := 0 TO 4095 DO TabP^[I] := BadOpcodeEntry;

   WITH GDT.SimCodeD DO
   BEGIN
      Init(READWRITE,0,FALSE,TRUE,TRUE);
      SetBaseAddr(VCPI.Free SHL 10);
      SetLimit($FFFFF);
   END;

   IF Avail4KPages < 4 THEN 
      FatalError('No room for entry table');

   FOR I := 1 TO 4 DO
      Allocate4K;

   CodeAddr := 16384; (* Load address for code *)
   Rem := 0;          (* remaining doublewords in last 4K page *)

   FOR Fno := 0 TO 35 DO
   BEGIN
      IF Fno > 9 
         THEN Fname := UCodePrefix + '8000.'+Chr(Fno - 10 +65)
         ELSE Fname := UCodePrefix + '8000.'+Chr(Fno MOD 10 +48);
      Assign(F,Fname);
{$I-}
      Reset(F,1);
{$I+}
      IF IoResult = 0 THEN
      BEGIN
         WriteLn('Loading ',Fname);
         CodeSize := FileSize(F) - 8192;
         IF CodeSize < 0 THEN
            FatalError('Bad file size: '+Fname);

         (* Load the entry table entries *)
         
         CodeBase := CodeAddr-8192;  (* Code rel. to first image (8000.0)
                                        Displacement of 8000.0 is 8K to
                                        account for the fact that the
                                        entry table is 8K bigger when loaded
                                        than it is in the file (see above) *)
         FOR I := 0 TO 1 DO  (* split in two blocks for convenience *)
         BEGIN
            BlockRead(F,BufP^,4096,Cnt);
            IF Cnt <> 4096 THEN
               FatalError('LoadCode: BlockRead???');

            FOR Op := 0 TO 2047 DO
            IF BufP^[Op] <> 0 
               THEN TabP^[Op + (I SHL 11)] := BufP^[Op] + CodeBase;
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
      END ELSE
         IF Fno = 0 THEN
            FatalError('8000.0 not found');

   END;

   (* All files loaded, now put the entry table in place *)
   ToCode(0,16384,TabP);

   FreeMemCheck(BufP,4096);
   FreeMemCheck(TabP,16384);

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

