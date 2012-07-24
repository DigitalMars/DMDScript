Intro
---------------------------------------
DMDScript is an implementation of ECMA-262 scripting language
written in the D programming language.
For more info on DMDscript, consult
http://www.digitalmars.com/dscript/index.html

This is DMDScript-2, a port of DMDScript to D 2.0.

Main goals of this project, in the order of priority:
1. Make it more stable (this is a MUST for browser-like apps for instance).
2. Bring it in line with ECMA spec.
3. Refactor to use modern D2 idioms and practices, Phobos being prime example.
4. Introduce an utility wrapper library, providing 
convenience of extensibility/embedding.
5. Make it even faster ;)


Status
---------------------------------------
Well, the porting itself is complete, but I was forced to reduce
it's performance a fair bit. The reason is simple, DMDScript used
a kind of speed hack to manipulate with the 
underlying AA implementation directly. The trick was to compute hash only 
once for given value, then search it in N hash-tables.
Chances are that D2 AA are different from theirs D1 counterpart.
For the moment I'm just using RandAA with equivalent hack which works fine.


As of now it's able to run a great deal of scripts.
I'm running it through the Google's sputnik ECMA-262 testsuit:
http://code.google.com/p/sputniktests/

See sputnikXXX.txt logfiles for extensive details.

Speaking of the aforementioned points:
[Stability] 
It's about 99.9% there I see few segfaults 
in 5200+ testes (and these are very nitpicky tests).
[ECMA Spec] 
This can be checked in accompaning logfile no less then 95%
[Refactoring]
Transition to exception handling and so on
[extending/embedding]
A in a highly experimential state, 
in fact requires refactoring of the library

Building
---------------------------------------
To get started just invoke make with the right makefile
in the project's root dir, that is
make -fwin32.mak
or 
make -fposix.mak

and make sure you have DMD's paths properly set up.
And if this all goes well you'll have 2 files produced:
dmdscript.lib/libdmdscript - the scripting language engine lib
ds.exe/ds - standalone console version, good for testing things

*** A note to Windows users:
If you are uncomfortable with makefiles there is also VisualD's solution file.
Check it out: http://www.dsource.org/projects/visuald


Testing
---------------------------------------

Was successfully tested on Windows 7 and Ubuntu 10.4 32bit.
Anyone having interest please take time to build and run it 
through the Google's Sputnik testsuit
the results if any is warmly welcome at dmitry.olsh@gmail.com

Samples
---------------------------------------
There some small samples to get started located at /samples.
Their number should gradualy increase as the main areas of work on  
the engine itself are complete.
To prepare samples, as thouse on extending/embedding script 
engine require additional compilation,  use samples target of makefile
make -f<win32.mak/posix.mak> samples

