(*#LEFT 6*)(*#TITLE ""*)

(**********************************************************************)
(* Unit name      : INTF.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-05-28 15:56   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Pascal interface for RC8000 simulator.
(*  92-05-28 16:02 HJ 
(**********************************************************************)

{$F+}

UNIT INTF;


INTERFACE

USES
   Descr;


CONST
   PMStackSize = 1024;
   PMIStackSize= 1024;
   SrvcIntNo:  BYTE = $f0;

TYPE
   FWORD =
   RECORD
      Offset   : HugePtr;
      Selector : WORD;
   END;

   SrvcKind    =  (IO_OP,AW_OP,DUMMY_OP);

   SrvcRec     =  RECORD
                     ReqKind:    SrvcKind;
                     WReg:       LONGINT;
                     EA:         LONGINT;
                     Optional:   ARRAY[0..7] OF LONGINT;
                  END;
                     


   State8000Rec=  RECORD
                     IC          : LONGINT;
                     IM          : LONGINT;
                     IR          : LONGINT;
                     BreakPoint  : LONGINT;
                     Ex23        : 0..1;
                     Ex22        : 0..1;
                     IntEn       : BOOLEAN;
                     ResetKey    : BOOLEAN;
                     AutoloadKey : BOOLEAN;
                     Step        : BOOLEAN;
                     Trace       : BOOLEAN;
                     Stop        : BOOLEAN;
                     ResetSys    : BOOLEAN;
                     ResetMode   : BOOLEAN;
                     Running     : BOOLEAN;
                     ClockSense  : LONGINT;
                     ClockCntP   : FWORD;
                     FullAccuracy: BOOLEAN;
                     NextScreen  : BYTE;  (* Virt. screen to activate *)
                     SrvcParam   : SrvcRec;
                  END;

   CoreCopyRec=   RECORD
                     V86Seg      : WORD;
                     V86Ref      : LongInt;
                     Words       : WORD;
                     PMSeg       : WORD;
                     CoreAddr    : LONGINT;
                  END;


CONST
   State8000 : State8000Rec =
                    (IC          : 8;
                     IM          : $80000000;
                     IR          : 0;
                     BreakPoint  : -1;
                     Ex23        : 0;
                     Ex22        : 0;
                     IntEn       : FALSE;
                     ResetKey    : FALSE;
                     AutoloadKey : FALSE;
                     Step        : FALSE;
                     Trace       : FALSE;
                     Stop        : FALSE;
                     ResetSys    : FALSE;
                     ResetMode   : TRUE;
                     Running     : FALSE;
                     ClockSense  : -1;
                     ClockCntP   : (Offset: 0;
                                    Selector: 0);
                     FullAccuracy: TRUE;
                     NextScreen  : $FF
                    );



VAR
   CoreCopyPar: CoreCopyRec;
   _PMStack   : ARRAY[0..PMStackSize-1] OF BYTE;    (* Stack used by ucode *)
   _PMIStack   : ARRAY[0..PMIStackSize-1] OF BYTE;  (* Stack used by intf. routines *)
   CodeBase,
   CoreBase   : LONGINT;   (* Linear address of code/core segm. *)



PROCEDURE InitIDT;
PROCEDURE Reset8000;
PROCEDURE Run8000 ;
PROCEDURE _Run8000;
PROCEDURE FromCore(Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE ToCore(Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE FromCoreP(Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE ToCoreP(Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE FromCorePToXtra (Select: WORD; Addr: LONGINT; Len: WORD; BufPtr: LONGINT);
PROCEDURE ToCorePFromXtra (Select: WORD; Addr: LONGINT; Len: WORD; BufPtr: LONGINT);
PROCEDURE FromCoreTxt(Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE ToCoreTxt(Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE FromCode (Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE ToCode (Addr: LONGINT; Len: WORD; BufPtr: POINTER);
PROCEDURE ResetCore;
PROCEDURE SetBreakSeg;



(*#PAGE*)
IMPLEMENTATION

USES
   Audio,
   Util,
   Vcpi;

PROCEDURE  IntHandler; EXTERNAL;
PROCEDURE _Run8000;    EXTERNAL;
PROCEDURE _FromCore;   EXTERNAL;
PROCEDURE _ToCore;     EXTERNAL;
PROCEDURE _FromCoreP;  EXTERNAL;
PROCEDURE _ToCoreP;    EXTERNAL;
PROCEDURE _FromCoreTxt;EXTERNAL;
PROCEDURE _ToCoreTxt;  EXTERNAL;
PROCEDURE _FromCode;   EXTERNAL;
PROCEDURE _ToCode;     EXTERNAL;
PROCEDURE _ResetCore;  EXTERNAL;
PROCEDURE _SetBreakSeg;EXTERNAL;
{$L INTF.OBJ}


{$F+} 
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : CallProtected
(* Function       : 
(**********************************************************************)
PROCEDURE CallProtected (P: POINTER);

BEGIN
   WITH PMParam DO
   BEGIN
      CS   := ICode;
      EIP  := Ofs(P^);
   END;

   IF CallProtectedMode(PtrToHuge(@PMParam)) = 0 THEN;

END; (* CallProtected *)


(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : InitIDT
(* Function       : Init the Interrupt Descriptor Table
(**********************************************************************)
PROCEDURE InitIDT;

VAR I:BYTE;

BEGIN
   FOR I := 0 TO 255 DO
   WITH IDT[I] DO
   BEGIN
      Init(INTGATE386,0,TRUE);
      SetSelector(ICode);
      SetOffset(Ofs(IntHandler)+(I SHL 2));
   END;

END; (* InitIDT *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Reset8000
(* Function       : 
(**********************************************************************)
PROCEDURE Reset8000;

VAR L: LONGINT;

BEGIN
   WITH State8000 DO
   IF NOT ResetMode THEN
   BEGIN
      L := IC SHL 9;
      ToCore(10,1,@L);  (* Save restart address *)
      IntEn := FALSE;
      ResetMode := TRUE;
   END;
END; (* Reset8000 *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : SetBreakSeg
(* Function       : Fills the break segment with the break offset
(**********************************************************************)
PROCEDURE SetBreakSeg;

BEGIN
   CallProtected(@_SetBreakSeg);
END; (* SetBreakSeg *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : Run8000
(* Function       : Start (resume) RC8000.
(**********************************************************************)
PROCEDURE Run8000 ;

BEGIN

   IF FALSE THEN
   WITH GDT DO
   BEGIN
      VCPIIntf[0].ShowDescr('VCPIIntf[0]');
      VCPIIntf[1].ShowDescr('VCPIIntf[1]');
      VCPIData.ShowDescr('VCPIData');
      IntfCode.ShowDescr('IntfCode');
      PasData.ShowDescr('PasData');
      PasStack.ShowDescr('PasStack');
      Core.ShowDescr('Core');
   END;

   WITH State8000 DO
   BEGIN
      ResetMode := FALSE;
      CallProtected(@_Run8000);
      Beeper.Kill;
      IF ResetSys THEN
      BEGIN
         Reset8000;
      END;
      ResetSys := FALSE;
   END;
END; (* Run8000 *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FromCore
(* Function       : Copy a block from RC8000 core to V86 memory
(**********************************************************************)
PROCEDURE FromCore (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_FromCore);

END; (* FromCore *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ToCore
(* Function       : Copy a block from V86 memory to RC8000 core
(**********************************************************************)
PROCEDURE ToCore (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_ToCore);

END; (* ToCore *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FromCoreP
(* Function       : Copy a block from RC8000 core to V86 memory
(*                  W. conversion 24->32 bpw
(**********************************************************************)
PROCEDURE FromCoreP (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   IF (Len AND 3) <> 0
      THEN FatalError('FromCoreP: Length error');
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_FromCoreP);

END; (* FromCoreP *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ToCoreP
(* Function       : Copy a block from V86 memory to RC8000 core
(*                  W. conversion 32->24 bpw
(**********************************************************************)
PROCEDURE ToCoreP (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   IF (Len AND 3) <> 0
      THEN FatalError('ToCoreP: Length error');
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_ToCoreP);

END; (* ToCoreP *)
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FromCorePToXtra
(* Function       : Copy a block from RC8000 core to V86 memory
(*                  W. conversion 24->32 bpw
(**********************************************************************)
PROCEDURE FromCorePToXtra (Select: WORD; Addr: LONGINT; Len: WORD; BufPtr: LONGINT);

BEGIN
   IF (Len AND 3) <> 0
      THEN FatalError('FromCorePToXtra: Length error');
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := BufPtr;
      V86Seg   := Select;
   END;

   CallProtected(@_FromCoreP);

END; (* FromCorePToXtra *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ToCorePFromXtra
(* Function       : Copy a block from V86 memory to RC8000 core
(*                  W. conversion 32->24 bpw
(**********************************************************************)
PROCEDURE ToCorePFromXtra (Select: WORD; Addr: LONGINT; Len: WORD; BufPtr: LONGINT);

BEGIN
   IF (Len AND 3) <> 0
      THEN FatalError('ToCorePFromXtra: Length error');
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := BufPtr;
      V86Seg   := Select;
   END;

   CallProtected(@_ToCoreP);

END; (* ToCorePFromXtra *)
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FromCoreTxt
(* Function       : Copy a block from RC8000 core to V86 memory
(*                  W. conversion 24->32 bpw
(**********************************************************************)
PROCEDURE FromCoreTxt (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_FromCoreTxt);

END; (* FromCoreTxt *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ToCoreTxt
(* Function       : Copy a block from V86 memory to RC8000 core
(*                  W. conversion 32->24 bpw
(**********************************************************************)
PROCEDURE ToCoreTxt (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := CoreSeg;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_ToCoreTxt);

END; (* ToCoreTxt *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : FromCode
(* Function       : Copy a block from RC8000 sim. code seg to V86 memory
(**********************************************************************)
PROCEDURE FromCode (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := SCodeD;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_FromCode);

END; (* FromCode *)

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ToCode
(* Function       : Copy a block from V86 memory to RC8000 sim. code seg.
(**********************************************************************)
PROCEDURE ToCode (Addr: LONGINT; Len: WORD; BufPtr: POINTER);

BEGIN
   WITH CoreCopyPar DO
   BEGIN
      PMSeg    := SCodeD;
      CoreAddr := Addr;
      Words    := Len;
      V86Ref   := PtrToHuge(BufPtr);
      V86Seg   := VCPIDS;
   END;

   CallProtected(@_ToCode);

END; (* ToCode *)
(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ResetCore
(* Function       : 
(**********************************************************************)
PROCEDURE ResetCore;

BEGIN
   CallProtected(@_ResetCore);
END; (* ResetCore *)


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

   InitIDT;
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT INTF *)

