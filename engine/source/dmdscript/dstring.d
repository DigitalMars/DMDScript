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


module dmdscript.dstring;

import undead.regexp;
import std.utf;
import core.stdc.stdlib;
import core.stdc.string;
import std.exception;
import std.algorithm;
import std.range;
import std.stdio;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dregexp;
import dmdscript.darray;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;

//alias script.tchar tchar;

/* ===================== Dstring_fromCharCode ==================== */

void* Dstring_fromCharCode(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    static import dmdscript.utf;

    // ECMA 15.5.3.2
    d_string s;

    for(size_t i = 0; i < arglist.length; i++)
    {
        Value* v;
        uint u;

        v = &arglist[i];
        u = v.toUint16(cc);
        //writef("string.fromCharCode(%x)", u);
        if(!std.utf.isValidDchar(u))
        {
            ErrInfo errinfo;

            ret.putVundefined();
            return pthis.RuntimeError(&errinfo,
                                      cc,
                                      errmsgtbl[ERR_NOT_VALID_UTF],
                                      "String", "fromCharCode()",
                                      u);
        }
        dmdscript.utf.encode(s, u);
        //writefln("s[0] = %x, s = '%s'", s[0], s);
    }
    ret.putVstring(s);
    return null;
}

/* ===================== Dstring_constructor ==================== */

class DstringConstructor : Dfunction
{
    this(CallContext* cc)
    {
        super(cc, 1, cc.tc.Dfunction_prototype);
        name = "String";

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_fromCharCode, &Dstring_fromCharCode, 1 },
        ];

        DnativeFunction.initialize(this, cc, nfd, 0);
    }

    override void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.5.2
        d_string s;
        Dobject o;

        s = (arglist.length) ? arglist[0].toString(cc) : TEXT_;
        o = new Dstring(cc, s);
        ret.putVobject(o);
        return null;
    }

    override void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.5.1
        d_string s;

        s = (arglist.length) ? arglist[0].toString(cc) : TEXT_;
        ret.putVstring(s);
        return null;
    }
}


/* ===================== Dstring_prototype_toString =============== */

void* Dstring_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    //writef("Dstring.prototype.toString()\n");
    // othis must be a String
    if(!othis.isClass(TEXT_String))
    {
        ErrInfo errinfo;

        ret.putVundefined();
        return pthis.RuntimeError(&errinfo,
                                  cc,
                                  errmsgtbl[ERR_FUNCTION_WANTS_STRING],
                                  TEXT_toString,
                                  othis.classname);
    }
    else
    {
        Value *v;

        v = &(cast(Dstring)othis).value;
        Value.copy(ret, v);
    }
    return null;
}

/* ===================== Dstring_prototype_valueOf =============== */

void* Dstring_prototype_valueOf(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // Does same thing as String.prototype.toString()

    //writef("string.prototype.valueOf()\n");
    // othis must be a String
    if(!othis.isClass(TEXT_String))
    {
        ErrInfo errinfo;

        ret.putVundefined();
        return pthis.RuntimeError(&errinfo,
                                  cc,
                                  errmsgtbl[ERR_FUNCTION_WANTS_STRING],
                                  TEXT_valueOf,
                                  othis.classname);
    }
    else
    {
        Value *v;

        v = &(cast(Dstring)othis).value;
        Value.copy(ret, v);
    }
    return null;
}

/* ===================== Dstring_prototype_charAt =============== */

void* Dstring_prototype_charAt(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA 15.5.4.4

    Value *v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    d_string s;
    d_string result;

    v = &othis.value;
    s = v.toString(cc);
    v = arglist.length ? &arglist[0] : &vundefined;
    pos = cast(int)v.toInteger(cc);

    result = TEXT_;

    if(pos >= 0)
    {
        size_t idx;

        while(1)
        {
            if(idx == s.length)
                break;
            if(pos == 0)
            {
                result = s[idx .. idx + std.utf.stride(s, idx)];
                break;
            }
            idx += std.utf.stride(s, idx);
            pos--;
        }
    }

    ret.putVstring(result);
    return null;
}

/* ===================== Dstring_prototype_charCodeAt ============= */

