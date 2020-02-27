;===========================================================|
; Basic ASCII Tic-Tac-Toe game, by Matthew Rease.           |
;     Created 9/22/2019, updated on file modification date. |
;     My first program in a new language is almost always a |
;     tictactoe game...                                     |
;===========================================================|

INCLUDE basic.mac ; Load in basic macro library

;-------------------|
;    BEGIN STACK    |
;-------------------|
DemoStack SEGMENT STACK
TheStack  DB   32 DUP ('(C) Matthew R.  ') ; Reserves 512 bytes of memory for Stack, containing 'STACK!!!' repeated 64 times
DemoStack ENDS
;-------------------|
;      END STACK    |
;-------------------|

;-------------------|
;    BEGIN DATA     |
;-------------------|
MyData    SEGMENT PUBLIC
          PUBLIC CRLF
moveText  DB "Your move, ",'$'
players   DB "XY",'$'
charSpace DB " ",'$'
gameVars  DW 0                        ; lsb is the current player (0 = x, 1 = y), bits 1-9 are board positions 1-9 respectively, remaining 6 bits unused
board     DB "   ³   ³   ÄÄÄÅÄÄÄÅÄÄÄ" ; building blocks of the game board
pattern   DB 88h                      ; takes the binary form of 10001000, which, if shifted right, will let me draw board chunk 0,0,0,1,0,0,0,1,0,0,0 while only using 1 byte for the pattern
CRLF      DB 0Dh,0Ah,'$'              ; EOL String
MyData    ENDS
;-------------------|
;      END DATA     |
;-------------------|

;-------------------|
;    BEGIN CODE     |
;-------------------|
MyCode SEGMENT PUBLIC

  assume CS:MyCode,DS:MyData

  EXTRN Write:PROC
  EXTRN WriteLn:PROC

;------------------------|
;    Main Procedure      |
;------------------------|

main PROC ; Define Main procedure
;
; Start of Program
;
start:

  ; ---------- set data location
  mov AX,MyData ; Moves Data segment address to AX register
  mov DS,AX     ; Allowing us to move that address to the intended data segment register, DS

InitGame:
  ; ---------- initialize game
  mov AX,0               ; set AX to 0, for use in "refreshing" variables in memory
  mov BX,OFFSET gameVars ; load memory offset of gameVars into BX
  mov [BX],AX          ; sets word at DS:BX to 0

  ; ---------- say whose turn it is, and draw the board
  lea DX,moveText        ; Loads the address of the 'words' string, into the DX register
  call WriteLn           ; Ouputs moveText to console, followed by CRLF

  call drawBoard

  EXIT 0 ; Calls macro to terminate program and sets ERRORLEVEL to 0

main ENDP

;------------------------|
;    Main Procedure Ends |
;------------------------|

;---------------------------|
; Draw Board Procedure      |
;---------------------------|
drawBoard PROC ; Define board drawing procedure
  mov CL,0Bh         ; set count to 11
  mov AH,pattern     ; place board pattern in AH
drawBLoop:
                     ; set register where string offset goes to 0
  mov AL,AH          ; place remaining board pattern in AL
  and AL,1           ; 0 out all but LSB
                     ; [shouldn't need, as AND should set Zero Flag] cmp 1,AL       ; subtracts AL from 1, and sets flags
  jz drawBFinish     ; if LSB is 0, skips following command (which would end up making the string output routine print the second board design)
                     ; set register where string offset goes to 0Bh (11)
drawBFinish:
                     ; add OFFSET BOARD to register where string offset goes
                     ; mov 0Bh to a register (11), to represent the length of the strings
  push CX            ; save count to stack (cannot push byte register), using CL
  push AX            ; save remaining pattern to stack, using AH
                     ; call string output proc
  mov DX,OFFSET CRLF ; load offset address of CRLF into DX
  call Write         ; will output CRLF to the console
  pop AX             ; get pattern back! (AH)
  pop CX             ; get count back; (CL)
  shr AH,1           ; shift pattern right, to get rid of previous pattern, and to see the next
  dec CL             ; decrease count by one, since part of the board has now been drawn
  jnz drawBLoop      ; draw another part of the board if count isn't 0, otherwise stop doing that!
  ret
drawBoard ENDP
;---------------------------|
; Draw Board Procedure ENDS |
;---------------------------|

MyCode ENDS
;-------------------|
;      END CODE     |
;-------------------|

  END start
;
; End of program
;
