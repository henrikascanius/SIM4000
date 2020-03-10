(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : RC749.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 20-03-07         HJ Initial version 
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC749 emulation.
(*
(**********************************************************************)

{$F+}
{$X+}
{$DEFINE LOG}
{ $DEFINE HLLOG} (* High level log, LOG must be defined too *)

UNIT RC749;


INTERFACE

USES
   OpRoot,
   Io;

CONST
   MaxBytesPerBlock =  768*10;

TYPE
   BlockBuffer    =  ARRAY[0..MaxBytesPerBlock-1] OF BYTE;
   BlockBufferPtr =  ^BlockBuffer;


   RC749DevicePtr  =  ^RC749Device;

   RC749Device     =   OBJECT (IoDevice)

                           CONSTRUCTOR Init(DevNo: WORD;
                                            IntNo: BYTE);
                           DESTRUCTOR Done; VIRTUAL;

                           PROCEDURE  MountTape(Path: STRING);                           
                           PROCEDURE  Sense(Modif: BYTE);    VIRTUAL;
                           PROCEDURE  Control(Modif: BYTE);  VIRTUAL;
                           FUNCTION   DeviceID: STRING;      VIRTUAL;
                           FUNCTION   TapePresent: BOOLEAN;  VIRTUAL;

                        PRIVATE
                           _IntNo         : BYTE;
                           Status0        : LONGINT;
                           CurrBlockLen   : LONGINT;
                           LastCore       : LONGINT;
                           Fault          : BOOLEAN;
                           Unloaded       : BOOLEAN;

                           DosFile        :  FILE;
                           DosFileName    :  STRING[32];
                           BlockBufferP   :  BlockBufferPtr;

                           PROCEDURE MoveTape(WReg: LONGINT);
                           PROCEDURE InputData(WReg: LONGINT);
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
   (* Status bits: *)

   INTERVENTION_0     =  LONGINT(1) SHL 23;
   PARITY_0           =  LONGINT(1) SHL 22;
   TIMER_0            =  LONGINT(1) SHL 21;
   OVERRUN_0          =  LONGINT(1) SHL 20;
   BLOCKLENGTH_0      =  LONGINT(1) SHL 19;
   EOT_0              =  LONGINT(1) SHL 18;
   BOT_0              =  LONGINT(1) SHL 17;
   TAPEMARK_0         =  LONGINT(1) SHL 16;
   WRITEENABLE_0      =  LONGINT(1) SHL 15;
   HIGHDENSITY_0      =  LONGINT(1) SHL 14;

   (* Record length part of NIMH-TAP tag word *) 
   RECLEN_MASK        = $00FFFFFF;

{$IFDEF LOG}
VAR
   Log: TEXT;
CONST
   LogOpen: BOOLEAN = FALSE;
{$ENDIF}


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.MoveTape
(* Function       : 
(**********************************************************************)
PROCEDURE RC749Device.MoveTape (WReg: LONGINT);

VAR
   Mark1   : LONGINT;
   Mark2   : LONGINT;
   Res     : INTEGER;
   I       : INTEGER;
   
BEGIN
   Status0 := HIGHDENSITY_0;
   State8000.Ex22 := Ord(Fault);
   
{$IFDEF LOG}
{$IFNDEF HLLOG}

   
   CASE WReg SHR 8 OF
      0: Write(Log,'Upspace File');
      1: Write(Log,'Upspace Block');
      2: Write(Log,'Backspace File');
      3: Write(Log,'Backspace Block');
      4: Write(Log,'Rewind Tape');
      5: Write(Log,'Unload Tape');
     ELSE Write(Log,'*** Move Tape '+Long2Str(Wreg SHR 8));
   END;
   IF Fault THEN WriteLn(Log,' ***FAULT') 
            ELSE WriteLn(Log);

{$ENDIF}
{$ENDIF}
   CASE Wreg SHR 8 OF
      0: (* Upspace file *)
      BEGIN
      REPEAT
         REPEAT
            BlockRead(DosFile,Mark1,4,Res);
         UNTIL (Res <> 4) OR (Mark1 <> $FFFFFFFE); (* Skip erase gaps *)
         IF (Res <> 4) OR (Mark1 = $FFFFFFFF) THEN
         BEGIN
            Status0 := Status0 OR EOT_0;
            IF Res = 4 THEN Seek(DosFile,FilePos(DosFile)-4);
         END ELSE
         IF Mark1 = 0 THEN Status0 := Status0 OR TAPEMARK_0 ELSE
         BEGIN
            Seek(DosFile,FilePos(DosFile)+(Mark1 AND RECLEN_MASK));
            IF BOOLEAN(Mark1 AND 1) THEN Seek(DosFile,FilePos(DosFile)+1);
            BlockRead(DosFile,Mark2,4,Res);
           IF Mark1 <> Mark2 THEN
           BEGIN
              Fault := TRUE;
{$IFDEF LOG}
              WriteLn(Log,'UPSPACE FILE AT FILEPOS ', FilePos(DosFile),' BLEN MISMATCH ',Mark1,' ',Mark2);
{$ENDIF}
           END;
        END;
     UNTIL Fault OR ((Status0 AND (TAPEMARK_0 + EOT_0)) <> 0);
     END;
            
      1: (* Upspace block *)
      BEGIN
      REPEAT
         BlockRead(DosFile,Mark1,4,Res);
      UNTIL (Res <> 4) OR (Mark1 <> $FFFFFFFE); (* Skip erase gaps *)
      IF (Res <> 4) OR (Mark1 = $FFFFFFFF) THEN 
      BEGIN
         Status0 := Status0 OR EOT_0;
         IF Res = 4 THEN Seek(DosFile,FilePos(DosFile)-4);
      END ELSE
      IF Mark1 = 0 THEN Status0 := Status0 OR TAPEMARK_0 ELSE
      BEGIN
         Seek(DosFile,FilePos(DosFile)+(Mark1 AND RECLEN_MASK));
         IF BOOLEAN(Mark1 AND 1) THEN Seek(DosFile,FilePos(DosFile)+1);
         BlockRead(DosFile,Mark2,4,Res);
         IF Mark1 <> Mark2 THEN
         BEGIN
            Fault := TRUE;
{$IFDEF LOG}
            WriteLn(Log,'UPSPACE BLOCK AT FILEPOS ', FilePos(DosFile),' BLEN MISMATCH ',Mark1,' ',Mark2);
{$ENDIF}
         END;
      END;
      END;
      
      2: (* Backspace file *)
      BEGIN
         REPEAT
            REPEAT
               IF FilePos(DosFile) > 0 THEN Seek(DosFile,FilePos(DosFile)-4);
               BlockRead(DosFile,Mark1,4,Res);
               Seek(DosFile,FilePos(DosFile)-4);
            UNTIL (FilePos(DosFile)=0) OR (Mark1 <> $FFFFFFFE); (* Skip erase gaps *)
            IF FilePos(DosFile) = 0 THEN Status0 := Status0 OR BOT_0 ELSE
            IF Mark1 = 0 THEN Status0 := Status0 OR TAPEMARK_0 ELSE
            BEGIN
               Seek(DosFile,FilePos(DosFile)-((Mark1 AND RECLEN_MASK)+4));
               IF BOOLEAN(Mark1 AND 1) THEN Seek(DosFile,FilePos(DosFile)-1);
            END;
         UNTIL ((Status0 AND (TAPEMARK_0 + BOT_0)) <> 0);
      END;
      
      3: (* Backspace block *)
      BEGIN
         REPEAT
            IF FilePos(DosFile) > 0 THEN Seek(DosFile,FilePos(DosFile)-4);
            BlockRead(DosFile,Mark1,4,Res);
            Seek(DosFile,FilePos(DosFile)-4);
         UNTIL (FilePos(DosFile)=0) OR (Mark1 <> $FFFFFFFE); (* Skip erase gaps *)
         IF FilePos(DosFile) = 0 THEN Status0 := Status0 OR BOT_0 ELSE
         IF Mark1 = 0 THEN Status0 := Status0 OR TAPEMARK_0 ELSE
         BEGIN
            Seek(DosFile,FilePos(DosFile)-((Mark1 AND RECLEN_MASK)+4)); (* We checked the structure during forward move... *)
            IF BOOLEAN(Mark1 AND 1) THEN Seek(DosFile,FilePos(DosFile)-1);
         END;
      END;
      
      4: (* Rewind tape *)
      BEGIN
         Seek(DosFile,0);
         Status0 := Status0 OR BOT_0;
         Fault := FALSE;
      END;
      
      5: (* Unload tape *)
      Unloaded := TRUE;
      
      ELSE ;
   END;
   
      
   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_IntNo));

END; (* RC749Device.MoveTape *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.InputData
(* Function       : 
(**********************************************************************)
PROCEDURE RC749Device.InputData (WReg: LONGINT);

VAR
   CoreAddr: LONGINT;
   Mark1   : LONGINT;
   Mark2   : LONGINT;
   Res     : INTEGER;
   I       : INTEGER;
   MaxWords: LONGINT;
   
BEGIN
   Status0 := HIGHDENSITY_0;
   CoreAddr := WReg SHR 9 SHL 1;

   REPEAT
      BlockRead(DosFile,Mark1,4,Res);
   UNTIL (Res <> 4) OR (Mark1 <> $FFFFFFFE); (* Skip erase gaps *)
   
   IF (Res <> 4) OR (Mark1 = $FFFFFFFF) THEN
   BEGIN
      Status0 := Status0 OR EOT_0;
      CurrBlocklen := 0;
      IF Res = 4 THEN Seek(DosFile,FilePos(DosFile)-4);
{$IFDEF LOG}
      WriteLn(Log,'EOT - Read: ',Res);
{$ENDIF}
   END ELSE
   IF Mark1 = 0 THEN
   BEGIN
      Status0 := Status0 OR TAPEMARK_0;
      CurrBlocklen := 0;
{$IFDEF LOG}
      WriteLn(Log,'TAPEMARK');
{$ENDIF}
   END ELSE
      IF (Mark1 AND RECLEN_MASK) > MaxBytesPerBlock THEN
   BEGIN
      Status0 := Status0 OR BLOCKLENGTH_0;
      CurrBlocklen := 0;
      Seek(DosFile,FilePos(DosFile)+(Mark1 AND RECLEN_MASK)+4);
      IF BOOLEAN(Mark1 AND 1) THEN Seek(DosFile,FilePos(DosFile)+1);
{$IFDEF LOG}
      WriteLn(Log,'BLOCK TOO LONG: ',Mark1);
{$ENDIF}
   END ELSE
   BEGIN
      BlockRead(DosFile,BlockBufferP^,(Mark1 AND RECLEN_MASK),Res);
      I := Res;
      WHILE (I MOD 3 <> 0) AND (I<MaxBytesPerBlock) DO
      BEGIN
         BlockBufferP^[I] := 0;
         Inc(I);
      END;
      MaxWords := LastCore-CoreAddr+1;
      IF Res < MaxWords*3
         THEN CurrBlocklen := Res ELSE
      BEGIN
         CurrBlocklen := MaxWords*3;
         Status0 := Status0 OR BLOCKLENGTH_0;
      END;

      IF BOOLEAN(Mark1 AND 1) THEN Seek(DosFile,FilePos(DosFile)+1);
      BlockRead(DosFile,Mark2,4,Res);
      IF Mark1 <> Mark2 THEN
      BEGIN
         Fault := TRUE;
{$IFDEF LOG}
         WriteLn(Log,'AT FILEPOS ', FilePos(DosFile),' LENGTH MISMATCH ',Mark1,' ',Mark2);
{$ENDIF}
      END ELSE
      BEGIN
         InterruptsOff;
         ToCoreTxt(CoreAddr,(CurrBlocklen+2) DIV 3,BlockBufferP);
         InterruptsOn;
{$IFDEF LOG}
         WriteLn(Log,'I:', FilePos(DosFile),' ',Mark1, ' ', CurrBlockLen);
{$ENDIF}
         IF Mark1 < 0 THEN Status0 := Status0 OR PARITY_0;
      END;
   END;

   WITH State8000 DO IR := IR OR (LONGINT(1) SHL (31-_IntNo));

END; (* RC749Device.InputData *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.MountTape
(* Function       : 
(**********************************************************************)
PROCEDURE RC749Device.MountTape (Path: STRING);

VAR
   I: BYTE;

BEGIN

   IF NOT Unloaded THEN Close(DosFile);

   IF Length(Path)=0 THEN Unloaded := TRUE ELSE
   BEGIN
     Unloaded := FALSE;
     Fault := FALSE;
     DosFileName := Path;
     Assign(DosFile,DosFileName);
{$I-}
      Reset(DosFile,1);
{$I+}
      IF IOResult <> 0 THEN
         FatalError('Cannot open NIMH-TAP file: '+DosFileName);
   END;
END; (* RC749Device.MountTape *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.Init
(* Function       : 
(**********************************************************************)
CONSTRUCTOR RC749Device.Init (DevNo: WORD; IntNo: BYTE);

VAR
   I: BYTE;

BEGIN
   INHERITED Init(DevNo);
   _IntNo := IntNo;

   Status0 := HIGHDENSITY_0;
   CurrBlockLen := 0;
   LastCore := 0;
   Fault := FALSE;
   Unloaded := TRUE;

   IF NOT GetMemCheck(BlockBufferP,MaxBytesPerBlock)
      THEN FatalError('RC749 Init: No heap memory');
      
END; (* RC749Device.Init *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.Done
(* Function       : 
(**********************************************************************)
DESTRUCTOR RC749Device.Done;

VAR 
   I: BYTE;

BEGIN
   INHERITED Done;
    IF NOT Unloaded THEN Close(DosFile);
END; (* RC749Device.Done *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.Sense
(* Function       : 
(**********************************************************************)
PROCEDURE RC749Device.Sense (Modif: BYTE);

VAR
   Status: LONGINT;

BEGIN
   WITH State8000 DO
   BEGIN
      Ex22 := Ord(Fault);
      IF Unloaded THEN Status0 := Status0 OR INTERVENTION_0;

      CASE Modif OF

         0: BEGIN  (* Sense0 *)
               Ex23 := 0;
               Status := Status0;
               SrvcParam.Wreg := Status SHL 8;
{$IFDEF LOG}
{$IFNDEF HLLOG}
               WriteLn(Log,'Sense0: '+BinaryW(SrvcParam.Wreg SHR 16)+
                       BinaryB((SrvcParam.Wreg SHR 8) AND $FF));
{$ENDIF}
{$ENDIF}
            END;

        1:  BEGIN  (* Sense4 *)
               Ex23 := 0;  (* Sense4 always OK *)
               SrvcParam.Wreg := CurrBlockLen SHL 8;
{$IFDEF LOG}
{$IFNDEF HLLOG}
               WriteLn(Log,'Sense4: ',Long2Str(CurrBlockLen));
{$ENDIF}
{$ENDIF}
            END;

         ELSE
{$IFDEF LOG}
            WriteLn(Log,'*** Sense: ',Modif);
{$ENDIF}

      END; (* CASE *)
   END;
END; (* RC749Device.Sense *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : RC749Device.Control
(* Function       : 
(**********************************************************************)
PROCEDURE RC749Device.Control (Modif: BYTE);


BEGIN
   WITH State8000, SrvcParam DO
   BEGIN
      Ex22 := Ord(Fault);
      
{$IFDEF LOG}
{$IFNDEF HLLOG}
      Write(Log,'D:',_DevNo,' ');
      CASE (Modif SHL 2)+1 OF
         1: Write(Log,'SetTrail ',Long2Str((WReg SHR 8) AND $FFF));
         5: Write(Log,'TransferAddress ',Long2Str(WReg SHR 8));
         9: Write(Log,'Move ',Long2Str((WReg SHR 8) AND 4095));
        13: Write(Log,'InputOdd ',Long2Str(WReg SHR 8));
        17: Write(Log,'OutputOdd ',Long2Str(WReg SHR 8));
        21: Write(Log,'Erase');
        45: Write(Log,'InputEven ',Long2Str(WReg SHR 8));
        49: Write(Log,'OutputEven ',Long2Str(WReg SHR 8));
        ELSE Write(Log,'*** Ctrl: '+Long2Str((Modif SHL 2) + 1));
      END;
      IF Fault THEN WriteLn(Log,' ***FAULT') 
               ELSE WriteLn(Log);

{$ENDIF}
{$ENDIF}

      Ex23 := 0;

      IF (NOT Unloaded) AND (NOT Fault) THEN
      BEGIN
          PushF;
          InterruptsOn;
          CASE (Modif SHL 2)+1 OF
               1:     BEGIN END; (* Set Trail, ignored *)
               5:     LastCore := (WReg SHR 9) SHL 1;
               9:     MoveTape(WReg);
              13, 45: InputData(WReg);
              17, 49: BEGIN END;  (* Output, ignored *)
              21:     BEGIN END; (* Erase, ignored *)
                ELSE ;
          END;
         PopF;
      END;
   END;
END; (* RC749Device.Control *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : RC749Device.DeviceID
(* Function       : 
(**********************************************************************)
FUNCTION RC749Device.DeviceID: STRING;

BEGIN
   DeviceID := 'MT';
END; (* RC749Device.DeviceID *)

(*#CPAGE 20*)
(**********************************************************************)
(* Func. Name     : RC749Device.TapePresent
(* Function       : 
(**********************************************************************)
FUNCTION RC749Device.TapePresent: BOOLEAN;

BEGIN
   TapePresent := NOT Unloaded;
END; (* RC749Device.TapePresent *)


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
   Assign(Log,'RC749.LOG');
   Rewrite(Log);
   LogOpen := TRUE;
{$ENDIF}
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT RC4818 *)