void* Dstring_prototype_charCodeAt(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA 15.5.4.5

    Value *v;
    int pos;            // ECMA says pos should be a d_number,
                        // but int should behave the same
    d_string s;
    uint len;
    d_number result;

    v = &othis.value;
    s = v.toString(cc);
    v = arglist.length ? &arglist[0] : &vundefined;
    pos = cast(int)v.toInteger(cc);

    result = d_number.nan;

    if(pos >= 0)
    {
        size_t idx;

        while(1)
        {
            assert(idx <= s.length);
            if(idx == s.length)
                break;
            if(pos == 0)
            {
                result = std.utf.decode(s, idx);
                break;
            }
            idx += std.utf.stride(s, idx);
            pos--;
        }
    }

    ret.putVnumber(result);
    return null;
}

/* ===================== Dstring_prototype_concat ============= */

void* Dstring_prototype_concat(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.6
    d_string s;

    //writefln("Dstring.prototype.concat()");

    s = othis.value.toString(cc);
    for(size_t a = 0; a < arglist.length; a++)
        s ~= arglist[a].toString(cc);

    ret.putVstring(s);
    return null;
}

/* ===================== Dstring_prototype_indexOf ============= */

void* Dstring_prototype_indexOf(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.string : indexOf;
    import std.utf : toUCSindex, toUTFindex;

    // ECMA 15.5.4.6
    // String.prototype.indexOf(searchString, position)

    Value* v1;
    Value* v2;
    ptrdiff_t pos;            // ECMA says pos should be a d_number,
                        // but I can't find a reason.
    d_string s;
    size_t sUCSdim;

    d_string searchString;
    ptrdiff_t k;

    Value xx;
    xx.putVobject(othis);
    s = xx.toString(cc);
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &vundefined;
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;

    searchString = v1.toString(cc);
    pos = cast(int)v2.toInteger(cc);

    if(pos < 0)
        pos = 0;
    else if(pos > sUCSdim)
        pos = sUCSdim;

    if(searchString.length == 0)
        k = pos;
    else
    {
        pos = toUTFindex(s, pos);
        k = indexOf(s[pos .. $], searchString);
        if(k != -1)
            k = toUCSindex(s, pos + k);
    }

    ret.putVnumber(k);
    return null;
}

/* ===================== Dstring_prototype_lastIndexOf ============= */

void* Dstring_prototype_lastIndexOf(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.math : isNaN;
    import std.string : lastIndexOf;
    import std.utf : toUCSindex, toUTFindex;

    // ECMA v3 15.5.4.8
    // String.prototype.lastIndexOf(searchString, position)

    Value *v1;
    ptrdiff_t pos;            // ECMA says pos should be a d_number,
                        // but I can't find a reason.
    d_string s;
    size_t sUCSdim;
    d_string searchString;
    ptrdiff_t k;

    version(all)
    {
        {
            // This is the 'transferable' version
            Value *v;
            void *a;
            v = othis.Get(TEXT_toString);
            a = v.Call(cc, othis, ret, null);
            if(a)                       // if exception was thrown
                return a;
            s = ret.toString(cc);
        }
    }
    else
    {
        // the 'builtin' version
        s = othis.value.toString();
    }
    sUCSdim = toUCSindex(s, s.length);

    v1 = arglist.length ? &arglist[0] : &vundefined;
    searchString = v1.toString(cc);
    if(arglist.length >= 2)
    {
        d_number n;
        Value *v = &arglist[1];

        n = v.toNumber(cc);
        if(isNaN(n) || n > sUCSdim)
            pos = sUCSdim;
        else if(n < 0)
            pos = 0;
        else
            pos = cast(int)n;
    }
    else
        pos = sUCSdim;

    //writef("len = %d, p = '%ls'\n", len, p);
    //writef("pos = %d, sslen = %d, ssptr = '%ls'\n", pos, sslen, ssptr);
    //writefln("s = '%s', pos = %s, searchString = '%s'", s, pos, searchString);

    if(searchString.length == 0)
        k = pos;
    else
    {
        pos = toUTFindex(s, pos);
        pos += searchString.length;
        if(pos > s.length)
            pos = s.length;
        k = lastIndexOf(s[0 .. pos], searchString);
        //writefln("s = '%s', pos = %s, searchString = '%s', k = %d", s, pos, searchString, k);
        if(k != -1)
            k = toUCSindex(s, k);
    }
    ret.putVnumber(k);
    return null;
}

/* ===================== Dstring_prototype_localeCompare ============= */

