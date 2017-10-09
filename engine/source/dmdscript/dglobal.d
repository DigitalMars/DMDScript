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

module dmdscript.dglobal;

import std.uri;
import core.stdc.stdlib;
import core.stdc.string;
import std.stdio;
import std.algorithm;
import std.math;
import std.exception;

import dmdscript.script;
import dmdscript.protoerror;
import dmdscript.parse;
import dmdscript.text;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.statement;
import dmdscript.threadcontext;
import dmdscript.functiondefinition;
import dmdscript.scopex;
import dmdscript.opcodes;
import dmdscript.property;

import dmdscript.dstring;
import dmdscript.darray;
import dmdscript.dregexp;
import dmdscript.dnumber;
import dmdscript.dboolean;
import dmdscript.dfunction;
import dmdscript.dnative;

immutable(char)[] arg0string(Value[] arglist, CallContext* cc)
{
    Value* v = arglist.length ? &arglist[0] : &vundefined;
    return v.toString(cc);
}

/* ====================== Dglobal_eval ================ */

void* Dglobal_eval(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.1.2.1
    Value* v;
    immutable(char)[] s;
    FunctionDefinition fd;
    ErrInfo errinfo;
    void *result;

    //FuncLog funclog(L"Global.eval()");

    v = arglist.length ? &arglist[0] : &vundefined;
    if(v.getType() != TypeString)
    {
        Value.copy(ret, v);
        return null;
    }
    s = v.toString(cc);
    //writef("eval('%ls')\n", s);

    // Parse program
    TopStatement[] topstatements;
    Parser p = new Parser("eval", s, 0);
    if(p.parseProgram(topstatements, &errinfo))
        goto Lsyntaxerror;

    // Analyze, generate code
    fd = new FunctionDefinition(topstatements);
    fd.iseval = 1;
    {
        Scope sc;
        sc.ctor(fd);
        sc.src = s;
        fd.semantic(&sc);
        errinfo = sc.errinfo;
        sc.dtor();
    }
    if(errinfo.message)
        goto Lsyntaxerror;
    fd.toIR(null);

    // Execute code
    Value[] locals;
    Value[] p1 = null;

    Value* v1 = null;
    static immutable ntry = 0;

    if(fd.nlocals < 128)
        v1 = cast(Value*)alloca(fd.nlocals * Value.sizeof);
    if(v1)
        locals = v1[0 .. fd.nlocals];
    else
    {
        p1 = new Value[fd.nlocals];
        locals = p1;
    }

   
    version(none)
    {
        Array scopex;
        scopex.reserve(cc.scoperoot + fd.withdepth + 2);
        for(uint u = 0; u < cc.scoperoot; u++)
            scopex.push(cc.scopex.data[u]);

        Array *scopesave = cc.scopex;
        cc.scopex = &scopex;
        Dobject variablesave = cc.variable;
        cc.variable = cc.global;

        fd.instantiate(cc.variable, 0);

        // The this value is the same as the this value of the
        // calling context.
        result = IR.call(cc, othis, fd.code, ret, locals);

        delete p1;
        cc.variable = variablesave;
        cc.scopex = scopesave;
        return result;
    }
    else
    {
        
        // The scope chain is initialized to contain the same objects,
        // in the same order, as the calling context's scope chain.
        // This includes objects added to the calling context's
        // scope chain by WithStatement.
//    cc.scopex.reserve(fd.withdepth);

        // Variable instantiation is performed using the calling
        // context's variable object and using empty
        // property attributes
        fd.instantiate(cc, cc.scopex, cc.variable, 0);

        // The this value is the same as the this value of the
        // calling context.
        assert(cc.callerothis);
        result = IR.call(cc, cc.callerothis, fd.code, ret, locals.ptr);
        if(p1)
            delete p1;
        fd = null;
        // if (result) writef("result = '%s'\n", (cast(Value* )result).toString());
        return result;
    }

Lsyntaxerror:
    Dobject o;

    // For eval()'s, use location of caller, not the string
    errinfo.linnum = 0;

    ret.putVundefined();
    o = new syntaxerror.D0(cc, &errinfo);
    Value* v2 = new Value;
    v2.putVobject(o);
    return v2;
}

