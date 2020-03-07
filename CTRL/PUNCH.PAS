(**********************************************************************)
(* Unit name      : PUNCH.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-03-09 22:06   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC2000 Paper Tape Punch simulator!
(*
(**********************************************************************)

{$F+}

UNIT PUNCH;


INTERFACE

USES
   Io;

TYPE
   RdBuf            =   ARRAY[0..0] OF BYTE;

   PunchDevicePtr  =  ^PunchDevice;

   PunchDevice     =   OBJECT (IoDevice)
                           TapePresent:  BOOLEAN;

                           CONSTRUCTOR Init(DevNo: WORD; Int: BYTE);
                           DESTRUCTOR Done;                  VIRTUAL;

                           PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                           PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                           PROCEDURE  Rd(Modif: BYTE);       VIRTUAL;
                           PROCEDURE  Wr(Modif: BYTE);       VIRTUAL;

                           FUNCTION   DeviceID: STRING;      VIRTUAL;
                          {FUNCTION   Configurable: BOOLEAN; VIRTUAL;}
                           PROCEDURE  Configure;             VIRTUAL;

                           PROCEDURE MountTape(FileName: STRING);
                        PRIVATE
                           _Int:  BYTE;
                           Status: LONGINT;
                           DosFile:      FILE;
                           BufP:   ^RdBuf;
                           BufGot : WORD;

                           FUNCTION FlushBuffer: BOOLEAN;
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
   INTERVENTION   = LONGINT(1) SHL 23;
   TIMER_ST       = LONGINT(1) SHL 21;
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
                   Rewrite(F,1);
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
   
   
(**********************************************************************)
(* Proc. Name     : PunchDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR PunchDevice.Init (DevNo: WORD; Int: BYTE);

BEGIN
   INHERITED Init(DevNo);
   _Int := Int;
   TapePresent := FALSE;
   Status := 0;
   BufGot := 0;

   IF NOT GetMemCheck(BufP,BufferSize) THEN
      FatalError('Tape Punch get buffer: No heap memory');

END; (* PunchDevice.Init *)

(**********************************************************************)
(* Proc. Name     : PunchDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR PunchDevice.Done;

BEGIN
   IF TapePresent THEN
   BEGIN
      IF FlushBuffer THEN;
      Close(DosFile);
   END;
   FreeMemCheck(BufP,BufferSize);
   INHERITED Done;
END; (* PunchDevice.Done *)

(**********************************************************************)
(* Proc. Name     : PunchDevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE PunchDevice.Sense (Modif: BYTE);

BEGIN
   State8000.Ex22 := 0;
   State8000.Ex23 := 0;
   WITH State8000, SrvcParam DO
   BEGIN
      WReg := Status;
      IF NOT TapePresent THEN WReg := WReg OR TIMER_ST;
      WReg := WReg SHL 8;
   END;
END; (* PunchDevice.Sense *)

(**********************************************************************)
(* Proc. Name     : PunchDevice.Control
(* Function       : 
(**********************************************************************)
PROCEDURE PunchDevice.Control (Modif: BYTE);

BEGIN
   State8000.Ex22 := 1;
   State8000.Ex23 := 0;
END; (* PunchDevice.Control *)

(**********************************************************************)
(* Proc. Name     : PunchDevice.Rd
(* Function       : 
(**********************************************************************)
PROCEDURE PunchDevice.Rd (Modif: BYTE);
BEGIN
   State8000.Ex22 := 1;
   State8000.Ex23 := 0;
END; (* PunchDevice.Rd *)


(**********************************************************************)
(* Proc. Name     : PunchDevice.Wr
(* Function       : 
(**********************************************************************)
PROCEDURE PunchDevice.Wr (Modif: BYTE);

VAR
   C: BYTE;
   EvenPar: BOOLEAN;

BEGIN
   State8000.Ex22 := 0;
   State8000.Ex23 := 0;
   Status := 0;

   IF NOT TapePresent THEN
   BEGIN
      Status := TIMER_ST;
      WITH State8000 DO
         IR := IR OR (LONGINT(1) SHL (31-_Int));
      EXIT;
   END;

   InterruptsOn;

   IF BufGot >= BufferSize THEN
   BEGIN
      IF NOT FlushBuffer THEN
      BEGIN
         Status := END_OF_TAPE;
         WITH State8000 DO
            IR := IR OR (LONGINT(1) SHL (31-_Int));
      END;
   END;

   C := Lo(State8000.SrvcParam.WReg SHR 8); 

   ASM
      xor   ah,ah
      mov   al,C
      and   al,7FH
      jnp   @OddP
      inc   ah
@OddP:mov   EvenPar,ah

   END;
   
   CASE Modif OF
      0: BEGIN  (* Write Odd *)
            BufP^[BufGot] := (C AND $7F) + (Ord(EvenPar) SHL 7);
         END;

      1: BEGIN  (* Write Even *)
            BufP^[BufGot] := (C AND $7F) + ((1-Ord(EvenPar)) SHL 7);
         END;

      2: BEGIN  (* Write General *)
            BufP^[BufGot] := C;
         END;
   END;

   Inc(BufGot);

   WITH State8000 DO
      IR := IR OR (LONGINT(1) SHL (31-_Int));

END; (* PunchDevice.Wr *)

(**********************************************************************)
(* Func. Name     : PunchDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION PunchDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'PUNCH';
END; (* PunchDevice.DeviceID *)


(**********************************************************************)
(* Proc. Name     : PunchDevice.MountTape
(* Function       : 
(**********************************************************************)
PROCEDURE PunchDevice.MountTape (FileName: STRING);

BEGIN
   IF TapePresent THEN Close(DosFile);
   Assign(DosFile,FileName);
{$I-}
   Rewrite(DosFile,1);
{$I+}
   TapePresent := IOResult = 0;
   BufGot := 0;
END; (* PunchDevice.MountTape *)

(**********************************************************************)
(* Proc. Name     : PunchDevice.Configure
(* Function       : 
(**********************************************************************)
PROCEDURE PunchDevice.Configure;

VAR
   ES: EntryScreen;

BEGIN
   InitEntryScreen(ES,' Mount paper tape, punch: ',DummyUserProc,LoadPostEdit,UR);
   ES.Process;
   IF ES.GetLastCommand <> ccQuit THEN MountTape(UR.FName);
   ES.Done;
END; (* PunchDevice.Configure *)

(**********************************************************************)
(* Proc. Name     : PunchDevice.FlushBuffer
(* Function       : 
(**********************************************************************)
FUNCTION PunchDevice.FlushBuffer: BOOLEAN;

VAR BufLast: WORD;

BEGIN
   IF (TapePresent) AND (BufGot > 0) THEN
   BEGIN
      BlockWrite(DosFile,BufP^,BufGot,BufLast);
      IF BufLast < BufGot THEN
      BEGIN
         TapePresent := FALSE;
         Close(DosFile);
         FlushBuffer := FALSE;
         EXIT;
      END;
      BufGot := 0;
   END;
   FlushBuffer := TRUE;
END; (* PunchDevice.FlushBuffer *)


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
   UR.FName := '';
   Exitsave := Exitproc;
   Exitproc := @UnitExit;

END; (* UnitEntry *)

BEGIN
   UnitEntry;
END. (* UNIT PUNCH *)

