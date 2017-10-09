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


module dmdscript.darray;

//Nonstandard treatment of Infinity as array length in slice/splice functions, supported by majority of browsers
//also treats negative starting index in splice wrapping it around just like in slice
version =  SliceSpliceExtension;

import std.string;
import core.stdc.stdlib;
import std.math;

import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.threadcontext;
import dmdscript.identifier;
import dmdscript.dfunction;
import dmdscript.text;
import dmdscript.property;
import dmdscript.errmsgs;
import dmdscript.dnative;
import dmdscript.program;

/* ===================== Darray_constructor ==================== */

class DarrayConstructor : Dfunction
{
    this(CallContext* cc)
    {
        super(cc, 1, cc.tc.Dfunction_prototype);
        name = "Array";
    }

    override void* Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.4.2
        Darray a;

        a = new Darray(cc);
        if(arglist.length == 0)
        {
            a.ulength = 0;
            a.length.number = 0;
        }
        else if(arglist.length == 1)
        {
            Value* v = &arglist[0];

            if(v.isNumber())
            {
                d_uint32 len;

                len = v.toUint32(cc);
                if(cast(double)len != v.number)
                {
                    ErrInfo errinfo;

                    ret.putVundefined();
                    return RangeError(&errinfo, cc, ERR_ARRAY_LEN_OUT_OF_BOUNDS, v.number);
                }
                else
                {
                    a.ulength = len;
                    a.length.number = len;
                    /+
                       if (len > 16)
                       {
                        //writef("setting %p dimension to %d\n", &a.proptable, len);
                        if (len > 10000)
                            len = 10000;		// cap so we don't run out of memory
                        a.proptable.roots.setDim(len);
                        a.proptable.roots.zero();
                       }
                     +/
                }
            }
            else
            {
                a.ulength = 1;
                a.length.number = 1;
                a.Put(cc, cast(d_uint32)0, v, 0);
            }
        }
        else
        {
            //if (arglist.length > 10) writef("Array constructor: arglist.length = %d\n", arglist.length);
            /+
               if (arglist.length > 16)
               {
                a.proptable.roots.setDim(arglist.length);
                a.proptable.roots.zero();
               }
             +/
            a.ulength = cast(uint)arglist.length;
            a.length.number = arglist.length;
            for(uint k = 0; k < arglist.length; k++)
            {
                a.Put(cc, k, &arglist[k], 0);
            }
        }
        Value.copy(ret, &a.value);
        //writef("Darray_constructor.Construct(): length = %g\n", a.length.number);
        return null;
    }

    override void* Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.4.1
        return Construct(cc, ret, arglist);
    }
}


/* ===================== Darray_prototype_toString ================= */

void *Darray_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    //writef("Darray_prototype_toString()\n");
    array_join(othis, cc, ret, null);
    return null;
}

/* ===================== Darray_prototype_toLocaleString ================= */

void *Darray_prototype_toLocaleString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.3
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    //writef("array_join(othis = %p)\n", othis);

    if(!othis.isClass(TEXT_Array))
    {
        ret.putVundefined();
        ErrInfo errinfo;
        return Dobject.RuntimeError(&errinfo, cc, ERR_TLS_NOT_TRANSFERRABLE);
    }

    v = othis.Get(TEXT_length);
    len = v ? v.toUint32(cc) : 0;

    Program prog = cc.prog;
    if(!prog.slist)
    {
        // Determine what list separator is only once per thread
        //prog.slist = list_separator(prog.lcid);
        prog.slist = ",";
    }
    separator = prog.slist;

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k);
        if(v && !v.isUndefinedOrNull())
        {
            Dobject ot;

            ot = v.toObject(cc);
            v = ot.Get(TEXT_toLocaleString);
            if(v && !v.isPrimitive())   // if it's an Object
            {
                void* a;
                Dobject o;
                Value rt;

                o = v.object;
                rt.putVundefined();
                a = o.Call(cc, ot, &rt, null);
                if(a)                   // if exception was thrown
                    return a;
                r ~= rt.toString(cc);
            }
        }
    }

    ret.putVstring(r);
    return null;
}

