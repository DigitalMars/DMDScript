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

module dmdscript.dnumber;

import std.math;
import core.stdc.stdlib;
import std.exception;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;

/* ===================== Dnumber_constructor ==================== */

class DnumberConstructor : Dfunction
{
    this(CallContext* cc)
    {
        super(cc, 1, cc.tc.Dfunction_prototype);
        uint attributes = DontEnum | DontDelete | ReadOnly;

        name = TEXT_Number;
        Put(cc, TEXT_MAX_VALUE, d_number.max, attributes);
        Put(cc, TEXT_MIN_VALUE, d_number.min_normal*d_number.epsilon, attributes);
        Put(cc, TEXT_NaN, d_number.nan, attributes);
        Put(cc, TEXT_NEGATIVE_INFINITY, -d_number.infinity, attributes);
        Put(cc, TEXT_POSITIVE_INFINITY, d_number.infinity, attributes);
    }

    override void* Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.7.2
        d_number n;
        Dobject o;

        n = (arglist.length) ? arglist[0].toNumber(cc) : 0;
        o = new Dnumber(cc, n);
        ret.putVobject(o);
        return null;
    }

    override void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.7.1
        d_number n;

        n = (arglist.length) ? arglist[0].toNumber(cc) : 0;
        ret.putVnumber(n);
        return null;
    }
}


/* ===================== Dnumber_prototype_toString =============== */

void* Dnumber_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.7.4.2
    d_string s;

    // othis must be a Number
    if(!othis.isClass(TEXT_Number))
    {
        ret.putVundefined();
        ErrInfo errinfo;
        return Dobject.RuntimeError(&errinfo,
                                    cc,
                                    errmsgtbl[ERR_FUNCTION_WANTS_NUMBER],
                                    TEXT_toString,
                                    othis.classname);
    }
    else
    {
        Value* v;

        v = &(cast(Dnumber)othis).value;

        if(arglist.length)
        {
            d_number radix;

            radix = arglist[0].toNumber(cc);
            if(radix == 10.0 || arglist[0].isUndefined())
                s = v.toString(cc);
            else
            {
                int r;

                r = cast(int)radix;
                // radix must be an integer 2..36
                if(r == radix && r >= 2 && r <= 36)
                    s = v.toString(cc, r);
                else
                    s = v.toString(cc);
            }
        }
        else
            s = v.toString(cc);
        ret.putVstring(s);
    }
    return null;
}

/* ===================== Dnumber_prototype_toLocaleString =============== */

void* Dnumber_prototype_toLocaleString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.7.4.3
    d_string s;

    // othis must be a Number
    if(!othis.isClass(TEXT_Number))
    {
        ret.putVundefined();
        ErrInfo errinfo;
        return Dobject.RuntimeError(&errinfo,
                                    cc,
                                    errmsgtbl[ERR_FUNCTION_WANTS_NUMBER],
                                    TEXT_toLocaleString,
                                    othis.classname);
    }
    else
    {
        Value* v;

        v = &(cast(Dnumber)othis).value;

        s = v.toLocaleString(cc);
        ret.putVstring(s);
    }
    return null;
}

/* ===================== Dnumber_prototype_valueOf =============== */

void* Dnumber_prototype_valueOf(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // othis must be a Number
    if(!othis.isClass(TEXT_Number))
    {
        ret.putVundefined();
        ErrInfo errinfo;
        return Dobject.RuntimeError(&errinfo,
                                    cc,
                                    errmsgtbl[ERR_FUNCTION_WANTS_NUMBER],
                                    TEXT_valueOf,
                                    othis.classname);
    }
    else
    {
        Value* v;

        v = &(cast(Dnumber)othis).value;
        Value.copy(ret, v);
    }
    return null;
}

/* ===================== Formatting Support =============== */

const int FIXED_DIGITS = 20;    // ECMA says >= 20


// power of tens array, indexed by power

static immutable d_number[FIXED_DIGITS + 1] tens =
[
    1, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
    1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
    1e20,
];

/************************************************
 * Let e and n be integers such that
 * 10**f <= n < 10**(f+1) and for which the exact
 * mathematical value of n * 10**(e-f) - x is as close
 * to zero as possible. If there are two such sets of
 * e and n, pick the e and n for which n * 10**(e-f)
 * is larger.
 */

