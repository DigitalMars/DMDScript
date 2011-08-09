
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


module dmdscript.dmath;

import std.math;
import std.random;

import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.dnative;

d_number math_helper(Value[] arglist)
{
    Value *v;

    v = arglist.length ? &arglist[0] : &vundefined;
    return v.toNumber();
}

void* Dmath_abs(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.1
    d_number result;

    result = fabs(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_acos(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.2
    d_number result;

    result = acos(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_asin(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.3
    d_number result;

    result = asin(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_atan(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.4
    d_number result;

    result = atan(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_atan2(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.5
    d_number n1;
    Value *v2;
    d_number result;

    n1 = math_helper(arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = atan2(n1, v2.toNumber());
    ret.putVnumber(result);
    return null;
}

void* Dmath_ceil(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.6
    d_number result;

    result = ceil(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_cos(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.7
    d_number result;

    result = cos(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_exp(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.8
    d_number result;

    result = std.math.exp(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_floor(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.9
    d_number result;

    result = std.math.floor(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_log(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.10
    d_number result;

    result = log(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_max(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.8.2.11
    d_number n;
    d_number result;
    uint a;

    result = -d_number.infinity;
    foreach (Value v; arglist)
    {
        n = v.toNumber();
        if (isnan(n))
        {   result = d_number.nan;
            break;
        }
        if (result == n)
        {
            // if n is +0 and result is -0, pick n
            if (n == 0 && !signbit(n))
                result = n;
        }
        else if (n > result)
            result = n;
    }
    ret.putVnumber(result);
    return null;
}

void* Dmath_min(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA v3 15.8.2.12
    d_number n;
    d_number result;
    uint a;

    result = d_number.infinity;
    foreach (Value v; arglist)
    {
        n = v.toNumber();
        if (isnan(n))
        {   result = d_number.nan;
            break;
        }
        if (result == n)
        {
            // if n is -0 and result is +0, pick n
            if (n == 0 && signbit(n))
                result = n;
        }
        else if (n < result)
            result = n;
    }
    ret.putVnumber(result);
    return null;
}

void* Dmath_pow(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.13
    d_number n1;
    Value *v2;
    d_number result;

    n1 = math_helper(arglist);
    v2 = (arglist.length >= 2) ? &arglist[1] : &vundefined;
    result = pow(n1, v2.toNumber());
    ret.putVnumber(result);
    return null;
}

void* Dmath_random(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.14
    // 0.0 <= result < 1.0
    d_number result;

    ulong x;

    // Only want 53 bits of precision
    x = (cast(ulong)std.random.rand() << 32) + std.random.rand();
    //PRINTF("x = x%016llx\n",x);
    x &= 0xFFFFFFFFFFFFF800L;
    result = x  * (1 / (0x100000000L * cast(double)0x100000000L))
                + (1 / (0x200000000L * cast(double)0x100000000L));

    // Experiments on linux show that this will never be exactly
    // 1.0, so is the assert() worth it?
    assert(result >= 0 && result < 1.0);
    ret.putVnumber(result);
    return null;
}

void* Dmath_round(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.15
    d_number result;

    result = math_helper(arglist);
    if (!isnan(result))
        result = copysign(std.math.floor(result + .5), result);
    ret.putVnumber(result);
    return null;
}

void* Dmath_sin(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.16
    d_number result;

    result = sin(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_sqrt(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.17
    d_number result;

    result = sqrt(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

void* Dmath_tan(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.8.2.18
    d_number result;

    result = tan(math_helper(arglist));
    ret.putVnumber(result);
    return null;
}

/* ===================== Dmath ==================== */

class Dmath : Dobject
{
    this(ThreadContext *tc)
    {
        super(tc.Dobject_prototype);

        //writef("Dmath::Dmath(%x)\n", this);
        uint attributes = DontEnum | DontDelete | ReadOnly;

        struct MathConst
        {   d_string *name;
            d_number value;
        }

        static MathConst table[] =
        [
            {   &TEXT_E,       std.math.E       },
            {   &TEXT_LN10,    std.math.LN10    },
            {   &TEXT_LN2,     std.math.LN2     },
            {   &TEXT_LOG2E,   std.math.LOG2E   },
            {   &TEXT_LOG10E,  std.math.LOG10E  },
            {   &TEXT_PI,      std.math.PI      },
            {   &TEXT_SQRT1_2, std.math.SQRT1_2 },
            {   &TEXT_SQRT2,   std.math.SQRT2   },
        ];

        for (size_t u = 0; u < table.length; u++)
        {   Value *v;

            v = Put(*table[u].name, table[u].value, attributes);
            //writef("Put(%s,%.5g) = %x\n", *table[u].name, table[u].value, v);
        }

        classname = TEXT_Math;

        static NativeFunctionData nfd[] =
        [
            {   &TEXT_abs,    &Dmath_abs,    1 },
            {   &TEXT_acos,   &Dmath_acos,   1 },
            {   &TEXT_asin,   &Dmath_asin,   1 },
            {   &TEXT_atan,   &Dmath_atan,   1 },
            {   &TEXT_atan2,  &Dmath_atan2,  2 },
            {   &TEXT_ceil,   &Dmath_ceil,   1 },
            {   &TEXT_cos,    &Dmath_cos,    1 },
            {   &TEXT_exp,    &Dmath_exp,    1 },
            {   &TEXT_floor,  &Dmath_floor,  1 },
            {   &TEXT_log,    &Dmath_log,    1 },
            {   &TEXT_max,    &Dmath_max,    2 },
            {   &TEXT_min,    &Dmath_min,    2 },
            {   &TEXT_pow,    &Dmath_pow,    2 },
            {   &TEXT_random, &Dmath_random, 0 },
            {   &TEXT_round,  &Dmath_round,  1 },
            {   &TEXT_sin,    &Dmath_sin,    1 },
            {   &TEXT_sqrt,   &Dmath_sqrt,   1 },
            {   &TEXT_tan,    &Dmath_tan,    1 },
        ];

        DnativeFunction.init(this, nfd, attributes);
    }

    static void init(ThreadContext *tc)
    {
        tc.Dmath_object = new Dmath(tc);
    }
}

