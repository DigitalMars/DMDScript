
/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2006 by Digital Mars
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


module dmdscript.derror;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dnative;
import dmdscript.text;
import dmdscript.property;


// Comes from MAKE_HRESULT(SEVERITY_ERROR, FACILITY_CONTROL, 0)
const uint FACILITY = 0x800A0000;

/* ===================== Derror_constructor ==================== */

class Derror_constructor : Dfunction
{
    this(ThreadContext *tc)
    {
        super(1, tc.Dfunction_prototype);
    }

    void* Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.7.2
        Dobject o;
        Value* m;
        Value* n;
        Value vemptystring;

        vemptystring.putVstring(null);
        switch (arglist.length)
        {
            case 0:     // ECMA doesn't say what we do if m is undefined
                    m = &vemptystring;
                    n = &vundefined;
                    break;
            case 1:
                    m = &arglist[0];
                    if (m.isNumber())
                    {
                        n = m;
                        m = &vemptystring;
                    }
                    else
                        n = &vundefined;
                    break;
            default:
                    m = &arglist[0];
                    n = &arglist[1];
                    break;
        }
        o = new Derror(m, n);
        ret.putVobject(o);
        return null;
    }

    void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA v3 15.11.1
        return Construct(cc, ret, arglist);
    }
}


/* ===================== Derror_prototype_toString =============== */

void* Derror_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.11.4.3
    // Return implementation defined string
    Value* v;

    //writef("Error.prototype.toString()\n");
    v = othis.Get(TEXT_message);
    if (!v)
        v = &vundefined;
    ret.putVstring(v.toString());
    return null;
}

/* ===================== Derror_prototype ==================== */

class Derror_prototype : Derror
{
    this(ThreadContext *tc)
    {
        super(tc.Dobject_prototype);
        Dobject f = tc.Dfunction_prototype;
        //d_string m = d_string_ctor(DTEXT("Error.prototype.message"));

        Put(TEXT_constructor, tc.Derror_constructor, DontEnum);

        static NativeFunctionData nfd[] =
        [
            {   &TEXT_toString, &Derror_prototype_toString, 0 },
        ];

        DnativeFunction.init(this, nfd, 0);

        Put(TEXT_name, TEXT_Error, 0);
        Put(TEXT_message, TEXT_, 0);
        Put(TEXT_description, TEXT_, 0);
        Put(TEXT_number, cast(d_number)(/*FACILITY |*/ 0), 0);
    }
}


/* ===================== Derror ==================== */

class Derror : Dobject
{
    this(Value* m, Value* v2)
    {
        super(getPrototype());
        classname = TEXT_Error;

        d_string msg;
        msg = m.toString();
        Put(TEXT_message, msg, 0);
        Put(TEXT_description, msg, 0);
        if (m.isString())
        {
        }
        else if (m.isNumber())
        {   d_number n = m.toNumber();
            n = cast(d_number)(/*FACILITY |*/ cast(int)n);
            Put(TEXT_number, n, 0);
        }
        if (v2.isString())
        {
            Put(TEXT_description, v2.toString(), 0);
            Put(TEXT_message, v2.toString(), 0);
        }
        else if (v2.isNumber())
        {   d_number n = v2.toNumber();
            n = cast(d_number)(/*FACILITY |*/ cast(int)n);
            Put(TEXT_number, n, 0);
        }
    }

    this(Dobject prototype)
    {
        super(prototype);
        classname = TEXT_Error;
    }

    static Dfunction getConstructor()
    {
        ThreadContext *tc = ThreadContext.getThreadContext();
        assert(tc);
        return tc.Derror_constructor;
    }

    static Dobject getPrototype()
    {
        ThreadContext *tc = ThreadContext.getThreadContext();
        assert(tc);
        return tc.Derror_prototype;
    }

    static void init(ThreadContext *tc)
    {
        tc.Derror_constructor = new Derror_constructor(tc);
        tc.Derror_prototype = new Derror_prototype(tc);

        tc.Derror_constructor.Put(TEXT_prototype, tc.Derror_prototype, DontEnum | DontDelete | ReadOnly);
    }
}

