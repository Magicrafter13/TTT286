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
              " 3 - CGA                ",'$',
              " 4 - EGA                ",'$'
gameVars  DW  0                               ; lsb is the current player (0 = x, 1 = y), bits 1-15 are board layout (5 bits per row)
board     DB  "   ³   ³   ÄÄÄÅÄÄÄÅÄÄÄ"        ; building blocks of the game board
pieces    DB  "XO",0                          ; possible pieces to place on board
cursor    DW  0101h
vidmodes  DB  3,9,4,0Dh                       ; video mode 3 (80x25 text), 9 is PCjr/Tandy 1000 320x200 16 color, 4 is CGA 320x200 4 color, D is EGA 320x200 16 color
          ; byte 0 = current video mode
          ; byte 1 = system video mode
settings  DB  2 DUP (0)
          ; PCjr/Tandy graphics data
          ;   sprite    0 = X                             -   0h
          ;   sprite    1 = O                             -  80h
          ;   sprite  2-5 = 'YOUR MOVE '                  - 100h, 180h, 200h, 280h
          ;   sprite    6 = fancy x                       - 300h
          ;   sprite    7 = fancy o                       - 380h
          ;   sprite 8-12 = "WINNER:"                     - 400h, 480h, 500h, 580h, 600h
          ;   sprite   13 = vertical bar                  - 680h
          ;   sprite   14 = horizontal bar                - 700h
          ;   sprite   15 = horizontal/vertical cross bar - 780h
          ;   sprite   16 = trophy                        - 800h
jrdata    DB  "JR.BIN",0,'$'                  ; location of binary data for PCjr/Tandy graphics
          ; CGA graphics data
          ;   sprite    0 = X                             -   0h
          ;   sprite    1 = O                             -  40h
          ;   sprite  2-5 = 'YOUR MOVE '                  -  80h,  C0h, 100h, 140h
          ;   sprite    6 = fancy x                       - 180h
          ;   sprite    7 = fancy o                       - 1C0h
          ;   sprite 8-12 = "WINNER:"                     - 200h, 240h, 280h, 2C0h, 300h
          ;   sprite   13 = vertical bar                  - 340h
          ;   sprite   14 = horizontal bar                - 380h
          ;   sprite   15 = horizontal/vertical cross bar - 3C0h
          ;   sprite   16 = trophy                        - 400h
cgadata   DB  "CGA.BIN",0,'$'                 ; location of binary data for CGA graphics
          ; EGA graphics data
          ; sprite offsets identical to PCjr/Tandy 1000 graphics data
egadata   DB  "EGA.BIN",0,'$'                 ; location of binary data for EGA graphics
grpieces  DB  0B00h DUP ('#')                 ; reserve 2688 bytes for the graphics data
pattern   equ 88h                             ; takes the binary form of 10001000, which, if shifted right,
                                              ; will let me draw board chunk 0,0,0,1,0,0,0,1,0,0,0 while only using 1 byte for the pattern
vidcount  equ 4                               ; there are currently 2 video options

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

;---------------------|
; Main Procedure      |
;---------------------|
main         PROC
             ;
             ; Start of Program
             ;
start:       mov AX,MyData ; Moves Data segment address to AX register
             mov DS,AX     ; Allowing us to move that address to the intended data segment register, DS
             mov AX,0B800h ; most modes use this address for the video memory
             mov ES,AX
             ;
             ; show user possible video modes
             ;
             lea DX,videoMode ; get address of video mode string
             call WriteLn     ; write to screen
             xor AX,AX        ; count 0
ShowVideo:   push AX          ; backup count
             lea DX,videos    ; get video modes
             mov CL,19h       ; 19h = 25
             mul CL           ; multiply AX by 25
             add DX,AX        ; use as offset
             call WriteLn     ; print
             pop AX           ; restore count
             inc AX           ; add 1
             cmp AX,vidcount  ; test if we're done
             jne ShowVideo    ; if not, keep going
             ;
             ; get video mode that the user wants
             ;
AskVideo:    mov AH,7          ; DOS function 1, get char without echo
             int 21h           ; Call DOS
             cmp AL,1Bh        ; check if escape was pressed
             je ExitGame       ; if so, return to DOS
             sub AL,31h        ; subtract 30h, (turn ascii number into actual number and subtract one)
             cmp AL,vidcount   ; make sure the user typed a valid number
             jae AskVideo      ; if not, wait for new input
             mov [settings],AL ; set video mode
             ;
             ; get current video mode, and store in memory
             ;
             mov AH,0Fh          ; BIOS video function F, get current video mode
             int 10h             ; call BIOS video
             mov [settings+1],AL ; place in memory
             ;
             ; set requested video mode
             ;
             xor AH,AH            ; Video function 0, set mode
             mov BL,[settings]    ; get video mode
             xor BH,BH            ; 0 out BH just in case
             mov AL,[vidmodes+BX] ; get requested video mode
             push BX              ; backup video mode
             int 10h              ; call BIOS video
             pop AX               ; restore video mode
             ;
             ; Initialize and Load graphics (if a graphics mode was selected)
             ;
             cmp AL,1         ; test PCjr/Tandy 1000 video
             je JrInit
             cmp AL,2         ; test CGA video
             je CGAInit
             cmp AL,3         ; test EGA video
             je EGAInit
             jmp InitGame
             ;
             ; PCjr/Tandy 1000 graphics initialization
             ;
               ;
               ; Video Gate Array Settings
               ;
JrInit:        mov DX,03D8h ; Mode Select
               mov AL,0Bh   ; high-res clock, 320x200 graphics, enable video signal
               out DX,AL
               mov DX,03B8h
               mov AL,88h
               out DX,AL
               ;
               ; Load Graphics from File
               ;
               mov AH,3Dh      ; DOS function 3D, open existing file
               xor AL,AL       ; place 0 in AL
               lea DX,jrdata   ; get filename
               int 21h         ; call DOS, if successful, file handle will be stored in AX
               jc NoFile       ; if carry flag set, error
               mov BX,AX       ; place file handle in BX
               mov AH,3Fh      ; DOS function 3F, read from file or device
               mov CX,0B00h    ; load 21 sprites of 80h bytes each
               lea DX,grpieces ; set address to load data
               int 21h         ; call DOS
               jmp InitGame
             ;
             ; CGA graphics initialization
             ;
