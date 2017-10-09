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


module dmdscript.dregexp;

private import undead.regexp;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.text;
import dmdscript.darray;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;

//alias script.tchar tchar;

// Values for Dregexp.exec.rettype
enum { EXEC_STRING, EXEC_ARRAY, EXEC_BOOLEAN, EXEC_INDEX };


/* ===================== Dregexp_constructor ==================== */

class DregexpConstructor : Dfunction
{
    Value* input;
    Value* multiline;
    Value* lastMatch;
    Value* lastParen;
    Value* leftContext;
    Value* rightContext;
    Value*[10] dollar;

    // Extensions
    Value* index;
    Value* lastIndex;

    this(CallContext* cc)
    {
        super(cc, 2, cc.tc.Dfunction_prototype);

        Value v;
        v.putVstring(null);

        Value vb;
        vb.putVboolean(false);

        Value vnm1;
        vnm1.putVnumber(-1);

        name = "RegExp";

        // Static properties
        Put(cc, TEXT_input, &v, DontDelete);
        Put(cc, TEXT_multiline, &vb, DontDelete);
        Put(cc, TEXT_lastMatch, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_lastParen, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_leftContext, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_rightContext, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar1, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar2, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar3, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar4, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar5, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar6, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar7, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar8, &v, ReadOnly | DontDelete);
        Put(cc, TEXT_dollar9, &v, ReadOnly | DontDelete);

        Put(cc, TEXT_index, &vnm1, ReadOnly | DontDelete);
        Put(cc, TEXT_lastIndex, &vnm1, ReadOnly | DontDelete);

        input = Get(TEXT_input);
        multiline = Get(TEXT_multiline);
        lastMatch = Get(TEXT_lastMatch);
        lastParen = Get(TEXT_lastParen);
        leftContext = Get(TEXT_leftContext);
        rightContext = Get(TEXT_rightContext);
        dollar[0] = lastMatch;
        dollar[1] = Get(TEXT_dollar1);
        dollar[2] = Get(TEXT_dollar2);
        dollar[3] = Get(TEXT_dollar3);
        dollar[4] = Get(TEXT_dollar4);
        dollar[5] = Get(TEXT_dollar5);
        dollar[6] = Get(TEXT_dollar6);
        dollar[7] = Get(TEXT_dollar7);
        dollar[8] = Get(TEXT_dollar8);
        dollar[9] = Get(TEXT_dollar9);

        index = Get(TEXT_index);
        lastIndex = Get(TEXT_lastIndex);

        // Should lastMatch be an alias for dollar[nparens],
        // or should it be a separate property?
        // We implemented it the latter way.
        // Since both are ReadOnly, I can't see that it makes
        // any difference.
    }

    override void* Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 262 v3 15.10.4.1

        Value* pattern;
        Value* flags;
        d_string P;
        d_string F;
        Dregexp r;
        Dregexp R;

        //writef("Dregexp_constructor.Construct()\n");
        ret.putVundefined();
        pattern = &vundefined;
        flags = &vundefined;
        switch(arglist.length)
        {
        case 0:
            break;

        default:
            flags = &arglist[1];
            goto case;
        case 1:
            pattern = &arglist[0];
            break;
        }
        R = Dregexp.isRegExp(pattern, cc);
        if(R)
        {
            if(flags.isUndefined())
            {
                P = R.re.pattern;
                F = R.re.flags;
            }
            else
            {
                ErrInfo errinfo;
                return RuntimeError(&errinfo, cc, ERR_TYPE_ERROR,
                                    "RegExp.prototype.constructor");
            }
        }
        else
        {
            P = pattern.isUndefined() ? "" : pattern.toString(cc);
            F = flags.isUndefined() ? "" : flags.toString(cc);
        }
        r = new Dregexp(cc, P, F);
        if(r.re.errors)
        {
            Dobject o;
            ErrInfo errinfo;

            version(none)
            {
                writef("P = '%s'\nF = '%s'\n", d_string_ptr(P), d_string_ptr(F));
                for(int i = 0; i < d_string_len(P); i++)
                    writef("x%02x\n", d_string_ptr(P)[i]);
            }
            errinfo.message = errmsgtbl[ERR_REGEXP_COMPILE];
            o = new syntaxerror.D0(cc, &errinfo);
            Value* v = new Value;
            v.putVobject(o);
            return v;
        }
        else
        {
            ret.putVobject(r);
            return null;
        }
    }

    override void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 262 v3 15.10.3.1
        if(arglist.length >= 1)
        {
            Value* pattern;
            Dobject o;

            pattern = &arglist[0];
            if(!pattern.isPrimitive())
            {
                o = pattern.object;
                if(o.isDregexp() &&
                   (arglist.length == 1 || arglist[1].isUndefined())
                   )
                {
                    ret.putVobject(o);
                    return null;
                }
            }
        }
        return Construct(cc, ret, arglist);
    }


    override Value* Get(d_string PropertyName)
    {
        return Dfunction.Get(perlAlias(PropertyName));
    }

    override Value* Put(CallContext* cc, d_string PropertyName, Value* value, uint attributes)
    {
        return Dfunction.Put(cc, perlAlias(PropertyName), value, attributes);
    }

    override Value* Put(CallContext* cc, d_string PropertyName, Dobject o, uint attributes)
    {
        return Dfunction.Put(cc, perlAlias(PropertyName), o, attributes);
    }

    override Value* Put(CallContext* cc, d_string PropertyName, d_number n, uint attributes)
    {
        return Dfunction.Put(cc, perlAlias(PropertyName), n, attributes);
    }

    override int CanPut(d_string PropertyName)
    {
        return Dfunction.CanPut(perlAlias(PropertyName));
    }

    override int HasProperty(d_string PropertyName)
    {
        return Dfunction.HasProperty(perlAlias(PropertyName));
    }

    override int Delete(d_string PropertyName)
    {
        return Dfunction.Delete(perlAlias(PropertyName));
    }

    // Translate Perl property names to script property names
    static d_string perlAlias(d_string s)
    {
        import std.algorithm.searching : countUntil;

        d_string t;

        static immutable tchar[] from = "_*&+`'";
        static enum d_string[] to =
        [
            TEXT_input,
            TEXT_multiline,
            TEXT_lastMatch,
            TEXT_lastParen,
            TEXT_leftContext,
            TEXT_rightContext,
        ];

        t = s;
        if(s.length == 2 && s[0] == '$')
        {
            ptrdiff_t i;

            i = countUntil(from, s[1]);
            if(i >= 0)
                t = to[i];
        }
        return t;
    }
}


