# Dscript makefile
# Copyright (C) 1999-2005 by Digital Mars
# All Rights Reserved
# www.digitalmars.com
# Written by Walter Bright

# Build with Digital Mars D:
#	make -f win32.mak


OUTDIR=.
DMD=dmd

# Debug build
#CFLAGS=-I.. -g
#LFLAGS=/ma/co

# Release build
CFLAGS=-I.. -O -release
LFLAGS=/ma

# Makerules:
.d.obj :
	 $(DMD) -c $(CFLAGS) $*.d

defaulttarget: ds.exe dmdscript.lib

################ RELEASES #########################

release:
	make clean
	make ds.exe
	make clean

#########################################

OBJS=	identifier.obj lexer.obj parse.obj expression.obj errmsgs.obj \
	property.obj iterator.obj value.obj dmath.obj dnative.obj \
	dstring.obj ddate.obj dboolean.obj dnumber.obj dregexp.obj derror.obj \
	darguments.obj dglobal.obj darray.obj dfunction.obj dobject.obj \
	threadcontext.obj script.obj program.obj statement.obj ddeclaredfunction.obj \
	scopex.obj symbol.obj functiondefinition.obj irstate.obj ir.obj \
	opcodes.obj text.obj \
	protoerror.obj testscript.obj

SRC=	identifier.d lexer.d parse.d expression.d textgen.d \
	property.d iterator.d protoerror.d value.d dmath.d dnative.d \
	dstring.d ddate.d dboolean.d dnumber.d dregexp.d derror.d \
	darguments.d dglobal.d darray.d dfunction.d dobject.d \
	threadcontext.d program.d statement.d ddeclaredfunction.d \
	scopex.d symbol.d functiondefinition.d irstate.d ir.d \
	opcodes.d text.d script.d testscript.d

SRCBLDS= errmsgs.d


############### Link Command Line ##########################

ds.exe : $(SRCBLDS) testscript.obj dmdscript.lib win32.mak
	$(DMD) ds.exe testscript.obj -L$(LFLAGS) dmdscript.lib

dmdscript.lib : $(OBJS) win32.mak
#	$(DMD) -lib dmdscript.lib $(OBJS)
	-del dmdscript.lib
	lib -c -p32 dmdscript.lib $(OBJS)

##################### SPECIAL BUILDS #####################

################# Source file dependencies ###############

dfunction.obj : dfunction.d protoerror.d

dglobal.obj : dglobal.d protoerror.d

dobject.obj : dobject.d

dregexp.obj : dregexp.d protoerror.d

opcodes.obj : opcodes.d
	 $(DMD) -c $(CFLAGS) -inline opcodes.d

property.obj : property.d
	 $(DMD) -c $(CFLAGS) -inline property.d

value.obj : value.d
	 $(DMD) -c $(CFLAGS) -inline value.d

threadcontext.obj : threadcontext.d

################### Utilities ################

errmsgs.d : $(OUTDIR)\textgen.exe
	$(OUTDIR)\textgen

$(OUTDIR)\textgen.obj : textgen.d
	$(DMD) -c textgen.d

$(OUTDIR)\textgen.exe : $(OUTDIR)\textgen.obj
	$(DMD) $(OUTDIR)\textgen.obj $(OUTDIR)\textgen.exe

################### Utilities ################

clean:
	del $(OBJS)
	del textgen.obj textgen.exe
	del errmsgs.d

zip : $(SRC) win32.mak linux.mak osx.mak gpl.txt
	del dmdscript.zip
	zip32 dmdscript $(SRC) win32.mak linux.mak osx.mak gpl.txt

###################################