CGAInit:       mov DX,3D8h ; CGA Mode control register
               mov AL,2    ; bit 1 = graphics mode
               out DX,AL
               mov DX,3D9h ; CGA Color control register
               mov AL,20h  ; bit 5 = palette ('snow'), bit 4 = high intensity mode (which I don't want)
               out DX,AL
               ;
               ; Load Graphics from File
               ;
               mov AH,3Dh      ; DOS function 3D, open existing file
               xor AL,AL       ; place 0 in AL
               lea DX,cgadata  ; get filename
               int 21h         ; call DOS, if successful, file handle will be stored in AX
               jc NoFile       ; if carry flag set, error
               mov BX,AX       ; place file handle in BX
               mov AH,3Fh      ; DOS function 3F, read from file or device
               mov CX,0440h    ; read 17 sprites of 40h bytes each
               lea DX,grpieces ; get memory address where graphics are to be stored
               int 21h         ; call DOS (now CGA graphics are in RAM)
               jmp InitGame
             ;
             ; EGA graphics initialization
             ;
EGAInit:       mov BX,0A000h
               mov ES,BX
               ;
               ; Load Graphics from File
               ;
               mov AH,3Dh      ; DOS function 3D, open existing file
               xor AL,AL       ; place 0 in AL
               lea DX,egadata  ; get filename
               int 21h         ; call DOS, if successful, file handle will be stored in AX
               jc NoFile       ; if carry flag set, error
               mov BX,AX       ; place file handle in BX
               mov AH,3Fh      ; DOS function 3F, read from file or device
               mov CX,0880h    ; load 17 sprites of 80h bytes each
               lea DX,grpieces ; set address to load data
               int 21h         ; call DOS
               jmp InitGame
             ;
             ; Unable to load graphics file
             ;
NoFile:      push DX             ; backup filename
             xor AH,AH           ; BIOS video function 0, set video mode
             mov AL,[settings+1] ; restore original video mode
             int 10h             ; call BIOS video
             pop DX              ; restore filename
             call Write          ; print filename
             lea DX,notfound     ; not found message
             call WriteLn        ; print rest of message
             jmp ExitGame        ; exit
             ;
             ; Initialize game
             ;
InitGame:    mov cursor,101h   ; reset cursor position
             mov gameVars,0    ; refresh variables
             cmp [pieces+2],0  ; check winner
             jz ClearScreen    ; if no winner was set, continue game
             mov AL,[pieces+2] ; get winner
             and AX,1          ; remove potential 2nd bit
             mov gameVars,AX   ; set player
             mov [pieces+2],0  ; unset winner
             ;
             ; Clear screen and redraw interface
             ;
ClearScreen: mov AL,[settings] ; get video mode
             cmp AL,0          ; check if we're in text mode
             je clsText        ; redraw screen (text)
             cmp AL,1          ; check if we're in PCjr/Tandy mode
             je clsJr          ; redraw screen (PCjr/Tandy 1000)
             cmp AL,2          ; check if we're in CGA mode
             je clsCGA         ; redraw screen (CGA)
             cmp AL,3          ; check if we're in EGA mode
             je clsEGA         ; redraw screen (EGA)
             jmp startGame     ; if not, start game as usual
clsText:     call drawBoardText
             jmp startGame
clsJr:       call drawBoardJr
             jmp startGame
clsCGA:      call drawBoardCGA
             jmp startGame
clsEGA:      call drawBoardEGA
             jmp startGame
             ;
             ; Main game loop
             ;
  startGame:   mov AL,[settings] ; get video mode
               ;
               ; Show whose turn it is
               ;
               cmp AL,0         ; test text mode
               je turnText      ; print current player
               cmp [pieces+2],0 ; check if someone has won
               jnz userInput    ; if so, we don't want to draw the "Your Move" sprites on TOP of the "Winner" sprites!
               cmp AL,1         ; test PCjr/Tandy 1000 mode
               je turnJr        ; draw current player
               cmp AL,2         ; test CGA mode
               je turnCGA       ; draw current player
               cmp AL,3         ; test EGA mode
               je turnEGA       ; draw current player
               jmp userInput    ; if unknown mode, skip section
               ;
               ; Print player character to screen
               ;
  turnText:    mov AH,2            ; BIOS video function 2, set cursor position
               xor BH,BH           ; page 0
               mov DX,0Bh          ; row 0, column 11
               int 10h             ; call BIOS video
               mov  BX,[gameVars]  ; load gameVars in BX
               and  BX,1           ; remove all but LSB
               mov  AL,[pieces+BX] ; get player char
               mov  AH,0Eh         ; function 0E, output char to screen
               xor  BX,BX          ; set BX to 0
               int  10h            ; call BIOS function 0E
               jmp userInput       ; procede to user input
               ;
               ; Draw player on screen
               ;
  turnJr:      mov AX,1B9Ch    ; location where 'fancy' x and o go
               mov BX,300h     ; location of 'fancy x' sprite
               test gameVars,1 ; check current player
               jz turnJrCont   ; if 0, do nothing
               add BX,80h      ; but if 1, move to 'fancy o' sprite
  turnJrCont:  call JrDrawSpr  ; and finally draw it to screen
               jmp userInput   ; then procede to user input
               ;
               ; Draw player on screen
               ;
  turnCGA:     mov AX,1B9Ch    ; location where 'fancy' x and o go
               mov BX,180h     ; location of 'fancy x' sprite
               test gameVars,1 ; check current player
               jz turnCGACont  ; if 0, do nothing
               add BX,40h      ; but if 1, move to 'fancy o' sprite
  turnCGACont: call CGADrawSpr ; and finally draw it to screen
               jmp userInput   ; then procede to user input
               ;
               ; Draw player on screen
               ;
  turnEGA:     mov AX,1B87h    ; location where 'fancy' x and o go
               mov BX,300h     ; location of 'fancy x' sprite
               test gameVars,1 ; check current player
               jz turnEGACont  ; if 0, do nothing
               add BX,80h      ; but if 1, move to 'fancy o' sprite
  turnEGACont: call EGADrawSpr ; and finally draw it to screen
               jmp userInput   ; then procede to user input
               ;
               ; Get user input
               ;
  userInput:   mov AH,7 ; DOS function 07, get single character from keyboard (no echo)
               int 21h  ; Call DOS
               ;
               ; Misc functions
               ;
               cmp AL,1Bh   ; compare AL to 1B which corresponds to the escape key
               je endGame   ; drop out of loop to end game
               cmp AL,71h   ; compare AL to 71 which corresponds to lowercase 'q'
               je endGame   ; gotta give people options :)
               cmp AL,72h   ; compare AL to 72 which corresponds to lowercase 'r'
               je InitGame  ; restarts game
               cmp AL,3Fh   ; compare AL to 3F which corresponds to '?'
               je printHelp ; print help text
               cmp AL,68h   ; compare AL to 68 which corresponds to lowercase 'h'
               je printHelp ; print help text
               cmp AL,0     ; check for 0
               je testSpecial
               ;
               ; Check for winner (if someone has won, allow no more board changes
               ;
               cmp [pieces+2],0 ; see if there is a winner
               jnz userInput    ; if there is, then we won't allow any further changes to the board
               cmp AL,20h       ; check if space was pressesd
               je cursorPlace   ; if so, try move
               cmp AL,0Dh       ; check if enter was pressed
               je cursorPlace
               jmp uiNumbers    ; if not, continue
  cursorPlace: mov AX,cursor    ; place cursor location in AX
               mov BH,2         ; place 2 in BH
               sub BH,AH        ; so we can invert the row
               mov AH,BH        ; copy to BX
               shl AH,1
               add AH,BH        ; AH * 3
               add AL,AH        ; add to AL
               add AL,31h       ; then add 31h as if a number had been pressed by the user
               ;
               ; Check if 1-9 were pressed, if so, attempt to update game board
               ;
  uiNumbers:   sub AL,31h      ; ascii for 1 is 31h, so turn that into a 0
               cmp AL,9        ; now subtract 9, that way if it is 0-8 we will trigger the carry flag
               jae userInput   ; if they did not input 1-9, then don't try anything (continue)
               call tryMove    ; attempt the requested move, if it is valid, the board will be updated, and the player will change
               cmp DL,0        ; check if board was updated
               jne userInput   ; if not, don't redraw
               jmp startGame   ; refresh screen
               ;
               ; Test for special keys
               ;
  testSpecial: int 21h        ; Call DOS again
               cmp AL,48h     ; 48 is returned if the up arrow was pressed
               je cursorUp    ; move up
               cmp AL,4Bh     ; 4B is returned if the left arrow was pressed
               je cursorLeft  ; move left
               cmp AL,4Dh     ; 4D is returned if the right arrow was pressed
               je cursorRight ; move right
               cmp AL,50h     ; 50 is returned if the down arrow was pressed
               je cursorDown  ; move down
               jmp userInput  ; return
               ;
               ; Move cursor
               ;
  cursorUp:    mov AX,cursor ; get current position
               mov BX,AX     ; copy into BX
               dec AH        ; increase row
               cmp AH,2      ; check if we're still within the bounds
               jb updateCur  ; update
               mov AH,2      ; if not, set row to 0
               jmp updateCur ; then update
  cursorLeft:  mov AX,cursor ; get current position
               mov BX,AX     ; copy into BX
               dec AL        ; decrease column
               cmp AL,2      ; check if we're still within the bounds
               jb updateCur  ; update
               mov AL,2      ; if not, set column to 2
               jmp updateCur ; then update
  cursorRight: mov AX,cursor ; get current position
               mov BX,AX     ; copy into BX
               inc AL        ; increase column
               cmp AL,3      ; check if we're still within the bounds
               jb updateCur  ; update
               xor AL,AL     ; if not, set column to 0
               jmp updateCur ; then update
  cursorDown:  mov AX,cursor ; get current position
               mov BX,AX     ; copy into BX
               inc AH        ; decrease row
               cmp AH,3      ; check if we're still within the bounds
               jb updateCur  ; update
               xor AH,AH     ; if not, set row to 2
               jmp updateCur ; then update
               ;
               ; Draw cursor and update memory
               ;
  updateCur:   push AX ; backup new cursor position
               mov AL,[settings] ; get video mode
               cmp AL,0
               je ucText
               cmp AL,1
               je ucJr
               cmp AL,2
               ;je ucCGA
               cmp AL,3
               ;je ucEGA
               pop AX
               jmp ucDone
               ;
               ; Print cursor to screen
               ;
  ucText:      mov AH,2      ; BIOS video function 2, set cursor - DOS function 2, print single char
               mov DX,BX     ; place old cursor position in DX
               shl DX,1
               shl DX,1      ; multiply row and column by 4
               xor BH,BH     ; page 0
               add DX,301h   ; add 3 to row, and 1 to column
               int 10h       ; call BIOS video
               mov DL,20h    ; space
               int 21h       ; call DOS
               pop AX        ; restore new cursor position
               mov cursor,AX ; update memory
               mov DX,AX     ; and place in DX
               shl DX,1
               shl DX,1      ; cursor position * 4
               mov AH,2      ; BIOS video function 2, set cursor - DOS function 2, print single char
               xor BH,BH     ; page 0
               add DX,301h   ; add 3 to row, and 1 to column
               int 10h       ; call BIOS video
               mov DL,0DFh   ; horizontal bar, upper
               int 21h       ; call DOS
               jmp ucDone
               ;
               ; Draw cursor on screen
               ;
  ucJr:        shl BX,1
               shl BX,1    ; old cursor position * 4
               mov DL,BH
               xor DH,DH
               mov AX,280h ; 4 pixel rows = 280h
               mul DX      ; multiply by row
               inc BL ; one more column
               shl BL,1
               shl BL,1
               shl BL,1 ; column * 8
               xor BH,BH ; remove BH
               add AX,BX ; add offset to AX
               mov BX,0A80h
               call JrDrawSpr
               add AX,278h
               call JrDrawSpr
               add AX,10h ; move 32 pixels right
               call JrDrawSpr
               add AX,278h
               call JrDrawSpr
               pop AX ; restore new cursor position
               mov cursor,AX ; update memory
               mov BX,AX ; and place in BX
               shl BX,1
               shl BX,1 ; new cursor position * 4
               mov DL,BH
               xor DH,DH
               mov AX,280h ; 4 pixel rows
               mul DX ; multiply by row
               inc BL ; one more column
               shl BL,1
               shl BL,1
               shl BL,1 ; column * 8
               xor BH,BH ; remove BH
               add AX,BX ; add offset to AX
               mov BX,880h
               call JrDrawSpr
               add AX,278h
               mov BX,900h
               call JrDrawSpr
               add AX,10h ; move 32 pixels right
               mov BX,980h
               call JrDrawSpr
               add AX,278h
               mov BX,0A00h
               call JrDrawSpr
               jmp ucDone
  ucDone:      jmp userInput
               ;
               ; Help screen
               ;
  printHelp:   mov AL,[settings] ; get current video mode
               cmp AL,0          ; test text mode
               je phText
               cmp AL,1          ; test PCjr/Tandy 1000
               je phJr
               cmp AL,2          ; test CGA
               je phCGA
               cmp AL,3          ; test EGA
               ;
               ; Print help message
               ;  Yes, this code is bad, just... consider it temporary I guess
               ;
phText:        push DS         ; backup data segment
               mov BX,ES       ; place video buffer in BX
               mov DS,BX       ; and then into DS
               xor SI,SI       ; we'll copy from the current video buffer
               mov DI,0FA0h    ; to another area in the video buffer that isn't displayed
               cld             ; go forward
               mov CX,410h     ; copy 13 screen rows of text
               rep movsw
               xor DI,DI       ; start at 0
               mov CX,410h     ; copy into 13 screen rows of text
               mov AX,0700h    ; retain default color setting, but remove any characters
               rep stosw
               pop DS          ; restore data segment (for Write)
               mov AH,2        ; BIOS video function 2, set cursor position
               xor BH,BH       ; page 0
               xor DX,DX       ; row 0, column 0
               int 10h         ; call BIOS video
               lea DX,helpText ; get address of help message
               call Write      ; print
               mov AH,7        ; DOS function 07, get single char from keyboard (no echo)
               int 21h         ; Call DOS again (for user input)
               push DS         ; backup data segment
               mov BX,ES       ; place video buffer in BX
               mov DS,BX       ; and then into DS
               mov SI,0FA0h    ; this time we'll start in the hidden area
               xor DI,DI       ; and copy to the visible area
               mov CX,410h     ; copy 13 screen rows of text
               rep movsw
               pop DS          ; restore data segment for the rest of the program
               jmp userInput   ; return to input
               ;
               ; Draw help message
               ;
  phJr:        jmp userInput
               ;
               ; Draw help message
               ;
  phCGA:       jmp userInput
               ;
               ; Draw help message
               ;
  phEGA:       jmp userInput
             ;
             ; Main game loop end
             ;
  endGame:   xor AH,AH           ; BIOS video function 0, set video mode
             mov AL,[settings+1] ; get original video mode before program execution
             int 10h             ; call BIOS video
             lea DX,copyright    ; place address of copyright string in DX
             call WriteLn        ; print to screen
             lea DX,thanks       ; place address of thank you message in DX
             call WriteLn        ; print to screen
             ;
             ; Return to DOS
             ;
ExitGame:    EXIT 0 ; Calls macro to terminate program and sets ERRORLEVEL to 0

main         ENDP
;---------------------|
; Main Procedure ENDS |
;---------------------|

;------------------------------------------|
; Draw Board Procedure, for text mode      |
;------------------------------------------|
drawBoardText PROC
              ;
              ; Clear Screen
              ;
              cld                ; clear direction
              xor AX,AX          ; set AX to 0
              mov AX,0700h       ; set color to 07, and clear the character
              mov DI,0           ; begin at 0
              mov CX,03E8h       ; whole screen (80x25 / 2)
              rep stosw          ; fill with 0
              ;
              ; Print board
              ;
              mov AH,1           ; BIOS video function 1, cursor control
              mov CH,1Fh         ; bit 5 disables cursor, 0-4 control cursor shape
              int 10h            ; call BIOS video
              mov AH,2           ; BIOS video function 2, set cursor position
              xor BH,BH          ; page 0
              xor DX,DX          ; row 0, column 0
              int 10h            ; call BIOS video
              lea DX,moveText    ; Loads the address of the 'words' string, into the DX register
              call WriteLn       ; Ouputs moveText to console, followed by CRLF
              lea BX,board       ; board pattern 0
              mov DX,0Bh         ; 11 characters long
              call WriteTextLn   ; row 0
              call WriteTextLn   ; row 1
              call WriteTextLn   ; row 2
              add BX,DX          ; board pattern 1
              call WriteTextLn   ; row 3
              sub BX,DX          ; board pattern 0
              call WriteTextLn   ; row 4
              call WriteTextLn   ; row 5
              call WriteTextLn   ; row 6
              add BX,DX          ; board pattern 1
              call WriteTextLn   ; row 7
              sub BX,DX          ; board pattern 0
              call WriteTextLn   ; row 8
              call WriteTextLn   ; row 9
              call WriteTextLn   ; row 10
              ret
drawBoardText ENDP
;------------------------------------------|
; Draw Board Procedure, for text mode ENDS |
;------------------------------------------|

;-------------------------------------------|
; Draw Board Procedure, for PCjr/Tandy      |
;-------------------------------------------|
drawBoardJr PROC
            ;
            ; clear screen
            ;
            cld          ; clear direction
            xor AX,AX    ; set AX to 0
            mov DI,0     ; begin at 0
            mov CX,0F9Fh ; whole screen (bank 0) (1F3F / 2)
            rep stosw    ; fill with 0
            add DI,0C1h  ; next bank (2000 - 1F3F)
            mov CX,0F9Fh ; whole screen (bank 1) (1F3F / 2)
            rep stosw    ; fill with 0
            add DI,0C1h  ; next bank
            mov CX,0F9Fh ; whole screen (bank 2) (1F3F / 2)
            rep stosw    ; fill with 0
            add DI,0C1h  ; last bank
            mov CX,0F9Fh ; whole screen (bank 3) (1F3F / 2)
            rep stosw    ; fill with 0
            ;
            ; draw board
            ;
            mov BX,pattern ; pattern of rows
            xor AX,AX      ; begin at pixel 0,0
dbJrStart:  cmp AX,1B80h   ; check if we've drawn all 11 rows
            jae dbJrEnd    ; if so, draw "Your Move" sprites
            test BX,1      ; check LSB
            jz dbJr0       ; 0 represents a vertical bar row
            jnz dbJr1      ; 1 represents a horizontal bar + cross row
dbJr0:      push BX        ; backup pattern
            add AX,18h     ; add 24
            mov BX,680h    ; sprite 13, vertical bar
            call JrDrawSpr ; draw first bar
            add AX,20h     ; add 32
            call JrDrawSpr ; draw second bar
            add AX,248h    ; beginning of next row
            pop BX         ; restore pattern
            shr BX,1       ; next pattern
            jmp dbJrStart  ; next iteration
dbJr1:      push BX        ; backup pattern
            mov BX,700h    ; sprite 14, horizontal bar
            call JrDrawSpr ; draw horizontal bar 1
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 2
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 3
            add AX,8       ; next grid space
            add BX,80h     ; sprite 15, cross
            call JrDrawSpr ; draw cross bar 1
            sub BX,80h     ; sprite 14, horizontal bar
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 4
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 5
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 6
            add AX,8       ; next grid space
            add BX,80h     ; sprite 15, cross
            call JrDrawSpr ; draw cross bar 2
            sub BX,80h     ; sprite 14, horizontal bar
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 7
            add AX,8       ; next grid space
            call JrDrawSpr ; draw horizontal bar 8
            add AX,8       ; final grid space
            call JrDrawSpr ; draw horizontal bar 9
            add AX,230h    ; beginning of next row
            pop BX         ; restore pattern
            shr BX,1       ; next pattern
            jmp dbJrStart  ; next iteration
dbJrEnd:    mov BX,100h    ; first sprite of "Your Move"
            call JrDrawSpr ; draw part 1
            add AX,8       ; move 8 pixels right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw part 2
            add AX,8       ; move 8 pixels right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw part 3
            add AX,8       ; move 8 pixels right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw part 4
            ret
drawBoardJr ENDP
;-------------------------------------------|
; Draw Board Procedure, for PCjr/Tandy ENDS |
;-------------------------------------------|

;------------------------------------|
; Draw Board Procedure, for CGA      |
;------------------------------------|
drawBoardCGA PROC
             ;
             ; clear screen
             ;
             cld          ; clear direction
             xor AX,AX    ; set AX to 0
             mov DI,0     ; begin at 0
             mov CX,0FA0h ; whole screen (bank 0) (1F40 / 2)
             rep stosw    ; fill with 0
             add DI,0C0h  ; next bank (2000 - 1F40)
             mov CX,0FA0h ; whole screen (bank 1) (1F40 / 2)
             rep stosw    ; fill with 0
             ;
             ; Draw board
             ;
             mov BX,pattern  ; pattern of rows
             xor AX,AX       ; begin at pixel 0,0
dbCGAStart:  cmp AX,1B80h    ; check if we've drawn all 11 rows
             jae dbCGAEnd    ; if so, draw "Your Move" sprites
             test BX,1       ; check LSB
             jz dbCGA0       ; 0 represents a vertical bar row
             jnz dbCGA1      ; 1 represents a horizontal bar + cross row
dbCGA0:      push BX         ; backup pattern
             add AX,0Ch      ; add 12
             mov BX,340h     ; sprite 13, vertical bar
             call CGADrawSpr ; draw first bar
             add AX,10h      ; add 16
             call CGADrawSpr ; draw second bar
             add AX,264h     ; beginning of next row
             pop BX          ; restore pattern
             shr BX,1        ; next pattern
             jmp dbCGAStart  ; next iteration
dbCGA1:      push BX         ; backup pattern
             mov BX,380h     ; sprite 14, horizontal bar
             call CGADrawSpr ; draw horizontal bar 1
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 2
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 3
             add AX,4        ; next grid space
             add BX,40h      ; sprite 15, cross
             call CGADrawSpr ; draw cross bar 1
             sub BX,40h      ; sprite 14, horizontal bar
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 4
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 5
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 6
             add AX,4        ; next grid space
             add BX,40h      ; sprite 15, cross
             call CGADrawSpr ; draw cross bar 2
             sub BX,40h      ; sprite 14, horizontal bar
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 7
             add AX,4        ; next grid space
             call CGADrawSpr ; draw horizontal bar 8
             add AX,4        ; final grid space
             call CGADrawSpr ; draw horizontal bar 9
             add AX,258h     ; beginning of next row
             pop BX          ; restore pattern
             shr BX,1        ; next pattern
             jmp dbCGAStart  ; next iteration
dbCGAEnd:    mov BX,080h     ; first sprite of "Your Move"
             call CGADrawSpr ; draw part 1
             add AX,4        ; move 4 pixels right
             add BX,40h      ; next sprite
             call CGADrawSpr ; draw part 2
             add AX,4        ; move 4 pixels right
             add BX,40h      ; next sprite
             call CGADrawSpr ; draw part 3
             add AX,4        ; move 4 pixels right
             add BX,40h      ; next sprite
             call CGADrawSpr ; draw part 4
             ret
drawBoardCGA ENDP
;------------------------------------|
; Draw Board Procedure, for CGA ENDS |
;------------------------------------|

;------------------------------------|
; Draw Board Procedure, for EGA      |
;------------------------------------|
drawBoardEGA PROC
             ;
             ; clear screen
             ;
             cld          ; clear direction
             xor AX,AX    ; set AX to 0
             mov DI,0     ; begin at 0
             mov CX,1F40h ; whole screen (1F40 / 2)
             rep stosw    ; fill with 0
             mov DX,03C4h ; Sequencer Registers - EGA
             mov AX,0F02h ; All bitplanes
             out DX,AX    ; update screen
             ;
             ; draw board
             ;
             mov BX,pattern  ; pattern of rows
             xor AX,AX       ; begin at pixel 0,0
dbEGAStart:  cmp AX,1B80h    ; check if we've drawn all 11 rows
             jae dbEGAEnd    ; if so, draw "Your Move" sprites
             test BX,1       ; check LSB
             jz dbEGA0       ; 0 represents a vertical bar row
             jnz dbEGA1      ; 1 represents a horizontal bar + cross row
dbEGA0:      push BX         ; backup pattern
             add AX,6        ; add 6
             mov BX,680h     ; sprite 13, vertical bar
             call EGADrawSpr ; draw first bar
             add AX,8        ; add 32
             call EGADrawSpr ; draw second bar
             add AX,272h     ; beginning of next row
             pop BX          ; restore pattern
             shr BX,1        ; next pattern
             jmp dbEGAStart  ; next iteration
dbEGA1:      push BX         ; backup pattern
             mov BX,700h     ; sprite 14, horizontal bar
             call EGADrawSpr ; draw horizontal bar 1
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 2
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 3
             add AX,2        ; next grid space
             add BX,80h      ; sprite 15, cross
             call EGADrawSpr ; draw cross bar 1
             sub BX,80h      ; sprite 14, horizontal bar
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 4
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 5
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 6
             add AX,2        ; next grid space
             add BX,80h      ; sprite 15, cross
             call EGADrawSpr ; draw cross bar 2
             sub BX,80h      ; sprite 14, horizontal bar
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 7
             add AX,2        ; next grid space
             call EGADrawSpr ; draw horizontal bar 8
             add AX,2        ; final grid space
             call EGADrawSpr ; draw horizontal bar 9
             add AX,26Ch     ; beginning of next row (3C + 4B0)
             pop BX          ; restore pattern
             shr BX,1        ; next pattern
             jmp dbEGAStart  ; next iteration
dbEGAEnd:    mov BX,100h     ; first sprite of "Your Move"
             call EGADrawSpr ; draw part 1
             add AX,2        ; move 16 pixels right
             add BX,80h      ; next sprite
             call EGADrawSpr ; draw part 2
             add AX,2        ; move 16 pixels right
             add BX,80h      ; next sprite
             call EGADrawSpr ; draw part 3
             add AX,2        ; move 16 pixels right
             add BX,80h      ; next sprite
             call EGADrawSpr ; draw part 4
             ret
drawBoardEGA ENDP
;------------------------------------|
; Draw Board Procedure, for EGA ENDS |
;------------------------------------|

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
tmRow:     jcxz tmDonePos  ; if row (CH) is 0, we're done (CL should already be 0 if we've gotten this far)
           shl AX,5        ; move to next row
           dec CH          ; row -= 1
           jmp tmRow       ; loop
           ;
           ; add constructed mask to board data
           ;