void* Dstring_prototype_localeCompare(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.9
    d_string s1;
    d_string s2;
    d_number n;
    Value *v;

    v = &othis.value;
    s1 = v.toString(cc);
    s2 = arglist.length ? arglist[0].toString(cc) : vundefined.toString(cc);
    n = localeCompare(cc, s1, s2);
    ret.putVnumber(n);
    return null;
}

/* ===================== Dstring_prototype_match ============= */

void* Dstring_prototype_match(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.10
    Dregexp r;
    Dobject o;

    if(arglist.length && !arglist[0].isPrimitive() &&
       (o = arglist[0].toObject(cc)).isDregexp())
    {
    }
    else
    {
        Value regret;

        regret.putVobject(null);
        Dregexp.getConstructor(cc).Construct(cc, &regret, arglist);
        o = regret.object;
    }

    r = cast(Dregexp)o;
    if(r.global.dbool)
    {
        Darray a = new Darray(cc);
        d_int32 n;
        d_int32 i;
        d_int32 lasti;

        i = 0;
        lasti = 0;
        for(n = 0;; n++)
        {
            r.lastIndex.putVnumber(i);
            Dregexp.exec(r, cc, ret, (&othis.value)[0 .. 1], EXEC_STRING);
            if(!ret.string)             // if match failed
            {
                r.lastIndex.putVnumber(i);
                break;
            }
            lasti = i;
            i = cast(d_int32)r.lastIndex.toInt32(cc);
            if(i == lasti)              // if no source was consumed
                i++;                    // consume a character

            a.Put(cc, n, ret, 0);           // a[n] = ret;
        }
        ret.putVobject(a);
    }
    else
    {
        Dregexp.exec(r, cc, ret, (&othis.value)[0 .. 1], EXEC_ARRAY);
    }
    return null;
}

/* ===================== Dstring_prototype_replace ============= */

void* Dstring_prototype_replace(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.string : indexOf;
    // ECMA v3 15.5.4.11
    // String.prototype.replace(searchValue, replaceValue)

    d_string string;
    d_string searchString;
    d_string newstring;
    Value *searchValue;
    Value *replaceValue;
    Dregexp r;
    RegExp re;
    d_string replacement;
    d_string result;
    int m;
    int i;
    int lasti;
    regmatch_t[1] pmatch;
    Dfunction f;
    Value* v;

    v = &othis.value;
    string = v.toString(cc);
    searchValue = (arglist.length >= 1) ? &arglist[0] : &vundefined;
    replaceValue = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    r = Dregexp.isRegExp(searchValue, cc);
    f = Dfunction.isFunction(replaceValue, cc);
    if(r)
    {
        int offset = 0;

        re = r.re;
        i = 0;
        result = string;

        r.lastIndex.putVnumber(0);
        for(;; )
        {
            Dregexp.exec(r, cc, ret, (&othis.value)[0 .. 1], EXEC_STRING);
            if(!ret.string)             // if match failed
                break;

            m = re.re_nsub;
            if(f)
            {
                Value* alist;

                alist = cast(Value *)alloca((m + 3) * Value.sizeof);
                assert(alist);
                alist[0].putVstring(ret.string);
                for(i = 0; i < m; i++)
                {
                    alist[1 + i].putVstring(
                        string[re.pmatch[1 + i].rm_so .. re.pmatch[1 + i].rm_eo]);
                }
                alist[m + 1].putVnumber(re.pmatch[0].rm_so);
                alist[m + 2].putVstring(string);
                f.Call(cc, f, ret, alist[0 .. m + 3]);
                replacement = ret.toString(cc);
            }
            else
            {
                newstring = replaceValue.toString(cc);
                replacement = re.replace(newstring);
            }
            ptrdiff_t starti = re.pmatch[0].rm_so + offset;
            ptrdiff_t endi = re.pmatch[0].rm_eo + offset;
            result = string[0 .. starti] ~
                     replacement ~
                     string[endi .. $];

            if(re.attributes & RegExp.REA.global)
            {
                offset += replacement.length - (endi - starti);

                // If no source was consumed, consume a character
                lasti = i;
                i = cast(d_int32)r.lastIndex.toInt32(cc);
                if(i == lasti)
                {
                    i++;
                    r.lastIndex.putVnumber(i);
                }
            }
            else
                break;
        }
    }
    else
    {
        searchString = searchValue.toString(cc);
        ptrdiff_t match = indexOf(string, searchString);
        if(match >= 0)
        {
            pmatch[0].rm_so = match;
            pmatch[0].rm_eo = match + searchString.length;
            if(f)
            {
                Value[3] alist;

                alist[0].putVstring(searchString);
                alist[1].putVnumber(pmatch[0].rm_so);
                alist[2].putVstring(string);
                f.Call(cc, f, ret, alist);
                replacement = ret.toString(cc);
            }
            else
            {
                newstring = replaceValue.toString(cc);
                replacement = RegExp.replace3(newstring, string, pmatch);
            }
            result = string[0 .. match] ~
                     replacement ~
                     string[match + searchString.length .. $];
        }
        else
        {
            result = string;
        }
    }

    ret.putVstring(result);
    return null;
}