/* ===================== Darray_prototype_concat ================= */

void *Darray_prototype_concat(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.4
    Darray A;
    Darray E;
    Value* v;
    d_uint32 k;
    d_uint32 n;
    d_uint32 a;

    A = new Darray(cc);
    n = 0;
    v = &othis.value;
    for(a = 0;; a++)
    {
        if(!v.isPrimitive() && v.object.isDarray())
        {
            d_uint32 len;

            E = cast(Darray)v.object;
            len = E.ulength;
            for(k = 0; k != len; k++)
            {
                v = E.Get(k);
                if(v)
                    A.Put(cc, n, v, 0);
                n++;
            }
        }
        else
        {
            A.Put(cc, n, v, 0);
            n++;
        }
        if(a == arglist.length)
            break;
        v = &arglist[a];
    }

    A.Put(cc, TEXT_length, n,  DontEnum);
    Value.copy(ret, &A.value);
    return null;
}

/* ===================== Darray_prototype_join ================= */

void *Darray_prototype_join(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    array_join(othis, cc, ret, arglist);
    return null;
}

void array_join(Dobject othis, CallContext* cc, Value* ret, Value[] arglist)
{
    // ECMA 15.4.4.3
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    //writef("array_join(othis = %p)\n", othis);
    v = othis.Get(TEXT_length);
    len = v ? v.toUint32(cc) : 0;
    if(arglist.length == 0 || arglist[0].isUndefined())
        separator = TEXT_comma;
    else
        separator = arglist[0].toString(cc);

    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toString(cc);
    }

    ret.putVstring(r);
}

/* ===================== Darray_prototype_toSource ================= */

void *Darray_prototype_toSource(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    d_string separator;
    d_string r;
    d_uint32 len;
    d_uint32 k;
    Value* v;

    v = othis.Get(TEXT_length);
    len = v ? v.toUint32(cc) : 0;
    separator = ",";

    r = "[".idup;
    for(k = 0; k != len; k++)
    {
        if(k)
            r ~= separator;
        v = othis.Get(k);
        if(v && !v.isUndefinedOrNull())
            r ~= v.toSource(cc);
    }
    r ~= "]";

    ret.putVstring(r);
    return null;
}


/* ===================== Darray_prototype_pop ================= */

void *Darray_prototype_pop(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.6
    Value* v;
    d_uint32 u;

    // If othis is a Darray, then we can optimize this significantly
    v = othis.Get(TEXT_length);
    if(!v)
        v = &vundefined;
    u = v.toUint32(cc);
    if(u == 0)
    {
        othis.Put(cc, TEXT_length, 0.0,  DontEnum);
        ret.putVundefined();
    }
    else
    {
        v = othis.Get(u - 1);
        if(!v)
            v = &vundefined;
        Value.copy(ret, v);
        othis.Delete(u - 1);
        othis.Put(cc, TEXT_length, u - 1,  DontEnum);
    }
    return null;
}

/* ===================== Darray_prototype_push ================= */

void *Darray_prototype_push(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.7
    Value* v;
    d_uint32 u;
    d_uint32 a;

    // If othis is a Darray, then we can optimize this significantly
    v = othis.Get(TEXT_length);
    if(!v)
        v = &vundefined;
    u = v.toUint32(cc);
    for(a = 0; a < arglist.length; a++)
    {
        othis.Put(cc, u + a, &arglist[a], 0);
    }
    othis.Put(cc, TEXT_length, u + a,  DontEnum);
    ret.putVnumber(u + a);
    return null;
}

/* ===================== Darray_prototype_reverse ================= */

