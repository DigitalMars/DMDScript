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


module dmdscript.protoerror;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.dfunction;
import dmdscript.property;

/* ===================== D0_constructor ==================== */

class D0_constructor : Dfunction
{
    d_string text_d1;
    Dobject function(d_string) newD0;

    this(d_string text_d1, Dobject function(d_string) newD0)
    {
        super(1, Dfunction_prototype);
        this.text_d1 = text_d1;
        this.newD0 = newD0;
    }

    override void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.11.7.2
        Value* m;
        Dobject o;
        d_string s;

        m = (arglist.length) ? &arglist[0] : &vundefined;
        // ECMA doesn't say what we do if m is undefined
        if(m.isUndefined())
            s = text_d1;
        else
            s = m.toString();
        o = (*newD0)(s);
        ret.putVobject(o);
        return null;
    }

    override void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
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
        this()
        {
            super(Derror_prototype);

            d_string s;

            Put(TEXT_constructor, ctorTable[TEXT_D1], DontEnum);
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

        this(d_string m)
        {
            this(D0.getPrototype());
            Put(TEXT_message, m, 0);
            Put(TEXT_description, m, 0);
            Put(TEXT_number, cast(d_number)0, 0);
            errinfo.message = m;
        }

        this(ErrInfo * perrinfo)
        {
            this(perrinfo.message);
            errinfo = *perrinfo;
            Put(TEXT_number, cast(d_number)perrinfo.code, 0);
        }

        override void getErrInfo(ErrInfo *perrinfo, int linnum)
        {
            if(linnum && errinfo.linnum == 0)
                errinfo.linnum = linnum;
            if(perrinfo)
                *perrinfo = errinfo;
            //writefln("getErrInfo(linnum = %d), errinfo.linnum = %d", linnum, errinfo.linnum);
        }

        static Dfunction getConstructor()
        {
            return ctorTable[TEXT_D1];
        }

        static Dobject getPrototype()
        {
            return protoTable[TEXT_D1];
        }

        static Dobject newD0(d_string s)
        {
            return new D0(s);
        }

        static void init()
        {
            Dfunction constructor = new D0_constructor(TEXT_D1, &newD0);
            ctorTable[TEXT_D1] = constructor;

            Dobject prototype = new D0_prototype();
            protoTable[TEXT_D1] = prototype;

            constructor.Put(TEXT_prototype, prototype, DontEnum | DontDelete | ReadOnly);
        }
    }
}

alias proto!(TEXT_SyntaxError) syntaxerror;
alias proto!(TEXT_EvalError) evalerror;
alias proto!(TEXT_ReferenceError) referenceerror;
alias proto!(TEXT_RangeError) rangeerror;
alias proto!(TEXT_TypeError) typeerror;
alias proto!(TEXT_URIError) urierror;

/**********************************
 * Register initializer for each class.
 */

static this()
{
    threadInitTable ~= &syntaxerror.D0.init;
    threadInitTable ~= &evalerror.D0.init;
    threadInitTable ~= &referenceerror.D0.init;
    threadInitTable ~= &rangeerror.D0.init;
    threadInitTable ~= &typeerror.D0.init;
    threadInitTable ~= &urierror.D0.init;
}