/* ===================== Dstring_prototype_search ============= */

void* Dstring_prototype_search(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.12
    Dregexp r;
    Dobject o;

    //writef("String.prototype.search()\n");
    if(arglist.length && !arglist[0].isPrimitive() &&
       (o = arglist[0].toObject(cc)).isDregexp())
    {
    }
    else
    {
        Value regret;

        regret.putVobject(null);
        Dregexp.getConstructor(cc).Construct(cc, &regret, arglist);
        o = regret.object;
    }

    r = cast(Dregexp)o;
    Dregexp.exec(r, cc, ret, (&othis.value)[0 .. 1], EXEC_INDEX);
    return null;
}

/* ===================== Dstring_prototype_slice ============= */

void* Dstring_prototype_slice(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.13
    ptrdiff_t start;
    ptrdiff_t end;
    ptrdiff_t sUCSdim;
    d_string s;
    d_string r;
    Value *v;

    v = &othis.value;
    s = v.toString(cc);
    sUCSdim = std.utf.toUCSindex(s, s.length);
    switch(arglist.length)
    {
    case 0:
        start = 0;
        end = sUCSdim;
        break;

    case 1:
        start = arglist[0].toInt32(cc);
        end = sUCSdim;
        break;

    default:
        start = arglist[0].toInt32(cc);
        end = arglist[1].toInt32(cc);
        break;
    }

    if(start < 0)
    {
        start += sUCSdim;
        if(start < 0)
            start = 0;
    }
    else if(start >= sUCSdim)
        start = sUCSdim;

    if(end < 0)
    {
        end += sUCSdim;
        if(end < 0)
            end = 0;
    }
    else if(end >= sUCSdim)
        end = sUCSdim;

    if(start > end)
        end = start;

    start = toUTFindex(s, start);
    end = toUTFindex(s, end);
    r = s[start .. end];

    ret.putVstring(r);
    return null;
}


/* ===================== Dstring_prototype_split ============= */