/* ====================== Dglobal_parseInt ================ */

void* Dglobal_parseInt(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    static import std.utf;

    // ECMA 15.1.2.2
    Value* v2;
    immutable(char) * s;
    immutable(char) * z;
    d_int32 radix;
    int sign = 1;
    d_number number;
    size_t i;
    d_string string;

    string = arg0string(arglist, cc);

    //writefln("Dglobal_parseInt('%s')", string);

    while(i < string.length)
    {
        size_t idx = i;
        dchar c = std.utf.decode(string, idx);
        if(!isStrWhiteSpaceChar(c))
            break;
        i = idx;
    }
    s = string.ptr + i;
    i = string.length - i;

    if(i)
    {
        if(*s == '-')
        {
            sign = -1;
            s++;
            i--;
        }
        else if(*s == '+')
        {
            s++;
            i--;
        }
    }

    radix = 0;
    if(arglist.length >= 2)
    {
        v2 = &arglist[1];
        radix = v2.toInt32(cc);
    }

    if(radix)
    {
        if(radix < 2 || radix > 36)
        {
            number = d_number.nan;
            goto Lret;
        }
        if(radix == 16 && i >= 2 && *s == '0' &&
           (s[1] == 'x' || s[1] == 'X'))
        {
            s += 2;
            i -= 2;
        }
    }
    else if(i >= 1 && *s != '0')
    {
        radix = 10;
    }
    else if(i >= 2 && (s[1] == 'x' || s[1] == 'X'))
    {
        radix = 16;
        s += 2;
        i -= 2;
    }
    else
        radix = 8;

    number = 0;
    for(z = s; i; z++, i--)
    {
        d_int32 n;
        tchar c;

        c = *z;
        if('0' <= c && c <= '9')
            n = c - '0';
        else if('A' <= c && c <= 'Z')
            n = c - 'A' + 10;
        else if('a' <= c && c <= 'z')
            n = c - 'a' + 10;
        else
            break;
        if(radix <= n)
            break;
        number = number * radix + n;
    }
    if(z == s)
    {
        number = d_number.nan;
        goto Lret;
    }
    if(sign < 0)
        number = -number;

    version(none)     // ECMA says to silently ignore trailing characters
    {
        while(z - &string[0] < string.length)
        {
            if(!isStrWhiteSpaceChar(*z))
            {
                number = d_number.nan;
                goto Lret;
            }
            z++;
        }
    }

    Lret:
    ret.putVnumber(number);
    return null;
}

/* ====================== Dglobal_parseFloat ================ */

void* Dglobal_parseFloat(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.1.2.3
    d_number n;
    size_t endidx;

    d_string string = arg0string(arglist, cc);
    n = StringNumericLiteral(string, endidx, 1);

    ret.putVnumber(n);
    return null;
}

/* ====================== Dglobal_escape ================ */

int ISURIALNUM(dchar c)
{
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9');
}

immutable tchar[16 + 1] TOHEX = "0123456789ABCDEF";

