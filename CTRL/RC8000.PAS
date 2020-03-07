(**********************************************************************)
(* Program name   : RC8000.PAS
(* Pascal Version : Borland Pascal 7.0
(* Change History :
(* 92-05-11 21:37   HJ Initial version
(*
(*
(**********************************************************************)

(**********************************************************************)
(* Functional description :
(* ------------------------
(*  RC8000 Simulator for 80386.
(*
(**********************************************************************)

PROGRAM RC8000;
{$M 32768,100000,400000}
{$N+}
{$E+}
USES
   OpCrt,
   OpColor,
   OpString,
   Util,
   Intr,
   Config,
   Win, 
   Intf,
   Descr,
   Vcpi,
   Popup,
   Logo,
   Scrn,
   Load;

{$I COLOR.DEF}

(*#PAGE*)
(**********************************************************************)
(* Procedure Name    : main { main procedure of program }
(* Called Procedures :
(**********************************************************************)
PROCEDURE Main;

CONST
    ShowLogo : BOOLEAN = TRUE;

VAR I: INTEGER;
    L,L2: ARRAY [0..9] OF LONGINT;

    BiosTime: WORD ABSOLUTE $40:$6C;
    StartTime: WORD;
    Attr: BYTE;
    x: SINGLE;

BEGIN
   x := 1.0; (* Force inclusion of 8087 emulator *)
   Test8086 := 0; (* Too many bugs! *)

   FOR I := 1 TO ParamCount DO
      IF StUpcase(ParamStr(I)) = '/A' THEN AutoAutoload := TRUE ELSE
      IF ParamStr(I) = '/:' THEN ShowLogo := FALSE;

   InitUserTextAttr;
   OpCrt.TextAttr := UserTextAttr; (* Our attr. detect is better than OpCrt *)
   WITH Colors DO
    FastFill(ScreenHeight*ScreenWidth,' ',1,1,UserTextAttr);

   State8000.FullAccuracy := Full8254Supported;

   InitDescrs;
   LoadCode;
   InitWindows;
   InitIntHandlers;
   MakeConfig;

   CoreSize := CreateCore(CoreMin,CoreMax);
   ResetCore;

   IF ShowLogo THEN
   WITH Colors DO
   BEGIN
      Attr := ColorMono(WhiteOnGreen,WhiteOnBlack);
      StartTime := BiosTime;
      PopUpLogo(Attr);

      IF State8000.FullAccuracy 
         THEN PopW.wFastCenter('Clock resolution: 100 us',7,Attr)
         ELSE PopW.wFastCenter('Clock resolution: 25.6 ms',7,Attr);

      PopW.wFastCenter('Core store size: '+Long2Str(CoreSize)+' HW',8,Attr); 

{$IFDEF DIAGS}
      PopW.wFastCenter('Heap: '+Long2Str(MemAvail)+' '+Long2Str(MaxAvail),6,Attr);
{$ENDIF}

      WHILE KeyPressed DO IF ReadKey=' ' THEN ;
      WHILE (BiosTime<(StartTime+6*18)) AND NOT KeyPressed DO;
      WHILE KeyPressed DO IF ReadKey=' ' THEN ;

      PopUpDone;
   END;

   WS.Process;
   WS.Done;

   {WITH Colors DO
    FastFill(ScreenHeight*ScreenWidth,' ',1,1,ColorMono(TextColor,TextMono));}
   FastFill(ScreenHeight*ScreenWidth,' ',1,1,UserTextAttr);

   IF CrtBorderOn THEN SetCrtBorder(UserTextAttr);
   ClrScr;

END; (* Main *)




 { Main Program }
 BEGIN main END.