void *Darray_prototype_reverse(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA 15.4.4.4
    d_uint32 a;
    d_uint32 b;
    Value* va;
    Value* vb;
    Value* v;
    d_uint32 pivot;
    d_uint32 len;
    Value tmp;

    v = othis.Get(TEXT_length);
    len = v ? v.toUint32(cc) : 0;
    pivot = len / 2;
    for(a = 0; a != pivot; a++)
    {
        b = len - a - 1;
        //writef("a = %d, b = %d\n", a, b);
        va = othis.Get(a);
        if(va)
            Value.copy(&tmp, va);
        vb = othis.Get(b);
        if(vb)
            othis.Put(cc, a, vb, 0);
        else
            othis.Delete(a);

        if(va)
            othis.Put(cc, b, &tmp, 0);
        else
            othis.Delete(b);
    }
    Value.copy(ret, &othis.value);
    return null;
}

/* ===================== Darray_prototype_shift ================= */

void *Darray_prototype_shift(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.9
    Value* v;
    Value* result;
    d_uint32 len;
    d_uint32 k;

    // If othis is a Darray, then we can optimize this significantly
    //writef("shift(othis = %p)\n", othis);
    v = othis.Get(TEXT_length);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);
    
    if(len)
    {
        result = othis.Get(0u);
        Value.copy(ret, result ? result : &vundefined);
        for(k = 1; k != len; k++)
        {
            v = othis.Get(k);
            if(v)
            {
                othis.Put(cc, k - 1, v, 0);
            }
            else
            {
                othis.Delete(k - 1);
            }
        }
        othis.Delete(len - 1);
        len--;
    }
    else
        Value.copy(ret, &vundefined);

    othis.Put(cc, TEXT_length, len, DontEnum);
    return null;
}


/* ===================== Darray_prototype_slice ================= */

void *Darray_prototype_slice(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.10
    d_uint32 len;
    d_uint32 n;
    d_uint32 k;
    d_uint32 r8;

    Value* v;
    Darray A;

    v = othis.Get(TEXT_length);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);

version(SliceSpliceExtension){
    d_number start;
    d_number end;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber(cc);
        end = len;
        break;

    case 1:
        start = arglist[0].toNumber(cc);
        end = len;
        break;

    default:
        start = arglist[0].toNumber(cc);
		if(arglist[1].isUndefined())
			end = len;
		else{
			end = arglist[1].toNumber(cc);
		}
        break;
    }
    if(start < 0)
    {
        k = cast(uint)(len + start);
        if(cast(d_int32)k < 0)
            k = 0;
    }
    else if(start == d_number.infinity)
        k = len;
    else if(start == -d_number.infinity)
        k = 0;
    else
    {
        k = cast(uint)start;
        if(len < k)
            k = len;
    }

    if(end < 0)
    {
        r8 = cast(uint)(len + end);
        if(cast(d_int32)r8 < 0)
            r8 = 0;
    }
    else if(end == d_number.infinity)
            r8 = len;
    else if(end == -d_number.infinity)
            r8 = 0;
    else
    {
        r8 = cast(uint)end;
        if(len < end)
            r8 = len;
    }
}
else{//Canonical ECMA all kinds of infinity maped to 0
    int start;
    int end;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toInt32();
        end = len;
        break;

    case 1:
        start = arglist[0].toInt32();
        end = len;
        break;

    default:
        start = arglist[0].toInt32();
		if(arglist[1].isUndefined())
			end = len;
		else{
			end = arglist[1].toInt32();
		}
        break;
    }
    if(start < 0)
    {
        k = cast(uint)(len + start);
        if(cast(d_int32)k < 0)
            k = 0;
    }
    else
    {
        k = cast(uint)start;
        if(len < k)
            k = len;
    }

    if(end < 0)
    {
        r8 = cast(uint)(len + end);
        if(cast(d_int32)r8 < 0)
            r8 = 0;
    }
    else
    {
        r8 = cast(uint)end;
        if(len < end)
            r8 = len;
    }
}
    A = new Darray(cc);
    for(n = 0; k < r8; k++)
    {
        v = othis.Get(k);
        if(v)
        {
            A.Put(cc, n, v, 0);
        }
        n++;
    }

    A.Put(cc, TEXT_length, n, DontEnum);
    Value.copy(ret, &A.value);
    return null;
}

