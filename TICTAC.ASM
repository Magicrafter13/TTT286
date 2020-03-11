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

moveText  DB  "Your move, ",'$'
copyright DB  "(c) 2020 - Matthew Rease",'$'
thanks    DB  "Thanks for playing!",'$'
congrats  DB  " Wins the game!",'$'
notfound  DB  " file wasn't found",'$'
helpText  DB  "Help:",0Dh,0Ah,
              "        r - restart game",0Dh,0Ah,
              "  q / esc - quit game",0Dh,0Ah,
              "  [7 - 9] - row 1, column 1-3",0Dh,0Ah,
              "  [4 - 6] - row 2, column 1-3",0Dh,0Ah,
              "  [1 - 3] - row 3, column 1-3",0Dh,0Ah,
              "Press any key to continue...",'$'
videoMode DB  "Please select video mode:",'$'
videos    DB  " 1 - Text only (default)",'$', ; add 19h to get next line
              " 2 - Tandy/PC Jr.       ",'$',
              " 3 - CGA                ",'$'
gameVars  DW  0                               ; lsb is the current player (0 = x, 1 = y), bits 1-15 are board layout (5 bits per row)
board     DB  "   ³   ³   ÄÄÄÅÄÄÄÅÄÄÄ"        ; building blocks of the game board
pieces    DB  " XO",0                         ; possible pieces to place on board
          ; PCjr/Tandy graphics data
          ;   sprite    0 = empty (space)                 -   0h
          ;   sprite    1 = X                             -  80h
          ;   sprite    2 = O                             - 100h
          ;   sprite  3-6 = 'YOUR MOVE '                  - 180h, 200h, 280h, 300h
          ;   sprite    7 = fancy x                       - 380h
          ;   sprite    8 = fancy o                       - 400h
          ;   sprite 9-13 = "WINNER:"                     - 480h, 500h, 580h, 600h, 680h
          ;   sprite   14 = vertical bar                  - 700h
          ;   sprite   15 = horizontal bar                - 780h
          ;   sprite   16 = horizontal/vertical cross bar - 800h
          ;   sprite   17 = trophy                        - 880h
jrdata    DB  "JR.BIN",0,'$'                  ; location of binary data for PCjr/Tandy graphics
cgadata   DB  "CGA.BIN",0,'$'                 ; location of binary data for CGA graphics
grpieces  DB  900h DUP ('#')                  ; reserve 2176 bytes for the PCjr/Tandy graphics
video     DB  0,3,9,4                         ; video mode 3 (80x25 text)
pattern   equ 88h                             ; takes the binary form of 10001000, which, if shifted right,
                                              ; will let me draw board chunk 0,0,0,1,0,0,0,1,0,0,0 while only using 1 byte for the pattern
vidcount  equ 3                               ; there are currently 2 video options

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
  EXTRN WriteTextLn:PROC

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

  ; ---------- set video mode
  lea DX,videoMode ; get address of video mode string
  call WriteLn     ; write to screen
  xor AX,AX        ; count 0
GetVideo:
  push AX          ; backup count
  lea DX,videos    ; get video modes
  mov CL,19h       ; 19h = 25
  mul CL           ; multiply AX by 25
  add DX,AX        ; use as offset
  call WriteLn     ; print
  pop AX           ; restore count
  inc AX           ; add 1
  cmp AX,vidcount  ; test if we're done
  jne GetVideo     ; if not, keep going
  mov AH,1         ; DOS function 1, get char with echo
  int 21h          ; Call DOS
  xor AH,AH        ; 0 out upper register
  sub AL,30h       ; subtract 30h, (turn ascii number into actual number)
  lea BX,video     ; get video mode data
  add BX,AX        ; use as offset
  mov AL,[BX]      ; place value in AL
  mov video,AL     ; set video mode
  mov AH,0Fh       ; BIOS video function F, get current video mode
  int 10h          ; call BIOS video
  mov [video+1],AL ; place in memory

  cmp video,9      ; test Tandy video
  jne NoTandy
  ; PCjr/Tandy Video Gate Array settings
  mov AH,0       ; Video function 0, set mode
  mov AL,[video] ; get video mode
  int 10h        ; call BIOS video
  mov DX,03D8h   ; Mode Select
  mov AL,0Bh     ; high-res clock, 320x200 graphics, enable video signal
  out DX,AL
  mov DX,03B8h
  mov AL,88h
  out DX,AL

  ; load graphics
  mov AH,3Dh       ; DOS function 3D, open existing file
  xor AL,AL        ; place 0 in AL
  lea DX,jrdata    ; get filename
  int 21h          ; call DOS, if successful, file handle will be stored in AX
  jc NoFile        ; if carry flag set, error
  mov BX,AX        ; place file handle in BX
  mov AH,3Fh       ; DOS function 3F, read from file or device
  mov CX,0900h     ; load 2176 bytes
  lea DX,grpieces  ; set address to load data
  int 21h          ; call DOS
  jmp InitGame

