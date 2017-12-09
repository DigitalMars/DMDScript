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
    Dobject function(CallContext* cc, d_string) newD0;

    this(CallContext* cc, d_string text_d1, Dobject function(CallContext* cc, d_string) newD0)
    {
        super(cc, 1, cc.tc.Dfunction_prototype);
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
            s = m.toString(cc);
        o = (*newD0)(cc, s);
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
        this(CallContext* cc)
        {
            super(cc, cc.tc.Derror_prototype);

            d_string s;

            Put(cc, TEXT_constructor, cc.tc.ctorTable[TEXT_D1], DontEnum);
            Put(cc, TEXT_name, TEXT_D1, 0);
            s = TEXT_D1 ~ ".prototype.message";
            Put(cc, TEXT_message, s, 0);
            Put(cc, TEXT_description, s, 0);
            Put(cc, TEXT_number, cast(d_number)0, 0);
        }
    }

    /* ===================== D0 ==================== */

    class D0 : Dobject
    {
        ErrInfo errinfo;

        this(CallContext* cc, Dobject prototype)
        {
            super(cc, prototype);
            classname = TEXT_Error;
        }

        this(CallContext* cc, d_string m)
        {
            this(cc, D0.getPrototype(cc));
            Put(cc, TEXT_message, m, 0);
            Put(cc, TEXT_description, m, 0);
            Put(cc, TEXT_number, cast(d_number)0, 0);
            errinfo.message = m;
        }

        this(CallContext* cc, ErrInfo * perrinfo)
        {
            this(cc, perrinfo.message);
            errinfo = *perrinfo;
            Put(cc, TEXT_number, cast(d_number)perrinfo.code, 0);
        }

        override void getErrInfo(CallContext* cc, ErrInfo *perrinfo, int linnum)
        {
            if(linnum && errinfo.linnum == 0)
                errinfo.linnum = linnum;
            if(perrinfo)
                *perrinfo = errinfo;
            //writefln("getErrInfo(linnum = %d), errinfo.linnum = %d", linnum, errinfo.linnum);
        }

        static Dfunction getConstructor(CallContext* cc)
        {
            return cc.tc.ctorTable[TEXT_D1];
        }

        static Dobject getPrototype(CallContext* cc)
        {
            return cc.tc.protoTable[TEXT_D1];
        }

        static Dobject newD0(CallContext* cc, d_string s)
        {
            return new D0(cc, s);
        }

        static void init(CallContext* cc)
        {
            Dfunction constructor = new D0_constructor(cc, TEXT_D1, &newD0);
            cc.tc.ctorTable[TEXT_D1] = constructor;

            Dobject prototype = new D0_prototype(cc);
            cc.tc.protoTable[TEXT_D1] = prototype;

            constructor.Put(cc, TEXT_prototype, prototype, DontEnum | DontDelete | ReadOnly);
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

void initErrors(CallContext* cc)
{
    cc.tc.threadInitTable ~= &syntaxerror.D0.init;
    cc.tc.threadInitTable ~= &evalerror.D0.init;
    cc.tc.threadInitTable ~= &referenceerror.D0.init;
    cc.tc.threadInitTable ~= &rangeerror.D0.init;
    cc.tc.threadInitTable ~= &typeerror.D0.init;
    cc.tc.threadInitTable ~= &urierror.D0.init;
}
