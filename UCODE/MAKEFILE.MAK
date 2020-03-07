# Makefile for RC4000/8000 emulator UCODE part   94-07-08 23:31 HJ 

COMMONS   = 8000.asm      \
            oputil.asm    \
            makemac.asm   \
            ..\ctrl\s8.asm\
            ..\ctrl\select.asm

COMMONS_I = $(COMMONS)    \
            addrmaci.asm

COMMONS_M = $(COMMONS)    \
            addrmacm.asm

COMMONS_S = $(COMMONS)    \
            addrmacs.asm


ucode : 8000.0 8000.1 8000.2 8000.3 8000.4 8000.5 8000.6 8000.7 8000.8 \
        8000.9 8000.A 8000.B 8000.C 8000.D 8000.E


8000.0 : instmac0.asm $(COMMONS_I)
         TASMX /dPart0 8000
         TLINK 8000,8000.0 /t /3

8000.1 : instmac1.asm $(COMMONS_M)
         TASMX /dPart1 8000
         TLINK 8000,8000.1 /t /3

8000.2 : instmac2.asm $(COMMONS_M)
         TASMX /dPart2 8000
         TLINK 8000,8000.2 /t /3

8000.3 : instmac3.asm $(COMMONS_M)
         TASMX /dPart3 8000
         TLINK 8000,8000.3 /t /3

8000.4 : instmac4.asm $(COMMONS_M)
         TASMX /dPart4 8000
         TLINK 8000,8000.4 /t /3

8000.5 : instmac5.asm $(COMMONS_M)
         TASMX /dPart5 8000
         TLINK 8000,8000.5 /t /3

8000.6 : instmac6.asm $(COMMONS_I)
         TASMX /dPart6 8000
         TLINK 8000,8000.6 /t /3

8000.7 : instmac7.asm $(COMMONS_S)
         TASMX /dPart7 8000
         TLINK 8000,8000.7 /t /3

8000.8 : instmac8.asm $(COMMONS_M)
         TASMX /dPart8 8000
         TLINK 8000,8000.8 /t /3

8000.9 : instmac9.asm $(COMMONS_S)
         TASMX /dPart9 8000
         TLINK 8000,8000.9 /t /3

8000.A : instmaca.asm $(COMMONS_M) flutil2.asm
         TASMX /dPartA 8000
         TLINK 8000,8000.A /t /3

8000.B : instmacb.asm $(COMMONS_M) flutil2.asm
         TASMX /dPartB 8000
         TLINK 8000,8000.B /t /3

8000.C : instmacc.asm $(COMMONS_S)
         TASMX /dPartC 8000
         TLINK 8000,8000.C /t /3

8000.D : instmacd.asm           # empty
         TASMX /dPartD 8000
         TLINK 8000,8000.D /t /3

8000.E : instmace.asm $(COMMONS_M) flutil2.asm
         TASMX /dPartE 8000
         TLINK 8000,8000.E /t /3



          