tmDonePos: shl AX,1           ; make room for player
           add gameVars,AX    ; update board and commit to memory
           pop CX             ; get column and row data for easy win testing
           mov AL,[settings]  ; get video mode
           cmp AL,0           ; check for text mode
           je tmDPtext
           cmp AL,1           ; check for PCjr/Tandy 1000 mode
           je tmDPjr
           cmp AL,2           ; check for CGA mode
           je tmDPcga
           cmp AL,3           ; check for EGA mode
           je tmDPega
           jmp tmDPcont       ; unknown mode, so skip section
tmDPtext:  call drawPieceText ; print added piece to screen
           jmp tmDPcont       ; continue
tmDPjr:    call drawPieceJr   ; draw added piece to screen
           jmp tmDPcont       ; continue
tmDPcga:   call drawPieceCGA  ; draw added piece to screen
           jmp tmDPcont       ; continue
tmDPega:   call drawPieceEGA  ; draw added piece to screen
           jmp tmDPcont       ; continue
tmDPcont:  call testWin       ; if we've gotten this far, that means the board has changed, so lets check if the player has won
           xor gameVars,1     ; XOR LSB, which will change current player
           xor DL,DL          ; set DL to 0, because we were successful in updating the board
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
              xor BX,BX          ; set player 0
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
            push CX         ; backup row, column
            mov AL,CH       ; place row in AL
            shl AL,1
            shl AL,1        ; row * 4
            inc AL          ; add 1
            xor AH,AH       ; remove upper byte
            mov DX,280h     ; 160 * 4 (y-distance between sprites)
            mul DX          ; multiply
            mov BX,AX       ; store video offset in BX
            mov AL,CL       ; place column in AL
            xor AH,AH       ; 0 out AH
            shl AX,1
            shl AX,1        ; column * 4
            mov DX,8        ; tiles are 8 bytes apart (16 pixels)
            mul DL          ; column * 4 * 8 = "y coordinate"
            add AX,DX       ; add one more column
            add AX,BX       ; add to video offset (now offset is stored in AX)
            mov BX,gameVars ; get game data in BX
            and BX,1        ; only want player
            shl BX,7        ; multiply by 80h (80h bytes per sprite)
            call JrDrawSpr  ; draw the new piece to the screen
            pop CX          ; restore row, column
            ret