/* ===================== Darray_prototype_sort ================= */


void *Darray_prototype_sort(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.11
    Value* v;
    d_uint32 len;
    uint u;

    //writef("Array.prototype.sort()\n");
    v = othis.Get(TEXT_length);
    len = v ? v.toUint32(cc) : 0;

    // This is not optimal, as isArrayIndex is done at least twice
    // for every array member. Additionally, the qsort() by index
    // can be avoided if we can deduce it is not a sparse array.

    Property *p;
    Value[] pvalues;
    d_uint32[] pindices;
    d_uint32 parraydim;
    d_uint32 nprops;

    // First, size & alloc our temp array
    if(len < 100)
    {   // Probably not too sparse an array
        parraydim = len;
    }
    else
    {
        parraydim = 0;
        foreach(ref Property p; *othis.proptable)
        {
            if(p.attributes == 0)       // don't count special properties
                parraydim++;
        }
        if(parraydim > len)             // could theoretically happen
            parraydim = len;
    }

    Value[] p1 = null;
    Value* v1;
    version(Win32)      // eh and alloca() not working under linux
    {
        if(parraydim < 128)
            v1 = cast(Value*)alloca(parraydim * Value.sizeof);
    }
    if(v1)
        pvalues = v1[0 .. parraydim];
    else
    {
        p1 = new Value[parraydim];
        pvalues = p1;
    }

    d_uint32[] p2 = null;
    d_uint32* p3;
    version(Win32)
    {
        if(parraydim < 128)
            p3 = cast(d_uint32*)alloca(parraydim * d_uint32.sizeof);
    }
    if(p3)
        pindices = p3[0 .. parraydim];
    else
    {
        p2 = new d_uint32[parraydim];
        pindices = p2;
    }

    // Now fill it with all the Property's that are array indices
    nprops = 0;
    foreach(Value key, ref Property p; *othis.proptable)
    {
        d_uint32 index;

        if(p.attributes == 0 && key.isArrayIndex(cc, index))
        {
            pindices[nprops] = index;
            Value.copy(&pvalues[nprops], &p.value);
            nprops++;
        }
    }

    synchronized
    {
        Dobject comparefn;

        if(arglist.length)
        {
            if(!arglist[0].isPrimitive())
                comparefn = arglist[0].object;
        }


        bool compare_value(ref Value vx, ref Value vy)
        {
            d_string sx;
            d_string sy;
            int cmp;

            //writef("compare_value()\n");
            if(vx.isUndefined())
            {
                cmp = (vy.isUndefined()) ? 0 : 1;
            }
            else if(vy.isUndefined())
                cmp = -1;
            else
            {
                if(comparefn)
                {
                    Value[2] arglist;
                    Value ret;
                    Value* v;
                    d_number n;

                    Value.copy(&arglist[0], &vx);
                    Value.copy(&arglist[1], &vy);
                    ret.putVundefined();
                    comparefn.Call(cc, comparefn, &ret, arglist);
                    n = ret.toNumber(cc);
                    if(n < 0)
                        cmp = -1;
                    else if(n > 0)
                        cmp = 1;
                    else
                        cmp = 0;
                }
                else
                {
                    sx = vx.toString(cc);
                    sy = vy.toString(cc);
                    cmp = std.string.cmp(sx, sy);
                    if(cmp < 0)
                        cmp = -1;
                    else if(cmp > 0)
                        cmp = 1;
                }
            }
            return cmp < 0;
        }

        // Sort pvalues[]
        import std.algorithm.sorting : sort;
        pvalues[0 .. nprops].sort!compare_value();
    }

    // Stuff the sorted value's back into the array
    for(u = 0; u < nprops; u++)
    {
        d_uint32 index;

        othis.Put(cc, u, &pvalues[u], 0);
        index = pindices[u];
        if(index >= nprops)
        {
            othis.Delete(index);
        }
    }

    delete p1;
    delete p2;

    ret.putVobject(othis);
    return null;
}

