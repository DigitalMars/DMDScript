
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
 * see www.digitalmars.com/dscript/cppscript.html.
 */


module dmdscript.dnative;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;

/******************* DnativeFunction ****************************/

alias void *function(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist) PCall;

struct NativeFunctionData
{
    d_string* string;
    PCall pcall;
    d_uint32 length;
}

class DnativeFunction : Dfunction
{
    PCall pcall;

    this(PCall func, tchar[] name, d_uint32 length)
    {
        super(length);
        this.name = name;
        pcall = func;
    }

    this(PCall func, tchar[] name, d_uint32 length, Dobject o)
    {
        super(length, o);
        this.name = name;
        pcall = func;
    }

    void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        return (*pcall)(this, cc, othis, ret, arglist);
    }

    /*********************************
     * Initalize table of native functions designed
     * to go in as properties of o.
     */

    static void init(Dobject o, NativeFunctionData[] nfd, uint attributes)
    {
        Dobject f = Dfunction.getPrototype();

        for (size_t i = 0; i < nfd.length; i++)
        {   NativeFunctionData* n = &nfd[i];

            o.Put(*n.string,
                new DnativeFunction(n.pcall, *n.string, n.length, f),
                attributes);
        }
    }
}