NoTandy:
  cmp video,4      ; test CGA video
  jne NoCGA

NoCGA:
  jmp InitGame     ; begin game

NoFile:
  push DX          ; backup filename
  xor AH,AH        ; BIOS video function 0, set video mode
  mov AL,[video+1] ; restore original video mode
  int 10h          ; call BIOS video
  pop DX           ; restore filename
  call Write       ; print filename
  lea DX,notfound  ; not found message
  call WriteLn     ; print rest of message
  jmp ExitGame     ; exit

InitGame:
  ; ---------- initialize game
  mov gameVars,0    ; refresh variables
  cmp [pieces+3],0  ; check winner
  jz ClearScreen    ; if no winner was set, continue game
  mov AL,[pieces+3] ; get winner
  and AX,1          ; remove potential 2nd bit
  mov gameVars,AX   ; set player
  mov [pieces+3],0  ; unset winner

ClearScreen:
  ; ---------- clear screen
  xor AH,AH         ; Video function 0, set mode
  mov AL,[video]    ; get video mode
  int 10h           ; call BIOS video
  cmp [video],3     ; check if we're in text mode
  je clsText
  cmp [video],9     ; check if we're in PCjr/Tandy mode
  je clsJr
  jmp startGameLoop ; if not, start game as usual
clsText:
  call drawBoardText
  jmp startGameLoop