/* ===================== Darray_prototype_splice ================= */

void *Darray_prototype_splice(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.12
    d_uint32 len;
    d_uint32 k;
    
    Value* v;
    Darray A;
    d_uint32 a;
    d_uint32 delcnt;
    d_uint32 inscnt;
    d_uint32 startidx;
    
    v = othis.Get(TEXT_length);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);
    
version(SliceSpliceExtension){
    d_number start;
    d_number deleteCount;
    
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toNumber(cc);
        deleteCount = 0;
        break;

    case 1:
        start = arglist[0].toNumber(cc);
        deleteCount = vundefined.toNumber(cc);
        break;

    default:
        start = arglist[0].toNumber(cc);
        deleteCount = arglist[1].toNumber(cc);
		//checked later
        break;
    }
    if(start == d_number.infinity)
        startidx = len;
    else if(start == -d_number.infinity)
        startidx = 0;
    else{
        if(start < 0)
        {
            startidx = cast(uint)(len + start);
            if(cast(d_int32)startidx < 0)
                startidx = 0;
        }
        else
            startidx = cast(uint)start;
    }
	startidx = startidx > len ? len : startidx; 
    if(deleteCount == d_number.infinity)
        delcnt = len;
    else if(deleteCount == -d_number.infinity)
        delcnt = 0;
    else
        delcnt = (cast(uint)deleteCount > 0) ? cast(uint) deleteCount : 0;
    if(delcnt > len - startidx)
        delcnt = len - startidx;
}else{    
    long start;
    d_int32 deleteCount;
    switch(arglist.length)
    {
    case 0:
        start = vundefined.toInt32();
        deleteCount = 0;
        break;

    case 1:
        start = arglist[0].toInt32();
        deleteCount = vundefined.toInt32();
        break;

    default:
        start = arglist[0].toInt32();
        deleteCount = arglist[1].toInt32();
		//checked later
        break;
    }
    startidx = cast(uint)start;
	startidx = startidx > len ? len : startidx; 
    delcnt = (deleteCount > 0) ? deleteCount : 0;
    if(delcnt > len - startidx)
        delcnt = len - startidx;
}
	
    A = new Darray(cc);

    // If deleteCount is not specified, ECMA implies it should
    // be 0, while "JavaScript The Definitive Guide" says it should
    // be delete to end of array. Jscript doesn't implement splice().
    // We'll do it the Guide way.
    if(arglist.length < 2)
        delcnt = len - startidx;

    //writef("Darray.splice(startidx = %d, delcnt = %d)\n", startidx, delcnt);
    for(k = 0; k != delcnt; k++)
    {
        v = othis.Get(startidx + k);
        if(v)
            A.Put(cc, k, v, 0);
    }

    A.Put(cc, TEXT_length, delcnt, DontEnum);
    inscnt = (arglist.length > 2) ? cast(uint)arglist.length - 2 : 0;
    if(inscnt != delcnt)
    {
        if(inscnt <= delcnt)
        {
            for(k = startidx; k != (len - delcnt); k++)
            {
                v = othis.Get(k + delcnt);
                if(v)
                    othis.Put(cc, k + inscnt, v, 0);
                else
                    othis.Delete(k + inscnt);
            }

            for(k = len; k != (len - delcnt + inscnt); k--)
                othis.Delete(k - 1);
        }
        else
        {
            for(k = len - delcnt; k != startidx; k--)
            {
                v = othis.Get(k + delcnt - 1);
                if(v)
                    othis.Put(cc, k + inscnt - 1, v, 0);
                else
                    othis.Delete(k + inscnt - 1);
            }
        }
    }
    k = startidx;
    for(a = 2; a < arglist.length; a++)
    {
        v = &arglist[a];
        othis.Put(cc, k, v, 0);
        k++;
    }

    othis.Put(cc, TEXT_length, len - delcnt + inscnt,  DontEnum);
    Value.copy(ret, &A.value);
    return null;
}