drawPieceJr ENDP
;-------------------------------------------|
; Draw Piece Procedure, for PCjr/Tandy ENDS |
;-------------------------------------------|

;------------------------------------|
; Draw Piece Procedure, for CGA      |
;   CH = row                         |
;   CL = column                      |
;   CX is preserved                  |
;------------------------------------|
drawPieceCGA PROC
             push CX         ; backup row, column
             mov AL,CH       ; place row in AL
             shl AL,1
             shl AL,1        ; row * 4
             inc AL          ; add 1
             xor AH,AH       ; remove upper byte
             mov DX,280h     ; 80 * 4 (y-distance between sprites)
             mul DX          ; multiply
             mov BX,AX       ; store video offset in BX
             mov AL,CL       ; place column in AL
             xor AH,AH       ; 0 out AH
             shl AX,1
             shl AX,1
             shl AX,1
             shl AX,1        ; column * 4 * 4 = "y coordinate"
             add AX,4        ; add one more column
             add AX,BX       ; add to video offset (now offset is stored in AX)
             mov BX,gameVars ; get game data in BX
             and BX,1        ; only want player
             shl BX,6        ; multiply by 40h (40h bytes per sprite)
             call CGADrawSpr ; draw the new piece to the screen
             pop CX          ; restore row, column
             ret
