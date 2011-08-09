
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


module dmdscript.dfunction;

import std.string;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;

/* ===================== Dfunction_constructor ==================== */

class Dfunction_constructor : Dfunction
{
    this(ThreadContext *tc)
    {
        super(1, tc.Dfunction_prototype);

        // Actually put in later by Dfunction::init()
        //unsigned attributes = DontEnum | DontDelete | ReadOnly;
        //Put(TEXT_prototype, Dfunction::getPrototype(), attributes);
    }

    void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.3.2.1
        d_string bdy;
        d_string P;
        FunctionDefinition fd;
        ErrInfo errinfo;

        //writef("Dfunction_constructor::Construct()\n");

        // Get parameter list (P) and body from arglist[]
        if (arglist.length)
        {
            bdy = arglist[arglist.length - 1].toString();
            if (arglist.length >= 2)
            {
                for (uint a = 0; a < arglist.length - 1; a++)
                {
                    if (a)
                        P ~= ',';
                    P ~= arglist[a].toString();
                }
            }
        }

        if (Parser.parseFunctionDefinition(fd, P, bdy, errinfo))
            goto Lsyntaxerror;

        if (fd)
        {
            Scope sc;

            sc.ctor(fd);
            fd.semantic(&sc);
            errinfo = sc.errinfo;
            if (errinfo.message)
                goto Lsyntaxerror;
            fd.toIR(null);
            ret.putVobject(fd.fobject);
        }
        else
            ret.putVundefined();

        return null;

    Lsyntaxerror:
        Dobject o;

        ret.putVundefined();
        o = new syntaxerror.D0(&errinfo);
        Value* v = new Value;
        v.putVobject(o);
        return v;
    }

    void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.3.1
        return Construct(cc, ret, arglist);
    }
}


/* ===================== Dfunction_prototype_toString =============== */

void* Dfunction_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    d_string s;
    Dfunction f;

    //writef("function.prototype.toString()\n");
    // othis must be a Function
    if (!othis.isClass(TEXT_Function))
    {   ErrInfo errinfo;
        ret.putVundefined();
        return Dobject.RuntimeError(&errinfo, ERR_TS_NOT_TRANSFERRABLE);
    }
    else
    {
        // Generate string that looks like a FunctionDeclaration
        // FunctionDeclaration:
        //      function Identifier (Identifier, ...) Block

        // If anonymous function, the name should be "anonymous"
        // per ECMA 15.3.2.1.19

        f = cast(Dfunction)othis;
        s = f.toString();
        ret.putVstring(s);
    }
    return null;
}

/* ===================== Dfunction_prototype_apply =============== */

void* Dfunction_prototype_apply(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.3.4.3

    Value* thisArg;
    Value* argArray;
    Dobject o;
    void* v;

    thisArg = &vundefined;
    argArray = &vundefined;
    switch (arglist.length)
    {
        case 0:
            break;
        default:
            argArray = &arglist[1];
        case 1:
            thisArg = &arglist[0];
            break;
    }

    if (thisArg.isUndefinedOrNull())
        o = cc.global;
    else
        o = thisArg.toObject();

    if (argArray.isUndefinedOrNull())
    {
        v = othis.Call(cc, o, ret, null);
    }
    else
    {
        if (argArray.isPrimitive())
        {
          Ltypeerror:
            ret.putVundefined();
            ErrInfo errinfo;
            return Dobject.RuntimeError(&errinfo, ERR_ARRAY_ARGS);
        }
        Dobject a;

        a = argArray.toObject();

        // Must be array or arguments object
        if (!a.isDarray() && !a.isDarguments())
            goto Ltypeerror;

        uint len;
        uint i;
        Value[] alist;
        Value* x;

        x = a.Get(TEXT_length);
        len = x ? x.toUint32() : 0;

        Value[] p1;
        Value* v1;
        if (len < 128)
            v1 = cast(Value*)alloca(len * Value.sizeof);
        if (v1)
            alist = v1[0 .. len];
        else
        {   p1 = new Value[len];
            alist = p1;
        }

        for (i = 0; i < len; i++)
        {
            x = a.Get(i);
            Value.copy(&alist[i], x);
        }

        v = othis.Call(cc, o, ret, alist);

        delete p1;
    }
    return v;
}