/* ===================== Darray_prototype_unshift ================= */

void *Darray_prototype_unshift(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.4.4.13
    Value* v;
    d_uint32 len;
    d_uint32 k;

    v = othis.Get(TEXT_length);
    if(!v)
        v = &vundefined;
    len = v.toUint32(cc);

    for(k = len; k>0; k--)
    {
        v = othis.Get(k - 1);
        if(v)
            othis.Put(cc, cast(uint)(k + arglist.length - 1), v, 0);
        else
            othis.Delete(cast(uint)(k + arglist.length - 1));
    }

    for(k = 0; k < arglist.length; k++)
    {
        othis.Put(cc, k, &arglist[k], 0);
    }
    othis.Put(cc, TEXT_length, len + arglist.length,  DontEnum);
    ret.putVnumber(len + arglist.length);
    return null;
}

/* =========================== Darray_prototype =================== */

class DarrayPrototype : Darray
{
    this(CallContext* cc)
    {
        super(cc, cc.tc.Dobject_prototype);
        Dobject f = cc.tc.Dfunction_prototype;

        Put(cc, TEXT_constructor, cc.tc.Darray_constructor, DontEnum);

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_toString, &Darray_prototype_toString, 0 },
            { TEXT_toLocaleString, &Darray_prototype_toLocaleString, 0 },
            { TEXT_toSource, &Darray_prototype_toSource, 0 },
            { TEXT_concat, &Darray_prototype_concat, 1 },
            { TEXT_join, &Darray_prototype_join, 1 },
            { TEXT_pop, &Darray_prototype_pop, 0 },
            { TEXT_push, &Darray_prototype_push, 1 },
            { TEXT_reverse, &Darray_prototype_reverse, 0 },
            { TEXT_shift, &Darray_prototype_shift, 0, },
            { TEXT_slice, &Darray_prototype_slice, 2 },
            { TEXT_sort, &Darray_prototype_sort, 1 },
            { TEXT_splice, &Darray_prototype_splice, 2 },
            { TEXT_unshift, &Darray_prototype_unshift, 1 },
        ];

        DnativeFunction.initialize(this, cc, nfd, DontEnum);
    }
}


/* =========================== Darray =================== */

class Darray : Dobject
{
    Value length;               // length property
    d_uint32 ulength;

    this(CallContext* cc)
    {
        this(cc, getPrototype(cc));
    }

    this(CallContext* cc, Dobject prototype)
    {
        super(cc, prototype);
        length.putVnumber(0);
        ulength = 0;
        classname = TEXT_Array;
    }

    override  Value* Put(CallContext* cc, Identifier* key, Value* value, uint attributes)
    {
        Value* result = proptable.put(&key.value, key.value.hash, value, attributes);
        if(!result)
            Put(cc, key.value.string, value, attributes);
        return null;
    }

    override Value* Put(CallContext* cc, d_string name, Value* v, uint attributes)
    {
        d_uint32 i;
        uint c;
        Value* result;

        // ECMA 15.4.5.1
        result = proptable.put(name, v, attributes);
        if(!result)
        {
            if(name == TEXT_length)
            {
                i = v.toUint32(cc);
                if(i != v.toInteger(cc))
                {
                    ErrInfo errinfo;

                    return Dobject.RangeError(&errinfo, cc, ERR_LENGTH_INT);
                }
                if(i < ulength)
                {
                    // delete all properties with keys >= i
                    d_uint32[] todelete;

                    foreach(Value key, ref Property p; *proptable)
                    {
                        d_uint32 j;

                        j = key.toUint32(cc);
                        if(j >= i)
                            todelete ~= j;
                    }
                    foreach(d_uint32 j; todelete)
                    {
                        proptable.del(j);
                    }
                }
                ulength = i;
                length.number = i;
                proptable.put(name, v, attributes | DontEnum);
            }

            // if (name is an array index i)

            i = 0;
            for(size_t j = 0; j < name.length; j++)
            {
                ulong k;

                c = name[j];
                if(c == '0' && i == 0 && name.length > 1)
                    goto Lret;
                if(c >= '0' && c <= '9')
                {
                    k = i * cast(ulong)10 + c - '0';
                    i = cast(d_uint32)k;
                    if(i != k)
                        goto Lret;              // overflow
                }
                else
                    goto Lret;
            }
            if(i >= ulength)
            {
                if(i == 0xFFFFFFFF)
                    goto Lret;
                ulength = i + 1;
                length.number = ulength;
            }
        }
        Lret:
        return null;
    }