drawPieceCGA ENDP
;------------------------------------|
; Draw Piece Procedure, for CGA ENDS |
;------------------------------------|

;------------------------------------|
; Draw Piece Procedure, for EGA      |
;   CH = row                         |
;   CL = column                      |
;   CX is preserved                  |
;------------------------------------|
drawPieceEGA PROC
             push CX         ; backup row, column
             mov AL,CH       ; place row in AL
             shl AL,1
             shl AL,1        ; row * 4
             inc AL          ; add 1
             xor AH,AH       ; remove upper byte
             mov DX,280h     ; 160 * 4 (y-distance between sprites)
             mul DX          ; multiply
             mov BX,AX       ; store video offset in BX
             mov AL,CL       ; place column in AL
             xor AH,AH       ; 0 out AH
             shl AX,1
             shl AX,1
             shl AX,1        ; column * 4 * 2 = "y coordinate"
             add AX,2        ; add one more column
             add AX,BX       ; add to video offset (now offset is stored in AX)
             mov BX,gameVars ; get game data in BX
             and BX,1        ; only want player
             shl BX,7        ; multiply by 80h (80h bytes per sprite)
             call EGADrawSpr ; draw the new piece to the screen
             pop CX          ; restore row, column
             ret
drawPieceEGA ENDP
;------------------------------------|
; Draw Piece Procedure, for EGA ENDS |
;------------------------------------|

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
            mov DL,CH       ; place column in DL
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
            mov [pieces+2],AL ; set winner
            mov BH,[settings] ; get video mode
            cmp BH,0          ; test text mode
            je twWinText      ; print winning message
            cmp BH,1          ; test PCjr/Tandy 1000
            je twWinJr        ; draw winning message
            cmp BH,2          ; test CGA
            je twWinCGA       ; draw winning message
            cmp BH,3          ; test EGA
            je twWinEGA       ; draw winning message
            jmp twEnd         ; unknown mode, skip section
            ;
            ; Congratulatory message, text
            ;
