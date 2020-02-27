;
; Console Write - Assembly Module, by Matthew Rease
;   Write to the screen via DOS service 'Print String' (09h).
;

;------------------|
;    DATA BEGIN    |
;------------------|
MyData SEGMENT PUBLIC
       EXTRN CRLF:BYTE ; Allows access to CRLF Variable
MyData ENDS
;------------------|
;    DATA END      |
;------------------|

;------------------|
;    CODE BEGIN    |
;------------------|
MyCode SEGMENT PUBLIC

       PUBLIC Write,WriteLn ; Provides external program access to module procedures

       ASSUME CS:MyCode,DS:MyData

;
;   Write -  will output text at the offset stored in DX, until
;            terminated by a '$'.
;   Updated: 09/17/2019
;
Write PROC
      mov AH,09h ; DOS Service 09h, Print String
      int 21h    ; Call DOS
      ret        ; Return to caller
Write ENDP

;
; WriteLn -  will call Write, and then return the cursor to the
;            left of the screen, and go down one line, scrolling
;            if the screen is at the bottom.
;  Updated:  9/17/2019
;
WriteLn PROC
        call Write   ; Ouputs user's text to screen
        mov  DX,OFFSET CRLF ; Next text to be output, will be an EOL
        call Write   ; Outputs CRLF
        ret          ; Returns to the caller
WriteLn ENDP

MyCode ENDS

       END