/* ===================== Dregexp_prototype_toString =============== */

void* Dregexp_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // othis must be a RegExp
    Dregexp r;

    if(!othis.isDregexp())
    {
        ret.putVundefined();
        ErrInfo errinfo;
        return Dobject.RuntimeError(&errinfo, cc, ERR_NOT_TRANSFERRABLE,
                                    "RegExp.prototype.toString()");
    }
    else
    {
        d_string s;

        r = cast(Dregexp)(othis);
        s = "/";
        s ~= r.re.pattern;
        s ~= "/";
        s ~= r.re.flags;
        ret.putVstring(s);
    }
    return null;
}

/* ===================== Dregexp_prototype_test =============== */

void* Dregexp_prototype_test(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.10.6.3 says this is equivalent to:
    //	RegExp.prototype.exec(string) != null
    return Dregexp.exec(othis, cc, ret, arglist, EXEC_BOOLEAN);
}

/* ===================== Dregexp_prototype_exec ============= */

void* Dregexp_prototype_exec(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return Dregexp.exec(othis, cc, ret, arglist, EXEC_ARRAY);
}


/* ===================== Dregexp_prototype_compile ============= */

void* Dregexp_prototype_compile(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // RegExp.prototype.compile(pattern, attributes)

    // othis must be a RegExp
    if(!othis.isClass(TEXT_RegExp))
    {
        ErrInfo errinfo;
        ret.putVundefined();
        return Dobject.RuntimeError(&errinfo, cc, ERR_NOT_TRANSFERRABLE,
                                    "RegExp.prototype.compile()");
    }
    else
    {
        d_string pattern;
        d_string attributes;
        Dregexp dr;
        RegExp r;

        dr = cast(Dregexp)othis;
        switch(arglist.length)
        {
        case 0:
            break;

        default:
            attributes = arglist[1].toString(cc);
            goto case;
        case 1:
            pattern = arglist[0].toString(cc);
            break;
        }

        r = dr.re;
        try
        {
            r.compile(pattern, attributes);
        }
        catch(RegExpException e)
        {
            // Affect source, global and ignoreCase properties
            dr.source.putVstring(r.pattern);
            dr.global.putVboolean((r.attributes & RegExp.REA.global) != 0);
            dr.ignoreCase.putVboolean((r.attributes & RegExp.REA.ignoreCase) != 0);
        }
        //writef("r.attributes = x%x\n", r.attributes);
    }
    // Documentation says nothing about a return value,
    // so let's use "undefined"
    ret.putVundefined();
    return null;
}

/* ===================== Dregexp_prototype ==================== */

class DregexpPrototype : Dregexp
{
    this(CallContext* cc)
    {
        super(cc, cc.tc.Dobject_prototype);
        classname = TEXT_Object;
        uint attributes = ReadOnly | DontDelete | DontEnum;
        Dobject f = cc.tc.Dfunction_prototype;

        Put(cc, TEXT_constructor, cc.tc.Dregexp_constructor, attributes);

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_toString, &Dregexp_prototype_toString, 0 },
            { TEXT_compile, &Dregexp_prototype_compile, 2 },
            { TEXT_exec, &Dregexp_prototype_exec, 1 },
            { TEXT_test, &Dregexp_prototype_test, 1 },
        ];

        DnativeFunction.initialize(this, cc, nfd, attributes);
    }
}