void* Dstring_prototype_split(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.14
    // String.prototype.split(separator, limit)
    size_t lim;
    size_t p;
    size_t q;
    size_t e;
    Value* separator = &vundefined;
    Value* limit = &vundefined;
    Dregexp R;
    RegExp re;
    d_string rs;
    d_string T;
    d_string S;
    Darray A;
    int str;

    //writefln("Dstring_prototype_split()");
    switch(arglist.length)
    {
    default:
        limit = &arglist[1];
        goto case;
    case 1:
        separator = &arglist[0];
        goto case;
    case 0:
        break;
    }

    Value *v;
    v = &othis.value;
    S = v.toString(cc);
    A = new Darray(cc);
    if(limit.isUndefined())
        lim = ~0u;
    else
        lim = limit.toUint32(cc);
    p = 0;
    R = Dregexp.isRegExp(separator, cc);
    if(R)       // regular expression
    {
        re = R.re;
        assert(re);
        rs = null;
        str = 0;
    }
    else        // string
    {
        re = null;
        rs = separator.toString(cc);
        str = 1;
    }
    if(lim == 0)
        goto Lret;

    // ECMA v3 15.5.4.14 is specific: "If separator is undefined, then the
    // result array contains just one string, which is the this value
    // (converted to a string)." However, neither Javascript nor Jscript
    // do that, they regard an undefined as being the string "undefined".
    // We match Javascript/Jscript behavior here, not ECMA.

    // Uncomment for ECMA compatibility
    //if (!separator.isUndefined())
    {
        //writefln("test1 S = '%s', rs = '%s'", S, rs);
        if(S.length)
        {
            L10:
            for(q = p; q != S.length; q++)
            {
                if(str)                 // string
                {
                    if(q + rs.length <= S.length && !memcmp(S.ptr + q, rs.ptr, rs.length * tchar.sizeof))
                    {
                        e = q + rs.length;
                        if(e != p)
                        {
                            T = S[p .. q];
                            A.Put(cc, cast(uint)A.length.number, T, 0);
                            if(A.length.number == lim)
                                goto Lret;
                            p = e;
                            goto L10;
                        }
                    }
                }
                else            // regular expression
                {
                    if(re.test(S, q))
                    {
                        q = re.pmatch[0].rm_so;
                        e = re.pmatch[0].rm_eo;
                        if(e != p)
                        {
                            T = S[p .. q];
                            //writefln("S = '%s', T = '%s', p = %d, q = %d, e = %d\n", S, T, p, q, e);
                            A.Put(cc, cast(uint)A.length.number, T, 0);
                            if(A.length.number == lim)
                                goto Lret;
                            p = e;
                            for(uint i = 0; i < re.re_nsub; i++)
                            {
                                ptrdiff_t so = re.pmatch[1 + i].rm_so;
                                ptrdiff_t eo = re.pmatch[1 + i].rm_eo;

                                //writefln("i = %d, nsub = %s, so = %s, eo = %s, S.length = %s", i, re.re_nsub, so, eo, S.length);
                                if(so != -1 && eo != -1)
                                    T = S[so .. eo];
                                else
                                    T = null;
                                A.Put(cc, cast(uint)A.length.number, T, 0);
                                if(A.length.number == lim)
                                    goto Lret;
                            }
                            goto L10;
                        }
                    }
                }
            }
            T = S[p .. S.length];
            A.Put(cc, cast(uint)A.length.number, T, 0);
            goto Lret;
        }
        if(str)                 // string
        {
            if(rs.length <= S.length && S[0 .. rs.length] == rs[])
                goto Lret;
        }
        else            // regular expression
        {
            if(re.test(S, 0))
                goto Lret;
        }
    }

    A.Put(cc, 0u, S, 0);
    Lret:
    ret.putVobject(A);
    return null;
}


/* ===================== Dstring_prototype_substr ============= */

void *dstring_substring(d_string s, size_t sUCSdim, d_number start, d_number end, Value *ret)
{
    import std.math : isNaN;
    import std.utf : toUTFindex;

    d_string sb;
    d_int32 sb_len;

    if(isNaN(start))
        start = 0;
    else if(start > sUCSdim)
        start = sUCSdim;
    else if(start < 0)
        start = 0;

    if(isNaN(end))
        end = 0;
    else if(end > sUCSdim)
        end = sUCSdim;
    else if(end < 0)
        end = 0;

    if(end < start)             // swap
    {
        d_number t;

        t = start;
        start = end;
        end = t;
    }

    size_t st = toUTFindex(s, cast(size_t)start);
    size_t en = toUTFindex(s, cast(size_t)end);
    sb = s[st .. en];

    ret.putVstring(sb);
    return null;
}

void* Dstring_prototype_substr(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.math : isNaN;
    import std.utf : toUCSindex;

    // Javascript: TDG pg. 689
    // String.prototype.substr(start, length)
    d_number start;
    d_number length;
    d_string s;

    s = othis.value.toString(cc);
    size_t sUCSdim = toUCSindex(s, s.length);
    start = 0;
    length = 0;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger(cc);
        if(start < 0)
            start = sUCSdim + start;
        if(arglist.length >= 2)
        {
            length = arglist[1].toInteger(cc);
            if(isNaN(length) || length < 0)
                length = 0;
        }
        else
            length = sUCSdim - start;
    }

    return dstring_substring(s, sUCSdim, start, start + length, ret);
}

/* ===================== Dstring_prototype_substring ============= */

void* Dstring_prototype_substring(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.utf : toUCSindex;

    // ECMA 15.5.4.9
    // String.prototype.substring(start)
    // String.prototype.substring(start, end)
    d_number start;
    d_number end;
    d_string s;

    //writefln("String.prototype.substring()");
    s = othis.value.toString(cc);
    size_t sUCSdim = toUCSindex(s, s.length);
    start = 0;
    end = sUCSdim;
    if(arglist.length >= 1)
    {
        start = arglist[0].toInteger(cc);
        if(arglist.length >= 2)
            end = arglist[1].toInteger(cc);
        //writef("s = '%ls', start = %d, end = %d\n", s, start, end);
    }

    void* p = dstring_substring(s, sUCSdim, start, end, ret);
    return p;
}

