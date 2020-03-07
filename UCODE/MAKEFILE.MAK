# Makefile for RC4000/8000 emulator UCODE part   94-07-08 23:31 HJ 

COMMONS   = uchead.asm    \
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

.asm.abs:
        TASMX /dDOSBOX $*
        TLINK $*,$*.ABS /t /3

ucode : 4000_0.ABS 4000_1.ABS 4000_2.ABS 4000_3.ABS 4000_4.ABS 4000_5.ABS \
        4000_6.ABS 4000_7.ABS 4000_8.ABS 4000_9.ABS 4000_A.ABS 4000_B.ABS \
        4000_C.ABS 4000_D.ABS 4000_E.ABS 4000_F.ABS


4000_0.ABS : 4000_0.asm $(COMMONS_I)
4000_1.ABS : 4000_1.asm $(COMMONS_M)
4000_2.ABS : 4000_2.asm $(COMMONS_M)
4000_3.ABS : 4000_3.asm $(COMMONS_M)
4000_4.ABS : 4000_4.asm $(COMMONS_M)
4000_5.ABS : 4000_5.asm $(COMMONS_M)
4000_6.ABS : 4000_6.asm $(COMMONS_I)
4000_7.ABS : 4000_7.asm $(COMMONS_S)
4000_8.ABS : 4000_8.asm $(COMMONS_M)
4000_9.ABS : 4000_9.asm $(COMMONS_S)
4000_A.ABS : 4000_a.asm $(COMMONS_M) flutil2.asm
4000_B.ABS : 4000_b.asm $(COMMONS_M) flutil2.asm
4000_C.ABS : 4000_c.asm $(COMMONS_S)
4000_D.ABS : 4000_d.asm $(COMMONS_M) flutil2.asm
4000_E.ABS : 4000_e.asm $(COMMONS_M) flutil2.asm
4000_F.ABS : 4000_f.asm $(COMMONS_M)



