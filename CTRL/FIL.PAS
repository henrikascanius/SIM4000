(**********************************************************************)
(* Unit name      : FIL.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-12-27 22:21   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Load and save core.
(*
(**********************************************************************)

{$F+}

UNIT FIL;


INTERFACE

USES
  Dos,
  OpInline,
  OpString,
  OpRoot,
  OpCrt,
  OpColor,
  OpAbsFld,
  OpCmd,
  OpField,
  OpFrame,
  OpWindow,
  OpSelect,
  OpEntry;


PROCEDURE SaveFile;
PROCEDURE LoadFile;
PROCEDURE AutoloadMonitor(FName: STRING; SetInitSwitch: BOOLEAN);

(*#PAGE*)
IMPLEMENTATION

USES
   Util,
   Popup,
   Win,
   Intf,
   Vcpi;

{Entry field constants}
const
  idFName                 = 0;
  idBase                  = idFName + 1;
  idLen                   = idBase + 1;

  Magic                   = 'IMG8000';


type
  UserRecord =
    record
      FName                 : string[30];
      Base                  : LongInt;
      Len                   : LongInt;
    end;
var
  Status : Word;
  UR     : UserRecord;

{$F+}
procedure DummyUserProc(ESP : EntryScreenPtr);
begin
end;

procedure SavePostEdit(ESP : EntryScreenPtr);
  {-Called just after a field has been edited}
begin
  with ESP^, UR do
  IF GetLastCommand <> ccQuit THEN
    case GetCurrentID of
      idFName : ;
      idBase  : BEGIN
                   Base := Base - (Base AND 1);
                   DrawField(idBase);
                END;

      idLen   : BEGIN
                   Len := Len + (Len AND 1);
                   IF Base+Len > CoreSize THEN Len := CoreSize - Base;
                   DrawField(idLen);
                END;

    end;
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
                   IF IOResult <> 0 THEN Err('Cannot open file: ') ELSE
                   BEGIN
                      BlockRead(F,S,Length(Magic)+1);
                      IF S <> Magic THEN Err('File not a RC8000 core image: ') ELSE
                      BEGIN
                         BlockRead(F,UR.Base,4);
                         BlockRead(F,UR.Len,4);
                         IF Base > CoreSize-2 THEN Base := 0;
                         IF Len + Base > CoreSize THEN Len  := CoreSize - Base;
                      END;
                      Close(F);
{$I+}
                       DrawField(idBase);
                       DrawField(idLen);
                   END;
                END;
      idBase,
      idLen   : SavePostEdit(ESP);
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
   Y2 := Y1 + 3;

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

      AddSimpleLongField(
         'Addr:   ', 3, 2, 
         '9', 3, 11, 7, 
         0, 0, CoreSize-2, UR.Base);

      AddLongField(
         'HWords: ', 4, 2, 
         '9999999', 4, 11, 
         0, 2, CoreSize, UR.Len);

      IF RawError <> 0 THEN
         FatalError('Init entry screen');

   END;
END; (* InitEntryScreen *)

(**********************************************************************)
(* Proc. Name     : DoSave
(* Function       : See SaveFile
(**********************************************************************)
PROCEDURE DoSave;

CONST
   BlkSize  = 2048;        (* RC8000 words *)
   BlkSizeF = BlkSize*3;   (* 3 bytes/word *)

TYPE
   Buf = ARRAY[0..0] OF BYTE;

VAR 
   F: FILE;
   CoreBufP,
   FileBufP: ^Buf;
   Blk,
   Addr,
   Words: LONGINT;
   I,J: WORD;
   S: STRING;

BEGIN
   Assign(F,UR.FName);
{$I-}
   Rewrite(F,1);
   IF IOResult <> 0 THEN
   BEGIN
      PopErr('Could not write to '+UR.FName);
      Exit;
   END;

   IF NOT GetMemCheck(CoreBufP,BlkSize*4) OR
     (NOT GetMemCheck(FileBufP,BlkSizeF)) THEN
         FatalError('DoSave: No heap memory');

   S := Magic;
   BlockWrite(F,S,Length(S)+1);
   BlockWrite(F,UR.Base,4);
   BlockWrite(F,UR.Len,4);

   Addr  := UR.Base;
   Words := UR.Len SHR 1;

   WHILE Words > 0 DO
   BEGIN
      IF Words > BlkSize 
         THEN Blk := BlkSize
         ELSE Blk := Words;

      FromCore(Addr,Blk,CoreBufP);
      J := 0;
      I := 1;
      WHILE I < Blk SHL 2 DO
      BEGIN
         FileBufP^[J]   := CoreBufP^[I];
         FileBufP^[J+1] := CoreBufP^[I+1];
         FileBufP^[J+2] := CoreBufP^[I+2];
         Inc(I,4);
         Inc(J,3);
      END;

      BlockWrite(F,FileBufP^,Blk*3,I);
      IF I <> Blk*3 THEN
      BEGIN
         PopErr('Disk full?');
         Words := 0;
      END ELSE
      BEGIN
         Inc(Addr,Blk SHL 1);
         Dec(Words,Blk);
      END;
   END;

   Close(F);
   IF IOResult <> 0 THEN
      PopErr('On Close: Disk full?');

   FreeMemCheck(CoreBufP,BlkSize*4);
   FreeMemCheck(FileBufP,BlkSizeF);

{$I+}
END; (* DoSave *)


(**********************************************************************)
(* Proc. Name     : SaveFile
(* Function       : Saves a block of core in a file.
(**********************************************************************)
PROCEDURE SaveFile;

VAR
   ES: EntryScreen;

BEGIN
   InitEntryScreen(ES,' Save file: ',DummyUserProc,SavePostEdit,UR);
   ES.Process;
   IF ES.GetLastCommand <> ccQuit THEN DoSave;
   ES.Done;
END; (* SaveFile *)

(**********************************************************************)
(* Proc. Name     : DoLoad
(* Function       : See LoadFile
(**********************************************************************)
PROCEDURE DoLoad;

CONST
   BlkSize  = 2048;        (* RC8000 words *)
   BlkSizeF = BlkSize*3;   (* 3 bytes/word *)

TYPE
   Buf = ARRAY[0..0] OF BYTE;

VAR 
   F: FILE;
   CoreBufP,
   FileBufP: ^Buf;
   Blk,
   Addr,
   Words: LONGINT;
   I,J: WORD;

BEGIN
   Assign(F,UR.FName);
{$I-}
   Reset(F,1);
   IF IOResult <> 0 THEN
   BEGIN
      PopErr('Could not open '+UR.FName);
      Exit;
   END;

   IF NOT GetMemCheck(CoreBufP,BlkSize*4) OR
     (NOT GetMemCheck(FileBufP,BlkSizeF)) THEN
         FatalError('DoLoad: No heap memory');

   BlockRead(F,FileBufP^,Length(Magic)+1);
   BlockRead(F,FileBufP^,8);  (* Base,len not used here (read by post edit *)

   FOR I := 0 TO (BlkSize-1) SHL 2 DO CoreBufP^[I] := 0;  (* 8 LSB must be 0 *)

   Addr  := UR.Base;
   Words := UR.Len SHR 1;

   WHILE Words > 0 DO
   BEGIN
      IF Words > BlkSize 
         THEN Blk := BlkSize
         ELSE Blk := Words;

      BlockRead(F,FileBufP^,Blk*3,I);
      IF I <> Blk*3 THEN
      BEGIN  (* EOF *)
         Blk := I DIV 3;
         Words := Blk;
      END;

      J := 0;
      I := 1;
      WHILE I < Blk SHL 2 DO
      BEGIN
         CoreBufP^[I]   := FileBufP^[J];
         CoreBufP^[I+1] := FileBufP^[J+1];
         CoreBufP^[I+2] := FileBufP^[J+2];
         Inc(I,4);
         Inc(J,3);
      END;

      ToCore(Addr,Blk,CoreBufP);
      Inc(Addr,Blk SHL 1);
      Dec(Words,Blk);
   END;

   Close(F);

   FreeMemCheck(CoreBufP,BlkSize*4);
   FreeMemCheck(FileBufP,BlkSizeF);

{$I+}
END; (* DoLoad *)

(**********************************************************************)
(* Proc. Name     : AutoloadMonitor   
(* Function       : Autoloads monitor placed in a DOS file
(**********************************************************************)
PROCEDURE AutoloadMonitor(FName: STRING; SetInitSwitch: BOOLEAN);

CONST
   BlkSize  = 2048;        (* RC8000 words *)
   BlkSizeF = BlkSize*3;   (* 3 bytes/word *)

TYPE
   Buf = ARRAY[0..0] OF BYTE;

VAR 
   F: FILE;
   CoreBufP,
   FileBufP: ^Buf;
   L,
   LoadAddr,
   Blk,
   Addr,
   Words: LONGINT;
   I,J: WORD;

BEGIN
   IF Pos('\',FName) = 0 THEN FName := JustPathname(ParamStr(0)) + '\' + FName;
   Assign(F,FName);
{$I-}
   Reset(F,1);
   IF IOResult <> 0 THEN
   BEGIN
      PopErr('Could not open '+FName);
      Exit;
   END;

   IF NOT GetMemCheck(CoreBufP,BlkSize*4) OR
     (NOT GetMemCheck(FileBufP,BlkSizeF)) THEN
         FatalError('AutoloadMonitor: No heap memory');


   FOR I := 0 TO (BlkSize-1) SHL 2 DO CoreBufP^[I] := 0;  (* 8 LSB must be 0 *)

   LoadAddr  := CoreSize DIV 2;
   Addr := LoadAddr;
   Words := FileSize(F) DIV 3;
   IF Addr + (Words SHL 1) > CoreSize
      THEN FatalError('No room for monitor in core');

   WHILE Words > 0 DO
   BEGIN
      IF Words > BlkSize 
         THEN Blk := BlkSize
         ELSE Blk := Words;

      BlockRead(F,FileBufP^,Blk*3,I);
      IF I <> Blk*3 THEN
      BEGIN  (* EOF *)
         Blk := I DIV 3;
         Words := Blk;
      END;

      J := 0;
      I := 1;
      WHILE I < Blk SHL 2 DO
      BEGIN
         CoreBufP^[I+2]   := FileBufP^[J];
         CoreBufP^[I+1] := FileBufP^[J+1];
         CoreBufP^[I] := FileBufP^[J+2];
         Inc(I,4);
         Inc(J,3);
      END;

      ToCore(Addr,Blk,CoreBufP);
      Inc(Addr,Blk SHL 1);
      Dec(Words,Blk);
   END;

   Close(F);

   FreeMemCheck(CoreBufP,BlkSize*4);
   FreeMemCheck(FileBufP,BlkSizeF);

   IF SetInitSwitch THEN
   BEGIN  (* Set disc load flag for autostart *)
      L := 2 SHL 8;
      ToCore(LoadAddr+2,1,@L);
   END;

   L := (LoadAddr + 6) SHL 8;
   ToCore(14,1,@L);   (* Set start key entry = monitor entry point *)
   AutoStart := TRUE;
{$I+}
END; (* AutoloadMonitor *)

(**********************************************************************)
(* Proc. Name     : LoadFile
(* Function       : Loads a block of core in a file.
(**********************************************************************)
PROCEDURE LoadFile;

VAR
   ES: EntryScreen;

BEGIN
   InitEntryScreen(ES,' Load file: ',DummyUserProc,LoadPostEdit,UR);
   ES.Process;
   IF ES.GetLastCommand <> ccQuit THEN DoLoad;
   ES.Done;
END; (* LoadFile *)


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

   {initialize user record}
   FillChar(UR, SizeOf(UR), 0);
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT FIL *)