number_t deconstruct_real(d_number x, int f, out int pe)
{
    number_t n;
    int e;
    int i;

    e = cast(int)log10(x);
    i = e - f;
    if(i >= 0 && i < tens.length)
        // table lookup for speed & accuracy
        n = cast(number_t)(x / tens[i] + 0.5);
    else
        n = cast(number_t)(x / std.math.pow(cast(real)10.0, i) + 0.5);

    pe = e;
    return n;
}

/* ===================== Dnumber_prototype_toFixed =============== */

void* Dnumber_prototype_toFixed(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.format : sformat;

    // ECMA v3 15.7.4.5
    Value* v;
    d_number x;
    d_number fractionDigits;
    d_string result;
    int dup;

    if(arglist.length)
	{
		v = &arglist[0];
		fractionDigits =  v.toInteger(cc);
	}
	else
		fractionDigits = 0;
    if(fractionDigits < 0 || fractionDigits > FIXED_DIGITS)
    {
        ErrInfo errinfo;

        ret.putVundefined();
        return Dobject.RangeError(&errinfo, cc, ERR_VALUE_OUT_OF_RANGE,
                                  TEXT_toFixed, "fractionDigits");
    }
    v = &othis.value;
    x = v.toNumber(cc);
    if(isNaN(x))
    {
        result = TEXT_NaN;              // return "NaN"
    }
    else
    {
        int sign;
        char[] m;

        sign = 0;
        if(x < 0)
        {
            sign = 1;
            x = -x;
        }
        if(x >= 1.0e+21)               // exponent must be FIXED_DIGITS+1
        {
            Value vn;
            vn.putVnumber(x);
            ret.putVstring(vn.toString(cc));
            return null;
        }
        else
        {
            number_t n;
            tchar[32 + 1] buffer;
            d_number tenf;
            int f;

            f = cast(int)fractionDigits;
            tenf = tens[f];             // tenf = 10**f

            // Compute n which gives |(n / tenf) - x| is the smallest
            // value. If there are two such n's, pick the larger.
            n = cast(number_t)(x * tenf + 0.5);         // round up & chop

            if(n == 0)
            {
                m = cast(char[])"0"; //TODO: try hacking this func to be clean ;)
                dup = 0;
            }
            else
            {
                // n still doesn't give 20 digits, only 19
                m = sformat(buffer[], "%d", cast(ulong)n);
                dup = 1;
            }
            if(f != 0)
            {
                ptrdiff_t i;
                ptrdiff_t k;
                k = m.length;
                if(k <= f)
                {
                    tchar* s;
                    ptrdiff_t nzeros;

                    s = cast(tchar*)alloca((f + 1) * tchar.sizeof);
                    assert(s);
                    nzeros = f + 1 - k;
                    s[0 .. nzeros] = '0';
                    s[nzeros .. f + 1] = m[0 .. k];

                    m = s[0 .. f + 1];
                    k = f + 1;
                }

                // res = "-" + m[0 .. k-f] + "." + m[k-f .. k];
                char[] res = new tchar[sign + k + 1];
                if(sign)
                    res[0] = '-';
                i = k - f;
                res[sign .. sign + i] = m[0 .. i];
                res[sign + i] = '.';
                res[sign + i + 1 .. sign + k + 1] = m[i .. k];
                result = assumeUnique(res);
                goto Ldone;
                //+++ end of patch ++++
            }
        }
        if(sign)
            result = TEXT_dash ~ m.idup;  // TODO: remove idup somehow
        else if(dup)
            result = m.idup;
        else
            result = assumeUnique(m);
    }

    Ldone:
    ret.putVstring(result);
    return null;
}

/* ===================== Dnumber_prototype_toExponential =============== */

