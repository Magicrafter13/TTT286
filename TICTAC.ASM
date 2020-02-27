;===========================================================|
; Basic ASCII Tic-Tac-Toe game, by Matthew Rease.           |
;     Created 9/22/2019, updated on file modification date. |
;     My first program in a new language is almost always a |
;     tictactoe game...                                     |
;===========================================================|

.286

INCLUDE basic.mac ; Load in basic macro library

;-------------------|
;    BEGIN STACK    |
;-------------------|
DemoStack SEGMENT STACK
TheStack  DB   32 DUP ('(C) Matthew R.  ') ; Reserves 512 bytes of memory for Stack, containing copyright string repeated 32 times
DemoStack ENDS
;-------------------|
;      END STACK    |
;-------------------|

;-------------------|
;    BEGIN DATA     |
;-------------------|
MyData    SEGMENT PUBLIC

EXTRN CRLF:BYTE

moveText  DB "Your move, ",'$'
copyright DB "(c) 2020 - Matthew Rease",'$'
thanks    DB "Thanks for playing!",'$'
gameVars  DW 0                                   ; lsb is the current player (0 = x, 1 = y), bits 1-15 are board layout (5 bits per row)
board     DB "   ³   ³   ÄÄÄÅÄÄÄÅÄÄÄ ! ³ ! ³ ! " ; building blocks of the game board
pieces    DB " XO"                               ; possible pieces to place on board
pattern   DB 88h                                 ; takes the binary form of 10001000, which, if shifted right,
                                                 ; will let me draw board chunk 0,0,0,1,0,0,0,1,0,0,0 while only using 1 byte for the pattern