twWinText:  mov AH,2        ; BIOS video function 2, set cursor position
            xor BH,BH       ; page 0
            mov DX,0C00h    ; row 12, column 0
            int 10h         ; call BIOS video
            xor AH,AH       ; remove bios video function
            dec AL          ; back to winning player
            lea BX,pieces   ; get player characters
            add BX,AX       ; offset to X or O
            mov DX,1        ; string length of 1
            call WriteText  ; print player character to screen
            lea DX,congrats ; load win text
            call WriteLn    ; print to screen
            jmp twEnd       ; continue
            ;
            ; Congratulatory message, PCjr/Tandy 1000
            ;
twWinJr:    push AX        ; backup winner offset
            mov AX,1B80h   ; screen location for "Your Move", and "Winner:" message
            mov BX,400h    ; sprite 8, beginning of "Winner:" message
            call JrDrawSpr ; draw sprite 1
            add AX,8       ; move 8 bytes right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw sprite 2
            add AX,8       ; move 8 bytes right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw sprite 3
            add AX,8       ; move 8 bytes right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw sprite 4
            add AX,8       ; move 8 bytes right
            add BX,80h     ; next sprite
            call JrDrawSpr ; draw sprite 5
            add AX,0Ch     ; move 12 bytes right (1.5 tiles)
            pop BX         ; restore winner offset
            shl BX,7       ; multiply by 128
            add BX,280h    ; then add 280h, now we will be positioned at the 'fancy x', or 'fancy o' sprite
            call JrDrawSpr ; draw said sprite
            add AX,0Ch     ; move 12 bytes right
            mov BX,800h    ; sprite 16, trophy
            call JrDrawSpr ; draw trophy
            jmp twEnd      ; continue
            ;
            ; Congratulatory message, CGA
            ;