void* Dnumber_prototype_toExponential(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.format : format, sformat;

    // ECMA v3 15.7.4.6
    Value* varg;
    Value* v;
    d_number x;
    d_number fractionDigits;
    d_string result;

    if(arglist.length)
	{
		varg = &arglist[0];
		fractionDigits = varg.toInteger(cc);
	}else
		fractionDigits = FIXED_DIGITS;
    v = &othis.value;
    x = v.toNumber(cc);
    if(isNaN(x))
    {
        result = TEXT_NaN;              // return "NaN"
    }
    else
    {
        int sign;

        sign = 0;
        if(x < 0)
        {
            sign = 1;
            x = -x;
        }
        if(std.math.isInfinity(x))
        {
            result = sign ? TEXT_negInfinity : TEXT_Infinity;
        }
        else
        {
            int f;
            number_t n;
            int e;
            tchar[] m;
            int i;
            tchar[32 + 1] buffer;

            if(fractionDigits < 0 || fractionDigits > FIXED_DIGITS)
            {
                ErrInfo errinfo;

                ret.putVundefined();
                return Dobject.RangeError(&errinfo,
                                          cc,
                                          ERR_VALUE_OUT_OF_RANGE,
                                          TEXT_toExponential,
                                          "fractionDigits");
            }

            f = cast(int)fractionDigits;
            if(x == 0)
            {
                tchar* s;

                s = cast(tchar*)alloca((f + 1) * tchar.sizeof);
                assert(s);
                m = s[0 .. f + 1];
                m[0 .. f + 1] = '0';
                e = 0;
            }
            else
            {
                if(arglist.length && !varg.isUndefined())
                {
                    /* Step 12
                     * Let e and n be integers such that
                     * 10**f <= n < 10**(f+1) and for which the exact
                     * mathematical value of n * 10**(e-f) - x is as close
                     * to zero as possible. If there are two such sets of
                     * e and n, pick the e and n for which n * 10**(e-f)
                     * is larger.
                     * [Note: this is the same as Step 15 in toPrecision()
                     *  with f = p - 1]
                     */
                    n = deconstruct_real(x, f, e);
                }
                else
                {
                    /* Step 19
                     * Let e, n, and f be integers such that f >= 0,
                     * 10**f <= n < 10**(f+1), the number value for
                     * n * 10**(e-f) is x, and f is as small as possible.
                     * Note that the decimal representation of n has f+1
                     * digits, n is not divisible by 10, and the least
                     * significant digit of n is not necessarilly uniquely
                     * determined by these criteria.
                     */
                    /* Implement by trying maximum digits, and then
                     * lopping off trailing 0's.
                     */
                    f = 19;             // should use FIXED_DIGITS
                    n = deconstruct_real(x, f, e);

                    // Lop off trailing 0's
                    assert(n);
                    while((n % 10) == 0)
                    {
                        n /= 10;
                        f--;
                        assert(f >= 0);
                    }
                }
                // n still doesn't give 20 digits, only 19
                m = sformat(buffer[], "%d", cast(ulong)n);
            }
            if(f)
            {
                tchar* s;

                // m = m[0] + "." + m[1 .. f+1];
                s = cast(tchar*)alloca((f + 2) * tchar.sizeof);
                assert(s);
                s[0] = m[0];
                s[1] = '.';
                s[2 .. f + 2] = m[1 .. f + 1];
                m = s[0 .. f + 2];
            }

            // result = sign + m + "e" + c + e;
            d_string c = (e >= 0) ? "+" : "";

            result = format("%s%se%s%d", sign ? "-" : "", m, c, e);
        }
    }

    ret.putVstring(result);
    return null;
}

/* ===================== Dnumber_prototype_toPrecision =============== */