Numbers   DB "0123456789"

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
  EXTRN WriteText:PROC

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
  mov  AX,0               ; set AX to 0, for use in "refreshing" variables in memory
  mov  BX,OFFSET gameVars ; load memory offset of gameVars into BX
  mov  [BX],AX            ; sets word at DS:BX to 0

  mov AX,3                ; video function 0 set video mode, mode 3
  int 10h                 ; call BIOS video

  startGameLoop:
    ; ---------- clear screen
    mov AH,2 ; BIOS video function 2, set cursor position
    mov BH,0 ; page 0
    mov DX,0 ; Row 0, Column 0
    int 10h  ; call BIOS video

    ; ---------- say whose turn it is, and draw the board
    lea  DX,moveText   ; Loads the address of the 'words' string, into the DX register
    call Write         ; Ouputs moveText to console, followed by CRLF
    mov  AX,[gameVars] ; load gameVars in AX
    mov  AH,0Eh        ; function 0E, output char to screen
    and  AL,1          ; remove all but LSB
    add  AL,30h        ; add 30h (ascii numbers begin at 30h)
    mov  BX,0          ; set BX to 0
    int  10h           ; call BIOS function 0E
    lea  DX,CRLF       ; load address of CRLF in DX
    call WriteLn       ; new line

    call drawBoard

    ; ---------- get user input
    mov AH,7       ; DOS function 07, get single character from keyboard (no echo)
    int 21h        ; Call DOS

    cmp AL,1Bh     ; compare AL to 1B which corresponds to the escape key
    jz endGameLoop ; drop out of loop to end game
    cmp AL,71h     ; compare AL to 71 which corresponds to lowercase 'q'
    jz endGameLoop ; gotta give people options :)
    cmp AL,72h     ; compare AL to 72 which corresponds to lowercase 'r'
    jz InitGame    ; restarts game

    sub AL,31h     ; ascii for 1 is 31h, so turn that into a 0
    sub AL,9       ; now subtract 9, that way if it is 0-8 we will trigger the carry flag
    jnc noTryMove  ; if they did not input 1-9, then don't try anything (continue)
    call tryMove   ;attempt the requested move, if it is valid, the board will be updated, and the player will change
  noTryMove:

    jmp startGameLoop ; refresh screen
  endGameLoop:

  lea DX,copyright ; place address of copyright string in DX
  call WriteLn     ; print to screen
  lea DX,thanks    ; place address of thank you message in DX
  call WriteLn     ; print to screen

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
  mov BX,0           ; set register where string offset goes to 0
  mov AL,AH          ; place remaining board pattern in AL
  and AL,1           ; 0 out all but LSB
                     ; [shouldn't need, as AND should set Zero Flag] cmp 1,AL       ; subtracts AL from 1, and sets flags
  jz drawBFinish     ; if LSB is 0, skips following command (which would end up making the string output routine print the second board design)
  mov BX,0Bh         ; set register where string offset goes to 0Bh (11)
drawBFinish:
  ;-----------------------------------------|
  ; determine if we should draw play pieces |
  ;-----------------------------------------|
  mov DL,CL           ; clone count into DL
  and DL,3            ; eliminate bits 2-7
  cmp DL,2            ; make sure it starts with 10
  jnz determineFinish ; if DL doesn't equal 10, stop testing
    ; ---- This should be enough, assuming CL is never greater than 11 (base 10)
    ; mov DL,CL
    ; shr DL
    ; shr DL   ; DL = 000000??
    ; cmp DL,3 ; if DL is 11, ZF will now eqaul 0
    ; draw letters if zero flag is false
  push AX             ;\
  push BX             ; |- Save
  push CX             ;/
  mov DL,CL           ; clone count into DL
  sub DL,2            ; subract 2 (this code SHOULD only run if CL is 2 6 or 10)
  shr DX,1
  shr DX,1            ; DL has now been divided by 4
  and DL,3            ; remove first 2 bits (in case there was anything in DH)
  call extractRow     ; will place play pieces for this row
  pop CX              ;\
  pop BX              ; |- Restore
  pop AX              ;/
  add BX,16h          ; add 22 to address so we draw 3rd board design
  ;-----------------------------------------|
  ; play piece row determination finished   |
  ;-----------------------------------------|
determineFinish:
  add BX,OFFSET board; add OFFSET BOARD to register where string offset goes
  mov DX,0Bh         ; mov 0Bh to a register (11), to represent the length of the strings
  push CX            ; save count to stack (cannot push byte register), using CL
  push AX            ; save remaining pattern to stack, using AH
  call WriteText     ; call string output proc
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

;-------------------------|
; Try Move Procedure      |
;-------------------------|
tryMove PROC                ; AL should contain a value from 0-8
  mov CX,0003         ; row = 0, and CL is 3 (for dividing later)
  add AL,9            ; restore request to original value before carry test
  mov DL,AL           ; temporarily store request
  sub AL,6            ; if request is 6-8, we won't carry
  jnc continueTryMove ; row is 0
  add CH,1            ; row = 1
  mov AL,DL           ; restore request
  sub AL,3            ; if request is 3-5, we won't carry
  jnc continueTryMove ; row is 1
  add CH,1            ; row is 2
continueTryMove:
  mov AH,0            ; zero out upper register
  mov AL,DL           ; restore request
  div CL              ; divide request by 3
  mov CL,AH           ; place request % 3 in CL
  mov AX,1            ; set AX to 1 (_ _ X)
tmColumn:
  sub CL,1            ; decrement column
  jc tmRow            ; if we underflow, our work is done
  mov DX,AX           ; save AX in DX
  shl AX,1            ; multiply AX by 2
  add AX,DX           ; add DX to AX (thus multiplying by 3)
  jmp tmColumn        ; try again
tmRow:
  sub CH,1            ; decrement row
  jc tmDoneAlign      ; if we underflow, our work is done
  mov DX,AX           ; save AX in DX
  shl AX,5            ; shift to next row (5 bits)
  jmp tmRow           ; try again
tmDoneAlign:
  mov DX,gameVars     ; copy gameVars to DX
  and DX,1            ; remove all but LSB
  mov CL,DL           ; get current player
  shl AX,CL           ; if player is 1, then double the value that we'll add
  xor DX,1            ; alternate LSB of DX (toggle player turn)
  shl AX,1            ; shift our board addition left, so we don't modify current player
  add AX,gameVars     ; add board data to temp board data
  and AX,0FFFEh       ; zero out LSB
  add AX,DX           ; if it's player 0's turn, nothing changes (we still add X) but if it's player 1's turn we add 1 (change to O)
  mov gameVars,AX     ; commit to memory (update board data)
  ret
tryMove ENDP
;-------------------------|
; Try Move Procedure      |
;-------------------------|

;----------------------------|
; Extract Row Procedure      |
;----------------------------|
extractRow PROC
  mov DH,DL ; copy row (DL) to DH
  shl DH,1 ; multiply row by 2
  shl DH,1 ; multiply row by 2 (4)
  add DH,DL ; add DL to DH
  mov CL,DH ; place DH in CL, thus multiplying DL by 5 (CL = DL * 5)

  mov AX,gameVars ; retrieve game variables
  shl AX,CL ; move to correct row of piece data
  shr AX,0Bh ; move the 5 bits we need to the front
  and AX,1Fh ; remove bits 5-15, we only want 0-4

  mov CH,0 ; set iteration 0

exRowIt:
  inc CH ; next iteration
  mov CL,3 ; set CX to 3, so we can divide by 3
  div CL ; divide AX by 3 (store in AL, remainder in AH)
  mov BX,OFFSET pieces ; get possible play pieces (address)
  mov DX,0 ; zero out DX
  mov DL,AH ; get remainder (modulus) into DL
  add BX,DX ; add result of division
  mov DL,[BX] ; DL should now have a space, an X, or an O
  mov BX,OFFSET board ; get board address
  add BX,13h ; move to 3rd layout + 1 for first column, but we subtract 4 so the following loop works correctly
  push CX ; save iteration (we only need CH)

exRowItColumn:
  add BX,4 ; next column
  dec CH ; iteration - 1
  jnz exRowItColumn ; if this is zero, we're in the correct column

  pop CX ; load iteration (from CH)
  cmp CH,3 ; check if we're on iteration 3
  mov [BX],DL ; and now we place the character in DL, into the board area
  mov AH,0 ; get rid of remainder, (so AX is divided by 3)
  jnz exRowIt ; if CH is anything other than 3, we reiterate

  ret
extractRow ENDP
;----------------------------|
; Extract Row Procedure      |
;----------------------------|

MyCode ENDS
;-------------------|
;      END CODE     |
;-------------------|

  END start
;
; End of program
;
