
InsEntry MACRO No

Addr    =       $
        ORG     (No*2)+100h
        dw      SMALL Addr - 100H   ; 100H comes from .COM file offset
        ORG     Addr

        ENDM



MakeOp  MACRO   Op,OpCode

OpNo    =       OpCode*64

; *************************** W0 ******************************

                        ; Displacement
        InsEntry %OpNo
        amode0
        _&Op& 0
OpNo    =       OpNo+1

                        ; x+Displacement
        InsEntry %OpNo
        amode2 1
        _&Op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 2
        _&Op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 3
        _&Op& 0
OpNo    =       OpNo+1



                        ; Displacement indirect
        InsEntry %OpNo
        amode4
        _&Op& 0
OpNo    =       OpNo+1

                        ; x+Displacement indirect
        InsEntry %OpNo
        amode6 1
        _&Op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 2
        _&Op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 3
        _&Op& 0
OpNo    =       OpNo+1



                        ; Displacement relative
        InsEntry %OpNo
        amode1
        _&Op& 0
OpNo    =       OpNo+1

                        ; x+Displacement relative
        InsEntry %OpNo
        amode3 1
        _&Op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 2
        _&Op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 3
        _&Op& 0
OpNo    =       OpNo+1



                        ; Displacement relative indirect
        InsEntry %OpNo
        amode5
        _&op& 0
OpNo    =       OpNo+1

                        ; x+Displacement relative indirect
        InsEntry %OpNo
        amode7 1
        _&op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 2
        _&op& 0
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 3
        _&op& 0
OpNo    =       OpNo+1



; *************************** W1 ******************************

                        ; Displacement
        InsEntry %OpNo
        amode0
        _&op& 1
OpNo    =       OpNo+1

                        ; x+Displacement
        InsEntry %OpNo
        amode2 1
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 2
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 3
        _&op& 1
OpNo    =       OpNo+1



                        ; Displacement indirect
        InsEntry %OpNo
        amode4
        _&op& 1
OpNo    =       OpNo+1

                        ; x+Displacement indirect
        InsEntry %OpNo
        amode6 1
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 2
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 3
        _&op& 1
OpNo    =       OpNo+1



                        ; Displacement relative
        InsEntry %OpNo
        amode1
        _&op& 1
OpNo    =       OpNo+1

                        ; x+Displacement relative
        InsEntry %OpNo
        amode3 1
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 2
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 3
        _&op& 1
OpNo    =       OpNo+1



                        ; Displacement relative indirect
        InsEntry %OpNo
        amode5
        _&op& 1
OpNo    =       OpNo+1

                        ; x+Displacement relative indirect
        InsEntry %OpNo
        amode7 1
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 2
        _&op& 1
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 3
        _&op& 1
OpNo    =       OpNo+1



; *************************** W2 ******************************

                        ; Displacement
        InsEntry %OpNo
        amode0
        _&op& 2
OpNo    =       OpNo+1

                        ; x+Displacement
        InsEntry %OpNo
        amode2 1
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 2
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 3
        _&op& 2
OpNo    =       OpNo+1



                        ; Displacement indirect
        InsEntry %OpNo
        amode4
        _&op& 2
OpNo    =       OpNo+1

                        ; x+Displacement indirect
        InsEntry %OpNo
        amode6 1
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 2
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 3
        _&op& 2
OpNo    =       OpNo+1



                        ; Displacement relative
        InsEntry %OpNo
        amode1
        _&op& 2
OpNo    =       OpNo+1

                        ; x+Displacement relative
        InsEntry %OpNo
        amode3 1
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 2
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 3
        _&op& 2
OpNo    =       OpNo+1



                        ; Displacement relative indirect
        InsEntry %OpNo
        amode5
        _&op& 2
OpNo    =       OpNo+1

                        ; x+Displacement relative indirect
        InsEntry %OpNo
        amode7 1
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 2
        _&op& 2
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 3
        _&op& 2
OpNo    =       OpNo+1


; *************************** W3 ******************************

                        ; Displacement
        InsEntry %OpNo
        amode0
        _&op& 3
OpNo    =       OpNo+1

                        ; x+Displacement
        InsEntry %OpNo
        amode2 1
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 2
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode2 3
        _&op& 3
OpNo    =       OpNo+1



                        ; Displacement indirect
        InsEntry %OpNo
        amode4
        _&op& 3
OpNo    =       OpNo+1

                        ; x+Displacement indirect
        InsEntry %OpNo
        amode6 1
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 2
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode6 3
        _&op& 3
OpNo    =       OpNo+1



                        ; Displacement relative
        InsEntry %OpNo
        amode1
        _&op& 3
OpNo    =       OpNo+1

                        ; x+Displacement relative
        InsEntry %OpNo
        amode3 1
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 2
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode3 3
        _&op& 3
OpNo    =       OpNo+1



                        ; Displacement relative indirect
        InsEntry %OpNo
        amode5
        _&op& 3
OpNo    =       OpNo+1

                        ; x+Displacement relative indirect
        InsEntry %OpNo
        amode7 1
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 2
        _&op& 3
OpNo    =       OpNo+1

        InsEntry %OpNo
        amode7 3
        _&op& 3


        ENDM            ; End of MakeOp


