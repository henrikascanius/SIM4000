(**********************************************************************)
(* Unit name      : RC4818.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 94-05-13 23:33   HJ Max. size ch. from 511 to 4095 segm.
(* 93-12-07 21:35   HJ Repair size of DOS files (RC4819.Init).
(* 93-11-01 21:14   HJ Bug fix: MaxCylPresent calc. corrected (RC4819.Init).
(* 93-02-23 22:05   HJ Initial version  0.1
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC4818/4819 emulation.
(*
(**********************************************************************)

{$F+}
{$X+}
{ $DEFINE LOG}
{ $DEFINE HLLOG} (* High level log, LOG must be defined too *)
{ $DEFINE NOHDINT}

UNIT RC4818;


INTERFACE

USES
   OpRoot,
   Io;

CONST
   DosBytesPerSec =  768;
   BytesPerTrack  =  9*DosBytesPerSec;

TYPE
   TrackBuffer    =  ARRAY[0..BytesPerTrack-1] OF BYTE;
   TrackBufferPtr =  ^TrackBuffer;


   DFC403DevicePtr  =  ^DFC403Device;
   RC4819Ptr        =   ^RC4819;

   RC4819           =   OBJECT (Root)
                           CONSTRUCTOR Init(Path: STRING; DFCPtr: DFC403DevicePtr);
                           DESTRUCTOR Done; VIRTUAL;

                        PRIVATE
                           MaxHead,
                           MaxCyl,
                           MaxSec         :  WORD;

                           FirstCyl,
                           CurrHead,
                           CurrCyl,
                           CurrSec        :  WORD;

                           CurrSize       :  WORD;

                           DosFile        :  FILE;
                           DosFileName    :  STRING[32];
                           MaxCylPresent  :  WORD;

                           TrackBufferP   :  TrackBufferPtr;
                           DFC            :  DFC403DevicePtr;

                           UnitStatus0,
                           UnitStatus32   :  LONGINT;

                           PROCEDURE TransferFirst(Wreg: LONGINT);
                           PROCEDURE TransferSize(Wreg: LONGINT);
                           PROCEDURE InputData(Wreg: LONGINT);    VIRTUAL;
                           PROCEDURE OutputData(Wreg: LONGINT);   VIRTUAL;
                           PROCEDURE InputAddress(Wreg: LONGINT);
                           PROCEDURE OutputAddress(Wreg: LONGINT);
                           PROCEDURE ReturnToZero;
                           PROCEDURE TransferForward(Wreg: LONGINT);
                           PROCEDURE TransferReverse(Wreg: LONGINT);
                           FUNCTION  Expand(Cyl: WORD): BOOLEAN;

                           PROCEDURE SetStatusBits(Stat0,Stat32: LONGINT);
                           PROCEDURE ClearStatusBits(Stat0,Stat32: LONGINT);
                           PROCEDURE LoadCSA;
                           PROCEDURE DataInterrupt(Stat0,Stat32: LONGINT);
                           PROCEDURE HeadInterrupt(Stat0,Stat32: LONGINT);
                        END;

                        (* RAM-based disc drive *)

   RC4819RamPtr     =   ^RC4819Ram;

   RC4819Ram        =   OBJECT (RC4819)
                           Slctr:  WORD;
                           CONSTRUCTOR Init(NoOfCyl: WORD; DFCPtr: DFC403DevicePtr);
                           DESTRUCTOR Done; VIRTUAL;

                           PROCEDURE InputData(Wreg: LONGINT);   VIRTUAL;
                           PROCEDURE OutputData(Wreg: LONGINT);  VIRTUAL;
                        END;


   DFC403Device     =   OBJECT (IoDevice)

                           CONSTRUCTOR Init(DevNo: WORD;
                                            DataInt,HeadInt: BYTE);
                           DESTRUCTOR Done; VIRTUAL;
                           FUNCTION   IncludeDrive(UnitNo: BYTE;
                                                   UP: RC4819Ptr): BOOLEAN;

                           PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                           PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                           FUNCTION   DeviceID: STRING;      VIRTUAL;

                        PRIVATE
                           _HeadInt,
                           _DataInt:  BYTE;

                           Drives:  ARRAY[0..7] OF RC4819Ptr;

                           CommandReg,
                           UnitReg:   BYTE;

                           HeadIntPending,
                           Busy:   BOOLEAN;

                           Status0,
                           Status32: LONGINT;

                           TrackBufferP   :  TrackBufferPtr;

                           PROCEDURE HeadInterrupt;
                           PROCEDURE DataInterrupt;
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
   TIMER_0            =  LONGINT(1) SHL 21;
   OVERRUN_0          =  LONGINT(1) SHL 20;
   LOCAL_0            =  LONGINT(1) SHL 15;
   FAULT_0            =  LONGINT(1) SHL 14;
   SYNC_ERROR_0       =  LONGINT(1) SHL 13;
   HEADS_MOVING_0     =  LONGINT(1) SHL 12;


   (* Sense32 status bits: *)

   WRONG_2ND_INDEX_32 =  LONGINT(1) SHL 8;
   ADDRESS_ERROR_32   =  LONGINT(1) SHL 7;
   DROP_OUT_32        =  LONGINT(1) SHL 6;
   SEEK_ERROR_32      =  LONGINT(1) SHL 5;
   FAULT_32           =  LONGINT(1) SHL 4;

   SENSE0_DFC_BITS    =  PARITY_0 + TIMER_0 + OVERRUN_0;
   SENSE0_UNIT_BITS   =  INTERVENTION_0 + LOCAL_0 + FAULT_0 + HEADS_MOVING_0;
   SENSE32_DFC_BITS   =  WRONG_2ND_INDEX_32 + ADDRESS_ERROR_32;
   SENSE32_UNIT_BITS  =  SEEK_ERROR_32 + FAULT_32;

   SYNC_ERROR_BITS    =  WRONG_2ND_INDEX_32 + ADDRESS_ERROR_32 + DROP_OUT_32 +
                         SEEK_ERROR_32;
                         

{$IFDEF LOG}
VAR
   Log: TEXT;
CONST
   LogOpen: BOOLEAN = FALSE;
{$ENDIF}

(**********************************************************************)
(* Proc. Name     : RC4819.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR RC4819.Init (Path: STRING; DFCPtr: DFC403DevicePtr);

VAR
   Size: LONGINT;

BEGIN
   INHERITED Init;
   DFC := DFCPtr;
   TrackBufferP := DFCPtr^.TrackBufferP;
   DosFileName := Path;
   Assign(DosFile,DosFileName);
{$I-}
   Reset(DosFile,1);
{$I+}
   IF IOResult <> 0 THEN
      FatalError('Cannot open file for virt. disk: '+DosFileName);

      (* RC4819 phys. parameters *)
   MaxHead := 19;
   MaxCyl  := 405;
   MaxSec  := 8;

   FirstCyl := 0;
   CurrHead := 0;
   CurrCyl  := 0;
   CurrSec  := 0;
   CurrSize := 0;
   UnitStatus0 := 0;
   UnitStatus32 := 0;

   Size := FileSize(DosFile);
   MaxCylPresent := (Size DIV (LONGINT(DosBytesPerSec)*(MaxHead+1)*(MaxSec+1))) - 1;
   IF MaxCylPresent < 5 THEN
   BEGIN
      IF NOT Expand(5) THEN
         FatalError('Virt. disk file too small: '+DosFileName);
      Size := FileSize(DosFile);
   END;
   IF Size <> (LONGINT(MaxCylPresent)+1)*DosBytesPerSec*(MaxHead+1)*(MaxSec+1) THEN
   BEGIN
      Expand(MaxCylPresent+1);
      WriteLn('---> Size error in disc image file ',DosFileName,' repaired');
      WriteLn('Press any key...');
      WHILE KeyPressed DO ReadKeyWord;
      WHILE NOT KeyPressed DO;
      ReadKeyWord;
   END;
END; (* RC4819.Init *)

(**********************************************************************)
(* Proc. Name     : RC4819.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR RC4819.Done;

BEGIN
   Close(DosFile);
END; (* RC4819.Done *)

(**********************************************************************)
(* Proc. Name     : RC4819.TransferFirst
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.TransferFirst (WReg: LONGINT);

BEGIN
   FirstCyl := (WReg SHR 20) AND 511;
   CurrHead := (WReg SHR 14) AND 63;
   CurrSec  := (WReg SHR 8)  AND 31;

   IF CurrHead > MaxHead THEN CurrHead := MaxHead;
   IF CurrSec  > MaxSec  THEN CurrSec  := MaxSec;
END; (* RC4819.TransferFirst *)

(**********************************************************************)
(* Proc. Name     : RC4819.TransferSize
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.TransferSize (WReg: LONGINT);

BEGIN
   CurrSize := (WReg SHR 8) AND 4095;
END; (* RC4819.TransferSize *)

(**********************************************************************)
(* Proc. Name     : RC4819.InputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.InputData (WReg: LONGINT);

VAR
   Sec,
   Head: BYTE;
   Blk,
   Res,
   SecCnt,
   Cyl : WORD;
   CoreAddr: LONGINT;

BEGIN
   LoadCSA;
   IF CurrSize = 0 THEN EXIT;
   IF FirstCyl <> CurrCyl THEN
   BEGIN
      DataInterrupt(0,WRONG_2ND_INDEX_32);
      EXIT;
   END;

   Cyl := CurrCyl;
   Head := CurrHead;
   Sec  := CurrSec;
   SecCnt := CurrSize;
   CoreAddr := WReg SHR 9 SHL 1;
   Seek(DosFile,(LONGINT(Cyl)*180+Head*9+Sec)*DosBytesPerSec);

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'I: Unit: ',DFC^.UnitReg,
           ' Segm: ',(LONGINT(Cyl)*180+Head*9+Sec):6,
           ' Size: ',CurrSize:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Cyl > MaxCylPresent THEN
      BEGIN   (* Read beyond the part of disc phys. present in DOS file *)
(*       DataInterrupt(PARITY_0,0); *)
         DataInterrupt(0,0);
         EXIT;
      END;

      Blk := SecCnt;
      IF Blk > 9 THEN Blk := 9;
      IF Blk+Sec > 9 THEN Blk := 9-Sec;
      BlockRead(DosFile,TrackBufferP^,Blk*DosBytesPerSec,Res);
      IF Blk*DosBytesPerSec <> Res THEN 
      BEGIN
         DataInterrupt(0,ADDRESS_ERROR_32);
         EXIT;
      END;

      InterruptsOff;
      ToCoreP(CoreAddr,Blk SHL 8,TrackBufferP);
      InterruptsOn;

      Inc(CoreAddr,Blk SHL 9);
      Dec(SecCnt,Blk);
      Sec := 0;
      IF SecCnt>0 THEN
      BEGIN
         Inc(Head);
         IF (Head = 20) THEN
         BEGIN
            Head := 0;
            Inc(Cyl);
         END;
      END;
   END;

   CurrCyl := Cyl;
   DataInterrupt(0,0);

END; (* RC4819.InputData *)

(**********************************************************************)
(* Proc. Name     : RC4819.OutputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.OutputData (WReg: LONGINT);

VAR
   Sec,
   Head: BYTE;
   Blk,
   Res,
   SecCnt,
   Cyl : WORD;
   CoreAddr: LONGINT;

BEGIN
   LoadCSA;
   IF CurrSize = 0 THEN EXIT;
   IF FirstCyl <> CurrCyl THEN
   BEGIN
      DataInterrupt(0,WRONG_2ND_INDEX_32);
      Exit;
   END;

   Cyl := CurrCyl;
   Head := CurrHead;
   Sec  := CurrSec;
   SecCnt := CurrSize;
   CoreAddr := WReg SHR 9 SHL 1;
   Seek(DosFile,(LONGINT(Cyl)*180+Head*9+Sec)*DosBytesPerSec);

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'O: Unit: ',DFC^.UnitReg,
           ' Segm: ',(LONGINT(Cyl)*180+Head*9+Sec):6,
           ' Size: ',CurrSize:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Cyl > MaxCylPresent THEN
      BEGIN
         IF NOT Expand(Cyl) THEN
         BEGIN
            DataInterrupt(PARITY_0,0);
            EXIT;
         END;
         Seek(DosFile,(LONGINT(Cyl)*180+Head*9+Sec)*DosBytesPerSec);
      END;

      Blk := SecCnt;
      IF Blk > 9 THEN Blk := 9;
      IF Blk+Sec > 9 THEN Blk := 9-Sec;

      InterruptsOff;
      FromCoreP(CoreAddr,Blk SHL 8,TrackBufferP);
      InterruptsOn;

      BlockWrite(DosFile,TrackBufferP^,Blk*DosBytesPerSec,Res);
      IF Blk*DosBytesPerSec <> Res THEN
      BEGIN
         DataInterrupt(0,ADDRESS_ERROR_32);
         EXIT;
      END;

      Inc(CoreAddr,Blk SHL 9);
      Dec(SecCnt,Blk);
      Sec := 0;
      IF SecCnt>0 THEN  
      BEGIN
         Inc(Head);
         IF (Head = 20) THEN
         BEGIN
            Head := 0;
            Inc(Cyl);
         END;
      END;
   END;

   CurrCyl := Cyl;
   DataInterrupt(0,0);

END; (* RC4819.OutputData *)

(**********************************************************************)
(* Proc. Name     : RC4819.InputAddress
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.InputAddress (WReg: LONGINT);

VAR
   Buf: ARRAY[0..8] OF LONGINT;
   I: BYTE;

BEGIN
   LoadCSA;
   FOR I := 0 TO 8 DO
      Buf[I] := ((LONGINT(CurrCyl) SHL 20) +
                (LONGINT(CurrHead) SHL 14) +
                (I + (CurrCyl MOD 3)) MOD 9) SHL 8;

   InterruptsOff;
   ToCore(WReg SHR 9 SHL 1,9,@Buf);
   InterruptsOn;
   DataInterrupt(0,0);
END; (* RC4819.InputAddress *)

(**********************************************************************)
(* Proc. Name     : RC4819.OutputAddress
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.OutputAddress (WReg: LONGINT);

BEGIN
   LoadCSA;
   DataInterrupt(0,0);
END; (* RC4819.OutputAddress *)

(**********************************************************************)
(* Proc. Name     : RC4819.ReturnToZero
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.ReturnToZero;

BEGIN
   CurrCyl := 0;
   ClearStatusBits(0,SEEK_ERROR_32);
   HeadInterrupt(0,0);
END; (* RC4819.ReturnToZero *)

(**********************************************************************)
(* Proc. Name     : RC4819.TransferForward
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.TransferForward (WReg: LONGINT);

VAR Offs: INTEGER;

BEGIN
   Offs := (WReg SHR 8) AND 511;
   {IF Offs <> 0 THEN}
   BEGIN
      CurrCyl := CurrCyl + Offs;
{$IFNDEF NOHDINT}
      IF CurrCyl > MaxCyl
         THEN HeadInterrupt(0,SEEK_ERROR_32)
         ELSE HeadInterrupt(0,0);
{$ENDIF}
   END;
END; (* RC4819.TransferForward *)

(**********************************************************************)
(* Proc. Name     : RC4819.TransferReverse
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.TransferReverse (WReg: LONGINT);

VAR Offs: INTEGER;

BEGIN
   Offs := (WReg SHR 8) AND 511;
   {IF Offs <> 0 THEN}
   BEGIN
      CurrCyl := CurrCyl - Offs;
{$IFNDEF NOHDINT}
      IF CurrCyl < 0
         THEN HeadInterrupt(0,SEEK_ERROR_32)
         ELSE HeadInterrupt(0,0);
{$ENDIF}
   END;
END; (* RC4819.TransferReverse *)

(**********************************************************************)
(* Proc. Name     : RC4819.SetStatusBits
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.SetStatusBits (Stat0,Stat32: LONGINT);

BEGIN
   UnitStatus0  := UnitStatus0 OR (Stat0 AND SENSE0_UNIT_BITS);
   UnitStatus32 := UnitStatus32 OR (Stat32 AND SENSE32_UNIT_BITS);
   WITH DFC^ DO
   BEGIN
      Status0  := Status0 OR (Stat0 AND SENSE0_DFC_BITS);
      Status32 := Status32 OR (Stat32 AND SENSE32_DFC_BITS);
   END;
END; (* RC4819.SetStatusBits *)

(**********************************************************************)
(* Proc. Name     : RC4819.ClearStatusBits
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.ClearStatusBits (Stat0,Stat32: LONGINT);

BEGIN
   UnitStatus0  := UnitStatus0 AND NOT (Stat0 AND SENSE0_UNIT_BITS);
   UnitStatus32 := UnitStatus32 AND NOT (Stat32 AND SENSE32_UNIT_BITS);
   WITH DFC^ DO
   BEGIN
      Status0  := Status0 AND NOT (Stat0 AND SENSE0_DFC_BITS);
      Status32 := Status32 AND NOT (Stat32 AND SENSE32_DFC_BITS);
   END;
END; (* RC4819.ClearStatusBits *)

(**********************************************************************)
(* Proc. Name     : RC4819.LoadCSA
(* Function       : "Load Core Store Address", clears various status
(*                  bits (see diagram for DFC403).
(**********************************************************************)
PROCEDURE RC4819.LoadCSA;

BEGIN
   ClearStatusBits(INTERVENTION_0 + PARITY_0 + TIMER_0 + OVERRUN_0,
                   WRONG_2ND_INDEX_32 + ADDRESS_ERROR_32 + DROP_OUT_32);
END; (* RC4819.LoadCSA *)

(**********************************************************************)
(* Proc. Name     : RC4819.HeadInterrupt
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.HeadInterrupt (Stat0,Stat32: LONGINT);

BEGIN
   SetStatusBits(Stat0,Stat32);
   DFC^.HeadInterrupt;
END; (* RC4819.HeadInterrupt *)

(**********************************************************************)
(* Proc. Name     : RC4819.DataInterrupt
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819.DataInterrupt (Stat0,Stat32: LONGINT);

BEGIN
   SetStatusBits(Stat0,Stat32);
   DFC^.DataInterrupt;
END; (* RC4819.DataInterrupt *)


(**********************************************************************)
(* Func. Name     : RC4819.Expand
(* Function       : Expands the dos file to cyl cylinders
(**********************************************************************)
FUNCTION RC4819.Expand (Cyl: WORD): BOOLEAN;

VAR
   Exp,
   Size,
   NewSize: LONGINT;

   I,
   Result,
   Blk: WORD;

BEGIN
   Expand := TRUE;
   IF MaxCylPresent >= Cyl THEN EXIT;
{  Size := (LONGINT(DosBytesPerSec)*(MaxCylPresent+1)*(MaxHead+1)*(MaxSec+1));}
   Size := FileSize(DosFile);  (* Take care of illegal size *)
   NewSize := (LONGINT(DosBytesPerSec)*(Cyl+1)*(MaxHead+1)*(MaxSec+1));
   Seek(DosFile,Size);
   Exp := NewSize-Size;

{$IFDEF LOG}
{$IFNDEF HLLOG}
   WriteLn(Log,'Expand: MaxCylPresent=',MaxCylPresent,
          '  Cyl=',Cyl,'  Size=',Size,' NewSize=',Newsize,
          ' Exp=',Exp);
{$ENDIF}
{$ENDIF}

   FOR I := 0 TO BytesPerTrack-1 DO TrackBufferP^[I] := 0;

   WHILE Exp > 0 DO
   BEGIN
      IF Exp > BytesPerTrack THEN Blk := BytesPerTrack ELSE Blk := Exp;
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

   MaxCylPresent := Cyl;

END; (* RC4819.Expand *)

(**********************************************************************)
(* Proc. Name     : DFC403Device.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR DFC403Device.Init (DevNo: WORD; DataInt,HeadInt: BYTE);

VAR
   I: BYTE;

BEGIN
   INHERITED Init(DevNo);
   _HeadInt := HeadInt;
   _DataInt := DataInt;

   FOR I := 0 TO 7 DO Drives[I] := NIL;
   HeadIntPending := FALSE;
   Busy := FALSE;
   CommandReg := 0;
   UnitReg := 0;
   Status0 := 0;
   Status32 := 0;

   IF NOT GetMemCheck(TrackBufferP,BytesPerTrack)
      THEN FatalError('DFC403 Init: No heap memory');

END; (* DFC403Device.Init *)

(**********************************************************************)
(* Proc. Name     : DFC403Device.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR DFC403Device.Done;

VAR 
   I: BYTE;

BEGIN
   INHERITED Done;

   FOR I := 0 TO 7 DO
      IF Drives[I] <> NIL THEN Drives[I]^.Done;
END; (* DFC403Device.Done *)


(**********************************************************************)
(* Proc. Name     : RC4819Ram.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR RC4819Ram.Init (NoOfCyl: WORD; DFCPtr: DFC403DevicePtr);

BEGIN
   Root.Init;
   DFC := DFCPtr;
   TrackBufferP := DFCPtr^.TrackBufferP;

   (* RC4819 phys. parameters *)
   MaxHead := 19;
   MaxCyl  := 405;
   MaxSec  := 8;

   FirstCyl := 0;
   CurrHead := 0;
   CurrCyl  := 0;
   CurrSec  := 0;
   CurrSize := 0;
   UnitStatus0 := 0;
   UnitStatus32 := 0;

   Slctr := AllocateXtraSegment((LONGINT(NoOfCyl)*(MaxHead+1)*(MaxSec+1)*768+4095) 
                                 DIV 4096);
   MaxCylPresent := NoOfCyl-1;

END; (* RC4819Ram.Init *)

(**********************************************************************)
(* Proc. Name     : RC4819Ram.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR RC4819Ram.Done;

BEGIN
END; (* RC4819Ram.Done *)




(**********************************************************************)
(* Proc. Name     : RC4819Ram.InputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819Ram.InputData (WReg: LONGINT);

VAR
   Sec,
   Head: BYTE;
   Blk,
   Res,
   SecCnt,
   Cyl : WORD;
   DiscPos,
   CoreAddr: LONGINT;

BEGIN
   LoadCSA;
   IF CurrSize = 0 THEN EXIT;
   IF FirstCyl <> CurrCyl THEN
   BEGIN
      DataInterrupt(0,WRONG_2ND_INDEX_32);
      EXIT;
   END;

   Cyl := CurrCyl;
   Head := CurrHead;
   Sec  := CurrSec;
   SecCnt := CurrSize;
   CoreAddr := WReg SHR 9 SHL 1;
   DiscPos := (LONGINT(Cyl)*180+Head*9+Sec)*768;

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'I: Unit: ',DFC^.UnitReg,
           ' Segm: ',(LONGINT(Cyl)*180+Head*9+Sec):6,
           ' Size: ',CurrSize:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Cyl > MaxCylPresent THEN
      BEGIN   (* Read beyond the part of disc phys. present in DOS file *)
         DataInterrupt(PARITY_0,0);
         EXIT;
      END;

      Blk := SecCnt;
      IF Blk > 9 THEN Blk := 9;
      IF Blk+Sec > 9 THEN Blk := 9-Sec;

      InterruptsOff;
      ToCorePFromXtra(Slctr,CoreAddr,Blk SHL 8,DiscPos);
      InterruptsOn;

      Inc(CoreAddr,Blk SHL 9);
      Inc(DiscPos,Blk*768);
      Dec(SecCnt,Blk);
      Sec := 0;
      IF SecCnt>0 THEN
      BEGIN
         Inc(Head);
         IF (Head = 20) THEN
         BEGIN
            Head := 0;
            Inc(Cyl);
         END;
      END;
   END;

   CurrCyl := Cyl;
   DataInterrupt(0,0);

END; (* RC4819Ram.InputData *)


(**********************************************************************)
(* Proc. Name     : RC4819Ram.OutputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC4819Ram.OutputData (WReg: LONGINT);

VAR
   Sec,
   Head: BYTE;
   Blk,
   Res,
   SecCnt,
   Cyl : WORD;
   DiscPos,
   CoreAddr: LONGINT;

BEGIN
   LoadCSA;
   IF CurrSize = 0 THEN EXIT;
   IF FirstCyl <> CurrCyl THEN
   BEGIN
      DataInterrupt(0,WRONG_2ND_INDEX_32);
      Exit;
   END;

   Cyl := CurrCyl;
   Head := CurrHead;
   Sec  := CurrSec;
   SecCnt := CurrSize;
   CoreAddr := WReg SHR 9 SHL 1;
   DiscPos := (LONGINT(Cyl)*180+Head*9+Sec)*768;

{$IFDEF LOG}
{$IFDEF HLLOG}
   WriteLn(Log,'O: Unit: ',DFC^.UnitReg,
           ' Segm: ',(LONGINT(Cyl)*180+Head*9+Sec):6,
           ' Size: ',CurrSize:3,
           ' Core: ',CoreAddr);
{$ENDIF}
{$ENDIF}

   WHILE SecCnt > 0 DO
   BEGIN
      IF Cyl > MaxCylPresent THEN
      BEGIN
         DataInterrupt(PARITY_0,0);
         EXIT;
      END;

      Blk := SecCnt;
      IF Blk > 9 THEN Blk := 9;
      IF Blk+Sec > 9 THEN Blk := 9-Sec;

      InterruptsOff;
      FromCorePToXtra(Slctr,CoreAddr,Blk SHL 8,DiscPos);
      InterruptsOn;

      Inc(CoreAddr,Blk SHL 9);
      Inc(DiscPos,Blk*768);
      Dec(SecCnt,Blk);
      Sec := 0;
      IF SecCnt>0 THEN  
      BEGIN
         Inc(Head);
         IF (Head = 20) THEN
         BEGIN
            Head := 0;
            Inc(Cyl);
         END;
      END;
   END;

   CurrCyl := Cyl;
   DataInterrupt(0,0);

END; (* RC4819Ram.OutputData *)


(**********************************************************************)
(* Func. Name     : DFC403Device.IncludeDrive
(* Function       : 
(**********************************************************************)
FUNCTION DFC403Device.IncludeDrive (UnitNo: BYTE; UP: RC4819Ptr): BOOLEAN;

BEGIN
   IF (UnitNo > 7) OR (Drives[UnitNo] <> NIL) THEN IncludeDrive := FALSE ELSE
   BEGIN
      Drives[UnitNo] := UP;
      IncludeDrive := TRUE;
   END;
END; (* DFC403Device.IncludeDrive *)


(**********************************************************************)
(* Proc. Name     : DFC403Device.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE DFC403Device.Sense (Modif: BYTE);

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
{$IFNDEF HLLOG}
               WriteLn(Log,'Sense 0: Busy');
{$ENDIF}
{$ENDIF}
               
            END ELSE
            BEGIN  (* Sense0 *)
               Ex23 := 0;
               Status := Status0;
               IF Drives[UnitReg] = NIL THEN Status := Status OR LOCAL_0 ELSE
               BEGIN
                  Status := Status OR Drives[UnitReg]^.UnitStatus0;
                  IF ((Status32 OR Drives[UnitReg]^.UnitStatus32) AND
                      SYNC_ERROR_BITS) <> 0 THEN
                  Status := Status OR SYNC_ERROR_0;
               END;
               Status := Status OR (1 SHL UnitReg) OR (CommandReg SHL 8);
               SrvcParam.Wreg := Status SHL 8;
{$IFDEF LOG}
{$IFNDEF HLLOG}
               WriteLn(Log,'Sense 0: '+BinaryW(SrvcParam.Wreg SHR 16)+
                       BinaryB((SrvcParam.Wreg SHR 8) AND $FF));
{$ENDIF}
{$ENDIF}
            END;

        32: BEGIN  (* Sense32 *)
               Ex23 := 0;  (* Sense32 always OK *)
               Status := Status32 OR UnitReg;
               IF Drives[UnitReg] <> NIL
                  THEN Status := Status OR Drives[UnitReg]^.UnitStatus32;

               (* Control Register not (really) implemented *)
               IF Busy 
                  THEN Status := Status OR (LONGINT(1) SHL 13)  (* CR(10) *)
                  ELSE Status := Status OR (LONGINT(1) SHL 23); (* CR(0) *)

               SrvcParam.Wreg := Status SHL 8;
{$IFDEF LOG}
{$IFNDEF HLLOG}
               WriteLn(Log,'Sense 32: '+BinaryW(SrvcParam.Wreg SHR 16)+
                       BinaryB((SrvcParam.Wreg SHR 8) AND $FF)+
                       ' '+Chr(Ord(Busy)+48));
{$ENDIF}
{$ENDIF}
            END;

         ELSE ;

      END; (* CASE *)
   END;
END; (* DFC403Device.Sense *)

(**********************************************************************)
(* Proc. Name     : DFC403Device.Control
(* Function       : 
(**********************************************************************)
PROCEDURE DFC403Device.Control (Modif: BYTE);


BEGIN
   WITH State8000, SrvcParam DO
   BEGIN
{$IFDEF LOG}
{$IFNDEF HLLOG}
      CASE (Modif SHL 2) + 1 OF
         5: Write(Log,'TransferFirst cyl=',Long2Str((WReg SHR 20) AND 511),
                  ' head=',Long2Str((WReg SHR 14) AND 63),
                  ' sector=',Long2Str((WReg SHR 8) AND 63));
         9: Write(Log,'TransferSize ',Long2Str((WReg SHR 8) AND 4095));
        13: Write(Log,'InputData ',Long2Str(WReg SHR 8));
        17: Write(Log,'OutputData ',Long2Str(WReg SHR 8));
        21: Write(Log,'InputAddress ',Long2Str(WReg SHR 8));
        25: Write(Log,'OutputAddress ',Long2Str(WReg SHR 8));
        29: Write(Log,'SelectDisc ',Long2Str((WReg SHR 8) AND 7));
        33: Write(Log,'ReturnToZero');
        37: Write(Log,'TransferForward ',Long2Str((WReg SHR 8) AND 511));
        41: Write(Log,'TransferReverse ',Long2Str((WReg SHR 8) AND 511));
        ELSE Write(Log,'*** '+Long2Str((Modif SHL 2) + 1));
      END;

      IF Busy
         THEN WriteLn(Log,' *BUSY* ')
         ELSE WriteLn(Log);
{$ENDIF}
{$ENDIF}

      Ex22 := 0;
      IF Busy THEN
      BEGIN
         Ex23 := 1;
         EXIT;
      END;

      Ex23 := 0;
      CommandReg := Modif;

      PushF;
      InterruptsOn;
      CASE (Modif SHL 2) + 1 OF

         29:   BEGIN  (* Select Disc *)
                  UnitReg := (WReg SHR 8) AND 7;   (* UnitReg should really be 4 bits! *)
               END;

         45:   ;   (* Set mode, not implemented *)

         61:   BEGIN  (* Master Clear *)
                  UnitReg := 0;
                  CommandReg := 0;
               END;
         ELSE
         BEGIN
            IF Drives[UnitReg] <> NIL THEN
            WITH Drives[UnitReg]^ DO
            CASE (Modif SHL 2) + 1 OF
               5:    TransferFirst(WReg);
               9:    TransferSize(WReg);
              13:    InputData(WReg);
              17:    OutputData(WReg);
              21:    InputAddress(WReg);
              25:    OutputAddress(WReg);
              33:    ReturnToZero;
              37:    TransferForward(WReg);
              41:    TransferReverse(WReg);
            ELSE ;
            END;
         END;

      END;
      PopF;
   END;
END; (* DFC403Device.Control *)

(**********************************************************************)
(* Func. Name     : DFC403Device.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION DFC403Device.DeviceID: STRING;

BEGIN
   DeviceID := 'DISC';
END; (* DFC403Device.DeviceID *)

(**********************************************************************)
(* Proc. Name     : DFC403Device.HeadInterrupt
(* Function       : 
(**********************************************************************)
PROCEDURE DFC403Device.HeadInterrupt;

BEGIN
   IF Busy THEN HeadIntPending := TRUE ELSE
   BEGIN
      WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_HeadInt));
      HeadIntPending := FALSE;
   END;

{$IFDEF LOG}
{$IFNDEF HLLOG}
   IF HeadIntPending
      THEN WriteLn(Log,'Head interrupt, pending')
      ELSE WriteLn(Log,'Head interrupt, active');
{$ENDIF}
{$ENDIF}
END; (* DFC403Device.HeadInterrupt *)

(**********************************************************************)
(* Proc. Name     : DFC403Device.DataInterrupt
(* Function       : 
(**********************************************************************)
PROCEDURE DFC403Device.DataInterrupt;

BEGIN
{$IFDEF LOG}
{$IFNDEF HLLOG}
   IF HeadIntPending
      THEN WriteLn(Log,'Data interrupt + Head interrupt')
      ELSE WriteLn(Log,'Data interrupt');
{$ENDIF}
{$ENDIF}

   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_DataInt));
   IF HeadIntPending THEN
      WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_HeadInt));
   HeadIntPending := FALSE;
   Busy := FALSE;
END; (* DFC403Device.DataInterrupt *)



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
{$IFDEF LOG}
   IF LogOpen THEN Close(Log);
{$ENDIF}
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

{$IFDEF LOG}
   Assign(Log,'RC4819.LOG');
   Rewrite(Log);
   LogOpen := TRUE;
{$ENDIF}
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT RC4818 *)