/* ===================== Dregexp ==================== */


class Dregexp : Dobject
{
    Value *global;
    Value *ignoreCase;
    Value *multiline;
    Value *lastIndex;
    Value *source;

    RegExp re;

    this(CallContext* cc, d_string pattern, d_string attributes)
    {
        super(cc, getPrototype(cc));

        Value v;
        v.putVstring(null);

        Value vb;
        vb.putVboolean(false);

        classname = TEXT_RegExp;

        //writef("Dregexp.Dregexp(pattern = '%ls', attributes = '%ls')\n", d_string_ptr(pattern), d_string_ptr(attributes));
        Put(cc, TEXT_source, &v, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_global, &vb, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_ignoreCase, &vb, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_multiline, &vb, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_lastIndex, 0.0, DontDelete | DontEnum);

        source = Get(TEXT_source);
        global = Get(TEXT_global);
        ignoreCase = Get(TEXT_ignoreCase);
        multiline = Get(TEXT_multiline);
        lastIndex = Get(TEXT_lastIndex);

        re = new RegExp(pattern, attributes);
        if(re.errors == 0)
        {
            source.putVstring(pattern);
            //writef("source = '%s'\n", source.x.string.toDchars());
            global.putVboolean((re.attributes & RegExp.REA.global) != 0);
            ignoreCase.putVboolean((re.attributes & RegExp.REA.ignoreCase) != 0);
            multiline.putVboolean((re.attributes & RegExp.REA.multiline) != 0);
        }
        else
        {
            // have caller throw SyntaxError
        }
    }

    this(CallContext* cc, Dobject prototype)
    {
        super(cc, prototype);

        Value v;
        v.putVstring(null);

        Value vb;
        vb.putVboolean(false);

        classname = TEXT_RegExp;

        Put(cc, TEXT_source, &v, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_global, &vb, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_ignoreCase, &vb, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_multiline, &vb, ReadOnly | DontDelete | DontEnum);
        Put(cc, TEXT_lastIndex, 0.0, DontDelete | DontEnum);

        source = Get(TEXT_source);
        global = Get(TEXT_global);
        ignoreCase = Get(TEXT_ignoreCase);
        multiline = Get(TEXT_multiline);
        lastIndex = Get(TEXT_lastIndex);

        re = new RegExp(null, null);
    }

    override void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // This is the same as calling RegExp.prototype.exec(str)
        Value* v;