/* ===================== Dstring_prototype_toLowerCase ============= */

enum CASE
{
    Lower,
    Upper,
    LocaleLower,
    LocaleUpper
};

void *tocase(Dobject othis, Value *ret, CASE caseflag, CallContext* cc)
{
    import std.string : toLower, toUpper;

    d_string s;

    s = othis.value.toString(cc);
    switch(caseflag)
    {
    case CASE.Lower:
        s = toLower(s);
        break;
    case CASE.Upper:
        s = toUpper(s);
        break;
    case CASE.LocaleLower:
        s = toLower(s);
        break;
    case CASE.LocaleUpper:
        s = toUpper(s);
        break;
    default:
        assert(0);
    }

    ret.putVstring(s);
    return null;
}

void* Dstring_prototype_toLowerCase(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA 15.5.4.11
    // String.prototype.toLowerCase()

    //writef("Dstring_prototype_toLowerCase()\n");
    return tocase(othis, ret, CASE.Lower, cc);
}

/* ===================== Dstring_prototype_toLocaleLowerCase ============= */

void* Dstring_prototype_toLocaleLowerCase(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.17

    //writef("Dstring_prototype_toLocaleLowerCase()\n");
    return tocase(othis, ret, CASE.LocaleLower, cc);
}

/* ===================== Dstring_prototype_toUpperCase ============= */

void* Dstring_prototype_toUpperCase(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA 15.5.4.12
    // String.prototype.toUpperCase()

    return tocase(othis, ret, CASE.Upper, cc);
}

/* ===================== Dstring_prototype_toLocaleUpperCase ============= */

void* Dstring_prototype_toLocaleUpperCase(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.5.4.18

    return tocase(othis, ret, CASE.LocaleUpper, cc);
}

/* ===================== Dstring_prototype_anchor ============= */

void *dstring_anchor(Dobject othis, CallContext* cc, Value* ret, d_string tag, d_string name, Value[] arglist)
{
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<tag name="bar">foo</tag>

    d_string foo = othis.value.toString(cc);
    Value* va = arglist.length ? &arglist[0] : &vundefined;
    d_string bar = va.toString(cc);

    d_string s;

    s = "<"     ~
        tag     ~
        " "     ~
        name    ~
        "=\""   ~
        bar     ~
        "\">"   ~
        foo     ~
        "</"    ~
        tag     ~
        ">";

    ret.putVstring(s);
    return null;
}


void* Dstring_prototype_anchor(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // Non-standard extension
    // String.prototype.anchor(anchor)
    // For example:
    //	"foo".anchor("bar")
    // produces:
    //	<A NAME="bar">foo</A>

    return dstring_anchor(othis, cc, ret, "A", "NAME", arglist);
}

void* Dstring_prototype_fontcolor(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_anchor(othis, cc, ret, "FONT", "COLOR", arglist);
}

void* Dstring_prototype_fontsize(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_anchor(othis, cc, ret, "FONT", "SIZE", arglist);
}

void* Dstring_prototype_link(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_anchor(othis, cc, ret, "A", "HREF", arglist);
}


/* ===================== Dstring_prototype bracketing ============= */

/***************************
 * Produce <tag>othis</tag>
 */

void *dstring_bracket(Dobject othis, CallContext* cc, Value* ret, d_string tag)
{
    d_string foo = othis.value.toString(cc);
    d_string s;

    s = "<"     ~
        tag     ~
        ">"     ~
        foo     ~
        "</"    ~
        tag     ~
        ">";

    ret.putVstring(s);
    return null;
}

void* Dstring_prototype_big(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // Non-standard extension
    // String.prototype.big()
    // For example:
    //	"foo".big()
    // produces:
    //	<BIG>foo</BIG>

    return dstring_bracket(othis, cc, ret, "BIG");
}

void* Dstring_prototype_blink(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "BLINK");
}

void* Dstring_prototype_bold(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "B");
}

void* Dstring_prototype_fixed(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "TT");
}

void* Dstring_prototype_italics(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "I");
}

