(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : READER.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-03-09 22:06   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC2000 Paper Tape Reader simulator module.
(*
(**********************************************************************)

{$F+}

UNIT READER;


INTERFACE

USES
   Io;

TYPE
   RdBuf            =   ARRAY[0..0] OF BYTE;

   ReaderDevicePtr  =  ^ReaderDevice;

   ReaderDevice     =   OBJECT (IoDevice)
                           TapePresent:  BOOLEAN;

                           CONSTRUCTOR Init(DevNo: WORD; Int: BYTE);
                           DESTRUCTOR Done;                  VIRTUAL;

                           PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                           PROCEDURE  Rd(Modif: BYTE);       VIRTUAL;
                           PROCEDURE  AutoloadWord;          VIRTUAL;

                           FUNCTION   DeviceID: STRING;      VIRTUAL;
                          {FUNCTION   Configurable: BOOLEAN; VIRTUAL;}
                           PROCEDURE  Configure;             VIRTUAL;

                           PROCEDURE MountTape(FileName: STRING);
                        PRIVATE
                           _Int:  BYTE;
                           Status: LONGINT;
                           DosFile:      FILE;
                           BufP:   ^RdBuf;
                           BufLast,
                           BufGot : WORD;

                        END;


(*#PAGE*)
IMPLEMENTATION

USES
   OpRoot,
   OpInt,
   OpAbsFld,
   OpCmd,
   OpField,
   OpFrame,
   OpWindow,
   OpSelect,
   OpEntry,
   OpColor,
   OpCrt,
   Util,
   Win,
   Popup,
   Intr,
   Intf;

CONST
   END_OF_BUFFER  = LONGINT(1) SHL 23;
   PARITY_ERR     = LONGINT(1) SHL 22;
   END_OF_TAPE    = LONGINT(1) SHL 18;


   BufferSize     =  4096;


{Entry field constants}
const
  idFName                 = 0;

type
  UserRecord =
    record
      FName                 : string[30];
    end;
var
  Status : Word;
  UR     : UserRecord;

{$F+}
procedure DummyUserProc(ESP : EntryScreenPtr);
begin
end;

procedure LoadPostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}

VAR F: FILE;
    S: STRING;

PROCEDURE Err(S: STRING);
BEGIN
   PopErr(S+UR.FName);
   ESP^.SetLastCommand(ccNone);  (* Cancel the field exit command *)
END;

begin
  with ESP^,UR do
  IF GetLastCommand <> ccQuit THEN
    case GetCurrentID of
      idFName : BEGIN
{$I-}
                   Assign(F,FName);
                   Reset(F,1);
                   IF IOResult <> 0 THEN Err('Cannot open file: ');
                   Close(F);
{$I+}
                END;
    end;
end;

procedure ErrorHandler(UnitCode : Byte; var ErrCode : Word; Msg : string);
  {-Report errors}
begin
  RingBell;
end;


PROCEDURE InitEntryScreen(VAR ES: EntryScreen; Header: STRING;
                         PreEdit,PostEdit: esUserProc; VAR UR: UserRecord);

CONST
  Frame1 = '…»ªºÕÕ∫∫';
  WinOptions = wBordered+wClear+wUserContents;

VAR
   X1,Y1,X2,Y2: BYTE;

BEGIN
   X1 := ScreenWidth DIV 2 - 19;
   X2 := X1 + 40;
   Y1 := ScreenHeight DIV 2 - 2;
   Y2 := Y1 + 1;

   WITH ES DO
   BEGIN
    
      IF NOT InitCustom(X1,Y1,X2,Y2, Colors, WinOptions) THEN
      BEGIN
         FatalError('Init entry screen?');
      END;

      wFrame.SetFrameType(Frame1);
      wFrame.AddShadow(shBR, shSeeThru);
      wFrame.AddHeaderColor(Header, heTC, WhiteOnCyan, WhiteOnCyan);
      SetWrapMode(ExitAtBot);

      SetPreEditProc(PreEdit);
      SetPostEditProc(PostEdit);
      SetErrorProc(ErrorHandler);
      EnableExplosions(10);

      esFieldOptionsOn(efRequired+efClearFirstChar);

      AddSimpleStringField(
         'File:   ', 2, 2, 
         'X', 2, 11, 30, 30, 
         0, UR.FName);

      IF RawError <> 0 THEN
         FatalError('Init entry screen');

   END;
END; (* InitEntryScreen *)
   
   
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR ReaderDevice.Init (DevNo: WORD; Int: BYTE);

BEGIN
   INHERITED Init(DevNo);
   _Int := Int;
   TapePresent := FALSE;
   Status := 0;
   BufLast := 0;
   BufGot := 0;

   IF NOT GetMemCheck(BufP,BufferSize) THEN
      FatalError('Tape reader get buffer: No heap memory');

END; (* ReaderDevice.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR ReaderDevice.Done;

BEGIN
   IF TapePresent THEN Close(DosFile);
   FreeMemCheck(BufP,BufferSize);
   INHERITED Done;
END; (* ReaderDevice.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE ReaderDevice.Sense (Modif: BYTE);

BEGIN
   State8000.Ex22 := 0;
   State8000.Ex23 := 0;
   WITH State8000, SrvcParam DO
   BEGIN
      WReg := Status;
      IF NOT TapePresent THEN WReg := WReg OR END_OF_TAPE;
      WReg := WReg SHL 8;
   END;
END; (* ReaderDevice.Sense *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.Rd
(* Function       : 
(**********************************************************************)
PROCEDURE ReaderDevice.Rd (Modif: BYTE);

VAR
   C: BYTE;
   EvenPar: BOOLEAN;
   Got: WORD;

BEGIN
   State8000.Ex22 := 0;
   State8000.Ex23 := 0;

   IF NOT TapePresent THEN
   BEGIN
      Status := END_OF_TAPE;
      EXIT;
   END;

   InterruptsOn;

   REPEAT
      IF BufGot >= BufLast THEN
      BEGIN
         BlockRead(DosFile,BufP^,BufferSize,BufLast);
         IF BufLast = 0 THEN
         BEGIN
            Status := END_OF_TAPE;
            TapePresent := FALSE;
            Close(DosFile);
            EXIT;
         END ELSE Dec(BufLast);
         BufGot := 0;
      END ELSE Inc(BufGot);

      C := BufP^[BufGot];

   UNTIL C <> 0;

   ASM
      xor   ah,ah
      mov   al,C
      or    al,al
      jnp   @OddP
      inc   ah
@OddP:mov   EvenPar,ah

   END;
   
   
   CASE Modif OF
      0: BEGIN  (* Read Odd *)
            Status := C AND $7F;
            IF EvenPar THEN Status := Status OR PARITY_ERR;
         END;

      1: BEGIN  (* Read Even *)
            Status := C AND $7F;
            IF NOT EvenPar THEN Status := Status OR PARITY_ERR;
         END;

      2: BEGIN  (* Read General *)
            Status := C;
            IF NOT EvenPar THEN Status := Status OR PARITY_ERR;
         END;

      ELSE Status := 0;

   END;

END; (* ReaderDevice.Rd *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.AutoloadWord
(* Function       : 
(**********************************************************************)
PROCEDURE ReaderDevice.AutoloadWord;

VAR
  I: BYTE;
  L: LONGINT;

(* Note: It is OK to destroy WReg, as it is not put back by the microcode *)

BEGIN
   L := 0;
   WITH State8000, SrvcParam DO
   BEGIN
      Ex22 := 0;
      Ex23 := 0;
      FOR I := 0 TO 3 DO
      BEGIN
         Rd(0);
         Sense(0);
         IF (Status AND (END_OF_TAPE OR PARITY_ERR)) <> 0 THEN
         BEGIN
            Stop := TRUE;
            ResetSys := TRUE;
            Optional[0] := 1;  (* Prevent write to core *)
            EXIT;
         END;

         L := (L SHL 6) OR Status;
      END;

      WReg := L SHL 8;
   END;
END; (* ReaderDevice.AutoloadWord *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : ReaderDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION ReaderDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'READER';
END; (* ReaderDevice.DeviceID *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.MountTape
(* Function       : 
(**********************************************************************)
PROCEDURE ReaderDevice.MountTape (FileName: STRING);

BEGIN
   IF TapePresent THEN Close(DosFile);
   Assign(DosFile,FileName);
{$I-}
   Reset(DosFile,1);
{$I+}
   TapePresent := IOResult = 0;
   IF TapePresent THEN
   WITH State8000 DO
      IR := IR OR (LONGINT(1) SHL (31-_Int));

   BufGot := 0;
   BufLast := 0;
END; (* ReaderDevice.MountTape *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ReaderDevice.Configure
(* Function       : 
(**********************************************************************)
PROCEDURE ReaderDevice.Configure;

VAR
   ES: EntryScreen;

BEGIN
   InitEntryScreen(ES,' Mount paper tape, reader: ',DummyUserProc,LoadPostEdit,UR);
   ES.Process;
   IF ES.GetLastCommand <> ccQuit THEN MountTape(UR.FName);
   ES.Done;
END; (* ReaderDevice.Configure *)


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
   UR.FName := '';
   Exitsave := Exitproc;
   Exitproc := @UnitExit;

END; (* UnitEntry *)

BEGIN
   UnitEntry;
END. (* UNIT READER *)

