(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : RC433.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 94-11-08 17:48 HJ Initial version
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  High speed disk simulator w. emulator-specific interface
(*
(**********************************************************************)

{$F+}
{$X+}
{ $DEFINE LOG}
{ $DEFINE HLLOG} (* High level log, LOG must be defined too *)

UNIT RC433;


INTERFACE

USES
   OpRoot,
   Io;

CONST
   DosBytesPerSec =  768;
   BufferSizeSecs =  9;
   BufferSize     =  BufferSizeSecs*DosBytesPerSec;

TYPE
   TrackBuffer    =  ARRAY[0..BufferSize-1] OF BYTE;
   TrackBufferPtr =  ^TrackBuffer;


   RC433xPtr        =   ^RC433x;

   RC433x           =   OBJECT (IoDevice)
      CONSTRUCTOR Init(DevNo: WORD; Path: STRING);
      DESTRUCTOR Done; VIRTUAL;

      PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
      PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
      FUNCTION   DeviceID: STRING;      VIRTUAL;

   PRIVATE
      DosFile        :  FILE;
      DosFileName    :  STRING[32];
      MaxSecPresent  :  WORD;

      Status0        :  LONGINT;

      TrackBufferP   :  TrackBufferPtr;

      PROCEDURE InputData(CoreAddr,FirstSec: LONGINT; SecCnt: WORD); VIRTUAL;
      PROCEDURE OutputData(CoreAddr,FirstSec: LONGINT; SecCnt: WORD);VIRTUAL;
      FUNCTION  Expand(Sec: LONGINT): BOOLEAN;
   END;


                        (* RAM-based disc drive: *)

   RC433xRamPtr     =   ^RC433xRam;

   RC433xRam        =   OBJECT (RC433x)
      Slctr:  WORD;
      CONSTRUCTOR Init(DevNo: WORD; NoOfSec: LONGINT);
      DESTRUCTOR Done; VIRTUAL;

      PROCEDURE InputData(CoreAddr,FirstSec: LONGINT; SecCnt: WORD);   VIRTUAL;
      PROCEDURE OutputData(CoreAddr,FirstSec: LONGINT; SecCnt: WORD);  VIRTUAL;
   END;




(*#PAGE*)
IMPLEMENTATION

USES
   OpCrt,
   OpString,
   Intf,
   Vcpi,
   OpInt,
   Util;


CONST
   (* Sense0 status bits: *)

   INTERVENTION_0     =  LONGINT(1) SHL 23;
   PARITY_0           =  LONGINT(1) SHL 22;
   SYNC_ERROR_0       =  LONGINT(1) SHL 21;
   OVERRUN_0          =  LONGINT(1) SHL 20;

TYPE

   (* Format of transformed i/o message to disc driver in RC4000 monitor.
      Most fields are only relevant to the monitor, not here. *)

   XferMess  = RECORD
                  OpTries  : LONGINT;
                  FirstCore: LONGINT;
                  NotXfered: LONGINT;
                  FirstSegm: LONGINT;
                  Remainder: LONGINT;
                  CylNo    : LONGINT;
                  XferedTot: LONGINT;
                  NextSegm : LONGINT;
               END;


{$IFDEF LOG}
VAR
   Log: TEXT;
CONST
   LogOpen: BOOLEAN = FALSE;
{$ENDIF}

CONST
   CommonTrackBufferP: POINTER = NIL;


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433x.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR RC433x.Init (DevNo: WORD; Path: STRING);

VAR
   Size: LONGINT;

BEGIN
   DosFileName := '';
   INHERITED Init(DevNo);
   IF CommonTrackBufferP = NIL THEN
   BEGIN
      IF NOT GetMemCheck(CommonTrackBufferP,BufferSize)
         THEN FatalError('RC433x Init: No heap memory');
   END;

   Status0 := 0;
   TrackBufferP := CommonTrackBufferP;
   Assign(DosFile,Path);
{$I-}
   Reset(DosFile,1);
{$I+}
   IF IOResult <> 0 THEN
      FatalError('Cannot open file for virt. disk: '+Path);

   DosFileName := Path;  (* AFTER file is opened (see Done) *)
   Size := FileSize(DosFile);
   MaxSecPresent := Size DIV DosBytesPerSec -1;
   IF MaxSecPresent < 255 THEN
   BEGIN
      IF NOT Expand(255) THEN
         FatalError('Virt. disk file too small: '+DosFileName);
      Size := FileSize(DosFile);
   END;
   IF Size <> (LONGINT(MaxSecPresent)+1)*DosBytesPerSec THEN
   BEGIN
      Expand(MaxSecPresent+1);
      WriteLn('---> Size error in disc image file ',DosFileName,' repaired');
      WriteLn('Press any key...');
      WHILE KeyPressed DO ReadKeyWord;
      WHILE NOT KeyPressed DO;
      ReadKeyWord;
   END;
END; (* RC433x.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433x.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR RC433x.Done;

BEGIN
   IF DosFIleName <> ''
      THEN Close(DosFile);
END; (* RC433x.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433x.InputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC433x.InputData (CoreAddr,FirstSec: LONGINT; SecCnt: WORD);

VAR
   Sec: LONGINT;
   Res,
   Blk: WORD;

BEGIN
   Status0 := 0;
   IF SecCnt = 0 THEN EXIT;
   Seek(DosFile,FirstSec*DosBytesPerSec);
   Sec := FirstSec;

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'I: Device: ',_DevNo,
           ' Segm: ',Sec:6,
           ' Size: ',SecCnt:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Sec > MaxSecPresent THEN
      BEGIN   (* Read beyond the part of disc phys. present in DOS file *)
         EXIT;  (* Do nothing *)
      END;

      Blk := SecCnt;
      IF Blk > BufferSizeSecs THEN Blk := BufferSizeSecs;
      BlockRead(DosFile,TrackBufferP^,Blk*DosBytesPerSec,Res);
      IF Blk*DosBytesPerSec <> Res THEN 
      BEGIN  (* End of file *)
         Blk := Res DIV DosBytesPerSec;
         SecCnt := Blk;
      END;

      InterruptsOff;
      ToCoreP(CoreAddr,Blk SHL 8,TrackBufferP);
      InterruptsOn;

      Inc(CoreAddr,Blk SHL 9);
      Dec(SecCnt,Blk);
      Inc(Sec,Blk);
   END;

END; (* RC433x.InputData *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433x.OutputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC433x.OutputData (CoreAddr,FirstSec: LONGINT; SecCnt: WORD);

VAR
   Sec: LONGINT;
   Res,
   Blk: WORD;

BEGIN
   Status0 := 0;
   IF SecCnt = 0 THEN EXIT;

   Seek(DosFile,FirstSec*DosBytesPerSec);
   Sec := FirstSec;

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'O: Device: ',_DevNo,
           ' Segm: ',Sec:6,
           ' Size: ',SecCnt:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Sec > MaxSecPresent THEN
      BEGIN
         IF NOT Expand(Sec) THEN
         BEGIN
            Status0 := PARITY_0;
            EXIT;
         END;
         Seek(DosFile,Sec*DosBytesPerSec);
      END;

      Blk := SecCnt;
      IF Blk > BufferSizeSecs THEN Blk := BufferSizeSecs;

      InterruptsOff;
      FromCoreP(CoreAddr,Blk SHL 8,TrackBufferP);
      InterruptsOn;

      BlockWrite(DosFile,TrackBufferP^,Blk*DosBytesPerSec,Res);
      IF Blk*DosBytesPerSec <> Res THEN
      BEGIN
         Status0 := PARITY_0;
         EXIT;
      END;

      Inc(CoreAddr,Blk SHL 9);
      Dec(SecCnt,Blk);
      Inc(Sec,Blk);
   END;

END; (* RC433x.OutputData *)



(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : RC433x.Expand
(* Function       : Expands the dos file to cyl cylinders
(**********************************************************************)
FUNCTION RC433x.Expand (Sec: LONGINT): BOOLEAN;

VAR
   Exp,
   Size,
   NewSize: LONGINT;

   I,
   Result,
   Blk: WORD;

BEGIN
   Expand := TRUE;
   IF MaxSecPresent >= Sec THEN EXIT;
   Size := FileSize(DosFile);  (* Take care of illegal size *)
   NewSize := (Sec+1)*DosBytesPerSec;
   Seek(DosFile,Size);
   Exp := NewSize-Size;

{$IFDEF LOG}
{$IFNDEF HLLOG}
   WriteLn(Log,'Expand: MaxSecPresent=',MaxSecPresent,
          '  Sec=',Sec,'  Size=',Size,' NewSize=',Newsize,
          ' Exp=',Exp);
{$ENDIF}
{$ENDIF}

   FOR I := 0 TO BufferSize-1 DO TrackBufferP^[I] := 0;

   WHILE Exp > 0 DO
   BEGIN
      IF Exp > BufferSize THEN Blk := BufferSize ELSE Blk := Exp;
      BlockWrite(DosFile,TrackBufferP^,Blk,Result);
      IF Result <> Blk THEN
      BEGIN
         Seek(DosFile,Size);
         Truncate(DosFile);
         Expand := FALSE;
         EXIT;
      END;
      Dec(Exp,Blk);
   END;

   MaxSecPresent := Sec;

END; (* RC433x.Expand *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433xRam.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR RC433xRam.Init (DevNo: WORD; NoOfSec: LONGINT);

BEGIN
   IoDevice.Init(DevNo);
   IF CommonTrackBufferP = NIL THEN
   BEGIN
      IF NOT GetMemCheck(CommonTrackBufferP,BufferSize)
         THEN FatalError('RC433x Init: No heap memory');
   END;
   TrackBufferP := CommonTrackBufferP;

   Status0 := 0;

   Slctr := AllocateXtraSegment((NoOfSec*768+4095) 
                                 DIV 4096);
   MaxSecPresent := NoOfSec-1;

END; (* RC433xRam.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433xRam.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR RC433xRam.Done;

BEGIN
END; (* RC433xRam.Done *)



(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433xRam.InputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC433xRam.InputData (CoreAddr,FirstSec: LONGINT; SecCnt: WORD);

VAR
   DiscPos,
   Sec: LONGINT;
   Blk: WORD;

BEGIN
   Status0 := 0;
   IF SecCnt = 0 THEN EXIT;
   Sec := FirstSec;
   DiscPos := Sec*768;

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'I: Device: ',_DevNo,
           ' Segm: ',Sec:6,
           ' Size: ',SecCnt:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Sec > MaxSecPresent THEN
      BEGIN   (* Read beyond the part of disc phys. present in DOS file *)
         EXIT;  (* Do nothing *)
      END;

      Blk := SecCnt;
      IF Blk > BufferSizeSecs THEN Blk := BufferSizeSecs;

      InterruptsOff;
      ToCorePFromXtra(Slctr,CoreAddr,Blk SHL 8,DiscPos);
      InterruptsOn;

      Inc(CoreAddr,Blk SHL 9);
      Inc(DiscPos,Blk*768);
      Dec(SecCnt,Blk);
      Inc(Sec,Blk);
   END;

END; (* RC433xRam.InputData *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433xRam.OutputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC433xRam.OutputData (CoreAddr,FirstSec: LONGINT; SecCnt: WORD);

VAR
   DiscPos,
   Sec: LONGINT;
   Blk: WORD;

BEGIN
   Status0 := 0;
   IF SecCnt = 0 THEN EXIT;

   Sec := FirstSec;
   DiscPos := Sec*768;

   IF Sec+SecCnt > MaxSecPresent+1 THEN
   BEGIN
      Status0 := PARITY_0;
      EXIT;
   END;


{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'O: Device: ',_DevNo,
           ' Segm: ',Sec:6,
           ' Size: ',SecCnt:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      Blk := SecCnt;
      IF Blk > BufferSizeSecs THEN Blk := BufferSizeSecs;

      InterruptsOff;
      FromCorePToXtra(Slctr,CoreAddr,Blk SHL 8,DiscPos);
      InterruptsOn;

      Inc(DiscPos,Blk*768);
      Inc(CoreAddr,Blk SHL 9);
      Dec(SecCnt,Blk);
      Inc(Sec,Blk);
   END;

END; (* RC433xRam.OutputData *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433x.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE RC433x.Sense (Modif: BYTE);

VAR
   Status: LONGINT;

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;
      Ex23 := 0;
      Status := Status0;
      SrvcParam.Wreg := Status SHL 8;

{$IFDEF LOG}
      WriteLn(Log,'Sense 0: '+BinaryW(SrvcParam.Wreg SHR 16)+
               BinaryB((SrvcParam.Wreg SHR 8) AND $FF));
{$ENDIF}

   END;


END; (* RC433x.Sense *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC433x.Control
(* Function       : 
(**********************************************************************)
PROCEDURE RC433x.Control (Modif: BYTE);

VAR 
   Mess : XferMess;
   CoreAddr,
   FirstSeg:   LONGINT;
   Segs:       WORD;
   Op:         BYTE;

BEGIN
   WITH State8000, SrvcParam DO
   BEGIN
      IF Modif = 0 THEN
      BEGIN
         CoreAddr := WReg SHR 9 SHL 1;
         IF CoreAddr+16 > CoreSize THEN
         BEGIN  (* Bad ref. to buffer *)
            WReg := $8000000;
            EXIT;
         END;
         FromCore(CoreAddr,8,@Mess);
         WITH Mess DO
         BEGIN
            CoreAddr := FirstCore SHR 9 SHL 1;
            FirstSeg := FirstSegm SHR 8;
            Segs     := XFeredTot SHR 20;
            Op       := OpTries SHR 20;
         END;
      END;

{$IFDEF LOG}
{$IFNDEF HLLOG}
      CASE (Modif SHL 2) + 1 OF
         1: BEGIN
               IF Op=3 THEN Write(Log,'Input  ') ELSE
               IF Op=5 THEN Write(Log,'Output ') ELSE
                            Write(Log,'?? Op=',Op);
               WriteLn(Log,' First segm = ',FirstSeg:6,
                           ' No.Segm = ',Segs:5,
                           ' Addr = ',CoreAddr);
            END;
        ELSE WriteLn(Log,'Ignored: '+Long2Str((Modif SHL 2) + 1));
      END;

{$ENDIF}
{$ENDIF}

      Ex22 := 0;
      Ex23 := 0;

      PushF;
      InterruptsOn;
      IF Modif = 0 THEN
      BEGIN
         IF CoreAddr+(Segs SHL 9) <= CoreSize THEN
         BEGIN
            IF Op = 3 THEN InputData(CoreAddr,FirstSeg,Segs) ELSE
            IF Op = 5 THEN OutputData(CoreAddr,FirstSeg,Segs) ELSE
               Status0 := INTERVENTION_0;
         END ELSE Status0 := INTERVENTION_0;
         WReg := Status0 SHL 8;
      END;
      PopF;
   END;
END; (* RC433x.Control *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : RC433x.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION RC433x.DeviceID: STRING;

BEGIN
   DeviceID := 'DISCx';
END; (* RC433x.DeviceID *)


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
{$IFDEF LOG}
   IF LogOpen THEN Close(Log);
{$ENDIF}
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

{$IFDEF LOG}
   Assign(Log,'RC433x.LOG');
   Rewrite(Log);
   LogOpen := TRUE;
{$ENDIF}
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT RC433x *)