/* ===================== Dfunction_prototype_call =============== */

void* Dfunction_prototype_call(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.3.4.4
    Value* thisArg;
    Dobject o;
    void* v;

    if (arglist.length == 0)
    {
        o = cc.global;
        v = othis.Call(cc, o, ret, arglist);
    }
    else
    {
        thisArg = &arglist[0];
        if (thisArg.isUndefinedOrNull())
            o = cc.global;
        else
            o = thisArg.toObject();
        v = othis.Call(cc, o, ret, arglist[1 .. length]);
    }
    return v;
}

/* ===================== Dfunction_prototype ==================== */

class Dfunction_prototype : Dfunction
{
    this(ThreadContext *tc)
    {
        super(0, tc.Dobject_prototype);

        uint attributes = DontEnum;

        classname = TEXT_Function;
        name = "prototype";
        Put(TEXT_constructor, tc.Dfunction_constructor, attributes);

        static NativeFunctionData nfd[] =
        [
            {   &TEXT_toString, &Dfunction_prototype_toString, 0 },
            {   &TEXT_apply, &Dfunction_prototype_apply, 2 },
            {   &TEXT_call, &Dfunction_prototype_call, 1 },
        ];

        DnativeFunction.init(this, nfd, attributes);
    }

    void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA v3 15.3.4
        // Accept any arguments and return "undefined"
        ret.putVundefined();
        return null;
    }
}


/* ===================== Dfunction ==================== */

class Dfunction : Dobject
{   tchar[] name;

    this(d_uint32 length)
    {
        this(length, Dfunction.getPrototype());
    }

    this(d_uint32 length, Dobject prototype)
    {
        super(prototype);
        classname = TEXT_Function;
        name = TEXT_Function;
        Put(TEXT_length, length, DontDelete | DontEnum | ReadOnly);
        Put(TEXT_arity, length, DontDelete | DontEnum | ReadOnly);
    }

    d_string getTypeof()
    {   // ECMA 11.4.3
        return TEXT_function;
    }

    d_string toString()
    {
        // Native overrides of this function replace Identifier with the actual name.
        // Don't need to do parameter list, though.
        d_string s;

        s = std.string.format("function %s() { [native code] }", name);
        return s;
    }

    void *HasInstance(Value* ret, Value* v)
    {
        // ECMA v3 15.3.5.3
        Dobject V;
        Value* w;
        Dobject o;

        if (v.isPrimitive())
            goto Lfalse;
        V = v.toObject();
        w = Get(TEXT_prototype);
        if (w.isPrimitive())
        {   ErrInfo errinfo;
            return RuntimeError(&errinfo, errmsgtbl[ERR_MUST_BE_OBJECT], w.getType());
        }
        o = w.toObject();
        for (;;)
        {
            V = V.internal_prototype;
            if (!V)
                goto Lfalse;
            if (o == V)
                goto Ltrue;
        }

    Ltrue:
        ret.putVboolean(true);
        return null;

    Lfalse:
        ret.putVboolean(false);
        return null;
    }

    static Dfunction isFunction(Value* v)
    {
        Dfunction r;
        Dobject o;

        r = null;
        if (!v.isPrimitive())
        {
            o = v.toObject();
            if (o.isClass(TEXT_Function))
                r = cast(Dfunction)o;
        }
        return r;
    }


    static Dfunction getConstructor()
    {
        ThreadContext *tc = ThreadContext.getThreadContext();
        assert(tc);
        return tc.Dfunction_constructor;
    }

    static Dobject getPrototype()
    {
        ThreadContext *tc = ThreadContext.getThreadContext();
        assert(tc);
        return tc.Dfunction_prototype;
    }

    static void init(ThreadContext *tc)
    {
        tc.Dfunction_constructor = new Dfunction_constructor(tc);
        tc.Dfunction_prototype = new Dfunction_prototype(tc);

        tc.Dfunction_constructor.Put(TEXT_prototype, tc.Dfunction_prototype, DontEnum | DontDelete | ReadOnly);

        tc.Dfunction_constructor.internal_prototype = tc.Dfunction_prototype;
        tc.Dfunction_constructor.proptable.previous = tc.Dfunction_prototype.proptable;
    }
}
