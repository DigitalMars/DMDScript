# DMDscript makefile for OSX
# Copyright (C) 2005-2009 by Digital Mars
# All Rights Reserved
# http://www.digitalmars.com
# Written by Walter Bright

# Build with g++:
#	make -f osx.mak


OUTDIR=.

#DFLAGS=-I.. -g
DFLAGS=-I.. -O -release

# See: http://developer.apple.com/documentation/developertools/conceptual/cross_development/Using/chapter_3_section_2.html#//apple_ref/doc/uid/20002000-1114311-BABGCAAB
ENVP= MACOSX_DEPLOYMENT_TARGET=10.3
SDK=/Developer/SDKs/MacOSX10.4u.sdk
#SDK=/Developer/SDKs/MacOSX10.6.sdk
LDFLAGS= -isysroot ${SDK} -Wl,-syslibroot,${SDK}

CC=gcc -m32 -isysroot $(SDK)

DMD=dmd

# Makerules:
.d.o :
	 $(DMD) -c $(DFLAGS) $*.d

defaulttarget: libdmdscript.a ds

################ RELEASES #########################

release:
	make clean
	make ds
	make clean

#########################################

OBJS=	identifier.o lexer.o parse.o expression.o errmsgs.o \
	property.o iterator.o value.o dmath.o dnative.o \
	dstring.o ddate.o dboolean.o dnumber.o dregexp.o derror.o \
	darguments.o dglobal.o darray.o dfunction.o dobject.o \
	threadcontext.o script.o program.o statement.o ddeclaredfunction.o \
	scopex.o symbol.o functiondefinition.o irstate.o ir.o \
	opcodes.o text.o \
	protoerror.o testscript.o

SRC=	identifier.d lexer.d parse.d expression.d textgen.d \
	property.d iterator.d protoerror.d value.d dmath.d dnative.d \
	dstring.d ddate.d dboolean.d dnumber.d dregexp.d derror.d \
	darguments.d dglobal.d darray.d dfunction.d dobject.d \
	threadcontext.d script.d program.d statement.d ddeclaredfunction.d \
	scopex.d symbol.d functiondefinition.d irstate.d ir.d \
	opcodes.d text.d testscript.d

SRCBLDS= errmsgs.d


############### Link Command Line ##########################

testscript.o : testscript.d
	$(DMD) -c $(DFLAGS) testscript.d

ds : testscript.o libdmdscript.a linux.mak
	${ENVP} $(CC) -o $@ testscript.o libdmdscript.a -lphobos -lpthread -lm -g

libdmdscript.a : $(OBJS) linux.mak
	ar -r $@ $(OBJS)

##################### SPECIAL BUILDS #####################

################# Source file dependencies ###############

darguments.o : darguments.d
	 $(DMD) -c $(DFLAGS) darguments.d

darray.o : darray.d
	 $(DMD) -c $(DFLAGS) darray.d

dboolean.o : dboolean.d
	 $(DMD) -c $(DFLAGS) dboolean.d

ddate.o : ddate.d
	 $(DMD) -c $(DFLAGS) ddate.d

ddeclaredfunction.o : ddeclaredfunction.d
	 $(DMD) -c $(DFLAGS) ddeclaredfunction.d

derror.o : derror.d
	 $(DMD) -c $(DFLAGS) derror.d

dfunction.o : dfunction.d protoerror.d
	 $(DMD) -c $(DFLAGS) dfunction.d

dglobal.o : dglobal.d protoerror.d
	 $(DMD) -c $(DFLAGS) dglobal.d

dmath.o : dmath.d
	 $(DMD) -c $(DFLAGS) dmath.d

dnative.o : dnative.d
	 $(DMD) -c $(DFLAGS) dnative.d

dnumber.o : dnumber.d
	 $(DMD) -c $(DFLAGS) dnumber.d

dobject.o : dobject.d
	 $(DMD) -c $(DFLAGS) dobject.d

dregexp.o : dregexp.d protoerror.d
	 $(DMD) -c $(DFLAGS) dregexp.d

dstring.o : dstring.d
	 $(DMD) -c $(DFLAGS) dstring.d

errmsgs.o : errmsgs.d
	 $(DMD) -c $(DFLAGS) errmsgs.d

expression.o : expression.d
	 $(DMD) -c $(DFLAGS) expression.d

functiondefinition.o : functiondefinition.d
	 $(DMD) -c $(DFLAGS) functiondefinition.d

identifier.o : identifier.d errmsgs.d
	 $(DMD) -c $(DFLAGS) identifier.d

ir.o : ir.d
	 $(DMD) -c $(DFLAGS) ir.d

irstate.o : irstate.d
	 $(DMD) -c $(DFLAGS) irstate.d

iterator.o : iterator.d
	 $(DMD) -c $(DFLAGS) iterator.d

lexer.o : lexer.d
	 $(DMD) -c $(DFLAGS) lexer.d

opcodes.o : opcodes.d
	 $(DMD) -c $(DFLAGS) -inline opcodes.d

parse.o : parse.d
	 $(DMD) -c $(DFLAGS) parse.d

program.o : program.d
	 $(DMD) -c $(DFLAGS) program.d

property.o : property.d
	 $(DMD) -c $(DFLAGS) -inline property.d

protoerror.o : protoerror.d
	 $(DMD) -c $(DFLAGS) protoerror.d

scopex.o : scopex.d
	 $(DMD) -c $(DFLAGS) scopex.d

script.o : script.d
	 $(DMD) -c $(DFLAGS) script.d

statement.o : statement.d
	 $(DMD) -c $(DFLAGS) statement.d

symbol.o : symbol.d
	 $(DMD) -c $(DFLAGS) symbol.d

text.o : text.d
	 $(DMD) -c $(DFLAGS) text.d

threadcontext.o : threadcontext.d
	 $(DMD) -c $(DFLAGS) threadcontext.d

value.o : value.d
	 $(DMD) -c $(DFLAGS) -inline value.d

################### Utilities ################

errmsgs.d : $(OUTDIR)/textgen
	$(OUTDIR)/textgen

$(OUTDIR)/textgen.o : textgen.d
	$(DMD) -c textgen.d

$(OUTDIR)/textgen : $(OUTDIR)/textgen.o
	$(DMD) -of$@ $(OUTDIR)/textgen.o

################### Utilities ################

clean:
	rm $(OBJS) textgen.o textgen errmsgs.d

zip : $(SRC) win32.mak linux.mak osx.mak gpl.txt
	rm dmdscript.zip
	zip dmdscript $(SRC) win32.mak linux.mak osx.mak gpl.txt

###################################