void* Dstring_prototype_small(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "SMALL");
}

void* Dstring_prototype_strike(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "STRIKE");
}

void* Dstring_prototype_sub(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "SUB");
}

void* Dstring_prototype_sup(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    return dstring_bracket(othis, cc, ret, "SUP");
}



/* ===================== Dstring_prototype ==================== */

class DstringPrototype : Dstring
{
    this(CallContext* cc)
    {
        super(cc, cc.tc.Dobject_prototype);

        Put(cc, TEXT_constructor, cc.tc.Dstring_constructor, DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_toString, &Dstring_prototype_toString, 0 },
            { TEXT_valueOf, &Dstring_prototype_valueOf, 0 },
            { TEXT_charAt, &Dstring_prototype_charAt, 1 },
            { TEXT_charCodeAt, &Dstring_prototype_charCodeAt, 1 },
            { TEXT_concat, &Dstring_prototype_concat, 1 },
            { TEXT_indexOf, &Dstring_prototype_indexOf, 1 },
            { TEXT_lastIndexOf, &Dstring_prototype_lastIndexOf, 1 },
            { TEXT_localeCompare, &Dstring_prototype_localeCompare, 1 },
            { TEXT_match, &Dstring_prototype_match, 1 },
            { TEXT_replace, &Dstring_prototype_replace, 2 },
            { TEXT_search, &Dstring_prototype_search, 1 },
            { TEXT_slice, &Dstring_prototype_slice, 2 },
            { TEXT_split, &Dstring_prototype_split, 2 },
            { TEXT_substr, &Dstring_prototype_substr, 2 },
            { TEXT_substring, &Dstring_prototype_substring, 2 },
            { TEXT_toLowerCase, &Dstring_prototype_toLowerCase, 0 },
            { TEXT_toLocaleLowerCase, &Dstring_prototype_toLocaleLowerCase, 0 },
            { TEXT_toUpperCase, &Dstring_prototype_toUpperCase, 0 },
            { TEXT_toLocaleUpperCase, &Dstring_prototype_toLocaleUpperCase, 0 },
            { TEXT_anchor, &Dstring_prototype_anchor, 1 },
            { TEXT_fontcolor, &Dstring_prototype_fontcolor, 1 },
            { TEXT_fontsize, &Dstring_prototype_fontsize, 1 },
            { TEXT_link, &Dstring_prototype_link, 1 },
            { TEXT_big, &Dstring_prototype_big, 0 },
            { TEXT_blink, &Dstring_prototype_blink, 0 },
            { TEXT_bold, &Dstring_prototype_bold, 0 },
            { TEXT_fixed, &Dstring_prototype_fixed, 0 },
            { TEXT_italics, &Dstring_prototype_italics, 0 },
            { TEXT_small, &Dstring_prototype_small, 0 },
            { TEXT_strike, &Dstring_prototype_strike, 0 },
            { TEXT_sub, &Dstring_prototype_sub, 0 },
            { TEXT_sup, &Dstring_prototype_sup, 0 },
        ];

        DnativeFunction.initialize(this, cc, nfd, DontEnum);
    }
}

/* ===================== Dstring ==================== */

class Dstring : Dobject
{
    this(CallContext* cc, d_string s)
    {
        super(cc, getPrototype(cc));
        classname = TEXT_String;

        Put(cc, TEXT_length, std.utf.toUCSindex(s, s.length), DontEnum | DontDelete | ReadOnly);
        value.putVstring(s);
    }

    this(CallContext* cc, Dobject prototype)
    {
        super(cc, prototype);

        classname = TEXT_String;
        Put(cc, TEXT_length, 0, DontEnum | DontDelete | ReadOnly);
        value.putVstring(null);
    }

    static void initialize(CallContext* cc)
    {
        cc.tc.Dstring_constructor = new DstringConstructor(cc);
        cc.tc.Dstring_prototype = new DstringPrototype(cc);

        cc.tc.Dstring_constructor.Put(cc, TEXT_prototype, cc.tc.Dstring_prototype, DontEnum | DontDelete | ReadOnly);
    }

    static Dfunction getConstructor(CallContext* cc)
    {
        return cc.tc.Dstring_constructor;
    }

    static Dobject getPrototype(CallContext* cc)
    {
        return cc.tc.Dstring_prototype;
    }
}