void* Dnumber_prototype_toPrecision(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    import std.format : format, sformat;

    // ECMA v3 15.7.4.7
    Value* varg;
    Value* v;
    d_number x;
    d_number precision;
    d_string result;

    v = &othis.value;
    x = v.toNumber(cc);

    varg = (arglist.length == 0) ? &vundefined : &arglist[0];

    if(arglist.length == 0 || varg.isUndefined())
    {
        Value vn;

        vn.putVnumber(x);
        result = vn.toString(cc);
    }
    else
    {
        if(isNaN(x))
            result = TEXT_NaN;
        else
        {
            int sign;
            int e;
            int p;
            int i;
            tchar[] m;
            number_t n;
            tchar[32 + 1] buffer;

            sign = 0;
            if(x < 0)
            {
                sign = 1;
                x = -x;
            }

            if(std.math.isInfinity(x))
            {
                result = sign ? TEXT_negInfinity : TEXT_Infinity;
                goto Ldone;
            }

            precision = varg.toInteger(cc);
            if(precision < 1 || precision > 21)
            {
                ErrInfo errinfo;

                ret.putVundefined();
                return Dobject.RangeError(&errinfo,
                                          cc,
                                          ERR_VALUE_OUT_OF_RANGE,
                                          TEXT_toPrecision,
                                          "precision");
            }

            p = cast(int)precision;
            if(x != 0)
            {
                /* Step 15
                 * Let e and n be integers such that 10**(p-1) <= n < 10**p
                 * and for which the exact mathematical value of n * 10**(e-p+1) - x
                 * is as close to zero as possible. If there are two such sets
                 * of e and n, pick the e and n for which n * 10**(e-p+1) is larger.
                 */
                n = deconstruct_real(x, p - 1, e);

                // n still doesn't give 20 digits, only 19
                m = sformat(buffer[], "%d", cast(ulong)n);

                if(e < -6 || e >= p)
                {
                    // result = sign + m[0] + "." + m[1 .. p] + "e" + c + e;
                    d_string c = (e >= 0) ? "+" : "";
                    result = format("%s%s.%se%s%d",
                                               (sign ? "-" : ""), m[0], m[1 .. $], c, e);
                    goto Ldone;
                }
            }
            else
            {
                // Step 12
                // m = array[p] of '0'
                tchar* s;
                s = cast(tchar*)alloca(p * tchar.sizeof);
                assert(s);
                m = s[0 .. p];
                m[] = '0';

                e = 0;
            }
            if(e != p - 1)
            {
                tchar* s;

                if(e >= 0)
                {
                    // m = m[0 .. e+1] + "." + m[e+1 .. p];

                    s = cast(tchar*)alloca((p + 1) * tchar.sizeof);
                    assert(s);
                    i = e + 1;
                    s[0 .. i] = m[0 .. i];
                    s[i] = '.';
                    s[i + 1 .. p + 1] = m[i .. p];
                    m = s[0 .. p + 1];
                }
                else
                {
                    // m = "0." + (-(e+1) occurrences of the character '0') + m;
                    int imax = 2 + - (e + 1);

                    s = cast(tchar*)alloca((imax + p) * tchar.sizeof);
                    assert(s);
                    s[0] = '0';
                    s[1] = '.';
                    s[2 .. imax] = '0';
                    s[imax .. imax + p] = m[0 .. p];
                    m = s[0 .. imax + p];
                }
            }
            if(sign)
                result = TEXT_dash ~ m.idup;  //TODO: remove idup somehow
            else
                result = m.idup;
        }
    }

    Ldone:
    ret.putVstring(result);
    return null;
}

/* ===================== Dnumber_prototype ==================== */

class DnumberPrototype : Dnumber
{
    this(CallContext* cc)
    {
        super(cc, cc.tc.Dobject_prototype);
        uint attributes = DontEnum;

        Dobject f = cc.tc.Dfunction_prototype;

        Put(cc, TEXT_constructor, cc.tc.Dnumber_constructor, attributes);

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_toString, &Dnumber_prototype_toString, 1 },
            // Permissible to use toString()
            { TEXT_toLocaleString, &Dnumber_prototype_toLocaleString, 1 },
            { TEXT_valueOf, &Dnumber_prototype_valueOf, 0 },
            { TEXT_toFixed, &Dnumber_prototype_toFixed, 1 },
            { TEXT_toExponential, &Dnumber_prototype_toExponential, 1 },
            { TEXT_toPrecision, &Dnumber_prototype_toPrecision, 1 },
        ];

        DnativeFunction.initialize(this, cc, nfd, attributes);
    }
}


/* ===================== Dnumber ==================== */

class Dnumber : Dobject
{
    this(CallContext* cc, d_number n)
    {
        super(cc, getPrototype(cc));
        classname = TEXT_Number;
        value.putVnumber(n);
    }

    this(CallContext* cc, Dobject prototype)
    {
        super(cc, prototype);
        classname = TEXT_Number;
        value.putVnumber(0);
    }

    static Dfunction getConstructor(CallContext* cc)
    {
        return cc.tc.Dnumber_constructor;
    }

    static Dobject getPrototype(CallContext* cc)
    {
        return cc.tc.Dnumber_prototype;
    }

    static void initialize(CallContext* cc)
    {
        cc.tc.Dnumber_constructor = new DnumberConstructor(cc);
        cc.tc.Dnumber_prototype = new DnumberPrototype(cc);

        cc.tc.Dnumber_constructor.Put(cc, TEXT_prototype, cc.tc.Dnumber_prototype, DontEnum | DontDelete | ReadOnly);
    }
}