        v = Get(TEXT_exec);
        return v.toObject(cc).Call(cc, this, ret, arglist);
    }

    static Dregexp isRegExp(Value* v, CallContext* cc)
    {
        Dregexp r;

        if(!v.isPrimitive() && v.toObject(cc).isDregexp())
        {
            r = cast(Dregexp)(v.toObject(cc));
        }
        return r;
    }

    static void* exec(Dobject othis, CallContext* cc, Value* ret, Value[] arglist, int rettype)
    {
        //writef("Dregexp.exec(arglist.length = %d, rettype = %d)\n", arglist.length, rettype);

        // othis must be a RegExp
        if(!othis.isClass(TEXT_RegExp))
        {
            ret.putVundefined();
            ErrInfo errinfo;
            return RuntimeError(&errinfo, cc, ERR_NOT_TRANSFERRABLE,
                                "RegExp.prototype.exec()");
        }
        else
        {
            d_string s;
            Dregexp dr;
            RegExp r;
            DregexpConstructor dc;
            uint i;
            d_int32 lasti;

            if(arglist.length)
                s = arglist[0].toString(cc);
            else
            {
                Dfunction df;

                df = Dregexp.getConstructor(cc);
                s = (cast(DregexpConstructor)df).input.string;
            }

            dr = cast(Dregexp)othis;
            r = dr.re;
            dc = cast(DregexpConstructor)Dregexp.getConstructor(cc);

            // Decide if we are multiline
            if(dr.multiline.dbool)
                r.attributes |= RegExp.REA.multiline;
            else
                r.attributes &= ~RegExp.REA.multiline;

            if(r.attributes & RegExp.REA.global && rettype != EXEC_INDEX)
                lasti = cast(int)dr.lastIndex.toInteger(cc);
            else
                lasti = 0;

            if(r.test(s, lasti))
            {   // Successful match
                Value* lastv;
                uint nmatches;

                if(r.attributes & RegExp.REA.global && rettype != EXEC_INDEX)
                {
                    dr.lastIndex.putVnumber(r.pmatch[0].rm_eo);
                }

                dc.input.putVstring(r.input);

                s = r.input[r.pmatch[0].rm_so .. r.pmatch[0].rm_eo];
                dc.lastMatch.putVstring(s);

                s = r.input[0 .. r.pmatch[0].rm_so];
                dc.leftContext.putVstring(s);

                s = r.input[r.pmatch[0].rm_eo .. $];
                dc.rightContext.putVstring(s);

                dc.index.putVnumber(r.pmatch[0].rm_so);
                dc.lastIndex.putVnumber(r.pmatch[0].rm_eo);

                // Fill in $1..$9
                lastv = &vundefined;
                nmatches = 0;
                for(i = 1; i <= 9; i++)
                {
                    if(i <= r.re_nsub)
                    {
                        int n;

                        // Use last 9 entries for $1..$9
                        n = i;
                        if(r.re_nsub > 9)
                            n += (r.re_nsub - 9);

                        if(r.pmatch[n].rm_so != -1)
                        {
                            s = r.input[r.pmatch[n].rm_so .. r.pmatch[n].rm_eo];
                            dc.dollar[i].putVstring(s);
                            nmatches = i;
                        }
                        else
                            dc.dollar[i].putVundefined();
                        lastv = dc.dollar[i];
                    }
                    else
                        dc.dollar[i].putVundefined();
                }
                // Last substring in $1..$9, or "" if none
                if(r.re_nsub)
                    Value.copy(dc.lastParen, lastv);
                else
                    dc.lastParen.putVstring(null);

                switch(rettype)
                {
                case EXEC_ARRAY:
                {
                    Darray a = new Darray(cc);

                    a.Put(cc, TEXT_input, r.input, 0);
                    a.Put(cc, TEXT_index, r.pmatch[0].rm_so, 0);
                    a.Put(cc, TEXT_lastIndex, r.pmatch[0].rm_eo, 0);

                    a.Put(cc, cast(d_uint32)0, dc.lastMatch, cast(uint)0);

                    // [1]..[nparens]
                    for(i = 1; i <= r.re_nsub; i++)
                    {
                        if(i > nmatches)
                            a.Put(cc, i, TEXT_, 0);

                        // Reuse values already put into dc.dollar[]
                        else if(r.re_nsub <= 9)
                            a.Put(cc, i, dc.dollar[i], 0);
                        else if(i > r.re_nsub - 9)
                            a.Put(cc, i, dc.dollar[i - (r.re_nsub - 9)], 0);
                        else if(r.pmatch[i].rm_so == -1)
                        {
                            a.Put(cc, i, &vundefined, 0);
                        }
                        else
                        {
                            s = r.input[r.pmatch[i].rm_so .. r.pmatch[i].rm_eo];
                            a.Put(cc, i, s, 0);
                        }
                    }
                    ret.putVobject(a);
                    break;
                }
                case EXEC_STRING:
                    Value.copy(ret, dc.lastMatch);
                    break;

                case EXEC_BOOLEAN:
                    ret.putVboolean(true);      // success
                    break;

                case EXEC_INDEX:
                    ret.putVnumber(r.pmatch[0].rm_so);
                    break;

                default:
                    assert(0);
                }
            }
            else        // failed to match
            {
                //writef("failed\n");
                switch(rettype)
                {
                case EXEC_ARRAY:
                    //writef("memcpy\n");
                    ret.putVnull();         // Return null
                    dr.lastIndex.putVnumber(0);
                    break;

                case EXEC_STRING:
                    ret.putVstring(null);
                    dr.lastIndex.putVnumber(0);
                    break;

                case EXEC_BOOLEAN:
                    ret.putVboolean(false);
                    dr.lastIndex.putVnumber(0);
                    break;

                case EXEC_INDEX:
                    ret.putVnumber(-1.0);
                    // Do not set lastIndex
                    break;

                default:
                    assert(0);
                }
            }
        }
        return null;
    }

    static Dfunction getConstructor(CallContext* cc)
    {
        return cc.tc.Dregexp_constructor;
    }

    static Dobject getPrototype(CallContext* cc)
    {
        return cc.tc.Dregexp_prototype;
    }

    static void initialize(CallContext* cc)
    {
        cc.tc.Dregexp_constructor = new DregexpConstructor(cc);
        cc.tc.Dregexp_prototype = new DregexpPrototype(cc);

        version(none)
        {
            writef("Dregexp_constructor = %x\n", cc.tc.Dregexp_constructor);
            uint *p;
            p = cast(uint *)cc.tc.Dregexp_constructor;
            writef("p = %x\n", p);
            if(p)
                writef("*p = %x, %x, %x, %x\n", p[0], p[1], p[2], p[3]);
        }

        cc.tc.Dregexp_constructor.Put(cc, TEXT_prototype, cc.tc.Dregexp_prototype, DontEnum | DontDelete | ReadOnly);
    }
}
