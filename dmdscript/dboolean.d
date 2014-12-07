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
    this()
    {
        super(1, Dfunction_prototype);
        name = "Boolean";
    }

    void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.6.2
        d_boolean b;
        Dobject o;

        b = (arglist.length) ? arglist[0].toBoolean() : false;
        o = new Dboolean(b);
        ret.putVobject(o);
        return null;
    }

    void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.6.1
        d_boolean b;

        b = (arglist.length) ? arglist[0].toBoolean() : false;
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
        return Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_FUNCTION_WANTS_BOOL],
                                    TEXT_toString,
                                    othis.classname);
    }
    else
    {
        Value *v;

        v = &(cast(Dboolean)othis).value;
        ret.putVstring(v.toString());
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
        return Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_FUNCTION_WANTS_BOOL],
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
    this()
    {
        super(Dobject_prototype);
        //Dobject f = Dfunction_prototype;

        Put(TEXT_constructor, Dboolean_constructor, DontEnum);

        static enum NativeFunctionData nfd[] =
        [
            { TEXT_toString, &Dboolean_prototype_toString, 0 },
            { TEXT_valueOf, &Dboolean_prototype_valueOf, 0 },
        ];

        DnativeFunction.initialize(this, nfd, DontEnum);
    }
}


/* ===================== Dboolean ==================== */

class Dboolean : Dobject
{
    this(d_boolean b)
    {
        super(Dboolean.getPrototype());
        value.putVboolean(b);
        classname = TEXT_Boolean;
    }

    this(Dobject prototype)
    {
        super(prototype);
        value.putVboolean(false);
        classname = TEXT_Boolean;
    }

    static Dfunction getConstructor()
    {
        return Dboolean_constructor;
    }

    static Dobject getPrototype()
    {
        return Dboolean_prototype;
    }

    static void initialize()
    {
        Dboolean_constructor = new DbooleanConstructor();
        Dboolean_prototype = new DbooleanPrototype();

        Dboolean_constructor.Put(TEXT_prototype, Dboolean_prototype, DontEnum | DontDelete | ReadOnly);
    }
}

