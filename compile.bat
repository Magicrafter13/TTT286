cd macros
masm ..\tictac.asm ..\tictac.obj
cd..
link tictac.obj+modules\conwrite.obj;
