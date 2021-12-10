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

module dmdscript.dboolean;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;

/* ===================== Dboolean_constructor ==================== */

class DbooleanConstructor : Dfunction
{
    this(CallContext* cc)
    {
        super(cc, 1, cc.tc.Dfunction_prototype);
        name = "Boolean";
    }

    override void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.6.2
        d_boolean b;
        Dobject o;

        b = (arglist.length) ? arglist[0].toBoolean(cc) : false;
        o = new Dboolean(cc, b);
        ret.putVobject(o);
        return null;
    }

    override void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.6.1
        d_boolean b;

        b = (arglist.length) ? arglist[0].toBoolean(cc) : false;
        ret.putVboolean(b);
        return null;
    }
}


/* ===================== Dboolean_prototype_toString =============== */

void* Dboolean_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // othis must be a Boolean
    if(!othis.isClass(TEXT_Boolean))
    {
        ErrInfo errinfo;

        ret.putVundefined();
        return Dobject.RuntimeError(&errinfo, cc, errmsgtbl[ERR_FUNCTION_WANTS_BOOL],
                                    TEXT_toString,
                                    othis.classname);
    }
    else
    {
        Value *v;

        v = &(cast(Dboolean)othis).value;
        ret.putVstring(v.toString(cc));
    }
    return null;
}

/* ===================== Dboolean_prototype_valueOf =============== */

void* Dboolean_prototype_valueOf(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    //FuncLog f("Boolean.prototype.valueOf()");
    //logflag = 1;

    // othis must be a Boolean
    if(!othis.isClass(TEXT_Boolean))
    {
        ErrInfo errinfo;

        ret.putVundefined();
        return Dobject.RuntimeError(&errinfo, cc, errmsgtbl[ERR_FUNCTION_WANTS_BOOL],
                                    TEXT_valueOf,
                                    othis.classname);
    }
    else
    {
        Value *v;

        v = &(cast(Dboolean)othis).value;
        Value.copy(ret, v);
    }
    return null;
}

/* ===================== Dboolean_prototype ==================== */

class DbooleanPrototype : Dboolean
{
    this(CallContext* cc)
    {
        super(cc, cc.tc.Dobject_prototype);
        //Dobject f = Dfunction_prototype;

        Put(cc, TEXT_constructor, cc.tc.Dboolean_constructor, DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_toString, &Dboolean_prototype_toString, 0 },
            { TEXT_valueOf, &Dboolean_prototype_valueOf, 0 },
        ];

        DnativeFunction.initialize(this, cc, nfd, DontEnum);
    }
}


/* ===================== Dboolean ==================== */

class Dboolean : Dobject
{
    this(CallContext* cc, d_boolean b)
    {
        super(cc, Dboolean.getPrototype(cc));
        value.putVboolean(b);
        classname = TEXT_Boolean;
    }

    this(CallContext* cc, Dobject prototype)
    {
        super(cc, prototype);
        value.putVboolean(false);
        classname = TEXT_Boolean;
    }

    static Dfunction getConstructor(CallContext* cc)
    {
        return cc.tc.Dboolean_constructor;
    }

    static Dobject getPrototype(CallContext* cc)
    {
        return cc.tc.Dboolean_prototype;
    }

    static void initialize(CallContext* cc)
    {
        cc.tc.Dboolean_constructor = new DbooleanConstructor(cc);
        cc.tc.Dboolean_prototype = new DbooleanPrototype(cc);

        cc.tc.Dboolean_constructor.Put(cc, TEXT_prototype, cc.tc.Dboolean_prototype, DontEnum | DontDelete | ReadOnly);
    }
}

