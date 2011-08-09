
	DMDScript in D

DMDScript is the Digital Mars implementation of the ECMA262 scripting
language, also known as javascript.
The D implementation is very high performance, as you can verify using
the enclosed sieve benchmark. Try it!


/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2005 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * www.digitalmars.com
 * Use at your own risk. There is no warranty, express or implied.
 * License for redistribution is by the GNU General Public License in gpl.txt.
 *
 * A binary, non-exclusive license for commercial use can be
 * purchased from www.digitalmars.com/dscript/buy.html.
 *
 * DMDScript is implemented in the D Programming Language,
 * www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support,
 * see www.digitalmars.com/dscript/cpp.html.
 */

DMDScript in D comes as source code in D with a compiled library.
To use it, you'll need the D compiler from www.digitalmars.com/d/

Documentation:

	www.digitalmars.com/dscript/index.html

Files:

	readme.txt	this file
	gpl.txt		GNU Public License
	*.d		DMDScript source files
	testscript.d	test program
	win32.mak	makefile for Windows
	linux.mak	makefile for Linux
	dmdscript.lib	library for Windows
	libdmdscript.a	library for Linux
	sieve.ds	simple sieve benchmark
	sieve.html	simple sieve benchmark to run under browswer
	suite.ds	small test suite

To create test program ds:

    Windows:

	1) unzip dmdscript.zip
	2) cd dmdscript
	3) dmd ds.exe testscript.d dmdscript.lib

    Linux:

	1) unzip dmdscript.zip
	2) cd dmdscript
	3) gcc -o ds testscript.o libdmdscript.a -lpthread -lm -g

To run sieve.ds:

    ds sieve

To run suite.ds:

    ds suite


