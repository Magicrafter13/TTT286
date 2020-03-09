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
copyright DB  "$(c) 2020 - Matthew Rease",'$'
thanks    DB  "$Thanks for playing!",'$'
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
videos    DB  " 1 - Text only (default)",'$',     ; add 19h to get next line
              " 2 - Tandy/PC Jr.       ",'$'
gameVars  DW  0                                   ; lsb is the current player (0 = x, 1 = y), bits 1-15 are board layout (5 bits per row)
board     DB  "   ³   ³   ÄÄÄÅÄÄÄÅÄÄÄ ! ³ ! ³ ! " ; building blocks of the game board
pieces    DB  " XO",0                             ; possible pieces to place on board
          ; PCjr/Tandy graphics data
          ;   sprite    0 = empty (space)
          ;   sprite    1 = X
          ;   sprite    2 = O
          ;   sprite  3-6 = 'YOUR MOVE '
          ;   sprite    7 = fancy x
          ;   sprite    8 = fancy o
          ;   sprite 9-13 = "WINNER:"
          ;   sprite   14 = vertical bar
          ;   sprite   15 = horizontal bar
          ;   sprite   16 = horizontal/vertical cross bar
          ;   sprite   17 = trophy
jrdata    DB  "JR.BIN",0,'$'                      ; location of binary data for PCjr/Tandy graphics
jrpieces  DB  900h DUP ('#')        ; reserve 2176 bytes for the PCjr/Tandy graphics
video     DB  0,3,9                               ; video mode 3 (80x25 text)
pattern   equ 88h                                 ; takes the binary form of 10001000, which, if shifted right,
                                                  ; will let me draw board chunk 0,0,0,1,0,0,0,1,0,0,0 while only using 1 byte for the pattern
vidcount  equ 2                                   ; there are currently 2 video options

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

  ; ---------- set video mode
  lea DX,videoMode ; get address of video mode string
  call WriteLn     ; write to screen
  mov AX,0         ; count 0
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
  mov AH,0         ; 0 out upper register
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
  mov AL,0         ;
  lea DX,jrdata    ; get filename
  int 21h          ; call DOS, if successful, file handle will be stored in AX
  ;jc NoFile        ; if carry flag set, error
  mov BX,AX        ; place file handle in BX
  mov AH,3Fh       ; DOS function 3F, read from file or device
  mov CX,0900h     ; load 2176 bytes
  lea DX,jrpieces  ; set address to load data
  int 21h          ; call DOS

  jmp InitGame

  mov BX,0B800h ; address of video buffer
  mov ES,BX     ; store for later in ES

  mov BX,80h
  mov AX,0
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  sub BX,100h
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr
  add AX,8
  call JrDrawSpr

  jmp endGameLoop
  ; test
  ;mov BX,00h
  ;mov AL,72
  ;mov ES:[BX],AL
  ;jmp endGameLoop

  ;mov BX,0
  ;mov SI,BX
  ;mov BX,80h ; JR.BIN offset 80h, X
;TestVid:
  ;mov AL,[BX+jrpieces] ; get pair of pixels
  ;call JrSetPixel ; set video memory
  ;inc BX ; next pair
  ;inc SI

  ;push BX ; backup offset
  ;mov AX,SI ; place in AX
  ;mov CL,8 ; divide by 8 (one row is 8 bytes)
  ;div CL ; AL now contains which row we're drawing
  ;xor BH,BH ; 0 out BH
  ;mov BL,AH ; place column in BL
  ;xor AH,AH ; remove column
  ;mov CL,4 ; divide by 4 (hard to explain, but trust me. this is due to the way video memory is stored in the PCjr/Tandy 1000)
  ;div CL ; AH now contains which bank of video memory we want to change
  ;mov AL,AH ; move it down to AL
  ;xor AH,AH ; remove it from AH
  ;mov CL,0A0h ; multiply by 160 (each row of pixels on the screen is 160 bytes, memory is linear so it wraps around)
  ;mul CL ; now the pixel will be placed in the proper row of the screen
  ;mov CX,AX ; place row in CX
  ;add CX,BX ; add column we saved in BL
  ;pop BX ; restore offset
  ;push BX ; but back it up again...
  ;mov AX,SI ; and place in AX again :p
  ;mov DX,20h ; divide by 32 (I decided to store the graphics, 1 bank at a time, so each 32 bytes is one bank, see PCjr/Tandy 1000 technical reference)
  ;div DL ; now AL is 0, 1, 2, or 3
  ;mov DL,AL ; place bank in DL
  ;pop BX ; restore offset again
  ;cmp SI,80h ; check if we've drawn the whole bitmap
  ;jb TestVid ; if not, then obviously we must continue
  ;jmp endGameLoop

