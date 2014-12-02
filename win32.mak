DMD=dmd

RFLAGS=-O -release -inline  -d 
LIB_SRC= \
dmdscript\darguments.d dmdscript\darray.d dmdscript\dboolean.d \
dmdscript\ddate.d dmdscript\ddeclaredfunction.d \
dmdscript\derror.d dmdscript\dfunction.d dmdscript\dglobal.d \
dmdscript\dmath.d dmdscript\dnative.d dmdscript\dnumber.d \
dmdscript\dobject.d dmdscript\dregexp.d dmdscript\dstring.d \
dmdscript\errmsgs.d dmdscript\expression.d dmdscript\functiondefinition.d \
dmdscript\identifier.d dmdscript\ir.d dmdscript\irstate.d \
dmdscript\iterator.d dmdscript\lexer.d dmdscript\opcodes.d dmdscript\parse.d \
dmdscript\program.d dmdscript\property.d \
dmdscript/date.d dmdscript/dateparse.d dmdscript/datebase.d \
dmdscript\protoerror.d dmdscript\RandAA.d dmdscript\scopex.d dmdscript/outbuffer.d\
dmdscript\script.d dmdscript\statement.d dmdscript\symbol.d dmdscript\text.d dmdscript/regexp.d\
dmdscript\threadcontext.d dmdscript\utf.d dmdscript\value.d dmdscript\extending.d

all: ds.exe samples

ds.exe: testscript.d dmdscript.lib
	$(DMD) $(RFLAGS) dmdscript.lib testscript.d -ofds.exe

dmdscript.lib: $(LIB_SRC)
	$(DMD) -lib $(RFLAGS) $(LIB_SRC) -ofdmdscript.lib

samples: samples/ext.exe

samples/ext.exe: samples/ext.d dmdscript.lib
	$(DMD) $(RFLAGS) dmdscript.lib samples/ext.d -ofext.exe
	copy ext.exe samples
	del ext.exe

clean:
	del dmdscript.lib
	del ds.exe
	del samples/ext.exe

