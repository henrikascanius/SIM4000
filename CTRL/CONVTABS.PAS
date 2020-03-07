(**********************************************************************)
(* Unit name      : CONVTABS.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 96-08-02 20:04   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  Conversion tables for char I/O
(*
(**********************************************************************)

{$F+}

UNIT CONVTABS;


INTERFACE

CONST
   MAXINPTABLENO = 2;

TYPE
   ConvAttributes   = (TERMINATING, ATTENTION_CHAR, BS_CHAR, CAN_CHAR, BLIND_CHAR);
   ConvAttributeSet = SET OF ConvAttributes;
   EchoString       = STRING[3];

   ConvTableEntryP= ^ConvTableEntry;

   ConvTableEntry = RECORD
      Attr  : ConvAttributeSet;
      Echo  : EchoString;
      ChVal : BYTE;
   END;

   InpConvTable = ARRAY[0..31] OF ConvTableEntry;
   InpConvTableP= ^InpConvTable;

CONST

(**********************************************************************)
(*****
(*****                     RC4000 Console table
(*****
(**********************************************************************)

   ConvTable0: InpConvTable =
   (
    (Attr   : [BS_CHAR];                       (*127 *)
     Echo   : '_';
     ChVal  : 0),

    (Attr   : [];                              (*  1 *)
     Echo   : #1;
     ChVal  : 1),

    (Attr   : [];                              (*  2 *)
     Echo   : #2;
     ChVal  : 2),

    (Attr   : [];                              (*  3 *)
     Echo   : #3;
     ChVal  : 3),

    (Attr   : [];                              (*  4 *)
     Echo   : #4;
     ChVal  : 4),

    (Attr   : [CAN_CHAR];                      (*  5 *)
     Echo   : '^';
     ChVal  : 5),

    (Attr   : [];                              (*  6 *)
     Echo   : #6;
     ChVal  : 6),

    (Attr   : [];                              (*  7 *)
     Echo   : #7;
     ChVal  : 7),

    (Attr   : [BS_CHAR];                       (*  8 *)
     Echo   : #8#32#8;
     ChVal  : 0),

    (Attr   : [];                              (*  9 *)
     Echo   : #9;
     ChVal  : 9),

    (Attr   : [TERMINATING];                   (* 10 *)
     Echo   : #10;
     ChVal  : 10),

    (Attr   : [];                              (* 11 *)
     Echo   : #11;
     ChVal  : 11),

    (Attr   : [];                              (* 12 *)
     Echo   : #12;
     ChVal  : 12),

    (Attr   : [TERMINATING];                   (* 13 *)
     Echo   : #13#10;
     ChVal  : 10),

    (Attr   : [];                              (* 14 *)
     Echo   : #14;
     ChVal  : 14),

    (Attr   : [];                              (* 15 *)
     Echo   : #15;
     ChVal  : 15),

    (Attr   : [];                              (* 16 *)
     Echo   : #16;
     ChVal  : 16),

    (Attr   : [];                              (* 17 *)
     Echo   : #17;
     ChVal  : 17),

    (Attr   : [];                              (* 18 *)
     Echo   : #18;
     ChVal  : 18),

    (Attr   : [];                              (* 19 *)
     Echo   : #19;
     ChVal  : 19),

    (Attr   : [];                              (* 20 *)
     Echo   : #20;
     ChVal  : 20),

    (Attr   : [];                              (* 21 *)
     Echo   : #21;
     ChVal  : 21),

    (Attr   : [];                              (* 22 *)
     Echo   : #22;
     ChVal  : 22),

    (Attr   : [];                              (* 23 *)
     Echo   : #23;
     ChVal  : 23),

    (Attr   : [];                              (* 24 *)
     Echo   : #24;
     ChVal  : 24),

    (Attr   : [];                              (* 25 *)
     Echo   : #25;
     ChVal  : 25),

    (Attr   : [];                              (* 26 *)
     Echo   : #26;
     ChVal  : 26),

    (Attr   : [TERMINATING,ATTENTION_CHAR];    (* 27 *)
     Echo   : #27;
     ChVal  : 0),

    (Attr   : [];                              (* 28 *)
     Echo   : #28;
     ChVal  : 28),

    (Attr   : [];                              (* 29 *)
     Echo   : #29;
     ChVal  : 29),

    (Attr   : [];                              (* 30 *)
     Echo   : #30;
     ChVal  : 30),

    (Attr   : [];                              (* 31 *)
     Echo   : #31;
     ChVal  : 31));

(**********************************************************************)
(*****
(*****                     DTU Data Entry table
(*****
(**********************************************************************)


   ConvTable1: InpConvTable =
   (
    (Attr   : [BS_CHAR];                       (*127 *)
     Echo   : #0;
     ChVal  : 0),

    (Attr   : [TERMINATING];                   (*  1 *)
     Echo   : '';
     ChVal  : 1),

    (Attr   : [TERMINATING];                   (*  2 *)
     Echo   : '';
     ChVal  : 2),

    (Attr   : [TERMINATING];                   (*  3 *)
     Echo   : '';
     ChVal  : 3),

    (Attr   : [TERMINATING];                   (*  4 *)
     Echo   : '';
     ChVal  : 4),

    (Attr   : [CAN_CHAR];                      (*  5 *)
     Echo   : '^';
     ChVal  : 5),

    (Attr   : [TERMINATING];                   (*  6 *)
     Echo   : '';
     ChVal  : 6),

    (Attr   : [TERMINATING];                   (*  7 *)
     Echo   : '';
     ChVal  : 7),

    (Attr   : [BS_CHAR];                       (*  8 *)
     Echo   : #8#32#8;
     ChVal  : 0),

    (Attr   : [];                              (*  9 *)
     Echo   : #9;
     ChVal  : 9),

    (Attr   : [TERMINATING];                   (* 10 *)
     Echo   : #10;
     ChVal  : 10),

    (Attr   : [TERMINATING];                   (* 11 *)
     Echo   : '';
     ChVal  : 11),

    (Attr   : [TERMINATING];                   (* 12 *)
     Echo   : '';
     ChVal  : 12),

    (Attr   : [TERMINATING];                   (* 13 *)
     Echo   : #13#10;
     ChVal  : 10),

    (Attr   : [TERMINATING];                   (* 14 *)
     Echo   : '';
     ChVal  : 14),

    (Attr   : [TERMINATING];                   (* 15 *)
     Echo   : '';
     ChVal  : 15),

    (Attr   : [TERMINATING];                   (* 16 *)
     Echo   : '';
     ChVal  : 16),

    (Attr   : [TERMINATING];                   (* 17 *)
     Echo   : '';
     ChVal  : 17),

    (Attr   : [TERMINATING];                   (* 18 *)
     Echo   : '';
     ChVal  : 18),

    (Attr   : [TERMINATING];                   (* 19 *)
     Echo   : '';
     ChVal  : 19),

    (Attr   : [TERMINATING];                   (* 20 *)
     Echo   : '';
     ChVal  : 20),

    (Attr   : [TERMINATING];                   (* 21 *)
     Echo   : '';
     ChVal  : 21),

    (Attr   : [TERMINATING];                   (* 22 *)
     Echo   : '';
     ChVal  : 22),

    (Attr   : [TERMINATING];                   (* 23 *)
     Echo   : '';
     ChVal  : 23),

    (Attr   : [];                              (* 24 *)
     Echo   : #24;
     ChVal  : 24),

    (Attr   : [TERMINATING];                   (* 25 *)
     Echo   : '';
     ChVal  : 25),

    (Attr   : [TERMINATING];                   (* 26 *)
     Echo   : '';
     ChVal  : 26),

    (Attr   : [TERMINATING,ATTENTION_CHAR];    (* 27 *)
     Echo   : '';
     ChVal  : 0),

    (Attr   : [];                              (* 28 *)
     Echo   : '';
     ChVal  : 0),

    (Attr   : [TERMINATING];                   (* 29 *)
     Echo   : '';
     ChVal  : 29),

    (Attr   : [TERMINATING];                   (* 30 *)
     Echo   : '';
     ChVal  : 30),

    (Attr   : [TERMINATING];                   (* 31 *)
     Echo   : '';
     ChVal  : 31));


(**********************************************************************)
(*****
(*****                    Table for Screen Editor
(*****
(**********************************************************************)

   ConvTable2: InpConvTable =
   (
    (Attr   : [TERMINATING];                   (*  0 *)
     Echo   : '';
     ChVal  : 127),

    (Attr   : [TERMINATING];                   (*  1 *)
     Echo   : '';
     ChVal  : 1),

    (Attr   : [TERMINATING];                   (*  2 *)
     Echo   : '';
     ChVal  : 2),

    (Attr   : [TERMINATING];                   (*  3 *)
     Echo   : '';
     ChVal  : 3),

    (Attr   : [TERMINATING];                   (*  4 *)
     Echo   : '';
     ChVal  : 4),

    (Attr   : [TERMINATING];                   (*  5 *)
     Echo   : '';
     ChVal  : 5),

    (Attr   : [TERMINATING];                   (*  6 *)
     Echo   : '';
     ChVal  : 6),

    (Attr   : [TERMINATING];                   (*  7 *)
     Echo   : '';
     ChVal  : 7),

    (Attr   : [TERMINATING];                   (*  8 *)
     Echo   : '';
     ChVal  : 8),

    (Attr   : [TERMINATING];                   (*  9 *)
     Echo   : '';
     ChVal  : 9),

    (Attr   : [TERMINATING];                   (* 10 *)
     Echo   : '';
     ChVal  : 10),

    (Attr   : [TERMINATING];                   (* 11 *)
     Echo   : '';
     ChVal  : 11),

    (Attr   : [TERMINATING];                   (* 12 *)
     Echo   : '';
     ChVal  : 12),

    (Attr   : [TERMINATING];                   (* 13 *)
     Echo   : '';
     ChVal  : 13),

    (Attr   : [TERMINATING];                   (* 14 *)
     Echo   : '';
     ChVal  : 14),

    (Attr   : [TERMINATING];                   (* 15 *)
     Echo   : '';
     ChVal  : 15),

    (Attr   : [TERMINATING];                   (* 16 *)
     Echo   : '';
     ChVal  : 16),

    (Attr   : [TERMINATING];                   (* 17 *)
     Echo   : '';
     ChVal  : 17),

    (Attr   : [TERMINATING];                   (* 18 *)
     Echo   : '';
     ChVal  : 18),

    (Attr   : [TERMINATING];                   (* 19 *)
     Echo   : '';
     ChVal  : 19),

    (Attr   : [TERMINATING];                   (* 20 *)
     Echo   : '';
     ChVal  : 20),

    (Attr   : [TERMINATING];                   (* 21 *)
     Echo   : '';
     ChVal  : 21),

    (Attr   : [TERMINATING];                   (* 22 *)
     Echo   : '';
     ChVal  : 22),

    (Attr   : [TERMINATING];                   (* 23 *)
     Echo   : '';
     ChVal  : 23),

    (Attr   : [TERMINATING];                   (* 24 *)
     Echo   : '';
     ChVal  : 24),

    (Attr   : [TERMINATING];                   (* 25 *)
     Echo   : '';
     ChVal  : 25),

    (Attr   : [TERMINATING];                   (* 26 *)
     Echo   : '';
     ChVal  : 26),

    (Attr   : [TERMINATING,ATTENTION_CHAR];    (* 27 *)
     Echo   : '';
     ChVal  : 0),

    (Attr   : [];                              (* 28 *)
     Echo   : '';
     ChVal  : 0),

    (Attr   : [TERMINATING];                   (* 29 *)
     Echo   : '';
     ChVal  : 29),

    (Attr   : [TERMINATING];                   (* 30 *)
     Echo   : '';
     ChVal  : 30),

    (Attr   : [TERMINATING];                   (* 31 *)
     Echo   : '';
     ChVal  : 31));


   InpConvTables: ARRAY[0..MAXINPTABLENO] OF InpConvTableP =
      (@ConvTable0,
       @ConvTable1,
       @ConvTable2);

(**********************************************************************)
(*****
(*****                Composite PC key convert table:
(*****
(**********************************************************************)


   CompKeyTable: ARRAY[0..255] OF BYTE =

   ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 4, 6,23,
    25,12,14,15,18, 0, 0,17,19, 7, 0, 8, 0,24, 0,22,
    20,11, 5,127,26,29,30,31,2,10,16, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

(*#PAGE*)
IMPLEMENTATION


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
END; (* UnitEntry *)



BEGIN
   UnitEntry;
END. (* UNIT CONVTABS *)