twWinCGA:   push AX         ; backup winner offset
            mov AX,1B80h    ; screen location for "Your Move", and "Winner:" message
            mov BX,200h     ; sprite 8, beginning of "Winner:" message
            call CGADrawSpr ; draw sprite 1
            add AX,4        ; move 4 bytes right
            add BX,40h      ; next sprite
            call CGADrawSpr ; draw sprite 2
            add AX,4        ; move 4 bytes right
            add BX,40h      ; next sprite
            call CGADrawSpr ; draw sprite 3
            add AX,4        ; move 4 bytes right
            add BX,40h      ; next sprite
            call CGADrawSpr ; draw sprite 4
            add AX,4        ; move 4 bytes right
            add BX,40h      ; next sprite
            call CGADrawSpr ; draw sprite 5
            add AX,6        ; move 6 bytes right (1.5 tiles)
            pop BX          ; restore winner offset
            shl BX,6        ; multiply by 64 (64 = 40h, which is the size of each sprite)
            add BX,140h     ; then add 140h, now we will be positioned at the 'fancy x', or 'fancy o' sprite
            call CGADrawSpr ; draw said sprite
            add AX,6        ; move 6 bytes right
            mov BX,400h     ; sprite 16, trophy
            call CGADrawSpr ; draw trophy
            jmp twEnd       ; continue
            ;
            ; Congratulatory message, EGA
            ;