    override Value* Put(CallContext* cc, d_string name, Dobject o, uint attributes)
    {
        return Put(cc, name, &o.value, attributes);
    }

    override Value* Put(CallContext* cc, d_string PropertyName, d_number n, uint attributes)
    {
        Value v;

        v.putVnumber(n);
        return Put(cc, PropertyName, &v, attributes);
    }

    override Value* Put(CallContext* cc, d_string PropertyName, d_string string, uint attributes)
    {
        Value v;

        v.putVstring(string);
        return Put(cc, PropertyName, &v, attributes);
    }

    override Value* Put(CallContext* cc, d_uint32 index, Value* vindex, Value* value, uint attributes)
    {
        if(index >= ulength)
            ulength = index + 1;

        proptable.put(vindex, index ^ 0x55555555 /*Value.calcHash(index)*/, value, attributes);
        return null;
    }

    override Value* Put(CallContext* cc, d_uint32 index, Value* value, uint attributes)
    {
        if(index >= ulength)
        {
            ulength = index + 1;
            length.number = ulength;
        }

        proptable.put(index, value, attributes);
        return null;
    }

    final Value* Put(CallContext* cc, d_uint32 index, d_string string, uint attributes)
    {
        if(index >= ulength)
        {
            ulength = index + 1;
            length.number = ulength;
        }

        proptable.put(index, string, attributes);
        return null;
    }

    override Value* Get(Identifier* id)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(id.value.string == TEXT_length)
        {
            length.number = ulength;
            return &length;
        }
        else
            return Dobject.Get(id);
    }

    override Value* Get(d_string PropertyName, uint hash)
    {
        //writef("Darray.Get(%p, '%s')\n", &proptable, PropertyName);
        if(PropertyName == TEXT_length)
        {
            length.number = ulength;
            return &length;
        }
        else
            return Dobject.Get(PropertyName, hash);
    }

    override Value* Get(d_uint32 index)
    {
        Value* v;

        //writef("Darray.Get(%p, %d)\n", &proptable, index);
        v = proptable.get(index);
        return v;
    }

    override Value* Get(d_uint32 index, Value* vindex)
    {
        Value* v;

        //writef("Darray.Get(%p, %d)\n", &proptable, index);
        v = proptable.get(vindex, index ^ 0x55555555 /*Value.calcHash(index)*/);
        return v;
    }

    override int Delete(d_string PropertyName)
    {
        // ECMA 8.6.2.5
        //writef("Darray.Delete('%ls')\n", d_string_ptr(PropertyName));
        if(PropertyName == TEXT_length)
            return 0;           // can't delete 'length' property
        else
            return proptable.del(PropertyName);
    }

    override int Delete(d_uint32 index)
    {
        // ECMA 8.6.2.5
        return proptable.del(index);
    }


    static Dfunction getConstructor(CallContext* cc)
    {
        return cc.tc.Darray_constructor;
    }

    static Dobject getPrototype(CallContext* cc)
    {
        return cc.tc.Darray_prototype;
    }

    static void initialize(CallContext* cc)
    {
        cc.tc.Darray_constructor = new DarrayConstructor(cc);
        cc.tc.Darray_prototype = new DarrayPrototype(cc);

        cc.tc.Darray_constructor.Put(cc, TEXT_prototype, cc.tc.Darray_prototype, DontEnum |  ReadOnly);
    }
}