void* Dglobal_escape(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    import std.string : indexOf;

    // ECMA 15.1.2.4
    d_string s;
    uint escapes;
    uint unicodes;
    size_t slen;

    s = arg0string(arglist, cc);
    escapes = 0;
    unicodes = 0;
    foreach(dchar c; s)
    {
        slen++;
        if(c >= 0x100)
            unicodes++;
        else
        if(c == 0 || c >= 0x80 || (!ISURIALNUM(c) && indexOf("*@-_+./", c) == -1))
            escapes++;
    }
    if((escapes + unicodes) == 0)
    {
        ret.putVstring(assumeUnique(s));
        return null;
    }
    else
    {
        //writefln("s.length = %d, escapes = %d, unicodes = %d", s.length, escapes, unicodes);
        char[] R = new char[slen + escapes * 2 + unicodes * 5];
        char* r = R.ptr;
        foreach(dchar c; s)
        {
            if(c >= 0x100)
            {
                r[0] = '%';
                r[1] = 'u';
                r[2] = TOHEX[(c >> 12) & 15];
                r[3] = TOHEX[(c >> 8) & 15];
                r[4] = TOHEX[(c >> 4) & 15];
                r[5] = TOHEX[c & 15];
                r += 6;
            }
            else if(c == 0 || c >= 0x80 || (!ISURIALNUM(c) && indexOf("*@-_+./", c) == -1))
            {
                r[0] = '%';
                r[1] = TOHEX[c >> 4];
                r[2] = TOHEX[c & 15];
                r += 3;
            }
            else
            {
                r[0] = cast(tchar)c;
                r++;
            }
        }
        assert(r - R.ptr == R.length);
        ret.putVstring(assumeUnique(R));
        return null;
    }
}

/* ====================== Dglobal_unescape ================ */

void* Dglobal_unescape(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    static import dmdscript.utf;

    // ECMA 15.1.2.5
    d_string s;
    d_string R;

    s = arg0string(arglist, cc);
    //writefln("Dglobal.unescape(s = '%s')", s);
    for(size_t k = 0; k < s.length; k++)
    {
        tchar c = s[k];

        if(c == '%')
        {
            if(k + 6 <= s.length && s[k + 1] == 'u')
            {
                uint u;

                u = 0;
                for(int i = 2;; i++)
                {
                    uint x;

                    if(i == 6)
                    {
                        dmdscript.utf.encode(R, cast(dchar)u);
                        k += 5;
                        goto L1;
                    }
                    x = s[k + i];
                    if('0' <= x && x <= '9')
                        x = x - '0';
                    else if('A' <= x && x <= 'F')
                        x = x - 'A' + 10;
                    else if('a' <= x && x <= 'f')
                        x = x - 'a' + 10;
                    else
                        break;
                    u = (u << 4) + x;
                }
            }
            else if(k + 3 <= s.length)
            {
                uint u;

                u = 0;
                for(int i = 1;; i++)
                {
                    uint x;

                    if(i == 3)
                    {
                        dmdscript.utf.encode(R, cast(dchar)u);
                        k += 2;
                        goto L1;
                    }
                    x = s[k + i];
                    if('0' <= x && x <= '9')
                        x = x - '0';
                    else if('A' <= x && x <= 'F')
                        x = x - 'A' + 10;
                    else if('a' <= x && x <= 'f')
                        x = x - 'a' + 10;
                    else
                        break;
                    u = (u << 4) + x;
                }
            }
        }
        R ~= c;
        L1:
        ;
    }

    ret.putVstring(R);
    return null;
}

/* ====================== Dglobal_isNaN ================ */

void* Dglobal_isNaN(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.1.2.6
    Value* v;
    d_number n;
    d_boolean b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &vundefined;
    n = v.toNumber(cc);
    b = isNaN(n) ? true : false;
    ret.putVboolean(b);
    return null;
}

/* ====================== Dglobal_isFinite ================ */

void* Dglobal_isFinite(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.1.2.7
    Value* v;
    d_number n;
    d_boolean b;

    if(arglist.length)
        v = &arglist[0];
    else
        v = &vundefined;
    n = v.toNumber(cc);
    b = isFinite(n) ? true : false;
    ret.putVboolean(b);
    return null;
}

/* ====================== Dglobal_ URI Functions ================ */

void* URI_error(d_string s, CallContext* cc)
{
    Dobject o = new urierror.D0(cc, s ~ "() failure");
    Value* v = new Value;
    v.putVobject(o);
    return v;
}

