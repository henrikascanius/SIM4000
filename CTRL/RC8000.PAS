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
{$E-}
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
   Load,
   Fil;

{$I COLOR.DEF}

(*#CPAGE 20*)
(**********************************************************************)
(* Proc. Name     : ShowHelp
(* Function       : 
(**********************************************************************)
PROCEDURE ShowHelp;

BEGIN
   WriteLn('RC4000 emulator ',VersString,'  (c) Henrik Jacobsen ',VersYear);
   WriteLn('');
   WriteLn('Available parameters:');
   WriteLn('   /A             : Automatic autoload from device 0 (paper tape reader)');
   WriteLn('   /A:<filename>  : Load monitor from DOS file and start it');
   WriteLn('   /S             : In connection w. /A:<filename>: Sets the');
   WriteLn('                    "Disc Load Flag" in rel. address +2 of the monitor,');
   WriteLn('                    causing the "autostart" action to occur if a startup');
   WriteLn('                    area name was included when the monitor was generated');
   WriteLn('Parameters must be separated by at least one blank.');
   WriteLn('');
END; (* ShowHelp *)


(*#PAGE*)
(**********************************************************************)
(* Procedure Name    : main { main procedure of program }
(* Called Procedures :
(**********************************************************************)
PROCEDURE Main;

CONST
    ShowLogo : BOOLEAN = TRUE;
    MonitorName: STRING[80] = '';
    SetInitSwitch : BOOLEAN = FALSE;

VAR I: INTEGER;
    L,L2: ARRAY [0..9] OF LONGINT;

    BiosTime: WORD ABSOLUTE $40:$6C;
    StartTime: WORD;
    Attr: BYTE;
    x: SINGLE;

BEGIN
   x := 1.0; (* Force test for 8087 *)
   Test8086 := 0; (* Too many bugs! *)

   FOR I := 1 TO ParamCount DO
      IF ParamStr(I) = '/?' THEN 
      BEGIN
         ShowHelp;
         Halt(0);
      END ELSE
      IF Copy(StUpcase(ParamStr(I)),1,2) = '/A' THEN
      BEGIN
         IF Length(ParamStr(I))=2 THEN AutoAutoload := TRUE ELSE
         BEGIN
            MonitorName := Copy(ParamStr(I),3,255);
            IF MonitorName[1] = ':' THEN Delete(MonitorName,1,1);
         END;
      END ELSE
      IF StUpcase(ParamStr(I)) = '/S' THEN SetInitSwitch := TRUE ELSE
      IF ParamStr(I) = '/:' THEN ShowLogo := FALSE ELSE
      BEGIN
         WriteLn('Bad parameter: ',ParamStr(I));
         WriteLn;
         ShowHelp;
         Halt(1);
      END;

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

   IF MonitorName <> '' THEN AutoloadMonitor(MonitorName,SetInitSwitch);
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


