(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : DOSDEV.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 93-02-23 22:05   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  DOS File interface device.
(*
(**********************************************************************)

{$F+}
{ $DEFINE LOG}

UNIT DOSDEV;


INTERFACE

USES
   OpRoot,
   Io;

CONST
   BufferSize  = 3*2048; (* MUST BE MULT. OF 3!! *)
   NameSize    = 81;   (* Chars in DOS file name, must be mult. of 3 *)

TYPE
   Buffer    =  ARRAY[0..BufferSize-1] OF BYTE;
   BufferPtr =  ^Buffer;




   DosDevicePtr     =   ^DosDevice;
   DosDevice        =   OBJECT (IoDevice)

                           CONSTRUCTOR Init(DevNo: WORD; Int: BYTE);
                           DESTRUCTOR Done; VIRTUAL;

                           PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                           PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                           FUNCTION   DeviceID: STRING;      VIRTUAL;

                        PRIVATE
                           DosFileName: STRING[NameSize];

                           DosFile:   FILE;
                           _Int:      BYTE;

                           Connected,
                           OutpMode,
                           TxtMode,
                           TxtDosMode,
                           EMSent,
                           Busy:   BOOLEAN;

                           CurrSize,
                           Status0,
                           Status4: LONGINT;

                           BufGot,
                           BufLast   :  WORD;

                           FBufferP,
                           CBufferP  :  BufferPtr;

                           PROCEDURE TransferSize(WReg: LONGINT);
                           PROCEDURE SetMode(WReg: LONGINT);
                           PROCEDURE InputData(WReg: LONGINT);
                           PROCEDURE OutputData(WReg: LONGINT);
                           PROCEDURE OpenF(WReg: LONGINT; Outp: BOOLEAN);
                           PROCEDURE CloseF(WReg: LONGINT);
                           PROCEDURE DataInterrupt;
                           FUNCTION  FlushBuffer: BOOLEAN;

                        END;



(*#PAGE*)
IMPLEMENTATION

USES
   OpString,
   Intf,
   OpInt,
   Scrn,
   Util;


CONST
   (* Sense0 status bits: *)

   INTERVENTION_0     =  LONGINT(1) SHL 23;
   PARITY_0           =  LONGINT(1) SHL 22;
   TIMER_0            =  LONGINT(1) SHL 21;
   OVERRUN_0          =  LONGINT(1) SHL 20;
   END_OF_DOC_0       =  LONGINT(1) SHL 18;
   LOCAL_0            =  LONGINT(1) SHL 15;
   FAULT_0            =  LONGINT(1) SHL 14;
   SYNC_ERROR_0       =  LONGINT(1) SHL 13;
   HEADS_MOVING_0     =  LONGINT(1) SHL 12;



{$IFDEF LOG}
VAR
   Log: TEXT;
CONST
   LogOpen: BOOLEAN = FALSE;
{$ENDIF}

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.TransferSize
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.TransferSize (WReg: LONGINT);

BEGIN
   CurrSize := (WReg SHR 8);
END; (* DosDevice.TransferSize *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.SetMode
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.SetMode (WReg: LONGINT);

BEGIN
   TxtDosMode := (WReg AND $700) = $400;
   TxtMode := TxtDosMode OR ((WReg AND $700) <> 0);
END; (* DosDevice.SetMode *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.OpenF
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.OpenF (WReg: LONGINT; Outp: BOOLEAN);

VAR
   CoreAddr: LONGINT;
   Name: STRING[NameSize];
   N: BYTE;
   NSize: WORD;

BEGIN
   IF Connected THEN
   BEGIN
      IF FlushBuffer THEN ;
{$I-}
      Close(DosFile);
{$I+}
      IF IOResult <> 0 THEN ;
      Connected := FALSE;
   END;

   NSize := (CurrSize SHR 1) * 3;
   IF (NSize = 0) OR (NSize > NameSize) THEN
   BEGIN
      Status0 := FAULT_0;
      Status4 := 0;
      DataInterrupt;
      Exit;
   END;
   CoreAddr := (WReg SHR 9 SHL 1);
   FromCoreTxt(CoreAddr,CurrSize SHR 1,@Name[1]);
   Name[0] := Chr(NSize);
   FOR N := NSize DOWNTO 1 DO IF Name[N] = #0 THEN Name[0] := Chr(N-1);

   Assign(DosFile,Name);
{$I-}
   IF Outp THEN Rewrite(DosFile,1) ELSE Reset(DosFile,1);
{$I+}
   IF IOResult=0 THEN
   BEGIN
      Status0 := 0;
      DosFileName := Name;
      Connected := TRUE;
      OutpMode := Outp;
      TxtMode := FALSE;
      TxtDosMode := FALSE;
      EMSent := FALSE;
      IF Outp THEN
      BEGIN
         BufGot := 0;
         BufLast := BufferSize-1;
      END ELSE
      BEGIN
         BufGot := BufferSize;
         BufLast := 0;
      END;
   END ELSE Status0 := INTERVENTION_0;

   Status4 := NSize;
   DataInterrupt;
END; (* DosDevice.OpenF *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.CloseF
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.CloseF (WReg: LONGINT);

BEGIN
   Status0 := 0;
   IF Connected THEN
   BEGIN
      IF NOT FlushBuffer THEN Status0 := FAULT_0 ELSE
      BEGIN
{$I-}
         Close(DosFile);
{$I+}
         IF IOResult<>0 THEN Status0 := FAULT_0;
      END;
      Connected := FALSE;
   END;
   DataInterrupt;
END; (* DosDevice.CloseF *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.InputData
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.InputData (WReg: LONGINT);

VAR
   Max,
   Cnt: WORD;
   C:   BYTE;

BEGIN
   Status0 := 0;
   Status4 := 0;
   IF (NOT Connected) OR OutpMode THEN
   BEGIN
      Status0 := INTERVENTION_0;
      DataInterrupt;
      EXIT;
   END;

   Max := (CurrSize SHR 1) * 3;
   IF Max > BufferSize THEN Max := BufferSize;
   IF Max = 0 THEN
   BEGIN
      DataInterrupt;
      Exit;
   END;

   InterruptsOn;
   Cnt := 0;

   REPEAT
      IF BufGot >= BufLast THEN
      BEGIN
         BufLast := 0;
         IF NOT EMSent THEN BlockRead(DosFile,FBufferP^,BufferSize,BufLast);
         IF BufLast = 0 THEN
         BEGIN
            IF EMSent OR NOT TxtMode THEN Status0 := END_OF_DOC_0 ELSE 
            BEGIN
               BufLast := 0;
               FBufferP^[0] := 25;
               EMSent := TRUE;
            END;
         END ELSE Dec(BufLast);
         BufGot := 0;
      END ELSE Inc(BufGot);

      IF Status0 = 0 THEN
      BEGIN
         C := FBufferP^[BufGot];
         IF TxtMode THEN
         BEGIN
            CASE C OF
               26: BEGIN
                      CBufferP^[Cnt] := 25;
                      Inc(Cnt);
                      Max := Cnt;
                      EMSent := TRUE;
                   END;

                0,
               13: ;

               ELSE
                   BEGIN
                      IF TxtDosMode
                        THEN CBufferP^[Cnt] := Pc2Rc[C]
                        ELSE CBufferP^[Cnt] := C;
                      Inc(Cnt);
                   END;
            END;
         END ELSE
         BEGIN
            CBufferP^[Cnt] := C;
            Inc(Cnt);
         END;
      END;

   UNTIL (Cnt>=Max) OR (Status0<>0);

   IF Cnt>0 THEN
   BEGIN
      WHILE (Cnt MOD 3) <> 0 DO
      BEGIN
         CBufferP^[Cnt] := 0;
         Inc(Cnt);
      END;

      InterruptsOff;
      ToCoreTxt(WReg SHR 9 SHL 1,Cnt DIV 3,CBufferP);
      InterruptsOn;
      Status0 := 0;
   END;

   Status4 := Cnt;
   DataInterrupt;

END; (* DosDevice.InputData *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.OutputData
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.OutputData (WReg: LONGINT);

VAR
   Max,
   Cnt: WORD;
   C:   BYTE;

   PROCEDURE Flush;
   BEGIN
      IF NOT FlushBuffer THEN
      BEGIN
         Status0 := FAULT_0;
         Max := Cnt;
      END;
   END;


BEGIN
   Status0 := 0;
   Status4 := 0;
   IF (NOT Connected) OR (NOT OutpMode) THEN
   BEGIN
      Status0 := INTERVENTION_0;
      DataInterrupt;
      EXIT;
   END;

   Max := (CurrSize SHR 1) * 3;
   IF Max > BufferSize THEN Max := BufferSize;
   IF Max = 0 THEN
   BEGIN
      DataInterrupt;
      Exit;
   END;

   FromCoreTxt(WReg SHR 9 SHL 1,Max DIV 3,CBufferP);

   InterruptsOn;
   Cnt := 0;

   REPEAT
      IF Status0 = 0 THEN
      BEGIN
         C := CBufferP^[Cnt];
         IF TxtMode THEN
         IF EMSent THEN Cnt := Max ELSE
         BEGIN
            CASE C OF
               25: BEGIN
                      Max := Cnt;
                      EMSent := TRUE;
                   END;


                0,
               13: ;

               10: BEGIN
                      IF BufGot >= BufferSize THEN Flush;
                      FBufferP^[BufGot] := 13;
                      Inc(BufGot);
                      IF BufGot >= BufferSize THEN Flush;
                      FBufferP^[BufGot] := 10;
                      Inc(BufGot);
                   END;

               ELSE
                   BEGIN
                      IF BufGot >= BufferSize THEN Flush;
                      IF TxtDosMode
                        THEN FBufferP^[BufGot] := Rc2Pc[C]
                        ELSE FBufferP^[BufGot] := C;
                      Inc(BufGot);
                   END;
            END;
         END ELSE
         BEGIN
            IF BufGot >= BufferSize THEN Flush;
            FBufferP^[BufGot] := C;
            Inc(BufGot);
         END;
      END;
      Inc(Cnt);

   UNTIL (Cnt>=Max) OR (Status0<>0);

   Status4 := Cnt;
   DataInterrupt;

END; (* DosDevice.OutputData *)



(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : DosDevice.FlushBuffer
(* Function       : 
(**********************************************************************)
FUNCTION DosDevice.FlushBuffer: BOOLEAN;

BEGIN
   IF Connected AND OutpMode AND (BufGot > 0) THEN
   BEGIN
      BlockWrite(DosFile,FBufferP^,BufGot,BufLast);
      IF BufLast < BufGot THEN
      BEGIN
         Connected := FALSE;
         Close(DosFile);
         FlushBuffer := FALSE;
         EXIT;
      END;
      BufGot := 0;
   END;
   FlushBuffer := TRUE;
END; (* DosDevice.FlushBuffer *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR DosDevice.Init (DevNo: WORD; Int: BYTE);

VAR
   I: BYTE;

BEGIN
   INHERITED Init(DevNo);
   _Int := Int;

   Connected := FALSE;
   Busy := FALSE;
   Status0 := 0;
   Status4 := 0;

   IF (NOT GetMemCheck(FBufferP,BufferSize)) OR
      (NOT GetMemCheck(CBufferP,BufferSize))
      THEN FatalError('DosDevice Init: No heap memory');

END; (* DosDevice.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR DosDevice.Done;

VAR 
   I: BYTE;

BEGIN
   INHERITED Done;
   IF Connected THEN
   BEGIN
      IF FlushBuffer THEN ;
{$I-}
      Close(DosFile);
{$I+}
      IF IOResult<>0 THEN ;
   END;
   FreeMemCheck(CBufferP,BufferSize);
   FreeMemCheck(FBufferP,BufferSize);
END; (* DosDevice.Done *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.Sense (Modif: BYTE);

VAR
   Status: LONGINT;

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := 0;

      CASE Modif SHL 2 OF

         0: IF Busy THEN
            BEGIN
               Ex23 := 1;
{$IFDEF LOG}
               WriteLn(Log,'Sense 0: Busy');
{$ENDIF}
               
            END ELSE
            BEGIN  (* Sense0 *)
               Ex23 := 0;
               Status := Status0;
               SrvcParam.Wreg := Status SHL 8;
{$IFDEF LOG}
               WriteLn(Log,'Sense 0: '+BinaryW(SrvcParam.Wreg SHR 16)+
                       BinaryB((SrvcParam.Wreg SHR 8) AND $FF));
{$ENDIF}
            END;

         4: IF Busy THEN
            BEGIN
               Ex23 := 1;
{$IFDEF LOG}
               WriteLn(Log,'Sense 4: Busy');
{$ENDIF}
               
            END ELSE
            BEGIN  (* Sense4 *)
               Ex23 := 0;
               Status := Status4;
               SrvcParam.Wreg := Status SHL 8;
{$IFDEF LOG}
               WriteLn(Log,'Sense 4: '+BinaryW(SrvcParam.Wreg SHR 16)+
                       BinaryB((SrvcParam.Wreg SHR 8) AND $FF));
{$ENDIF}
            END;

         ELSE ;

      END; (* CASE *)
   END;
END; (* DosDevice.Sense *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.Control
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.Control (Modif: BYTE);


BEGIN
   WITH State8000, SrvcParam DO
   BEGIN
{$IFDEF LOG}
      CASE (Modif SHL 2) + 1 OF
         9: Write(Log,'TransferSize ',Long2Str((WReg SHR 8) AND 511));
        13: Write(Log,'InputData ',Long2Str(WReg SHR 8));
        17: Write(Log,'OutputData ',Long2Str(WReg SHR 8));
        33: Write(Log,'ReturnToZero');
        45: Write(Log,'OpenIn');
        49: Write(Log,'OpenOut');
        54: Write(Log,'Close');
        ELSE Write(Log,'*** '+Long2Str((Modif SHL 2) + 1));
      END;

      IF Busy
         THEN WriteLn(Log,' *BUSY* ')
         ELSE WriteLn(Log);
{$ENDIF}

      Ex22 := 0;
      IF Busy THEN
      BEGIN
         Ex23 := 1;
         EXIT;
      END;

      Ex23 := 0;

      PushF;
      InterruptsOn;
      CASE (Modif SHL 2) + 1 OF
          5:    SetMode(WReg);
          9:    TransferSize(WReg);
         13:    InputData(WReg);
         17:    OutputData(WReg);
         45:    OpenF(WReg,FALSE);
         49:    OpenF(WReg,TRUE);
         53:    CloseF(WReg);
         ELSE ;
      END;
      PopF;
   END;
END; (* DosDevice.Control *)


(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : DosDevice.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION DosDevice.DeviceID: STRING;

BEGIN
   DeviceID := 'DOS Device';
END; (* DosDevice.DeviceID *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : DosDevice.DataInterrupt
(* Function       : 
(**********************************************************************)
PROCEDURE DosDevice.DataInterrupt;

BEGIN
{$IFDEF LOG}
   WriteLn(Log,'Data interrupt');
{$ENDIF}
   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_Int));
   Busy := FALSE;
END; (* DosDevice.DataInterrupt *)



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
   Assign(Log,'DOSDEV.LOG');
   Rewrite(Log);
   LogOpen := TRUE;
{$ENDIF}
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT DOSDEV *)