NoTandy:

  jmp InitGame     ; begin game

NoFile:
  mov DX,BX        ; place filename address in DX
  call Write       ; print filename
  lea DX,notfound  ; not found message
  call WriteLn     ; print rest of message
  jmp endGameLoop  ; exit

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
  mov AH,0       ; Video function 0, set mode
  mov AL,[video] ; get video mode
  int 10h        ; call BIOS video

  startGameLoop:
    ; ---------- clear screen
    mov AH,2 ; BIOS video function 2, set cursor position
    mov BH,0 ; page 0
    mov DX,0 ; Row 0, Column 0
    int 10h  ; call BIOS video

    ; ---------- say whose turn it is
    cmp [video],3       ; check if we're in text mode
    jne drawGame        ; if not, don't print text
    lea  DX,moveText    ; Loads the address of the 'words' string, into the DX register
    call Write          ; Ouputs moveText to console, followed by CRLF
    mov  BX,[gameVars]  ; load gameVars in BX
    and  BX,1           ; remove all but LSB
    add  BX,1           ; add 1 (1 = X, 2 = O)
    mov  AL,[pieces+BX] ; get player char
    mov  AH,0Eh         ; function 0E, output char to screen
    mov  BX,0           ; set BX to 0
    int  10h            ; call BIOS function 0E
    lea  DX,CRLF        ; load address of CRLF in DX
    call WriteLn        ; new line

  drawGame:
    call drawBoard

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
    jmp startGameLoop ; refresh screen
  printHelp:
    lea DX,helpText   ; get address of help message
    call WriteLn      ; print
    mov AH,7          ; DOS function 07, get single char from keyboard (no echo)
    int 21h           ; Call DOS again (for user input)
    jmp ClearScreen   ; refresh screen (if they print help repeatedly they might push the gameboard offscreen, we don't want that to happen)
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
drawBoard   PROC
            ;
            ; initialize board to be drawn (11 lines, with AH as "tile" pattern)
            ;
            mov CL,0Bh         ; set count to 11
            mov AH,pattern     ; place board pattern in AH

            ;
            ; each iteration of this loop will print one strip of the board to the screen
            ;
drawBLoop:  mov BX,0           ; set register where string offset goes to 0
            test AH,1          ; check LSB
            jz drawBDeter      ; if LSB is 0, skips following command
            mov BX,0Bh         ; change offset to 11, so we print the 2nd board strip

drawBDeter: ;-----------------------------------------|
            ; determine if we should draw play pieces |
            ;-----------------------------------------|
            mov DL,CL       ; clone count into DL
            and DL,3        ; eliminate bits 2-7
            cmp DL,2        ; make sure it starts with 10
            jnz drawBCont   ; if DL doesn't equal 10, stop testing
            push AX         ;\
            push BX         ; |- Save
            push CX         ;/
            mov DL,CL       ; clone count into DL
            sub DL,2        ; subract 2 (this code SHOULD only run if CL is 2 6 or 10)
            shr DX,1
            shr DX,1        ; DL has now been divided by 4
            and DL,3        ; remove bits 2-7 (in case there was anything in DH)
            call extractRow ; will place play pieces for this row
            pop CX          ;\
            pop BX          ; |- Restore
            pop AX          ;/
            add BX,16h      ; add 22 to address so we draw 3rd board design
            ;-----------------------------------------|
            ; play piece row determination finished   |
            ;-----------------------------------------|

drawBCont:  ;
            ; now that we know which row to print, it's time to print it
            ;
            cmp [video],3       ; see if we're in text mode
            je dbText           ; if so, print text like usual
            cmp [video],9       ; check if we're in PCjr/Tandy graphics mode
            je dbJr             ; draw graphics, PCjr/Tandy
            jmp dbEnd           ; all else fails, just do nothing
            ;
            ; print row
            ;
dbText:     add BX,OFFSET board ; combine address of board layouts with offset
            mov DX,0Bh          ; tell WriteText to print 11 characters
            push CX             ; save count (CL)
            push AX             ; save remaining pattern (AH)
            call WriteText      ; call string output proc
            mov DX,OFFSET CRLF  ; give Write address of CRLF so we get a new line
            call Write          ; will output CRLF to the console
            pop AX              ; get pattern back! (AH)
            pop CX              ; get count back; (CL)
            jmp dbEnd           ; finish iteration
            ;
            ; draw row (PCjr/Tandy)
            ;
dbJr:       push CX             ; save count (CL)
            push AX             ; save remaining pattern (AH)
            mov AX,BX           ; board pattern offset
            mov DX,0Bh          ; 11
            div DL              ; divide by 11 (so we get 0, 1, or 2)
            jmp dbJrCont
            cmp AX,2            ; see if it's one of those rows
            jne dbJrCont        ; if not, continue
            push CX
            sub CL,2
            shr CX,1
            shr CX,1
            and CL,3            ; same logic as drawBDeter
            mov DX,gameVars     ; place game data in DX
            shr DX,1            ; remove player
            shr DX,CL
            shr DX,CL
            shr DX,CL
            and DX,1Fh
            pop CX
dbJrCont:   mov BX,AX
            mov AX,0Bh          ; 11
            sub AL,CL           ; inverted count (instead of 11-1, it's now 0-10)
            call drawBoardJr    ; draw row, PCjr/Tandy style
            pop AX              ; get pattern back (AH)
            pop CX              ; get count back (CL)
            jmp dbEnd           ; finish iteration
            ;
            ; after row is drawn:
            ;
dbEnd:      shr AH,1            ; shift pattern right, to get rid of previous pattern, and to see the next
            dec CL              ; decrease count by one, since part of the board has now been drawn
            jnz drawBLoop       ; draw another part of the board if count isn't 0, otherwise stop doing that!

            ret
drawBoard   ENDP
;---------------------------|
; Draw Board Procedure ENDS |
;---------------------------|

;-------------------------------------------|
; Draw Board Procedure, for PCjr/Tandy      |
;   BX = row type                           |
;    0 > vertical bars                      |
;    1 > horizontal bar + crosses           |
;    2 > vertical bar (data)                |
;   AX = vertical offset (row technically)  |
;-------------------------------------------|
drawBoardJr PROC
;mov DX,03DAh ; PCjr/Tandy Video data address, 'Mode Control 1' register
;mov AL,10h   ; enable 16 color graphics
;out DX,AL    ; send byte to video
;add DX,4     ; select 'Border Color' register
;mov AL,6     ; color is now brown
;out DX,AL    ; send byte to video

;sub DX,4     ; select 'Mode Control 1' register
;mov AL,3     ; bit 0 = high-bandwidth, bit 1 = graphics mode
;out DX,AL    ; send byte to video
;mov DX,03DEh ; select 'Mode Control 2' register
;mov AL,14h   ; 1 = enable border color, 4 = enable 16 colors
;out DX,AL

;mov AX,0B800h; PCjr/Tandy video offset in memory
;mov ES,AX    ; place in Extra Segment register
;ret
            shl AX,1
            shl AX,1 ; multiply offset by 4 (because of vram banks, we only multiply by 4 instead of 16)
            mov CL,0A0h ; 160
            mul CL ; multiply by 160
            ;
            ; draw standard empty row, with vertical bars
            ;
dbJr0:      cmp BX,0 ; check if vertical bar row
            jne dbJr1 ; not vertical bar row, try the others
            add AX,18h ; add 24
            push AX ; backup offset
            mov BX,700h ; sprite 14, vertical bar
            call JrDrawSpr ; draw first bar
            sub BX,80h ; move back to sprite 14
            pop AX ; restore offset
            add AX,20h ; add 24
            call JrDrawSpr ; draw second bar
            ret
            ;
            ; draw horizontal row (crosses)
            ;
dbJr1:      cmp BX,1 ; check if horizontal bar + crosses row
            jne dbJr2 ; must be vertical bar (data) row
            push AX ; backup offset
            mov BX,780h ; sprite 15, horizontal bar
            call JrDrawSpr ; draw horizontal bar 1
            sub BX,80h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 2
            sub BX,80h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 3
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw cross bar 1
            sub BX,100h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 4
            sub BX,80h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 5
            sub BX,80h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 6
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw cross bar 2
            sub BX,100h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 7
            sub BX,80h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; next grid space
            push AX ; backup offset
            call JrDrawSpr ; draw horizontal bar 8
            sub BX,80h ; sprite 15
            pop AX ; restore offset
            add AX,8 ; final grid space
            call JrDrawSpr ; draw horizontal bar 9
            ret
            ;
            ; draw row 1, 5, or 9 (where pieces show up)
            ;
dbJr2:      add AX,8 ; first play piece grid space
            push AX ; backup offset
            mov BX,17h ; get piece 1
            mov CL,[board+BX] ; place in CL
            mov BL,CL ; move to BL
            shl BX,7 ; multiply by 80h
            call JrDrawSpr ; draw first piece of row
            pop AX ; restore offset
            add AX,10h ; next required grid space
            push AX ; backup offset
            mov BX,700h ; sprite 14 vertical bar
            call JrDrawSpr ; draw first vertical bar
            pop AX ; restore offset
            add AX,10h ; next required grid space
            push AX
            mov BX,1Bh ; get piece 2
            mov CL,[board+BX] ; place in CL
            mov BL,CL ; move to BL
            shl BX,7 ; multiply by 80h
            call JrDrawSpr ; draw second piece of row
            pop AX ; restore offset
            add AX,10h ; next required grid space
            push AX ; backup offset
            mov BX,700h ; sprite 14 vertical bar
            call JrDrawSpr ; draw second vertical bar
            pop AX ; restore offset
            add AX,10h ; next required grid space
            mov BX,1Fh ; get piece 3
            mov CL,[board+BX] ; place in CL
            mov BL,CL ; move to BL
            shl BX,7 ; multiply by 80h
            call JrDrawSpr
            ret
drawBoardJr ENDP
;-------------------------------------------|
; Draw Board Procedure, for PCjr/Tandy ENDS |
;-------------------------------------------|

;-------------------------|
; Try Move Procedure      |
;                         |
;  AL should be a value   |
;  from 0-8               |
;-------------------------|
tryMove    PROC
           ;
           ; determine which row and column to modify
           ;
           mov AH,0  ; 0 out upper register
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
           call testWin    ; if we've gotten this far, that means the board has changed, so lets check if the player has won
           xor gameVars,1  ; XOR LSB, which will change current player
tmFinish:  ret
tryMove    ENDP
;-------------------------|
; Try Move Procedure      |
;-------------------------|

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
            mov BX,0        ; iteration 0
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
            mov BL,0        ; iteration 0
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
            mov DL,0        ; column 0
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
            mov DL,0        ; column 0
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
            lea BX,pieces     ; get player characters
            add BX,AX         ; offset to X or O
            mov DX,1          ; string length of 1
            call WriteText    ; print player character to screen
            lea DX,congrats   ; load win text
            call WriteLn      ; print to screen
twEnd:      ret
testWin     ENDP
;-----------------------------|
; Test for Win Procedure      |
;-----------------------------|

;----------------------------|
; Extract Row Procedure      |
;                            |
;   DL - row                 |
;----------------------------|
extractRow  PROC
            ;
            ; get row from memory
            ;
            mov CL,DL       ; CL = row
            shl CL,1        ; row * 2
            shl CL,1        ; row * 4
            add CL,DL       ; row * 5
            mov BX,gameVars ; get game data
            shl BX,CL       ; move to requested row
            shr BX,0Bh      ; now BH will be 0 (we'll use this for iteration) and BL will be the row data
            ;
            ; grab each column and place in memory
            ;
exRowIt:    mov AL,BL          ; copy row data into AL
            mov DX,0           ; zero out DX
            mov DL,BH          ; use iteration as column
            call getColumn     ; get column
            mov CX,BX          ; get column and row
            push BX            ; save column and row
            mov BX,DX          ; we're going to add DL to an address offset
            mov AL,DL
            cmp [video],3
            jne exRowGraf
            mov AL,[pieces+BX] ; get piece character
exRowGraf:  lea BX,board       ; get board address
            add BX,17h         ; add 23 (22 + 1 offset)
            shr CX,8           ; get column alone
            shl CL,1           ; DL * 2
            shl CL,1           ; DL * 4
            add BX,CX          ; add BH * 4 offset
            mov [BX],AL        ; place in memory
            pop BX             ; load column and row
            inc BH             ; next column
            cmp BH,3           ; see if we've reached the end
            jne exRowIt        ; if not, repeat
            ret
extractRow  ENDP
;----------------------------|
; Extract Row Procedure      |
;----------------------------|

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
          mov AH,0    ; clear out possible remainder from previous iteration
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
          mov SI,0      ; begin with pixel pair 0
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
          mov AL,[BX+jrpieces] ; get pair of pixels
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
jrDrawSpr ENDP
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
