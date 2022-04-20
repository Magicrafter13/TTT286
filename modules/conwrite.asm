;
; Console Write - Assembly Module, by Matthew Rease
;   Various string printing utilities, using either DOS or BIOS interrupts
;

;------------------|
;    DATA BEGIN    |
;------------------|
MyData SEGMENT PUBLIC
       PUBLIC CRLF            ; Allow CRLF to be accessed globally
       CRLF    DB 0Dh,0Ah,'$' ; EOL String
MyData ENDS
;------------------|
;    DATA END      |
;------------------|

;------------------|
;    CODE BEGIN    |
;------------------|
MyCode SEGMENT PUBLIC

       PUBLIC Write,WriteLn,WriteText,WriteTextLn ; Provides external program access to module procedures

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

;
; WriteText - ouputs text to the console, from a starting address
;             to the end, designated by specifying string length
;             BX - address of string
;             DX - length of string (characters)
;  Updated:   2/27/2020
;  This procedure was written in 60-90 minutes, on a school day
;   in college, after I'd taken a long break from ASM
;
WriteText      PROC
               mov CX,0          ; set CX to 0
WriteTextLoop: push BX           ; save string address
               mov AH,0Eh        ; function 0E, output char to screen
               add BX,CX         ; add char offset to BX
               mov AL,[BX]       ; place character at DS:BX in AL

               push DX           ; save length
               push CX           ; save current char

               mov BX,0          ; set BX to 0
               int 10h           ; call BIOS function 0E

               pop CX            ; restore current char
               pop DX            ; restore length
               pop BX            ; restore string address

               inc CX            ; increment char by 1
               cmp DX,CX         ; compare length to current char
               jnz WriteTextLoop ; continue writing if current char hasn't reached length
               ret
WriteText      ENDP

;
; WriteTextLn - calls WriteText, then prints CRLF
;               see WriteText
;  Updated:     3/10/2020
;
WriteTextLn PROC
            push BX
            call WriteText
            push DX
            lea DX,CRLF
            call Write
            pop DX
            pop BX
            ret
WriteTextLn ENDP

MyCode ENDS

       END
