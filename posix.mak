DMD=dmd

RFLAGS=-O -release -inline  -d 
LIB_SRC= \
dmdscript/darguments.d dmdscript/darray.d dmdscript/dboolean.d \
dmdscript/ddate.d dmdscript/ddeclaredfunction.d \
dmdscript/derror.d dmdscript/dfunction.d dmdscript/dglobal.d \
dmdscript/dmath.d dmdscript/dnative.d dmdscript/dnumber.d \
dmdscript/dobject.d dmdscript/dregexp.d dmdscript/dstring.d \
dmdscript/errmsgs.d dmdscript/expression.d dmdscript/functiondefinition.d \
dmdscript/identifier.d dmdscript/ir.d dmdscript/irstate.d \
dmdscript/iterator.d dmdscript/lexer.d dmdscript/opcodes.d dmdscript/parse.d \
dmdscript/program.d dmdscript/property.d \
dmdscript/date.d dmdscript/dateparse.d dmdscript/datebase.d \
dmdscript/protoerror.d dmdscript/RandAA.d dmdscript/scopex.d dmdscript/outbuffer.d \
dmdscript/script.d dmdscript/statement.d dmdscript/symbol.d dmdscript/text.d dmdscript/regexp.d\
dmdscript/threadcontext.d dmdscript/utf.d dmdscript/value.d  dmdscript/extending.d

all: ds samples

ds: testscript.d dmdscriptlib.a
	$(DMD) $(RFLAGS) dmdscriptlib.a testscript.d -ofds

dmdscriptlib.a : $(LIB_SRC)
	$(DMD) -lib $(RFLAGS) $(LIB_SRC) -ofdmdscriptlib.a
samples: samples/ext ds

samples/ext: samples/ext.d dmdscriptlib.a
	$(DMD) $(RFLAGS) dmdscriptlib.a samples/ext.d -ofsamples/ext

redist:
	tar -jc dmdscript/*.d dmdscript/*.visualdproj samples/*.d samples/*.ds *.d posix.mak win32.mak README.txt LICENSE_1_0.txt *.visualdproj dmdscript.sln > dmdscript.tar.bz2
clean:
	rm -f dmdscriptlib.a ds samples/ext

