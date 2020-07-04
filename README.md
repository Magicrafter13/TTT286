# Assembling
For this project I use the Microsoft Macro Assembler (MASM) version 6.0b.
I'm sure other versions will work, but here's a link to this version if you want to try it out yourself. [MASM 6](https://winworldpc.com/product/macro-assembler/6x)

You may use the provided 'compile.bat' if you don't know which commands to use, however \<path_to_masm\>\BIN and \<path_to_masm\>\BINB must be in your system path.

This program should assemble and run perfectly fine in DOSBox.

# Playing
You can either, Assemble the code yourself, or click on the Releases tab and download an assembled binary (an exe file). (Make sure to download a graphics file unless you want to play in text only.)
Just type the name of the program at the DOS prompt, while in the same directory as the game, ie `C:\TTT286\> tictac` and press enter. Then select which mode you want to use.

I think the controls are pretty intuitive, especially since there are 2 different ways you can play, but if you aren't sure, just press H to bring up the help screen. (May not work in all graphics modes, so if nothing happens, run the game in text mode first to learn the controls.)

## Modes
1. Text Mode - Uses a mode 3, 80x25 text. (though it doesn't use that entire space)
2. PCjr/Tandy 1000 - 320x200, 16 color mode (requires JR.BIN)
3. CGA - 320x200 4 color mode (requires CGA.BIN)
4. EGA - 320x200 16 color mode (requires EGA.BIN)

## Why?
1. Why did I make the program: Well, I want to try and start making games/software for DOS, and this is a simple way to get some practice.
2. Why do I need a 286 or higher to run Tic-Tac-Toe??? You don't *need* a 286 to run it, however since I only need this thing to run on a 286, and I wanted to be a little lazy with some bit shifting feature that was introduced with the 286, I decided to make it a requirement. So no, there is no good reason why this won't run on an original intel 8086, in fact, remove the .286 from the beginning of the source file, and assemble it. You will get one or two errors, after that you can just manually "fix" them yourself, then it should assemble for any x86.