
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


module dmdscript.protoerror;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.dfunction;


/* ===================== D0_constructor ==================== */

class D0_constructor : Dfunction
{
    d_string text_d1;
    Dobject function(d_string) newD0;

    this(ThreadContext *tc, d_string text_d1, Dobject function(d_string) newD0)
    {
        super(1, tc.Dfunction_prototype);
        this.text_d1 = text_d1;
        this.newD0 = newD0;
    }

    void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.11.7.2
        Value* m;
        Dobject o;
        tchar[] s;

        m = (arglist.length) ? &arglist[0] : &vundefined;
        // ECMA doesn't say what we do if m is undefined
        if (m.isUndefined())
            s = text_d1;
        else
            s = m.toString();
        o = (*newD0)(s);
        ret.putVobject(o);
        return null;
    }

    void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA v3 15.11.7.1
        return Construct(cc, ret, arglist);
    }
}


template proto(alias TEXT_D1)
{

    /* ===================== D0_prototype ==================== */

    class D0_prototype : D0
    {
        this(ThreadContext *tc)
        {
            super(tc.Derror_prototype);

            tchar[] s;

            Put(TEXT_constructor, tc.ctorTable[TEXT_D1], DontEnum);
            Put(TEXT_name, TEXT_D1, 0);
            s = TEXT_D1 ~ ".prototype.message";
            Put(TEXT_message, s, 0);
            Put(TEXT_description, s, 0);
            Put(TEXT_number, cast(d_number)0, 0);
        }
    }


    /* ===================== D0 ==================== */

    class D0 : Dobject
    {
        ErrInfo errinfo;

        this(Dobject prototype)
        {
            super(prototype);
            classname = TEXT_Error;
        }

        this(tchar[] m)
        {
            this(D0.getPrototype());
            Put(TEXT_message, m, 0);
            Put(TEXT_description, m, 0);
            Put(TEXT_number, cast(d_number)0, 0);
            errinfo.message = m;
        }

        this(ErrInfo *perrinfo)
        {
            this(perrinfo.message);
            errinfo = *perrinfo;
            Put(TEXT_number, cast(d_number)perrinfo.code, 0);
        }

        void getErrInfo(ErrInfo *perrinfo, int linnum)
        {
            if (linnum && errinfo.linnum == 0)
                errinfo.linnum = linnum;
            if (perrinfo)
                *perrinfo = errinfo;
            //writefln("getErrInfo(linnum = %d), errinfo.linnum = %d", linnum, errinfo.linnum);
        }

        static Dfunction getConstructor()
        {
            ThreadContext *tc = ThreadContext.getThreadContext();
            assert(tc);
            return tc.ctorTable[TEXT_D1];
        }

        static Dobject getPrototype()
        {
            ThreadContext *tc = ThreadContext.getThreadContext();
            assert(tc);
            return tc.protoTable[TEXT_D1];
        }

        static Dobject newD0(d_string s)
        {
            return new D0(s);
        }

        static void init(ThreadContext *tc)
        {
            Dfunction constructor = new D0_constructor(tc, TEXT_D1, &newD0);
            tc.ctorTable[TEXT_D1] = constructor;

            Dobject prototype = new D0_prototype(tc);
            tc.protoTable[TEXT_D1] = prototype;

            constructor.Put(TEXT_prototype, prototype, DontEnum | DontDelete | ReadOnly);
        }
    }

    /**********************************
     * Register initializer for this class.
     */

    static this()
    {
        ThreadContext.initTable ~= &D0.init;
    }

}

alias proto!(TEXT_SyntaxError) syntaxerror;
alias proto!(TEXT_EvalError) evalerror;
alias proto!(TEXT_ReferenceError) referenceerror;
alias proto!(TEXT_RangeError) rangeerror;
alias proto!(TEXT_TypeError) typeerror;
alias proto!(TEXT_URIError) urierror;