clsJr:
  call drawBoardJr
  jmp startGameLoop

  startGameLoop:
    ; ---------- clear screen
    mov AH,2  ; BIOS video function 2, set cursor position
    xor BH,BH ; page 0
    xor DX,DX ; Row 0, Column 0
    int 10h   ; call BIOS video

    ; ---------- say whose turn it is
    cmp [video],3
    je turnText
    cmp [video],9
    je turnJr
    jmp userInput
  turnText:
    mov AH,2
    xor BH,BH
    mov DX,0Bh
    int 10h
    mov  BX,[gameVars]  ; load gameVars in BX
    and  BX,1           ; remove all but LSB
    add  BX,1           ; add 1 (1 = X, 2 = O)
    mov  AL,[pieces+BX] ; get player char
    mov  AH,0Eh         ; function 0E, output char to screen
    xor  BX,BX          ; set BX to 0
    int  10h            ; call BIOS function 0E
    lea  DX,CRLF        ; load address of CRLF in DX
    call WriteLn        ; new line
    jmp userInput
  turnJr:
    cmp [pieces+3],0
    jnz userInput
    mov AX,1B80h
    push AX
    mov BX,180h
    call JrDrawSpr
    pop AX
    add AX,8
    push AX
    call JrDrawSpr
    pop AX
    add AX,8
    push AX
    call JrDrawSpr
    pop AX
    add AX,8
    push AX
    call JrDrawSpr
    pop AX
    add AX,4
    test gameVars,1
    jz turnJrCont
    add BX,80h
  turnJrCont:
    call JrDrawSpr
    jmp userInput

    ; ---------- get user input
  userInput:
    mov AH,7          ; DOS function 07, get single character from keyboard (no echo)
    int 21h           ; Call DOS

    cmp AL,1Bh        ; compare AL to 1B which corresponds to the escape key
    je endGameLoop    ; drop out of loop to end game
    cmp AL,71h        ; compare AL to 71 which corresponds to lowercase 'q'
    je endGameLoop    ; gotta give people options :)
    cmp AL,72h        ; compare AL to 72 which corresponds to lowercase 'r'
    je InitGame       ; restarts game
    cmp AL,3Fh        ; compare AL to 3F which corresponds to '?'
    je printHelp      ; print help text
    cmp AL,68h        ; compare AL to 68 which corresponds to lowercase 'h'
    je printHelp      ; print help text

    cmp [pieces+3],0  ; see if there is a winner
    jnz userInput     ; if there is, then we won't allow any further changes to the board

    sub AL,31h        ; ascii for 1 is 31h, so turn that into a 0
    cmp AL,9          ; now subtract 9, that way if it is 0-8 we will trigger the carry flag
    jae userInput     ; if they did not input 1-9, then don't try anything (continue)
    call tryMove      ; attempt the requested move, if it is valid, the board will be updated, and the player will change
    cmp DL,0          ; check if board was updated
    jne userInput     ; if not, don't redraw
    jmp startGameLoop ; refresh screen
  printHelp:
    lea DX,helpText   ; get address of help message
    call WriteLn      ; print
    mov AH,7          ; DOS function 07, get single char from keyboard (no echo)
    int 21h           ; Call DOS again (for user input)
    jmp ClearScreen   ; refresh screen (if they print help repeatedly they might push the gameboard offscreen, we don't want that to happen)
  endGameLoop:

  xor AH,AH        ; BIOS video function 0, set video mode
  mov AL,[video+1] ; get original video mode before program execution
  int 10h          ; call BIOS video
  lea DX,copyright ; place address of copyright string in DX
  call WriteLn     ; print to screen
  lea DX,thanks    ; place address of thank you message in DX
  call WriteLn     ; print to screen
ExitGame:
  EXIT 0 ; Calls macro to terminate program and sets ERRORLEVEL to 0

main ENDP

;------------------------|
;    Main Procedure Ends |
;------------------------|

;------------------------------------------|
; Draw Board Procedure, for text mode      |
;------------------------------------------|
drawBoardText PROC
              lea DX,moveText    ; Loads the address of the 'words' string, into the DX register
              call WriteLn       ; Ouputs moveText to console, followed by CRLF
              lea BX,board
              mov DX,0Bh
              call WriteTextLn
              call WriteTextLn
              call WriteTextLn
              add BX,DX
              call WriteTextLn
              sub BX,DX
              call WriteTextLn
              call WriteTextLn
              call WriteTextLn
              add BX,DX
              call WriteTextLn
              sub BX,DX
              call WriteTextLn
              call WriteTextLn
              call WriteTextLn
              ret
drawBoardText ENDP
;------------------------------------------|
; Draw Board Procedure, for text mode ENDS |
;------------------------------------------|

;-------------------------------------------|
; Draw Board Procedure, for PCjr/Tandy      |
;-------------------------------------------|
drawBoardJr PROC
            mov BX,pattern
            xor AX,AX
dbJrStart:  cmp AX,1B80h   ; check if we've drawn all 11 rows
            jae dbJrEnd
            test BX,1      ; check LSB
            jz dbJr0
            jnz dbJr1
dbJr0:      push BX        ; backup pattern
            add AX,18h     ; add 24
            push AX        ; backup offset
            mov BX,700h    ; sprite 14, vertical bar
            call JrDrawSpr ; draw first bar
            sub BX,80h     ; move back to sprite 14
            pop AX         ; restore offset
            add AX,20h     ; add 32
            call JrDrawSpr ; draw second bar
            add AX,248h    ; beginning of next row
            pop BX         ; restore pattern
            shr BX,1       ; next pattern
            jmp dbJrStart
dbJr1:      push BX        ; backup pattern
            push AX        ; backup offset
            mov BX,780h    ; sprite 15, horizontal bar
            call JrDrawSpr ; draw horizontal bar 1
            sub BX,80h     ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 2
            sub BX,80h     ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 3
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw cross bar 1
            sub BX,100h    ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 4
            sub BX,80h     ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 5
            sub BX,80h     ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 6
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw cross bar 2
            sub BX,100h    ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 7
            sub BX,80h     ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; next grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 8
            sub BX,80h     ; sprite 15
            pop AX         ; restore offset
            add AX,8       ; final grid space
            push AX        ; backup offset
            call JrDrawSpr ; draw horizontal bar 9
            pop AX         ; restore offset
            add AX,230h    ; beginning of next row
            pop BX         ; restore pattern
            shr BX,1       ; next pattern
            jmp dbJrStart
dbJrEnd:    ret
drawBoardJr ENDP
;-------------------------------------------|
; Draw Board Procedure, for PCjr/Tandy ENDS |
;-------------------------------------------|

;-------------------------|
; Try Move Procedure      |
;                         |
;  AL should be a value   |
;  from 0-8               |
;  DL will return 0 if    |
;   successful, and 1 or 2|
;   if not                |
;-------------------------|
tryMove    PROC
           ;
           ; determine which row and column to modify
           ;
           xor AH,AH ; 0 out upper register
           mov CL,3  ; will divide by 3
           div CL    ; divide AX(L) by 3
                     ; AX = column row
           mov DL,AH ; place high in low
           mov CL,2  ; CL = 2
           sub CL,AL ; CL - row
           mov DH,CL ; row is now inverted (2 = 0, 1 = 1, 0 = 2)
                     ; DX = row column
           ;
           ; find out if we're allowed to modify this part of the board
           ;
           mov AX,gameVars ; get board data
           shr AX,1        ; remove player
           mov CL,DH       ; place row in CL
           shr AX,CL
           shr AX,CL
           shr AX,CL
           shr AX,CL
           shr AX,CL       ; eliminate CL * 5 bits
           and AX,1Fh      ; eliminate bits 5-15
           push DX         ; backup DX
           call getColumn  ; now DL = 0 1 or 2 (_ X or O)
           pop CX          ; restore DX into CX
           cmp DL,0        ; test if column is empty
           jnz tmFinish    ; if it isn't, then don't do anything
           push CX         ; store column and row data for win testing later
           ;
           ; construct mask to add to board data
           ;
           mov AX,gameVars ; get current game data
           and AX,1        ; set pattern to player
           inc AX          ; then add one (1 = X, 2 = O)
tmColumn:  cmp CL,0        ; see if column is 0
           jz tmRow        ; time to adjust the new piece to the proper row
           mov BX,AX       ; temp store AX in BX
           shl AX,1        ; now to position row
           add AX,BX       ; multiply AX by 3
           dec CL          ; column -= 1
           jmp tmColumn    ; loop
tmRow:     cmp CH,0        ; see if row is 0
           jz tmDonePos    ; we're done
           shl AX,5        ; move to next row
           dec CH          ; row -= 1
           jmp tmRow       ; loop
           ;
           ; add constructed mask to board data
           ;
tmDonePos: shl AX,1        ; make room for player
           add gameVars,AX ; update board and commit to memory
           pop CX          ; get column and row data for easy win testing
           cmp [video],3
           je tmDPtext
           cmp [video],9
           je tmDPjr
           jmp tmDPcont
tmDPtext:  call drawPieceText
           jmp tmDPcont
tmDPjr:    call drawPieceJr
           jmp tmDPcont
tmDPcont:  call testWin    ; if we've gotten this far, that means the board has changed, so lets check if the player has won
           xor gameVars,1  ; XOR LSB, which will change current player
           xor DL,DL       ; set DL to 0, because we were successful in updating the board
tmFinish:  ret
tryMove    ENDP
;-------------------------|
; Try Move Procedure      |
;-------------------------|

;------------------------------------------|
; Draw Piece Procedure, for text mode      |
;   CH = row                               |
;   CL = column                            |
;   CX is preserved                        |
;------------------------------------------|
drawPieceText PROC
              push CX            ; backup row, column
              xor BH,BH          ; page 0
              mov DX,CX          ; place row, column in DX for BIOS
              shl DX,1
              shl DX,1           ; multiply column and row by 4 (since they are 4 spaces apart visually)
              inc DL             ; increase 1 column, due to offset from board margin
              add DH,2           ; increase 2 rows (because "Your Move" text is in row 0)
              mov AH,2           ; BIOS video function 2, set cursor position
              int 10h            ; call BIOS video, also DOS function 2 is write character to output
              mov BX,1           ; first piece (X)
              test gameVars,1    ; check current player
              jz dptEnd          ; if 0, stay with X
              inc BX             ; next piece (O)
dptEnd:       mov DL,[pieces+BX] ; get X or O character
              int 21h            ; call DOS
              pop CX             ; restore row, column
              ret
drawPieceText ENDP
;------------------------------------------|
; Draw Piece Procedure, for text mode ENDS |
;------------------------------------------|

;-------------------------------------------|
; Draw Piece Procedure, for PCjr/Tandy      |
;   CH = row                                |
;   CL = column                             |
;   CX is preserved                         |
;-------------------------------------------|
drawPieceJr PROC
push CX ; backup row, column
mov AL,CH
shl AL,1
shl AL,1
inc AL
xor AH,AH
mov DX,280h ; 160 * 4
mul DX
mov BX,AX ; store video offset in BX
mov AL,CL ; place column in AL
xor AH,AH ; 0 out AH
shl AX,1
shl AX,1 ; column * 4
mov DX,8 ; tiles are 8 bytes apart (16 pixels)
mul DL ; column * 4 * 8 = "y coordinate"
add AX,DX ; add one more column
add AX,BX ; add to video offset (now offset is stored in AX)
mov BX,gameVars ; get game data in BX
and BX,1 ; only want player
inc BX ; add 1 for proper offset
shl BX,7 ; multiply by 80h (80h bytes per sprite)
call JrDrawSpr
pop CX
ret
drawPieceJr ENDP
;-------------------------------------------|
; Draw Piece Procedure, for PCjr/Tandy ENDS |
;-------------------------------------------|

;-----------------------------|
; Test for Win Procedure      |
;                             |
;   CH - row, CL - column     |
;-----------------------------|
testWin     PROC
            ;
            ; swap row and column
            ;
            mov DX,CX ; place row,column in DX
            mov CH,DL ; so we can swap
            mov CL,DH ; the row and column
            ;
            ; test 1 - win by row
            ;
            mov AX,gameVars ; get current game data
            mov DX,AX       ; copy data into DX (the less we call RAM, the faster we ride)
            shr AX,1        ; remove player from data
            shr AX,CL
            shr AX,CL
            shr AX,CL
            shr AX,CL
            shr AX,CL       ; AX has been divided by CL * 5
            and AX,1Fh      ; isolate row
            test DX,1       ; test which player just played
            jz twContinue   ; if it was X, then continue
            shr AX,1        ; now we've divided by 2 (since O made the move, now O O O will become X X X)
twContinue: cmp AX,0Dh      ; check if row is X X X
            je twWin        ; if it is, then they've won
            ;
            ; test 2 - win by column
            ;
            xor BX,BX       ; iteration 0
            shr DX,1        ; remove player from data
twTest2:    mov AX,DX       ; place data in AX
            and AX,1Fh      ; only want first 5 bits
            push CX         ; save column,row
            push DX         ; save board data
            mov DL,CH       ; set column for procedure
            call getColumn  ; we need to find out if this column contains the player's piece
            pop DX          ; load board data
            shr DX,5        ; next row
            mov CX,gameVars ; test for X
            and CL,1        ; player data only
            inc CL          ; add one (since a 0 1 and 2 from getColumn represent nothing, X, and O respectively)
            mov AL,CL       ; place in AL
            pop CX          ; load column,row
            cmp AH,AL       ; test if column has an X in it
            jne twTest3     ; if not, final test
            inc BX          ; next iteration
            cmp BX,3        ; test iteration
            je twWin        ; if we've reached 3, we have a winner
            jmp twTest2     ; loop
            ;
            ; test 3 - win by diagonal
            ;
twTest3:    cmp CL,1        ; check if play was in middle row
            je twTest4      ; if so, check if play was in middle of board
            xor BL,BL       ; iteration 0
            mov DH,1        ; each iteration, we will add 1 to the column
            cmp CH,0        ; test column 0
            jz twTest31     ; if it is, we're fine
            mov DH,0FFh     ; otherwise we'll want to "subtract 1" from the column
twTest31:   mov DL,1        ; each iteration, we will add 1 to the row
            cmp CL,0        ; test row 0
            jz twTest32     ; if it is, we're fine
            mov DL,0FFh     ; otherwise we'll want to "subract 1" from the row
twTest32:   cmp BL,3        ; check if we've reached the end of our loop
            je twWin        ; if we have, then they must have won
            mov AX,gameVars ; get game data
            shr AX,1        ; remove player
            shr AX,CL
            shr AX,CL
            shr AX,CL
            shr AX,CL
            shr AX,CL       ; get proper row
            and AX,1Fh      ; and ONLY that row
            push CX         ; backup column,row
            push DX         ; backup column,row direction
            mov DL,CH
            call getColumn  ; find out what's there
            mov DX,gameVars ; get game data
            and DX,1        ; isolate player
            inc DX          ; increase by one so we can compare to getColumn
            cmp AH,DL       ; check if it contained the proper piece
            pop DX          ; restore column,row direction
            pop CX          ; restore column,row
            jne twEnd       ; if not, then they didn't win yet
            add CL,DL       ; this will add (or subtract) 1 row, based on the previous tests
            add CH,DH       ; this will add (or subtract) 1 column, based on the previous tests
            inc BL          ; next iteration
            jmp twTest32    ; if we haven't, then keep going
            ;
            ; test 4 - diagonal win, center play
            ;   this test is only ran if the center of the board is changed, however it is the most extensive/least optimized test unfortunately
            ;
twTest4:    cmp CH,1        ; check if play was in middle column
            jne twEnd       ; if not, then they couldn't have made a winning move (after having tested row and column of course)
            mov AX,gameVars ; get game data
            mov BX,AX       ; copy into BX
            and BX,1        ; player only
            inc BX          ; 1 = X 2 = O
            shr AX,1        ; remove player
            and AX,1Fh      ; get row 0
            xor DL,DL       ; column 0
            call getColumn  ; check 0,0
            cmp DL,BL       ; see if 0,0 is owned by this player
            jne twTest4R    ; if it isn't, try going right to left
            mov AX,gameVars ; get game data
            shr AX,11       ; get row 2
            mov DL,2        ; column 2
            call getColumn  ; check 2,2
            cmp DL,BL       ; see if 2,2 is owned by this player
            je twWin        ; if it is, they win
            jmp twEnd       ; otherwise, keep playing...
twTest4R:   mov AX,gameVars ; get game data
            shr AX,1        ; remove player
            and AX,1Fh      ; get row 0
            mov DL,2        ; column 2
            call getColumn  ; check 2,0
            cmp DL,BL       ; see if 2,0 is owned by this player
            jne twEnd       ; if it isn't, keep playing...
            mov AX,gameVars ; get game data
            shr AX,11       ; get row 2
            xor DL,DL       ; column 0
            call getColumn  ; check 0,2
            cmp DL,BL       ; see if 0,2 is owned by this player
            je twWin        ; if it is, they win
            jmp twEnd       ; otherwise, keep playing...
            ;
            ; congratulations, someone has won
            ;
twWin:      mov AX,gameVars   ; get data
            and AX,1          ; only want LSB
            add AX,1          ; increase by one that way we get X or O, instead of space or X
            mov [pieces+3],AL ; set winner
            cmp [video],3
            je twWinText
            cmp [video],9
            je twWinJr
            jmp twEnd
twWinText:  mov AH,2          ; BIOS video function 2, set cursor position
            xor BH,BH         ; page 0
            mov DX,0C00h      ; row 12, column 0
            int 10h           ; call BIOS video
            xor AH,AH         ; remove bios video function
            lea BX,pieces     ; get player characters
            add BX,AX         ; offset to X or O
            mov DX,1          ; string length of 1
            call WriteText    ; print player character to screen
            lea DX,congrats   ; load win text
            call WriteLn      ; print to screen
            jmp twEnd
twWinJr:    push AX ; backup winner offset
            mov AX,1B80h
            push AX
            mov BX,480h
            call JrDrawSpr
            pop AX
            add AX,8
            push AX
            call JrDrawSpr
            pop AX
            add AX,8
            push AX
            call JrDrawSpr
            pop AX
            add AX,8
            push AX
            call JrDrawSpr
            pop AX
            add AX,8
            push AX
            call JrDrawSpr
            pop AX
            add AX,0Ch
            pop BX ; restore winner offset
            shl BX,7
            add BX,300h
            push AX
            call JrDrawSpr
            pop AX
            add AX,0Ch
            mov BX,880h
            call JrDrawSpr
            jmp twEnd
twEnd:      ret
testWin     ENDP
;-----------------------------|
; Test for Win Procedure      |
;-----------------------------|

;---------------------------|
; Get Column Procedure      |
;   Place row data in AX    |
;   and column in DL (0-2)  |
; column will be returned   |
; in DL                     |
;---------------------------|
getColumn PROC
          mov CX,0FF03h    ; set iteration 255 and CL to 3 for division
gcLoop:   inc CH      ; increment iteration
          xor AH,AH   ; clear out possible remainder from previous iteration
          div CL      ; divide board in AX by 3
          cmp CH,DL   ; compare current column to requested column
          jnz gcLoop  ; if we haven't reached the column we want, try again
          mov DL,AH   ; store value of column in DL

          ret
getColumn ENDP
;---------------------------|
; Get Column Procedure ENDS |
;---------------------------|

;--------------------------------------|
; PCjr/Tandy, Set Pixel Procedure      |
;   AL = color (0-15)                  |
;   CX = column (video offset)         |
;   DX = video bank (0-3)              |
;   ES must be B800                    |
;  Preserves BX                        |
;--------------------------------------|
JrSetPixel PROC
	       ;
	       ; Save registers.
	       ;
           push BX ; this is the only register not required by this procedure, so there's a good chance it's being used for something
           push AX ; save color
           ;
	       ; Set Base register to correct bank of memory
           ;
           mov AX,2000h
           mul DX
           mov BX,AX ; now we have the correct segment for this pixel row
           pop AX ; restore color
           ;
           ; Add "column" offset
           ;
           add BX,CX
	       ;
	       ; Write the byte to the video buffer.
	       ;
           mov ES:[BX],AL
	       ;
	       ; Restore registers and return.
	       ;
           pop BX
           ret
JrSetPixel ENDP
;--------------------------------------|
; PCjr/Tandy, Set Pixel Procedure ENDS |
;--------------------------------------|

;------------------------------|
; PCjr/Tandy, draw sprite      |
;   BX = address of sprite     |
;   AX = video offset/"coords" |
;------------------------------|
JrDrawSpr PROC
          mov DX,0B800h ; offset of PCjr/Tandy video
          mov ES,DX     ; place in ES
          xor SI,SI     ; begin with pixel pair 0
JDSloop:  push AX  ; backup "coords"
          push BX  ; backup offset
          ;
          ; Set Video offset
          ;
          mov DX,AX   ; place "coords" in DX
          mov AX,SI   ; current pixels in AX
          mov CL,8    ; divide by 8 (one row is 8 bytes)
          div CL      ; AL now contains which row we're drawing
          xor BH,BH   ; 0 out BH
          mov BL,AH   ; place column in BL
          xor AH,AH   ; remove column
          mov CL,4    ; divide by 4 (hard to explain, but trust me. this is due to the way video memory is stored in the PCjr/Tandy 1000)
          div CL      ; AH now contains which bank of video memory we want to change
          mov AL,AH   ; move it down to AL
          xor AH,AH   ; remove it from AH
          mov CL,0A0h ; multiply by 160 (each row of pixels on the screen is 160 bytes, memory is linear so it wraps around)
          mul CL      ; now the pixel will be placed in the proper row of the screen
          mov CX,AX   ; place row in CX
          add CX,BX   ; add column we saved in BL
          add CX,DX   ; add "coords" to AX
          ;
          ; Set Video bank
          ;
          mov AX,SI  ; current pixels in AX
          mov DX,20h ; divide by 32 (I decided to store the graphics, 1 bank at a time, so each 32 bytes is one bank, see PCjr/Tandy 1000 technical reference)
          div DL     ; now AL is 0, 1, 2, or 3
          mov DL,AL  ; place bank in DL
          pop BX     ; restore offset
          ;
          ; Get sprite data, and draw
          ;
          mov AL,[BX+grpieces] ; get pair of pixels
          call JrSetPixel      ; set video memory
          ;
          ; Continue
          ;
          pop AX     ; restore "coords"
          inc BX     ; next pair
          inc SI     ; next pair
          cmp SI,80h ; check if we've drawn the whole bitmap (8x16 bytes)
          jb JDSloop ; if not, then obviously we must continue
          ret
JrDrawSpr ENDP
;------------------------------|
; PCjr/Tandy, draw sprite      |
;------------------------------|

MyCode ENDS
;-------------------|
;      END CODE     |
;-------------------|

  END start
;
; End of program
;
