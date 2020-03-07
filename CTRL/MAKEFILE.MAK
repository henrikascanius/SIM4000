# Makefile for RC4000/8000 emulator CTRL part   94-07-09 00:15 HJ 
.asm.obj :
    TASM $*


PAS_FILES   =   AUDIO.PAS    \
                CLOCK.PAS    \
                CONFIG.PAS   \
                CONS.PAS     \
                CX.PAS       \
                CONVTABS.PAS \
                DESCR.PAS    \
                DOSDEV.PAS   \
                EXPANDER.PAS \
                FIL.PAS      \
                INTF.PAS     \
                INTR.PAS     \
                IO.PAS       \
                LOAD.PAS     \
                LOGO.PAS     \
                MKDISC.PAS   \
                POPUP.PAS    \
                PUNCH.PAS    \
                RC4818.PAS   \
                RC433.PAS    \
                RC8000.PAS   \
                RC851.PAS    \
                READER.PAS   \
                SCRN.PAS     \
                SLANGP.PAS   \
                UTIL.PAS     \
                VCPI.PAS     \
                WIN.PAS      \
                VERSION.INC  \
                OPDEFINE.INC \
                COLOR.DEF


OBJ_FILES   =   INTF.OBJ     \
                VCPI.OBJ


UCODE_OBJS  =   ..\UCODE\*.ASM


ctrl       : RC8000.EXE

rc8000.exe : $(PAS_FILES) $(OBJ_FILES) $(UCODE_OBJS)
             @cd ..\ucode
             @make
             @cd ..\ctrl
             bpc /m $*

.AUTODEPEND