void* Dglobal_decodeURI(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.1.3.1
    d_string s;

    s = arg0string(arglist, cc);
    try
    {
        s = std.uri.decode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(TEXT_decodeURI, cc);
    }
    ret.putVstring(s);
    return null;
}

void* Dglobal_decodeURIComponent(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.1.3.2
    d_string s;

    s = arg0string(arglist, cc);
    try
    {
        s = std.uri.decodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(TEXT_decodeURIComponent, cc);
    }
    ret.putVstring(s);
    return null;
}

void* Dglobal_encodeURI(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.1.3.3
    d_string s;

    s = arg0string(arglist, cc);
    try
    {
        s = std.uri.encode(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(TEXT_encodeURI, cc);
    }
    ret.putVstring(s);
    return null;
}

void* Dglobal_encodeURIComponent(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.1.3.4
    d_string s;

    s = arg0string(arglist, cc);
    try
    {
        s = std.uri.encodeComponent(s);
    }
    catch(URIException u)
    {
        ret.putVundefined();
        return URI_error(TEXT_encodeURIComponent, cc);
    }
    ret.putVstring(s);
    return null;
}

/* ====================== Dglobal_print ================ */

static void dglobal_print(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // Our own extension
    if(arglist.length)
    {
        uint i;

        for(i = 0; i < arglist.length; i++)
        {
            d_string s = arglist[i].toString(cc);

            writef("%s", s);
        }
    }

    ret.putVundefined();
}

void* Dglobal_print(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    return null;
}

/* ====================== Dglobal_println ================ */

void* Dglobal_println(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // Our own extension
    dglobal_print(cc, othis, ret, arglist);
    writef("\n");
    return null;
}

/* ====================== Dglobal_readln ================ */

void* Dglobal_readln(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    static import dmdscript.utf;

    // Our own extension
    dchar c;
    d_string s;

    for(;; )
    {
        version(linux)
        {
            c = core.stdc.stdio.getchar();
            if(c == EOF)
                break;
        }
        else version(Windows)
        {
            c = core.stdc.stdio.getchar();
            if(c == EOF)
                break;
        }
        else version(OSX)
        {
            c = core.stdc.stdio.getchar();
            if(c == EOF)
                break;
        }
        else version(FreeBSD)
        {
            c = core.stdc.stdio.getchar();
            if(c == EOF)
                break;
        }
        else
        {
            static assert(0);
        }
        if(c == '\n')
            break;
        dmdscript.utf.encode(s, c);
    }
    ret.putVstring(s);
    return null;
}

/* ====================== Dglobal_getenv ================ */

void* Dglobal_getenv(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    import std.string : toStringz;

    // Our own extension
    ret.putVundefined();
    if(arglist.length)
    {
        d_string s = arglist[0].toString(cc);
        char* p = getenv(toStringz(s));
        if(p)
            ret.putVstring(p[0 .. strlen(p)].idup);
        else
            ret.putVnull();
    }
    return null;
}


/* ====================== Dglobal_ScriptEngine ================ */

void* Dglobal_ScriptEngine(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    ret.putVstring(TEXT_DMDScript);
    return null;
}

void* Dglobal_ScriptEngineBuildVersion(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    ret.putVnumber(BUILD_VERSION);
    return null;
}

void* Dglobal_ScriptEngineMajorVersion(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    ret.putVnumber(MAJOR_VERSION);
    return null;
}

void* Dglobal_ScriptEngineMinorVersion(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    ret.putVnumber(MINOR_VERSION);
    return null;
}

/* ====================== Dglobal =========================== */

class Dglobal : Dobject
{
    this(CallContext* cc, tchar[][] argv)
    {
        super(cc, Dobject.getPrototype(cc));  // Dglobal.prototype is implementation-dependent

        //writef("Dglobal.Dglobal(%x)\n", this);

        Dobject f = Dfunction.getPrototype(cc);

        classname = TEXT_global;

        // ECMA 15.1
        // Add in built-in objects which have attribute { DontEnum }

        // Value properties

        Put(cc, TEXT_NaN, d_number.nan, DontEnum | DontDelete);
        Put(cc, TEXT_Infinity, d_number.infinity, DontEnum| DontDelete);
		Put(cc, TEXT_undefined, &vundefined, DontEnum| DontDelete);
        static enum NativeFunctionData[] nfd =
        [
            // Function properties
            { TEXT_eval, &Dglobal_eval, 1 },
            { TEXT_parseInt, &Dglobal_parseInt, 2 },
            { TEXT_parseFloat, &Dglobal_parseFloat, 1 },
            { TEXT_escape, &Dglobal_escape, 1 },
            { TEXT_unescape, &Dglobal_unescape, 1 },
            { TEXT_isNaN, &Dglobal_isNaN, 1 },
            { TEXT_isFinite, &Dglobal_isFinite, 1 },
            { TEXT_decodeURI, &Dglobal_decodeURI, 1 },
            { TEXT_decodeURIComponent, &Dglobal_decodeURIComponent, 1 },
            { TEXT_encodeURI, &Dglobal_encodeURI, 1 },
            { TEXT_encodeURIComponent, &Dglobal_encodeURIComponent, 1 },

            // Dscript unique function properties
            { TEXT_print, &Dglobal_print, 1 },
            { TEXT_println, &Dglobal_println, 1 },
            { TEXT_readln, &Dglobal_readln, 0 },
            { TEXT_getenv, &Dglobal_getenv, 1 },

            // Jscript compatible extensions
            { TEXT_ScriptEngine, &Dglobal_ScriptEngine, 0 },
            { TEXT_ScriptEngineBuildVersion, &Dglobal_ScriptEngineBuildVersion, 0 },
            { TEXT_ScriptEngineMajorVersion, &Dglobal_ScriptEngineMajorVersion, 0 },
            { TEXT_ScriptEngineMinorVersion, &Dglobal_ScriptEngineMinorVersion, 0 },
        ];

        DnativeFunction.initialize(this, cc, nfd, DontEnum);

        // Now handled by AssertExp()
        // Put(TEXT_assert, Dglobal_assert(), DontEnum);

        // Constructor properties

        Put(cc, TEXT_Object, cc.tc.Dobject_constructor, DontEnum);
        Put(cc, TEXT_Function, cc.tc.Dfunction_constructor, DontEnum);
        Put(cc, TEXT_Array, cc.tc.Darray_constructor, DontEnum);
        Put(cc, TEXT_String, cc.tc.Dstring_constructor, DontEnum);
        Put(cc, TEXT_Boolean, cc.tc.Dboolean_constructor, DontEnum);
        Put(cc, TEXT_Number, cc.tc.Dnumber_constructor, DontEnum);
        Put(cc, TEXT_Date, cc.tc.Ddate_constructor, DontEnum);
        Put(cc, TEXT_RegExp, cc.tc.Dregexp_constructor, DontEnum);
        Put(cc, TEXT_Error, cc.tc.Derror_constructor, DontEnum);

        foreach(d_string key, Dfunction ctor; cc.tc.ctorTable)
        {
            Put(cc, key, ctor, DontEnum);
        }

        // Other properties

        assert(cc.tc.Dmath_object);
        Put(cc, TEXT_Math, cc.tc.Dmath_object, DontEnum);

        // Build an "arguments" property out of argv[],
        // and add it to the global object.
        Darray arguments;

        arguments = new Darray(cc);
        Put(cc, TEXT_arguments, arguments, DontDelete);
        arguments.length.putVnumber(argv.length);
        for(int i = 0; i < argv.length; i++)
        {
            arguments.Put(cc, i, argv[i].idup, DontEnum);
        }
        arguments.Put(cc, TEXT_callee, &vnull, DontEnum);
    }
}
