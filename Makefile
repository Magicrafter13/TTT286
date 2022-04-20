MAIN = tictac
TEST = test

ASM_DIR = modules
OBJ_DIR = build
SOURCES = conwrite.asm

AFLAGS = /Imacros

all: $(OBJ_DIR) $(MAIN).exe $(TEST).exe

$(OBJ_DIR):
	@-mkdir $@ > nul

# Main program
$(MAIN).exe: $(OBJ_DIR)\$$(@B).obj $(OBJ_DIR)\$(SOURCES:.asm=.obj)
	LINK $**,$@;

# Testing program
$(TEST).exe: $(OBJ_DIR)\$$(@B).obj $(OBJ_DIR)\$(SOURCES:.asm=.obj)
	LINK $**,$@;

#$(OBJ_DIR)\$(MAIN).obj: $(MAIN).asm
#	$(AS) $(AFLAGS) /Fo$@ /c $**

.asm{$(OBJ_DIR)}.obj:
	$(AS) $(AFLAGS) /Fo$@ /c $<

{$(ASM_DIR)}.asm{$(OBJ_DIR)}.obj:
	$(AS) $(AFLAGS) /Fo$@ /c $<

clean:
	-del $(MAIN).exe > nul
	-del $(TEST).exe > nul
	-del $(OBJ_DIR)\*.obj > nul
