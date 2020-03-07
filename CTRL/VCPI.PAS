(**********************************************************************)
(* Unit name      : VCPI.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-05-10 21:03   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  VCPI-specific part of SIM8000.
(*  Change history:
(* 94-12-10 18:25 HJ Release VCPI memory before EMS handle (STEALTH problem)
(*
(**********************************************************************)

{$F+}

UNIT VCPI;

INTERFACE

USES
   Descr;




TYPE

   PMEntryBlock =
   RECORD
      CR3   :  LONGINT;
      GDTR  :  LONGINT;
      IDTR  :  LONGINT;
      LDTR  :  WORD;
      TR    :  WORD;
      EIP   :  LONGINT;
      CS    :  WORD;
   END;

   V86EntryBlock =
   RECORD
      V86Block: ARRAY [1..256] OF BYTE;  (* Defined in STRUCTS.ASM *)
   END;


   FWORD =
   RECORD
      Offset   : HugePtr;
      Selector : WORD;
   END;

   DTRType =
   RECORD
      Limit    : WORD;
      Offset   : HugePtr;
   END;

   PageTableType = ARRAY[0..1023] OF LONGINT;
   PageDirType   = PageTableType;

VAR
   EmsHandle   : WORD;

   PageFrame   : Pointer;
   VcpiPMEntry : FWORD;

   PageTablePtr: ARRAY [0..2] OF ^PageTableType;
   PageDirPtr  : ^PageTableType;
   NoOfPageTables: WORD;
   V86         : V86EntryBlock;

   CoreSize    : LONGINT;

CONST
   MaxXtraGDescrs  = 8;  (* Descriptors in GDT for RAM-discs etc. *)

   LDT          =  1  * 8;
   VCPICS       =  2  * 8;
   VCPIDS       =  5  * 8;
   CoreSeg      =  6  * 8;
   TSSDescr     =  7  * 8;
   PascData     =  8  * 8;
   PascStack    =  9  * 8;
   SCode        = 10  * 8;
   SCodeD       = 11  * 8;
   ICode        = 12  * 8;
   PMStackSeg   = 13  * 8;
   State8Seg    = 14  * 8;
   PMItackSeg   = 15  * 8;
   BreakSeg     = 16  * 8;
   XtraBase     = 17  * 8;


VAR
   GDT   :  RECORD
               NullDescr   :  Descr386;
               LDT0        :  MemDescr;
               VCPIIntf    :  ARRAY[0..2] OF MemDescr;
               VCPIData    :  MemDescr;
               Core        :  MemDescr;
               TSSD        :  SysDescr;
               PasData     :  MemDescr;
               PasStack    :  MemDescr;
               SimCode     :  MemDescr;
               SimCodeD    :  MemDescr;
               IntfCode    :  MemDescr;
               Stack       :  MemDescr;
               State8      :  MemDescr;
               IStack      :  MemDescr;
               BreakS      :  Memdescr;
               XtraDescrs  :  ARRAY [0..MaxXtraGDescrs-1] OF MemDescr;
            END;

   IDT   :  ARRAY [0..255] OF GateDescr;
               


   GDTRVal :  DTRType;
   IDTRVal :  DTRType;

   PMParam : PMEntryBlock;

   TSS     : TSSType;  (* Dummy Task State Segment *)

CONST
   VcpiInitialised: BOOLEAN = FALSE;
   Free:            LONGINT = 0;

   FirstFreeXtraGDescr: BYTE = 0;


FUNCTION  Avail4KPages: LONGINT; 

FUNCTION  PtrToHuge(Ptr: Pointer): HugePtr; 
FUNCTION  GetPhysAddr(PageNo: WORD): HugePtr; 
FUNCTION  CallProtectedMode(PMPar: HugePtr): WORD ; 


PROCEDURE InitVCPI;
PROCEDURE InitDescrs;
FUNCTION  CreateCore (Min,Max: LONGINT): LONGINT;
FUNCTION  AllocateXtraSegment (Appetite: LONGINT): INTEGER;
PROCEDURE Allocate4K;


(*#PAGE*)
IMPLEMENTATION

USES
   Util,
   Intf,
   Dos,
   OpRoot,
   OpString,
   OpEms;




CONST
   EmsAllocated: BOOLEAN = FALSE;

   FirstCorePage: LONGINT = 0;
   LastCorePage:  LONGINT = -1;

   _Free:         LONGINT = 0; (* Initial free *)


FUNCTION  PtrToHuge(Ptr: Pointer): HugePtr; EXTERNAL;

FUNCTION  VCPIAvail: BOOLEAN; EXTERNAL;
FUNCTION  GetVCPI(PageTb,GDTEntry: Pointer;
                  VAR EntryPoint: LONGINT; VAR FreeOffs: WORD): BOOLEAN; EXTERNAL;
FUNCTION  Allocate4KPage : HugePtr;  EXTERNAL;
FUNCTION  Free4KPage(PhysAddr: HugePtr): BOOLEAN; EXTERNAL;
FUNCTION  Avail4KPages: LONGINT; EXTERNAL;
FUNCTION  GetPhysAddr(PageNo: WORD): HugePtr; EXTERNAL;
FUNCTION  CallProtectedMode(PMPar: HugePtr): WORD ; EXTERNAL;

{$L VCPI.OBJ}

(**********************************************************************)
(* Proc. Name     : InitVCPI
(* Function       : Create page tables etc.
(**********************************************************************)
PROCEDURE InitVCPI;

VAR
   Fr,
   Pg: WORD;

BEGIN
   IF NOT VCPIInitialised THEN
   BEGIN
      IF NOT EmsInstalled
         THEN FatalError('EMS handler not found');

      IF NOT EmsStatusOK 
         THEN FatalError('EMS handler reports status not OK');

      PageFrame := EmsPageFramePtr;
   
      (* Allocate space for Page Directory & Page Tables 0..3 *)
      EmsHandle := AllocateEmsPages(1);
      IF EmsHandle = EmsErrorCode
         THEN FatalError('Could not allocate page tables in EMS');

      EmsAllocated := TRUE;

      IF NOT VCPIAvail
         THEN FatalError('VCPI server not found');

      IF NOT MapEmsPage(EmsHandle,0,0)
         THEN FatalError('Map EMS page Failed ???');

      GDT.VCPIIntf[0].Init(EXECREAD,0,FALSE,FALSE,TRUE);

      IF NOT GetVCPI(PageFrame,@GDT.VCPIIntf[0],VcpiPMEntry.Offset,Fr)
         THEN FatalError('Get VCPI PM interface failed');

      Free := Fr;  (* Convert to LONGINT *)

      VcpiPMEntry.Selector := VCPICS;

      (* Build descriptor of VCPI data area *)
      WITH GDT.VCPIData DO
      BEGIN
         Init(READWRITE,0,TRUE,TRUE,TRUE);
         SetBaseAddr(0);
         SetLimit(Free SHR 2);
      END;

      PageTablePtr[0] := PageFrame;
      PageTablePtr[1] := Ptr(Seg(PageFrame^),Ofs(PageFrame^)+$1000);
      PageTablePtr[2] := Ptr(Seg(PageFrame^),Ofs(PageFrame^)+$2000);

      (* Allocate Page Directory in upper 4K of the 16K EMS frame.
         At present, we allow max. 3 page tables (placed in rest of EMS frame),
         corresp. to 12 MB physical 80386 memory
      *)
      PageDirPtr := Ptr(Seg(PageFrame^),Ofs(PageFrame^)+$3000);
      PageDirPtr^[0] := GetPhysAddr(PtrToHuge(PageTablePtr[0]) SHR 12) + 7;
      NoOfPageTables := 1;

      FOR Pg := NoOfPageTables TO 1023 DO PageDirPtr^[Pg] := 0;
      FOR Pg := (Free SHR 2) TO 3071 DO PageTablePtr[0]^[Pg] := 0;

      WITH PMParam DO
      BEGIN
         CR3  := GetPhysAddr(PtrToHuge(PageDirPtr) SHR 12);
         GDTR := PtrToHuge(@GDTRVal);
         IDTR := PtrToHuge(@IDTRVal);
         LDTR := 0;
         TR   := TSSDescr;
      END;

      _Free := Free;
      VCPIInitialised := TRUE;
   END;
END; (* InitVCPI *)

(**********************************************************************)
(* Proc. Name     : Allocate4K
(* Function       : Allocate a 4K-page and insert in page table.
(**********************************************************************)
PROCEDURE Allocate4K;

VAR
   PhAddr: HugePtr;
   PageNo: WORD;

BEGIN
   InitVCPI;
   PhAddr := Allocate4KPage;
   IF PhAddr = 0
      THEN FatalError('Allocate 4K page failed');

   PageNo := Free SHR 2;
   PageTablePtr[0]^[PageNo] := PhAddr + 7; (* Present, R/W *)

   IF (PageNo AND $3FF) = 0 THEN
   BEGIN
      PageDirPtr^[NoOfPageTables] :=
         GetPhysAddr(PtrToHuge(PageTablePtr[NoOfPageTables]) SHR 12) + 7;
      Inc(NoOfPageTables);
      IF NoOfPageTables > 3    (* requires >12MB ext. memory to occur *)
         THEN FatalError('Page directory overflow, reduce max. core size');
   END;

   Inc(Free,4);

END; (* Allocate4K *)



(**********************************************************************)
(* Func. Name     : CreateCore
(* Function       : Reserves RC8000 core store.
(**********************************************************************)
FUNCTION CreateCore (Min, Max: LONGINT): LONGINT;

VAR
   CorePages,
   Size: LONGINT;
   I: WORD;

BEGIN
   InitVCPI;
   IF (Max=0) OR (Max>$400000) THEN Max := $400000; (* Max. core size = 2**22 hw *)
   Max := Max AND $00fff800;     (* int. no. of 2K hw *)


   Size := Avail4KPages * 2048;
   IF Size > Max THEN Size := Max;
   IF Size < Min
      THEN FatalError('Not enough memory available');

   CorePages := Size DIV 2048;

   FirstCorePage := Free SHR 2;

   FOR LastCorePage := FirstCorePage TO FirstCorePage+CorePages-1 DO
      Allocate4K;

   WITH GDT.Core DO
   BEGIN
      Init(READWRITE,0,TRUE,TRUE,TRUE);
      SetBaseAddr(FirstCorePage SHL 12);
      SetLimit(CorePages-1);
      CoreBase := FirstCorePage SHL 12;
   END;

   CreateCore := Size;

END; (* CreateCore *)

(**********************************************************************)
(* Proc. Name     : AllocateXtraSegment
(* Function       : Allocate an amount of phys. memory and return 
(*                  selector. Appetite is req. size in 4K pages.
(**********************************************************************)
FUNCTION AllocateXtraSegment (Appetite: LONGINT): INTEGER;

VAR
   SelectNo: BYTE;
   I,
   FirstPage,
   Pages: LONGINT;

BEGIN
   InitVCPI;
   IF FirstFreeXtraGDescr > MaxXtraGDescrs THEN
      FatalError('No more xtra memory descriptors available');

   SelectNo := FirstFreeXtraGDescr;
   Inc(FirstFreeXtraGDescr);

   Pages := Appetite;
   IF Avail4KPages < Pages THEN
      FatalError('Not enough memory, req. segment size: '
                 +Long2Str(Appetite SHL 12)+' bytes');
   FirstPage := Free SHR 2;
   FOR I := 1 TO Pages DO Allocate4K;

   WITH GDT.XtraDescrs[SelectNo] DO
   BEGIN
      Init(READWRITE,0,TRUE,TRUE,TRUE);
      SetBaseAddr(firstPage SHL 12);
      SetLimit(Pages-1);
   END;

   AllocateXtraSegment := XtraBase + (SelectNo SHL 3);

END; (* AllocateXtraSegment *)



(**********************************************************************)
(* Proc. Name     : InitDescrs
(* Function       : Init various descriptors etc.
(**********************************************************************)
PROCEDURE InitDescrs;

VAR I: WORD;

BEGIN
   FOR I := 0 TO TSSSize-1 DO
      TSS[I] := 0;

   FOR I := 1 TO SizeOf(V86) DO V86.V86Block[I] := 0;


   GDTRVal.Limit := SizeOf(GDT)-1;
   GDTRVal.Offset := PtrToHuge(@GDT);

   IDTRVal.Limit := SizeOf(IDT)-1;
   IDTRVal.Offset := PtrToHuge(@IDT);

   (* Init. task descriptor *)
   WITH GDT.TSSD DO
   BEGIN
      Init(TSS386,0,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(@TSS));
      SetLimit(SizeOf(TSS));
   END;

   (* Init. descriptor for Turbo Pascal DS *)
   WITH GDT.PasData DO
   BEGIN
      Init(READWRITE,0,FALSE,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(Ptr(Seg(GDT),0)));
      SetLimit($FFFF);
   END;

   (* Init. descriptor for Turbo Pascal SS *)
   WITH GDT.PasStack DO
   BEGIN
      Init(READWRITE,0,FALSE,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(Ptr(Seg(I),0)));
      SetLimit($FFFF);
   END;

   (* Init. descriptor for interface code segment *)
   WITH GDT.IntfCode DO
   BEGIN
      Init(EXECREAD,0,FALSE,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(Ptr(Seg(_Run8000),0)));
      SetLimit($FFFF);
   END;

   (* Build descriptor of protected mode stack for ucode *)
   WITH GDT.Stack DO
   BEGIN
      Init(READWRITE,0,FALSE,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(@_PMStack));
      SetLimit(PMStackSize-1);
   END;

   (* Build descriptor of protected mode stack for intf. routines *)
   WITH GDT.IStack DO
   BEGIN
      Init(READWRITE,0,FALSE,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(@_PMIStack));
      SetLimit(PMIStackSize-1);
   END;

   (* Build descriptor of State8000 record *)
   WITH GDT.State8 DO
   BEGIN
      Init(READWRITE,0,FALSE,FALSE,TRUE);
      SetBaseAddr(PtrToHuge(@State8000));
      SetLimit(SizeOf(State8000)-1);
   END;

END; (* InitDescrs *)

(**********************************************************************)
(* Proc. Name     : ReleaseMemory
(* Function       : Free memory used for RC8000 core and code.
(**********************************************************************)
PROCEDURE ReleaseMemory;

VAR 
   Pg: LONGINT;

BEGIN
   IF Free > 0 THEN
   FOR Pg := (_Free SHR 2) TO (Free SHR 2) - 1 DO
      IF Free4KPage(PageTablePtr[0]^[Pg] AND $FFFFF000) THEN ;
END; (* ReleaseMemory *)


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
   ReleaseMemory;

   IF EmsAllocated THEN
      IF DeallocateEMSHandle(EmsHandle) THEN;


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
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT VCPI *)