twWinEGA:   push AX         ; backup winner offset
            mov AX,1B80h    ; screen location for "Your Move", and "Winner:" message
            mov BX,400h     ; sprite 8, beginning of "Winner:" message
            call EGADrawSpr ; draw sprite 1
            add AX,2        ; move 2 bytes right
            add BX,80h      ; next sprite
            call EGADrawSpr ; draw sprite 2
            add AX,2        ; move 2 bytes right
            add BX,80h      ; next sprite
            call EGADrawSpr ; draw sprite 3
            add AX,2        ; move 2 bytes right
            add BX,80h      ; next sprite
            call EGADrawSpr ; draw sprite 4
            add AX,2        ; move 2 bytes right
            add BX,80h      ; next sprite
            call EGADrawSpr ; draw sprite 5
            add AX,3        ; move 3 bytes right (1.5 tiles)
            pop BX          ; restore winner offset
            shl BX,7        ; multiply by 128
            add BX,280h     ; then add 280h, now we will be positioned at the 'fancy x', or 'fancy o' sprite
            call EGADrawSpr ; draw said sprite
            add AX,3        ; move 3 bytes right
            mov BX,800h     ; sprite 16, trophy
            call EGADrawSpr ; draw trophy
            jmp twEnd       ; continue
            ;
            ; End of procedure
            ;
twEnd:      ret
testWin     ENDP
;-----------------------------|
; Test for Win Procedure ENDS |
;-----------------------------|

;---------------------------|
; Get Column Procedure      |
;   Place row data in AX    |
;   and column in DL (0-2)  |
; column will be returned   |
; in DL                     |
;---------------------------|
getColumn PROC
          mov CX,0FF03h ; set iteration 255 and CL to 3 for division
gcLoop:   inc CH        ; increment iteration
          xor AH,AH     ; clear out possible remainder from previous iteration
          div CL        ; divide board in AX by 3
          cmp CH,DL     ; compare current column to requested column
          jnz gcLoop    ; if we haven't reached the column we want, try again
          mov DL,AH     ; store value of column in DL
          ret
getColumn ENDP
;---------------------------|
; Get Column Procedure ENDS |
;---------------------------|

;------------------------------|
; PCjr/Tandy, draw sprite      |
;   BX = address of sprite     |
;   AX = video offset/"coords" |
;  AX is preserved             |
;  BX is preserved             |
;------------------------------|
JrDrawSpr PROC
          lea SI,grpieces ; source index will begin where the graphics are loaded
          add SI,BX       ; move to requested sprite
          mov DI,AX       ; set destination address to requested video offset
          mov CX,8        ; 8 bytes will be copied (8 bytes per row)
          rep movsb       ; copy 8 bytes from DS to video memory
          add DI,98h      ; DI + A0 - 8 (add one row to destination, but subtract the 8 bytes we already copied , since DI was changed)
          mov CX,8        ; set count 8 again
          rep movsb       ; I think we see where this is going
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,1E18h    ; DI - 08 - A0 - A0 - A0 + 2000, -8 is back to start of row, 3 A0s are for 3 previous rows, 2000 is for next video bank
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,1E18h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,1E18h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,98h
          mov CX,8
          rep movsb
          add DI,1E18h
          mov CX,8
          rep movsb
          ret
JrDrawSpr ENDP
;------------------------------|
; PCjr/Tandy, draw sprite ENDS |
;------------------------------|

;--------------------------|
; CGA, draw sprite         |
;   BX = address of sprite |
;   AX = video offset      |
;--------------------------|
CGADrawSpr PROC
           lea SI,grpieces
           add SI,BX
           mov DI,AX
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,1DCCh
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           add DI,4Ch
           mov CX,4
           rep movsb
           ret
CGADrawSpr ENDP
;--------------------------|
; CGA, draw sprite ENDS    |
;--------------------------|

;------------------------------|
; EGA, draw sprite             |
;   BX = address of sprite     |
;   AX = video offset/"coords" |
;  AX is preserved             |
;  BX is preserved             |
;------------------------------|
EGADrawSpr PROC
           lea SI,grpieces
           add SI,BX
           mov DX,03C4h ; Sequencer Registers - EGA
           mov CL,8     ; begin with intensity bitplane
           cld          ; go forward
EGAdsLoop: mov DI,AX    ; set destination to video address
           movsw        ; write 2 bytes (16 pixels) to bitplane
           add DI,26h   ; each row (320 px) is 28h bytes, and we just moved forward 2
           movsw        ; etc
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           add DI,26h
           movsw
           push AX      ; backup AX, since apparently I can't use the C registers with OUT or IN...
           mov AH,CL    ; place CL in AH
           shr AH,1     ; and move to the right (now it should be 4 2 1 or 0
           mov AL,2     ; Map Mask register
           out DX,AX    ; update screen
           pop AX       ; restore video address
           shr CL,1     ; keep going if we haven't set all 4 bitplanes
           jnz EGAdsLoop
           push AX
           mov AX,0F02h
           out DX,AX
           pop AX
           ret
EGADrawSpr ENDP
;------------------------------|
; EGA, draw sprite ENDS        |
;------------------------------|

MyCode ENDS
;-------------------|
;      END CODE     |
;-------------------|

  END start
;
; End of program
;
