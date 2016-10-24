#
# Makefile for DELAY device driver
#
# Bob Eager   April 2003
#
# Uses MASM 5.1
#
# Product name
#
PRODUCT		= delay
#
# Target directory
#
TARGET		= f:\binp
#
# Assembler setup
#
MFLAGS		= /n /p /t /w2
#
# Names of library files
#
LIBS		= os2286.lib
#
# Names of object files
#
OBJ		= delay.obj
#
# Other files
#
DEF		= $(PRODUCT).def
LNK		= $(PRODUCT).lnk
README		= readme.txt
#
# Final driver file
#
SYS		= $(PRODUCT).sys
#
# Distribution
#
DIST		= dist.zip
NETLIBDLL	= ..\netlib\netlib.dll
#
# Archive
#
ARCH		= arch.zip
#
#-----------------------------------------------------------------------
#
$(SYS):		$(OBJ) $(DEF) $(LNK)
		link /batch @$(LNK)
#
# Linker response file. Rebuild if makefile changes
#
$(LNK):		makefile
		echo $(OBJ)          > $(LNK)
		echo $(SYS)         >> $(LNK)
		echo $(PRODUCT)/map >> $(LNK)
		echo $(LIBS)        >> $(LNK)
		echo $(DEF)         >> $(LNK)
#
delay.obj:	delay.asm
		masm $(MFLAGS) delay,delay,delay;
#
clean:		
		-erase $(OBJ) $(LNK) $(PRODUCT).map $(PRODUCT).lst
#
install:	$(SYS)
		@copy $(SYS) $(TARGET) > nul
#
dist:		$(README) $(SYS)
		zip -9 -j $(DIST) $**
#
arch:		$(SYS) $(README) $(DEF) *.asm makefile
		zip -9 -j $(ARCH) $**
#
# End of makefile for DELAY device driver
#
