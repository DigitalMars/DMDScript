/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2010 by Digital Mars
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 * written by Walter Bright
 * http://www.digitalmars.com
 *
 * D2 port by Dmitry Olshansky
 *
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */


module dmdscript.threadcontext;


import dmdscript.script;
import dmdscript.program;
import dmdscript.dmath;
import dmdscript.dobject;
import dmdscript.dfunction;

// These are our per-thread global variables
// Tables where the prototype and constructor object are stored.

struct ThreadContext {
	Dobject[d_string] protoTable;
	Dfunction[d_string] ctorTable;

	Dfunction Dobject_constructor;
	Dobject Dobject_prototype;

	Dfunction Dfunction_constructor;
	Dobject Dfunction_prototype;

	Dfunction Darray_constructor;
	Dobject Darray_prototype;

	Dfunction Dstring_constructor;
	Dobject Dstring_prototype;

	Dfunction Dboolean_constructor;
	Dobject Dboolean_prototype;

	Dfunction Dnumber_constructor;
	Dobject Dnumber_prototype;

	Dfunction Derror_constructor;
	Dobject Derror_prototype;

	Dfunction Ddate_constructor;
	Dobject Ddate_prototype;

	Dfunction Dregexp_constructor;
	Dobject Dregexp_prototype;

	Dfunction Denumerator_constructor;
	Dobject Denumerator_prototype;

	Dmath Dmath_object;

	void function (CallContext*)[] threadInitTable;
}

// kept for backwards compatibility with the dmdscript.extending module
void delegate (CallContext*)[] threadInitTable;
