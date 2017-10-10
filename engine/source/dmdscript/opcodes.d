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


module dmdscript.opcodes;

import std.stdio;
import core.stdc.string;
import std.string;
import std.conv;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.statement;
import dmdscript.functiondefinition;
import dmdscript.value;
import dmdscript.iterator;
import dmdscript.scopex;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.ddeclaredfunction;
import dmdscript.dfunction;

//debug=VERIFY;	// verify integrity of code

version = SCOPECACHING;         // turn scope caching on
//version = SCOPECACHE_LOG;	// log statistics on it

// Catch & Finally are "fake" Dobjects that sit in the scope
// chain to implement our exception handling context.

class Catch : Dobject
{
    // This is so scope_get() will skip over these objects
    override Value* Get(d_string PropertyName) const
    {
        return null;
    }
    override Value* Get(d_string PropertyName, uint hash) const
    {
        return null;
    }

    // This is so we can distinguish between a real Dobject
    // and these fakers
    override d_string getTypeof()
    {
        return null;
    }

    uint offset;        // offset of CatchBlock
    d_string name;      // catch identifier

    this(uint offset, d_string name)
    {
        super(null);
        this.offset = offset;
        this.name = name;
    }

    override int isCatch() const
    {
        return true;
    }
}

class Finally : Dobject
{
    override Value* Get(d_string PropertyName) const
    {
        return null;
    }
    override Value* Get(d_string PropertyName, uint hash) const
    {
        return null;
    }
    override d_string getTypeof()
    {
        return null;
    }

    IR *finallyblock;    // code for FinallyBlock

    this(IR * finallyblock)
    {
        super(null);
        this.finallyblock = finallyblock;
    }

    override int isFinally() const
    {
        return true;
    }
}


/************************
 * Look for identifier in scope.
 */

Value* scope_get(Dobject[] scopex, Identifier* id, Dobject *pthis)
{
    size_t d;
    Dobject o;
    Value* v;

    //writef("scope_get: scope = %p, scope.data = %p\n", scopex, scopex.data);
    //writefln("scope_get: scopex = %x, length = %d, id = %s", cast(uint)scopex.ptr, scopex.length, id.toString());
    d = scopex.length;
    for(;; )
    {
        if(!d)
        {
            v = null;
            *pthis = null;
            break;
        }
        d--;
        o = scopex[d];
        //writef("o = %x, hash = x%x, s = '%s'\n", o, hash, s);
        v = o.Get(id);
        if(v)
        {
            *pthis = o;
            break;
        }
    }
    return v;
}

Value* scope_get_lambda(Dobject[] scopex, Identifier* id, Dobject *pthis)
{
    size_t d;
    Dobject o;
    Value* v;

    //writefln("scope_get_lambda: scope = %x, length = %d, id = %s", cast(uint)scopex.ptr, scopex.length, id.toString());
    d = scopex.length;
    for(;; )
    {
        if(!d)
        {
            v = null;
            *pthis = null;
            break;
        }
        d--;
        o = scopex[d];
        //printf("o = %p ", o);
        //writefln("o = %s", o);
        //printf("o = %x, hash = x%x, s = '%.*s'\n", o, hash, s);
        //v = o.GetLambda(s, hash);
        v = o.Get(id);
        if(v)
        {
            *pthis = o;
            break;
        }
    }
    //writefln("v = %x", cast(uint)cast(void*)v);
    return v;
}

Value* scope_get(Dobject[] scopex, Identifier* id)
{
    size_t d;
    Dobject o;
    Value* v;

    //writefln("scope_get: scopex = %x, length = %d, id = %s", cast(uint)scopex.ptr, scopex.length, id.toString());
    d = scopex.length;
    // 1 is most common case for d
    if(d == 1)
    {
        return scopex[0].Get(id);
    }
    for(;; )
    {
        if(!d)
        {
            v = null;
            break;
        }
        d--;
        o = scopex[d];
        //writefln("\to = %s", o);
        v = o.Get(id);
        if(v)
            break;
        //writefln("\tnot found");
    }
    return v;
}

/************************************
 * Find last object in scopex, null if none.
 */

Dobject scope_tos(Dobject[] scopex)
{
    size_t d;
    Dobject o;

    for(d = scopex.length; d; )
    {
        d--;
        o = scopex[d];
        if(o.getTypeof() != null)  // if not a Finally or a Catch
            return o;
    }
    return null;
}

/*****************************************
 */

void PutValue(CallContext *cc, d_string s, Value* a)
{
    // ECMA v3 8.7.2
    // Look for the object o in the scope chain.
    // If we find it, put its value.
    // If we don't find it, put it into the global object

    size_t d;
    uint hash;
    Value* v;
    Dobject o;
    //a.checkReference();
    d = cc.scopex.length;
    if(d == cc.globalroot)
    {
        o = scope_tos(cc.scopex);
        o.Put(s, a, 0);
        return;
    }

    hash = Value.calcHash(s);

    for(;; d--)
    {
        assert(d > 0);
        o = cc.scopex[d - 1];
        
        v = o.Get(s, hash);
        if(v)
        {
            // Overwrite existing property with new one
            v.checkReference();
            o.Put(s, a, 0);
            break;
        }
        if(d == cc.globalroot)
        {
            o.Put(s, a, 0);
            return;
        }
    }
}


void PutValue(CallContext *cc, Identifier* id, Value* a)
{
    // ECMA v3 8.7.2
    // Look for the object o in the scope chain.
    // If we find it, put its value.
    // If we don't find it, put it into the global object

    size_t d;
    Value* v;
    Dobject o;
    //a.checkReference();
    d = cc.scopex.length;
    if(d == cc.globalroot)
    {
        o = scope_tos(cc.scopex);
    }
    else
    {
        for(;; d--)
        {
            assert(d > 0);
            o = cc.scopex[d - 1];
            v = o.Get(id);
            if(v)
            {
                v.checkReference();
                break;// Overwrite existing property with new one
            }
            if(d == cc.globalroot)
                break;
        }
    }
    o.Put(id, a, 0);
}


/*****************************************
 * Helper function for Values that cannot be converted to Objects.
 */

Value* cannotConvert(Value* b, int linnum)
{
    ErrInfo errinfo;

    errinfo.linnum = linnum;
    if(b.isUndefinedOrNull())
    {
        b = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_CANNOT_CONVERT_TO_OBJECT4],
                                 b.getType());
    }
    else
    {
        b = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_CANNOT_CONVERT_TO_OBJECT2],
                                 b.getType(), b.toString());
    }
    return b;
}

const uint INDEX_FACTOR = 16;   // or 1

struct IR
{
    import core.stdc.stdint : uintptr_t;
    alias Op = uintptr_t;

    static assert(IR.sizeof == Op.sizeof);

    union
    {
        struct
        {
            version(LittleEndian)
            {
                ubyte opcode;
                static if (Op.sizeof == uint.sizeof) {
                    ubyte padding;
                    ushort linnum;
                } else {
                    ubyte[3] padding;
                    uint linnum;
                }
            }
            else
            {
                static if (Op.sizeof == uint.sizeof) {
                    ushort linnum;
                    ubyte padding;
                    ubyte opcode;
                } else {
                    uint linnum;
                    ubyte[3] padding;
                    ubyte opcode;
                }
            }
        }
                    IR* code;
        Value*      value;
        // NOTE: this must be a uintptr_t, because it is frequently used to read
        // the operand bits for a pointer value when generating the IR
        uintptr_t        index;      // index into local variable table
        uint        hash;       // cached hash value
        int         offset;
        Identifier* id;
        d_boolean   boolean;
        Statement   target;     // used for backpatch fixups
        Dobject     object;
        void*       ptr;
    }

    /****************************
     * This is the main interpreter loop.
     */

    static void *call(CallContext *cc, Dobject othis,
                      IR *code, Value* ret, Value* locals)
    {
        Value* a;
        Value* b;
        Value* c;
        Value* v;
        Iterator *iter;
        Identifier *id;
        d_string s;
        d_string s2;
        d_number n;
        d_boolean bo;
        d_int32 i32;
        d_uint32 u32;
        d_boolean res;
        d_string tx;
        d_string ty;
        Dobject o;
        Dobject[] scopex;
        uint dimsave;
        uint offset;
        Catch ca;
        Finally f;
        IR* codestart = code;
        //Finally blocks are sort of called, sort of jumped to 
        //So we are doing "push IP in some stack" + "jump"
        IR*[] finallyStack;      //it's a stack of backreferences for finally
        d_number inc;
        void callFinally(Finally f){
            //cc.scopex = scopex;
            finallyStack ~= code;
            code = f.finallyblock;
        }
        Value* unwindStack(Value* err){
                assert(scopex.length && scopex[0] !is null,"Null in scopex, Line " ~ to!string(code.linnum));
                a = err;
                //v = scope_get(scopex,Identifier.build("mycars2"));
                //a.getErrInfo(null, GETlinnum(code));
                
                for(;; )
                {
                    if(scopex.length <= dimsave)
                    {
                        ret.putVundefined();
                        // 'a' may be pointing into the stack, which means
                        // it gets scrambled on return. Therefore, we copy
                        // its contents into a safe area in CallContext.
                        assert(cc.value.sizeof == Value.sizeof);
                        Value.copy(&cc.value, a);
                        return &cc.value;
                    }
                    o = scopex[$ - 1];
                    scopex = scopex[0 .. $ - 1];            // pop entry off scope chain
                    
                    if(o.isCatch())
                    {
                        ca = cast(Catch)o;
                        //writef("catch('%s')\n", ca.name);
                        o = new Dobject(Dobject.getPrototype());
                        version(JSCRIPT_CATCH_BUG)
                        {
                            PutValue(cc, ca.name, a);
                        }
                        else
                        {
                            o.Put(ca.name, a, DontDelete);
                        }
                        scopex ~= o;
                        cc.scopex = scopex;
                        code = codestart + ca.offset;
                        break;
                    }
                    else
                    {
                        if(o.isFinally())
                        {
                            f = cast(Finally)o;
                            callFinally(f);
                            break;
                        }
                    }
                }
                return null;
        }
        /***************************************
         * Cache for getscope's
         */
        version(SCOPECACHING)
        {
            struct ScopeCache
            {
                d_string s;
                Value*   v;     // never null, and never from a Dcomobject
            }
            int si;
            ScopeCache zero;
            ScopeCache[16] scopecache;
            version(SCOPECACHE_LOG)
                int scopecache_cnt = 0;

            uint SCOPECACHE_SI(immutable(tchar)* s)
            {
                return (cast(uint)(s)) & 15;
            }
            void SCOPECACHE_CLEAR()
            {
                scopecache[] = zero;
            }
        }
        else
        {
            uint SCOPECACHE_SI(d_string s)
            {
                return 0;
            }
            void SCOPECACHE_CLEAR()
            {
            }
        }

        version(all)
        {
            // Eliminate the scale factor of Value.sizeof by computing it at compile time
            Value* GETa(IR* code)
            {
                return cast(Value*)(cast(void*)locals + (code + 1).index * (16 / INDEX_FACTOR));
            }
            Value* GETb(IR* code)
            {
                return cast(Value*)(cast(void*)locals + (code + 2).index * (16 / INDEX_FACTOR));
            }
            Value* GETc(IR* code)
            {
                return cast(Value*)(cast(void*)locals + (code + 3).index * (16 / INDEX_FACTOR));
            }
            Value* GETd(IR* code)
            {
                return cast(Value*)(cast(void*)locals + (code + 4).index * (16 / INDEX_FACTOR));
            }
            Value* GETe(IR* code)
            {
                return cast(Value*)(cast(void*)locals + (code + 5).index * (16 / INDEX_FACTOR));
            }
        }
        else
        {
            Value* GETa(IR* code)
            {
                return &locals[(code + 1).index];
            }
            Value* GETb(IR* code)
            {
                return &locals[(code + 2).index];
            }
            Value* GETc(IR* code)
            {
                return &locals[(code + 3).index];
            }
            Value* GETd(IR* code)
            {
                return &locals[(code + 4).index];
            }
            Value* GETe(IR* code)
            {
                return &locals[(code + 5).index];
            }
        }

        uint GETlinnum(IR* code)
        {
            return code.linnum;
        }

        debug(VERIFY) uint checksum = IR.verify(__LINE__, code);

        version(none)
        {
            writefln("+printfunc");
            printfunc(code);
            writefln("-printfunc");
        }
        scopex = cc.scopex;
        //printf("call: scope = %p, length = %d\n", scopex.ptr, scopex.length);
        dimsave = cast(uint)scopex.length;
        //if (logflag)
        //    writef("IR.call(othis = %p, code = %p, locals = %p)\n",othis,code,locals);

        //debug
        version(none) //no data field in scop struct
        {
            uint debug_scoperoot = cc.scoperoot;
            uint debug_globalroot = cc.globalroot;
            uint debug_scopedim = scopex.length;
            uint debug_scopeallocdim = scopex.allocdim;
            Dobject debug_global = cc.global;
            Dobject debug_variable = cc.variable;

            void** debug_pscoperootdata = cast(void**)mem.malloc((void*).sizeof * debug_scoperoot);
            void** debug_pglobalrootdata = cast(void**)mem.malloc((void*).sizeof * debug_globalroot);

            memcpy(debug_pscoperootdata, scopex.data, (void*).sizeof * debug_scoperoot);
            memcpy(debug_pglobalrootdata, scopex.data, (void*).sizeof * debug_globalroot);
        }

        assert(code);
        assert(othis);
        
        for(;; )
        {
            Lnext:
            //writef("cc = %x, interrupt = %d\n", cc, cc.Interrupt);
            if(cc.Interrupt)                    // see if script was interrupted
                goto Linterrupt;
            try{
                version(none)
                {
                    writef("Scopex len: %d ",scopex.length);
                    writef("%2d:", code - codestart);
                    print(cast(uint)(code - codestart), code);
                    writeln();
                }

                //debug
                version(none) //no data field in scop struct
                {
                    assert(scopex == cc.scopex);
                    assert(debug_scoperoot == cc.scoperoot);
                    assert(debug_globalroot == cc.globalroot);
                    assert(debug_global == cc.global);
                    assert(debug_variable == cc.variable);
                    assert(scopex.length >= debug_scoperoot);
                    assert(scopex.length >= debug_globalroot);
                    assert(scopex.length >= debug_scopedim);
                    assert(scopex.allocdim >= debug_scopeallocdim);
                    assert(0 == memcmp(debug_pscoperootdata, scopex.data, (void*).sizeof * debug_scoperoot));
                    assert(0 == memcmp(debug_pglobalrootdata, scopex.data, (void*).sizeof * debug_globalroot));
                    assert(scopex);
                }

                //writef("\tIR%d:\n", code.opcode);

                switch(code.opcode)
                {
                case IRerror:
                    assert(0);

                case IRnop:
                    code++;
                    break;

                case IRget:                 // a = b.c
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        a = cannotConvert(b, GETlinnum(code));
                        goto Lthrow;
                    }
                    c = GETc(code);
                    if(c.vtype == V_NUMBER &&
                       (i32 = cast(d_int32)c.number) == c.number &&
                       i32 >= 0)
                    {
                        //writef("IRget %d\n", i32);
                        v = o.Get(cast(d_uint32)i32, c);
                    }
                    else
                    {
                        s = c.toString();
                        v = o.Get(s);
                    }
                    if(!v)
                        v = &vundefined;
                    Value.copy(a, v);
                    code += 4;
                    break;

                case IRput:                 // b.c = a
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(c.vtype == V_NUMBER &&
                       (i32 = cast(d_int32)c.number) == c.number &&
                       i32 >= 0)
                    {
                        //writef("IRput %d\n", i32);
                        if(b.vtype == V_OBJECT)
                            a = b.object.Put(cast(d_uint32)i32, c, a, 0);
                        else
                            a = b.Put(cast(d_uint32)i32, c, a);
                    }
                    else
                    {
                        s = c.toString();
                        a = b.Put(s, a);
                    }
                    if(a)
                        goto Lthrow;
                    code += 4;
                    break;

                case IRgets:                // a = b.s
                    a = GETa(code);
                    b = GETb(code);
                    s = (code + 3).id.value.string;
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s.%s cannot convert to Object", b.getType(), b.toString(), s);
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_CANNOT_CONVERT_TO_OBJECT3],
                                                 b.getType(), b.toString(),
                                                 s);
                        goto Lthrow;
                    }
                    v = o.Get(s);
                    if(!v)
                    {
                        //writef("IRgets: %s.%s is undefined\n", b.getType(), d_string_ptr(s));
                        v = &vundefined;
                    }
                    Value.copy(a, v);
                    code += 4;
                    goto Lnext;
                case IRcheckref: // s
	                id = (code+1).id;
	                s = id.value.string;
	                if(!scope_get(scopex, id))
		                throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR],s)); 
	                code += 2;
	                break;
                case IRgetscope:            // a = s
                    a = GETa(code);
                    id = (code + 2).id;
                    s = id.value.string;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                        {
                            version(SCOPECACHE_LOG)
                                scopecache_cnt++;
                            Value.copy(a, scopecache[si].v);
                            code += 3;
                            break;
                        }
                        //writefln("miss %s, was %s, s.ptr = %x, cache.ptr = %x", s, scopecache[si].s, cast(uint)s.ptr, cast(uint)scopecache[si].s.ptr);
                    }
                    version(all)
                    {
                        v = scope_get(scopex,id);
                        if(!v){
                            v = signalingUndefined(s);
                            PutValue(cc,id,v);
                        }
                        else
                        {
                            version(SCOPECACHING)
                            {
                                if(1) //!o.isDcomobject())
                                {
                                    scopecache[si].s = s;
                                    scopecache[si].v = v;
                                }
                            }
                        }
                    }
                    //writef("v = %p\n", v);
                    //writef("v = %g\n", v.toNumber());
                    //writef("v = %s\n", d_string_ptr(v.toString()));
                    Value.copy(a, v);
                    code += 3;
                    break;

                case IRaddass:              // a = (b.c += a)
                    c = GETc(code);
                    s = c.toString();
                    goto Laddass;

                case IRaddasss:             // a = (b.s += a)
                    s = (code + 3).id.value.string;
                    Laddass:
                    b = GETb(code);
                    v = b.Get(s);
                    goto Laddass2;

                case IRaddassscope:         // a = (s += a)
                    b = null;               // Needed for the b.Put() below to shutup a compiler use-without-init warning
                    id = (code + 2).id;
                    s = id.value.string;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                            v = scopecache[si].v;
                        else
                            v = scope_get(scopex, id);
                    }
                    else
                    {
                        v = scope_get(scopex, id);
                    }
                    Laddass2:
                    a = GETa(code);
                    if(!v)
                    {
						throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR],s));
                        //a.putVundefined();
                        /+
                                            if (b)
                                            {
                                                a = b.Put(s, v);
                                                //if (a) goto Lthrow;
                                            }
                                            else
                                            {
                                                PutValue(cc, s, v);
                                            }
                         +/
                    }
                    else if(a.vtype == V_NUMBER && v.vtype == V_NUMBER)
                    {
                        a.number += v.number;
                        v.number = a.number;
                    }
                    else
                    {
                        v.toPrimitive(v, null);
                        a.toPrimitive(a, null);
                        if(v.isString())
                        {
                            s2 = v.toString() ~a.toString();
                            a.putVstring(s2);
                            Value.copy(v, a);
                        }
                        else if(a.isString())
                        {
                            s2 = v.toString() ~a.toString();
                            a.putVstring(s2);
                            Value.copy(v, a);
                        }
                        else
                        {
                            a.putVnumber(a.toNumber() + v.toNumber());
                            *v = *a;//full copy
                        }
                    }
                    code += 4;
                    break;

                case IRputs:            // b.s = a
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        a = cannotConvert(b, GETlinnum(code));
                        goto Lthrow;
                    }
                    a = o.Put((code + 3).id.value.string, a, 0);
                    if(a)
                        goto Lthrow;
                    code += 4;
                    goto Lnext;

                case IRputscope:            // s = a
                    a = GETa(code);
                    a.checkReference();
                    PutValue(cc, (code + 2).id, a);
                    code += 3;
                    break;

                case IRputdefault:              // b = a
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_CANNOT_ASSIGN], a.getType(),
                                                 b.getType());
                        goto Lthrow;
                    }
                    a = o.PutDefault(a);
                    if(a)
                        goto Lthrow;
                    code += 3;
                    break;

                case IRputthis:             // s = a
                    //a = cc.variable.Put((code + 2).id.value.string, GETa(code), DontDelete);
                    o = scope_tos(scopex);
                    assert(o);
                    if(o.HasProperty((code + 2).id.value.string))
                        a = o.Put((code+2).id.value.string,GETa(code),DontDelete);
                    else
                        a = cc.variable.Put((code + 2).id.value.string, GETa(code), DontDelete);
                    if (a) goto Lthrow;
                    code += 3;
                    break;

                case IRmov:                 // a = b
                    Value.copy(GETa(code), GETb(code));
                    code += 3;
                    break;

                case IRstring:              // a = "string"
                    GETa(code).putVstring((code + 2).id.value.string);
                    code += 3;
                    break;

                case IRobject:              // a = object
                { FunctionDefinition fd;
                  fd = cast(FunctionDefinition)(code + 2).ptr;
                  Dfunction fobject = new DdeclaredFunction(fd);
                  fobject.scopex = scopex;
                  GETa(code).putVobject(fobject);
                  code += 3;
                  break; }

                case IRthis:                // a = this
                    GETa(code).putVobject(othis);
                    //writef("IRthis: %s, othis = %x\n", GETa(code).getType(), othis);
                    code += 2;
                    break;

                case IRnumber:              // a = number
                    GETa(code).putVnumber(*cast(d_number *)(code + 2));
                    code += 2 + d_number.sizeof/Op.sizeof;
                    break;

                case IRboolean:             // a = boolean
                    GETa(code).putVboolean((code + 2).boolean);
                    code += 3;
                    break;

                case IRnull:                // a = null
                    GETa(code).putVnull();
                    code += 2;
                    break;

                case IRundefined:           // a = undefined
                    GETa(code).putVundefined();
                    code += 2;
                    break;

                case IRthisget:             // a = othis.ident
                    a = GETa(code);
                    v = othis.Get((code + 2).id.value.string);
                    if(!v)
                        v = &vundefined;
                    Value.copy(a, v);
                    code += 3;
                    break;

                case IRneg:                 // a = -a
                    a = GETa(code);
                    n = a.toNumber();
                    a.putVnumber(-n);
                    code += 2;
                    break;

                case IRpos:                 // a = a
                    a = GETa(code);
                    n = a.toNumber();
                    a.putVnumber(n);
                    code += 2;
                    break;

                case IRcom:                 // a = ~a
                    a = GETa(code);
                    i32 = a.toInt32();
                    a.putVnumber(~i32);
                    code += 2;
                    break;

                case IRnot:                 // a = !a
                    a = GETa(code);
                    a.putVboolean(!a.toBoolean());
                    code += 2;
                    break;

                case IRtypeof:      // a = typeof a
                    // ECMA 11.4.3 says that if the result of (a)
                    // is a Reference and GetBase(a) is null,
                    // then the result is "undefined". I don't know
                    // what kind of script syntax will generate this.
                    a = GETa(code);
                    a.putVstring(a.getTypeof());
                    code += 2;
                    break;

                case IRinstance:        // a = b instanceof c
                {
                    Dobject co;

                    // ECMA v3 11.8.6

                    b = GETb(code);
                    o = b.toObject();
                    c = GETc(code);
                    if(c.isPrimitive())
                    {
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_RHS_MUST_BE_OBJECT],
                                                 "instanceof", c.getType());
                        goto Lthrow;
                    }
                    co = c.toObject();
                    a = GETa(code);
                    v = cast(Value*)co.HasInstance(a, b);
                    if(v)
                    {
                        a = v;
                        goto Lthrow;
                    }
                    code += 4;
                    break;
                }
                case IRadd:                     // a = b + c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);

                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        a.putVnumber(b.number + c.number);
                    }
                    else
                    {
                        char[Value.sizeof] vtmpb;
                        Value* vb = cast(Value*)vtmpb;
                        char[Value.sizeof] vtmpc;
                        Value* vc = cast(Value*)vtmpc;

                        b.toPrimitive(vb, null);
                        c.toPrimitive(vc, null);

                        if(vb.isString() || vc.isString())
                        {
                            s = vb.toString() ~vc.toString();
                            a.putVstring(s);
                        }
                        else
                        {
                            a.putVnumber(vb.toNumber() + vc.toNumber());
                        }
                    }

                    code += 4;
                    break;

                case IRsub:                 // a = b - c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toNumber() - c.toNumber());
                    code += 4;
                    break;

                case IRmul:                 // a = b * c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toNumber() * c.toNumber());
                    code += 4;
                    break;

                case IRdiv:                 // a = b / c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);

                    //writef("%g / %g = %g\n", b.toNumber() , c.toNumber(), b.toNumber() / c.toNumber());
                    a.putVnumber(b.toNumber() / c.toNumber());
                    code += 4;
                    break;

                case IRmod:                 // a = b % c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toNumber() % c.toNumber());
                    code += 4;
                    break;

                case IRshl:                 // a = b << c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    i32 = b.toInt32();
                    u32 = c.toUint32() & 0x1F;
                    i32 <<= u32;
                    a.putVnumber(i32);
                    code += 4;
                    break;

                case IRshr:                 // a = b >> c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    i32 = b.toInt32();
                    u32 = c.toUint32() & 0x1F;
                    i32 >>= cast(d_int32)u32;
                    a.putVnumber(i32);
                    code += 4;
                    break;

                case IRushr:                // a = b >>> c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    i32 = b.toUint32();
                    u32 = c.toUint32() & 0x1F;
                    u32 = (cast(d_uint32)i32) >> u32;
                    a.putVnumber(u32);
                    code += 4;
                    break;

                case IRand:         // a = b & c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toInt32() & c.toInt32());
                    code += 4;
                    break;

                case IRor:          // a = b | c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toInt32() | c.toInt32());
                    code += 4;
                    break;

                case IRxor:         // a = b ^ c
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    a.putVnumber(b.toInt32() ^ c.toInt32());
                    code += 4;
                    break;
				case IRin:          // a = b in c
					a = GETa(code);
					b = GETb(code);
					c = GETc(code);
					s = b.toString();
					o = c.toObject();
					if(!o){
						ErrInfo errinfo;
						throw new ErrorValue(Dobject.RuntimeError(&errinfo,errmsgtbl[ERR_RHS_MUST_BE_OBJECT],"in",c.toString()));
					}
					a.putVboolean(o.HasProperty(s));
					code += 4;
					break;
					
                /********************/

                case IRpreinc:     // a = ++b.c
                    c = GETc(code);
                    s = c.toString();
                    goto Lpreinc;
                case IRpreincs:    // a = ++b.s
                    s = (code + 3).id.value.string;
                    Lpreinc:
                    inc = 1;
                    Lpre:
                    a = GETa(code);
                    b = GETb(code);
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n + inc);
                    b.Put(s, a);
                    code += 4;
                    break;

                case IRpreincscope:        // a = ++s
                    inc = 1;
                    Lprescope:
                    a = GETa(code);
                    id = (code + 2).id;
                    s = id.value.string;
                    version(SCOPECACHING)
                    {
                        si = SCOPECACHE_SI(s.ptr);
                        if(s is scopecache[si].s)
                        {
                            v = scopecache[si].v;
                            n = v.toNumber() + inc;
                            v.putVnumber(n);
                            a.putVnumber(n);
                        }
                        else
                        {
                            v = scope_get(scopex, id, &o);
                            if(v)
                            {
                                n = v.toNumber() + inc;
                                v.putVnumber(n);
                                a.putVnumber(n);
                            }
                            else
                            {
                                //FIXED: as per ECMA v5 should throw ReferenceError
                                a = Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR], s);
                                //a.putVundefined();
                                goto Lthrow;
                            }
                        }
                    }
                    else
                    {
                        v = scope_get(scopex, id, &o);
                        if(v)
                        {
                            n = v.toNumber();
                            v.putVnumber(n + inc);
                            Value.copy(a, v);
                        }
                        else
                             throw new ErrorValue(Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR], s));
                    }
                    code += 4;
                    break;

                case IRpredec:     // a = --b.c
                    c = GETc(code);
                    s = c.toString();
                    goto Lpredec;
                case IRpredecs:    // a = --b.s
                    s = (code + 3).id.value.string;
                    Lpredec:
                    inc = -1;
                    goto Lpre;

                case IRpredecscope:        // a = --s
                    inc = -1;
                    goto Lprescope;

                /********************/

                case IRpostinc:     // a = b.c++
                    c = GETc(code);
                    s = c.toString();
                    goto Lpostinc;
                case IRpostincs:    // a = b.s++
                    s = (code + 3).id.value.string;
                    Lpostinc:
                    a = GETa(code);
                    b = GETb(code);
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n + 1);
                    b.Put(s, a);
                    a.putVnumber(n);
                    code += 4;
                    break;

                case IRpostincscope:        // a = s++
                    id = (code + 2).id;
                    v = scope_get(scopex, id, &o);
                    if(v && v != &vundefined)
                    {
                        a = GETa(code);
                        n = v.toNumber();
                        v.putVnumber(n + 1);
                        a.putVnumber(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw new ErrorValue(Dobject.ReferenceError(id.value.string));
                        //v = signalingUndefined(id.value.string);
                    }
                    code += 3;
                    break;

                case IRpostdec:     // a = b.c--
                    c = GETc(code);
                    s = c.toString();
                    goto Lpostdec;
                case IRpostdecs:    // a = b.s--
                    s = (code + 3).id.value.string;
                    Lpostdec:
                    a = GETa(code);
                    b = GETb(code);
                    v = b.Get(s);
                    if(!v)
                        v = &vundefined;
                    n = v.toNumber();
                    a.putVnumber(n - 1);
                    b.Put(s, a);
                    a.putVnumber(n);
                    code += 4;
                    break;

                case IRpostdecscope:        // a = s--
                    id = (code + 2).id;
                    v = scope_get(scopex, id, &o);
                    if(v && v != &vundefined)
                    {
                        n = v.toNumber();
                        a = GETa(code);
                        v.putVnumber(n - 1);
                        a.putVnumber(n);
                    }
                    else
                    {
                        //GETa(code).putVundefined();
                        //FIXED: as per ECMA v5 should throw ReferenceError
                        throw new ErrorValue(Dobject.ReferenceError(id.value.string));
                        //v = signalingUndefined(id.value.string);
                    }
                    code += 3;
                    break;

                case IRdel:     // a = delete b.c
                case IRdels:    // a = delete b.s
                    b = GETb(code);
                    if(b.isPrimitive())
                        bo = true;
                    else
                    {
                        o = b.toObject();
                        if(!o)
                        {
                            a = cannotConvert(b, GETlinnum(code));
                            goto Lthrow;
                        }
                        s = (code.opcode == IRdel)
                            ? GETc(code).toString()
                            : (code + 3).id.value.string;
                        if(o.implementsDelete())
                            bo = o.Delete(s);
                        else
                            bo = !o.HasProperty(s);
                    }
                    GETa(code).putVboolean(bo);
                    code += 4;
                    break;

                case IRdelscope:    // a = delete s
                    id = (code + 2).id;
                    s = id.value.string;
                    //o = scope_tos(scopex);		// broken way
                    if(!scope_get(scopex, id, &o))
                        bo = true;
                    else if(o.implementsDelete())
                        bo = o.Delete(s);
                    else
                        bo = !o.HasProperty(s);
                    GETa(code).putVboolean(bo);
                    code += 3;
                    break;

                /* ECMA requires that if one of the numeric operands is NAN,
                 * then the result of the comparison is false. D generates a
                 * correct test for NAN operands.
                 */

                case IRclt:         // a = (b <   c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number < c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber() < c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;

                case IRcle:         // a = (b <=  c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number <= c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber() <= c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;

                case IRcgt:         // a = (b >   c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number > c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) > 0;
                        }
                        else
                            res = b.toNumber() > c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;


                case IRcge:         // a = (b >=  c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                        res = (b.number >= c.number);
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) >= 0;
                        }
                        else
                            res = b.toNumber() >= c.toNumber();
                    }
                    a.putVboolean(res);
                    code += 4;
                    break;

                case IRceq:         // a = (b ==  c)
                case IRcne:         // a = (b !=  c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    Lagain:
                    tx = b.getType();
                    ty = c.getType();
                    if(logflag)
                        writef("tx('%s', '%s')\n", tx, ty);
                    if(tx == ty)
                    {
                        if(tx == TypeUndefined ||
                           tx == TypeNull)
                            res = true;
                        else if(tx == TypeNumber)
                        {
                            d_number x = b.number;
                            d_number y = c.number;

                            res = (x == y);
                            //writef("x = %g, y = %g, res = %d\n", x, y, res);
                        }
                        else if(tx == TypeString)
                        {
                            if(logflag)
                            {
                                writef("b = %x, c = %x\n", b, c);
                                writef("cmp('%s', '%s')\n", b.string, c.string);
                                writef("cmp(%d, %d)\n", b.string.length, c.string.length);
                            }
                            res = (b.string == c.string);
                        }
                        else if(tx == TypeBoolean)
                            res = (b.dbool == c.dbool);
                        else // TypeObject
                        {
                            res = b.object == c.object;
                        }
                    }
                    else if(tx == TypeNull && ty == TypeUndefined)
                        res = true;
                    else if(tx == TypeUndefined && ty == TypeNull)
                        res = true;
                    else if(tx == TypeNumber && ty == TypeString)
                    {
                        c.putVnumber(c.toNumber());
                        goto Lagain;
                    }
                    else if(tx == TypeString && ty == TypeNumber)
                    {
                        b.putVnumber(b.toNumber());
                        goto Lagain;
                    }
                    else if(tx == TypeBoolean)
                    {
                        b.putVnumber(b.toNumber());
                        goto Lagain;
                    }
                    else if(ty == TypeBoolean)
                    {
                        c.putVnumber(c.toNumber());
                        goto Lagain;
                    }
                    else if(ty == TypeObject)
                    {
                        v = cast(Value*)c.toPrimitive(c, null);
                        if(v)
                        {
                            a = v;
                            goto Lthrow;
                        }
                        goto Lagain;
                    }
                    else if(tx == TypeObject)
                    {
                        v = cast(Value*)b.toPrimitive(b, null);
                        if(v)
                        {
                            a = v;
                            goto Lthrow;
                        }
                        goto Lagain;
                    }
                    else
                    {
                        res = false;
                    }

                    res ^= (code.opcode == IRcne);
                    //Lceq:
                    a.putVboolean(res);
                    code += 4;
                    break;

                case IRcid:         // a = (b === c)
                case IRcnid:        // a = (b !== c)
                    a = GETa(code);
                    b = GETb(code);
                    c = GETc(code);
                    version(none)
                    {
                        writeln("***\n");
                        print(code-codestart,code);
                        writeln();
                    }
                    tx = b.getType();
                    ty = c.getType();
                    if(tx == ty)
                    {
                        if(tx == TypeUndefined ||
                           tx == TypeNull)
                            res = true;
                        else if(tx == TypeNumber)
                        {
                            d_number x = b.number;
                            d_number y = c.number;

                            // Ensure that a NAN operand produces false
                            if(code.opcode == IRcid)
                                res = (x == y);
                            else
                                res = (x != y);
                            goto Lcid;
                        }
                        else if(tx == TypeString)
                            res = (b.string == c.string);
                        else if(tx == TypeBoolean)
                            res = (b.dbool == c.dbool);
                        else // TypeObject
                        {
                            res = b.object == c.object;
                        }
                    }
                    else
                    {
                        res = false;
                    }

                    res ^= (code.opcode == IRcnid);
                    Lcid:
                    a.putVboolean(res);
                    code += 4;
                    break;

                case IRjt:          // if (b) goto t
                    b = GETb(code);
                    if(b.toBoolean())
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case IRjf:          // if (!b) goto t
                    b = GETb(code);
                    if(!b.toBoolean())
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case IRjtb:         // if (b) goto t
                    b = GETb(code);
                    if(b.dbool)
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case IRjfb:         // if (!b) goto t
                    b = GETb(code);
                    if(!b.dbool)
                        code += (code + 1).offset;
                    else
                        code += 3;
                    break;

                case IRjmp:
                    code += (code + 1).offset;
                    break;

                case IRjlt:         // if (b <   c) goto c
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        if(b.number < c.number)
                            code += 4;
                        else
                            code += (code + 1).offset;
                        break;
                    }
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) < 0;
                        }
                        else
                            res = b.toNumber() < c.toNumber();
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 4;
                    break;

                case IRjle:         // if (b <=  c) goto c
                    b = GETb(code);
                    c = GETc(code);
                    if(b.vtype == V_NUMBER && c.vtype == V_NUMBER)
                    {
                        if(b.number <= c.number)
                            code += 4;
                        else
                            code += (code + 1).offset;
                        break;
                    }
                    else
                    {
                        b.toPrimitive(b, TypeNumber);
                        c.toPrimitive(c, TypeNumber);
                        if(b.isString() && c.isString())
                        {
                            d_string x = b.toString();
                            d_string y = c.toString();

                            res = std.string.cmp(x, y) <= 0;
                        }
                        else
                            res = b.toNumber() <= c.toNumber();
                    }
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 4;
                    break;

                case IRjltc:        // if (b < constant) goto c
                    b = GETb(code);
                    res = (b.toNumber() < *cast(d_number *)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 3 + d_number.sizeof/Op.sizeof;
                    break;

                case IRjlec:        // if (b <= constant) goto c
                    b = GETb(code);
                    res = (b.toNumber() <= *cast(d_number *)(code + 3));
                    if(!res)
                        code += (code + 1).offset;
                    else
                        code += 3 + d_number.sizeof/Op.sizeof;
                    break;

                case IRiter:                // a = iter(b)
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        a = cannotConvert(b, GETlinnum(code));
                        goto Lthrow;
                    }
                    a = o.putIterator(a);
                    if(a)
                        goto Lthrow;
                    code += 3;
                    break;

                case IRnext:        // a, b.c, iter
                                    // if (!(b.c = iter)) goto a; iter = iter.next
                    s = GETc(code).toString();
                    goto case_next;

                case IRnexts:       // a, b.s, iter
                    s = (code + 3).id.value.string;
                    case_next:
                    iter = GETd(code).iter;
                    v = iter.next();
                    if(!v)
                        code += (code + 1).offset;
                    else
                    {
                        b = GETb(code);
                        b.Put(s, v);
                        code += 5;
                    }
                    break;

                case IRnextscope:   // a, s, iter
                    s = (code + 2).id.value.string;
                    iter = GETc(code).iter;
                    v = iter.next();
                    if(!v)
                        code += (code + 1).offset;
                    else
                    {
                        o = scope_tos(scopex);
                        o.Put(s, v, 0);
                        code += 4;
                    }
                    break;

                case IRcall:        // a = b.c(argc, argv)
                    s = GETc(code).toString();
                    goto case_call;

                case IRcalls:       // a = b.s(argc, argv)
                    s = (code + 3).id.value.string;
                    goto case_call;

                    case_call:               
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        goto Lcallerror;
                    }
                    {
                        //writef("v.call\n");
                        v = o.Get(s);
                        if(!v)
                            goto Lcallerror;
                        //writef("calling... '%s'\n", v.toString());
                        cc.callerothis = othis;
                        a.putVundefined();
                        a = cast(Value*)v.Call(cc, o, a, GETe(code)[0 .. (code + 4).index]);
                        //writef("regular call, a = %x\n", a);
                    }
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(a)
                        goto Lthrow;
                    code += 6;
                    goto Lnext;

                    Lcallerror:
                    {
                        //writef("%s %s.%s is undefined and has no Call method\n", b.getType(), b.toString(), s);
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_UNDEFINED_NO_CALL3],
                                                 b.getType(), b.toString(),
                                                 s);
                        goto Lthrow;
                    }

                case IRcallscope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = id.value.string;
                    a = GETa(code);
                    v = scope_get_lambda(scopex, id, &o);
                    //writefln("v.toString() = '%s'", v.toString());
                    if(!v)
                    {
                        ErrInfo errinfo;
                        a = Dobject.ReferenceError(errmsgtbl[ERR_UNDEFINED_VAR],s);
                        //a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_UNDEFINED_NO_CALL2], "property", s);
                        goto Lthrow;
                    }
                    // Should we pass othis or o? I think othis.
                    cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    a = cast(Value*)v.Call(cc, o, a, GETd(code)[0 .. (code + 3).index]);
                    //writef("callscope result = %x\n", a);
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(a)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case IRcallv:   // v(argc, argv) = a
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_UNDEFINED_NO_CALL2],
                                                 b.getType(), b.toString());
                        goto Lthrow;
                    }
                    cc.callerothis = othis;        // pass othis to eval()
                    a.putVundefined();
                    a = cast(Value*)o.Call(cc, o, a, GETd(code)[0 .. (code + 3).index]);
                    if(a)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case IRputcall:        // b.c(argc, argv) = a
                    s = GETc(code).toString();
                    goto case_putcall;

                case IRputcalls:       //  b.s(argc, argv) = a
                    s = (code + 3).id.value.string;
                    goto case_putcall;

                    case_putcall:
                    a = GETa(code);
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                        goto Lcallerror;
                    //v = o.GetLambda(s, Value.calcHash(s));
                    v = o.Get(s, Value.calcHash(s));
                    if(!v)
                        goto Lcallerror;
                    //writef("calling... '%s'\n", v.toString());
                    o = v.toObject();
                    if(!o)
                    {
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_CANNOT_ASSIGN_TO2],
                                                 b.getType(), s);
                        goto Lthrow;
                    }
                    a = cast(Value*)o.put_Value(a, GETe(code)[0 .. (code + 4).index]);
                    if(a)
                        goto Lthrow;
                    code += 6;
                    goto Lnext;

                case IRputcallscope:   // a = s(argc, argv)
                    id = (code + 2).id;
                    s = id.value.string;
                    v = scope_get_lambda(scopex, id, &o);
                    if(!v)
                    {
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_UNDEFINED_NO_CALL2],
                                                 "property", s);
                        goto Lthrow;
                    }
                    o = v.toObject();
                    if(!o)
                    {
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_CANNOT_ASSIGN_TO],
                                                 s);
                        goto Lthrow;
                    }
                    a = cast(Value*)o.put_Value(GETa(code), GETd(code)[0 .. (code + 3).index]);
                    if(a)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case IRputcallv:        // v(argc, argv) = a
                    b = GETb(code);
                    o = b.toObject();
                    if(!o)
                    {
                        //writef("%s %s is undefined and has no Call method\n", b.getType(), b.toString());
                        ErrInfo errinfo;
                        a = Dobject.RuntimeError(&errinfo,
                                                 errmsgtbl[ERR_UNDEFINED_NO_CALL2],
                                                 b.getType(), b.toString());
                        goto Lthrow;
                    }
                    a = cast(Value*)o.put_Value(GETa(code), GETd(code)[0 .. (code + 3).index]);
                    if(a)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case IRnew: // a = new b(argc, argv)
                    a = GETa(code);
                    b = GETb(code);
                    a.putVundefined();
                    a = cast(Value*)b.Construct(cc, a, GETd(code)[0 .. (code + 3).index]);
                    debug(VERIFY)
                        assert(checksum == IR.verify(__LINE__, codestart));
                    if(a)
                        goto Lthrow;
                    code += 5;
                    goto Lnext;

                case IRpush:
                    SCOPECACHE_CLEAR();
                    a = GETa(code);
                    o = a.toObject();
                    if(!o)
                    {
                        a = cannotConvert(a, GETlinnum(code));
                        goto Lthrow;
                    }
                    scopex ~= o;                // push entry onto scope chain
                    cc.scopex = scopex;
                    code += 2;
                    break;

                case IRpop:
                    SCOPECACHE_CLEAR();
                    o = scopex[$ - 1];
                    scopex = scopex[0 .. $ - 1];        // pop entry off scope chain
                    cc.scopex = scopex;
                    // If it's a Finally, we need to execute
                    // the finally block
                    code += 1;
                    
                    if(o.isFinally())   // test could be eliminated with virtual func
                    {
                        f = cast(Finally)o;
                        callFinally(f);
                        debug(VERIFY)
                            assert(checksum == IR.verify(__LINE__, codestart));
                    }

                    goto Lnext;

                case IRfinallyret:
                    assert(finallyStack.length);
                    code = finallyStack[$-1];
                    finallyStack = finallyStack[0..$-1];
                    goto Lnext;
                case IRret:
                    version(SCOPECACHE_LOG)
                        printf("scopecache_cnt = %d\n", scopecache_cnt);
                    return null;

                case IRretexp:
                    a = GETa(code);
                    a.checkReference();
                    Value.copy(ret, a);
                    //writef("returns: %s\n", ret.toString());
                    return null;

                case IRimpret:
                    a = GETa(code);
                    a.checkReference();
                    Value.copy(ret, a);
                    //writef("implicit return: %s\n", ret.toString());
                    code += 2;
                    goto Lnext;

                case IRthrow:
                    a = GETa(code);
                    cc.linnum = GETlinnum(code);
                    Lthrow:
                    assert(scopex[0] !is null);     
                    v = unwindStack(a);
                    if(v) 
                        return v;
                    break;
                case IRtrycatch:
                    SCOPECACHE_CLEAR();
                    offset = cast(uint)(code - codestart) + (code + 1).offset;
                    s = (code + 2).id.value.string;
                    ca = new Catch(offset, s);
                    scopex ~= ca;
                    cc.scopex = scopex;
                    code += 3;
                    break;

                case IRtryfinally:
                    SCOPECACHE_CLEAR();
                    f = new Finally(code + (code + 1).offset);
                    scopex ~= f;
                    cc.scopex = scopex;
                    code += 2;
                    break;

                case IRassert:
                {
                    ErrInfo errinfo;
                    errinfo.linnum = cast(uint)(code + 1).index;
                    version(all)  // Not supported under some com servers
                    {
                        a = Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_ASSERT], (code + 1).index);
                        goto Lthrow;
                    }
                    else
                    {
                        RuntimeErrorx(ERR_ASSERT, (code + 1).index);
                        code += 2;
                        break;
                    }
                }

                default:
                    //writef("1: Unrecognized IR instruction %d\n", code.opcode);
                    assert(0);              // unrecognized IR instruction
                }
             }
            catch(ErrorValue err)
            {
                v = unwindStack(&err.value);
                if(v)//v is exception that was not caught
                    return v;
            }
        }
        
        Linterrupt:
        ret.putVundefined();
        return null;
    }

    /*******************************************
     * This is a 'disassembler' for our interpreted code.
     * Useful for debugging.
     */

    static void print(uint address, IR *code)
    {
        switch(code.opcode)
        {
        case IRerror:
            writef("\tIRerror\n");
            break;

        case IRnop:
            writef("\tIRnop\n");
            break;

        case IRend:
            writef("\tIRend\n");
            break;

        case IRget:                 // a = b.c
            writef("\tIRget       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRput:                 // b.c = a
            writef("\tIRput       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRgets:                // a = b.s
            writef("\tIRgets      %d, %d, '%s'\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRgetscope:            // a = othis.ident
            writef("\tIRgetscope  %d, '%s', hash=%d\n", (code + 1).index, (code + 2).id.value.string, (code + 2).id.value.hash);
            break;

        case IRaddass:              // b.c += a
            writef("\tIRaddass    %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRaddasss:             // b.s += a
            writef("\tIRaddasss   %d, %d, '%s'\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRaddassscope:         // othis.ident += a
            writef("\tIRaddassscope  %d, '%s', hash=%d\n", (code + 1).index, (code + 2).id.value.string, (code + 3).index);
            break;

        case IRputs:                // b.s = a
            writef("\tIRputs      %d, %d, '%s'\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRputscope:            // s = a
            writef("\tIRputscope  %d, '%s'\n", (code + 1).index, (code + 2).id.value.string);
            break;

        case IRputdefault:                // b = a
            writef("\tIRputdefault %d, %d\n", (code + 1).index, (code + 2).index);
            break;

        case IRputthis:             // b = s
            writef("\tIRputthis   '%s', %d\n", (code + 2).id.value.string, (code + 1).index);
            break;

        case IRmov:                 // a = b
            writef("\tIRmov       %d, %d\n", (code + 1).index, (code + 2).index);
            break;

        case IRstring:              // a = "string"
            writef("\tIRstring    %d, '%s'\n", (code + 1).index, (code + 2).id.value.string);
            break;

        case IRobject:              // a = object
            writef("\tIRobject    %d, %x\n", (code + 1).index, cast(void*)(code + 2).object);
            break;

        case IRthis:                // a = this
            writef("\tIRthis      %d\n", (code + 1).index);
            break;

        case IRnumber:              // a = number
            writef("\tIRnumber    %d, %g\n", (code + 1).index, *cast(d_number *)(code + 2));
            break;

        case IRboolean:             // a = boolean
            writef("\tIRboolean   %d, %d\n", (code + 1).index, (code + 2).boolean);
            break;

        case IRnull:                // a = null
            writef("\tIRnull      %d\n", (code + 1).index);
            break;

        case IRundefined:           // a = undefined
            writef("\tIRundefined %d\n", (code + 1).index);
            break;

        case IRthisget:             // a = othis.ident
            writef("\tIRthisget   %d, '%s'\n", (code + 1).index, (code + 2).id.value.string);
            break;

        case IRneg:                 // a = -a
            writef("\tIRneg      %d\n", (code + 1).index);
            break;

        case IRpos:                 // a = a
            writef("\tIRpos      %d\n", (code + 1).index);
            break;

        case IRcom:                 // a = ~a
            writef("\tIRcom      %d\n", (code + 1).index);
            break;

        case IRnot:                 // a = !a
            writef("\tIRnot      %d\n", (code + 1).index);
            break;

        case IRtypeof:              // a = typeof a
            writef("\tIRtypeof   %d\n", (code + 1).index);
            break;

        case IRinstance:            // a = b instanceof c
            writef("\tIRinstance  %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRadd:                 // a = b + c
            writef("\tIRadd       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRsub:                 // a = b - c
            writef("\tIRsub       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRmul:                 // a = b * c
            writef("\tIRmul       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRdiv:                 // a = b / c
            writef("\tIRdiv       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRmod:                 // a = b % c
            writef("\tIRmod       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRshl:                 // a = b << c
            writef("\tIRshl       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRshr:                 // a = b >> c
            writef("\tIRshr       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRushr:                // a = b >>> c
            writef("\tIRushr      %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRand:                 // a = b & c
            writef("\tIRand       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRor:                  // a = b | c
            writef("\tIRor        %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRxor:                 // a = b ^ c
            writef("\tIRxor       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;
			
        case IRin:                 // a = b in c
            writef("\tIRin        %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRpreinc:                  // a = ++b.c
            writef("\tIRpreinc  %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRpreincs:            // a = ++b.s
            writef("\tIRpreincs %d, %d, %s\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRpreincscope:        // a = ++s
            writef("\tIRpreincscope %d, '%s', hash=%d\n", (code + 1).index, (code + 2).id.value.string, (code + 3).hash);
            break;

        case IRpredec:             // a = --b.c
            writef("\tIRpredec  %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRpredecs:            // a = --b.s
            writef("\tIRpredecs %d, %d, %s\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRpredecscope:        // a = --s
            writef("\tIRpredecscope %d, '%s', hash=%d\n", (code + 1).index, (code + 2).id.value.string, (code + 3).hash);
            break;

        case IRpostinc:     // a = b.c++
            writef("\tIRpostinc  %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRpostincs:            // a = b.s++
            writef("\tIRpostincs %d, %d, %s\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRpostincscope:        // a = s++
            writef("\tIRpostincscope %d, %s\n", (code + 1).index, (code + 2).id.value.string);
            break;

        case IRpostdec:             // a = b.c--
            writef("\tIRpostdec  %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRpostdecs:            // a = b.s--
            writef("\tIRpostdecs %d, %d, %s\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRpostdecscope:        // a = s--
            writef("\tIRpostdecscope %d, %s\n", (code + 1).index, (code + 2).id.value.string);
            break;

        case IRdel:                 // a = delete b.c
            writef("\tIRdel       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRdels:                // a = delete b.s
            writef("\tIRdels      %d, %d, '%s'\n", (code + 1).index, (code + 2).index, (code + 3).id.value.string);
            break;

        case IRdelscope:            // a = delete s
            writef("\tIRdelscope  %d, '%s'\n", (code + 1).index, (code + 2).id.value.string);
            break;

        case IRclt:                 // a = (b <   c)
            writef("\tIRclt       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRcle:                 // a = (b <=  c)
            writef("\tIRcle       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRcgt:                 // a = (b >   c)
            writef("\tIRcgt       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRcge:                 // a = (b >=  c)
            writef("\tIRcge       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRceq:                 // a = (b ==  c)
            writef("\tIRceq       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRcne:                 // a = (b !=  c)
            writef("\tIRcne       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRcid:                 // a = (b === c)
            writef("\tIRcid       %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRcnid:        // a = (b !== c)
            writef("\tIRcnid      %d, %d, %d\n", (code + 1).index, (code + 2).index, (code + 3).index);
            break;

        case IRjt:                  // if (b) goto t
            writef("\tIRjt        %d, %d\n", (code + 1).index + address, (code + 2).index);
            break;

        case IRjf:                  // if (!b) goto t
            writef("\tIRjf        %d, %d\n", (code + 1).index + address, (code + 2).index);
            break;

        case IRjtb:                 // if (b) goto t
            writef("\tIRjtb       %d, %d\n", (code + 1).index + address, (code + 2).index);
            break;

        case IRjfb:                 // if (!b) goto t
            writef("\tIRjfb       %d, %d\n", (code + 1).index + address, (code + 2).index);
            break;

        case IRjmp:
            writef("\tIRjmp       %d\n", (code + 1).offset + address);
            break;

        case IRjlt:                 // if (b < c) goto t
            writef("\tIRjlt       %d, %d, %d\n", (code + 1).index + address, (code + 2).index, (code + 3).index);
            break;

        case IRjle:                 // if (b <= c) goto t
            writef("\tIRjle       %d, %d, %d\n", (code + 1).index + address, (code + 2).index, (code + 3).index);
            break;

        case IRjltc:                // if (b < constant) goto t
            writef("\tIRjltc      %d, %d, %g\n", (code + 1).index + address, (code + 2).index, *cast(d_number *)(code + 3));
            break;

        case IRjlec:                // if (b <= constant) goto t
            writef("\tIRjlec      %d, %d, %g\n", (code + 1).index + address, (code + 2).index, *cast(d_number *)(code + 3));
            break;

        case IRiter:                // a = iter(b)
            writef("\tIRiter    %d, %d\n", (code + 1).index, (code + 2).index);
            break;

        case IRnext:                // a, b.c, iter
            writef("\tIRnext    %d, %d, %d, %d\n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).index,
                   (code + 4).index);
            break;

        case IRnexts:               // a, b.s, iter
            writef("\tIRnexts   %d, %d, '%s', %d\n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).id.value.string,
                   (code + 4).index);
            break;

        case IRnextscope:           // a, s, iter
            writef
                ("\tIRnextscope   %d, '%s', %d\n",
                (code + 1).index,
                (code + 2).id.value.string,
                (code + 3).index);
            break;

        case IRcall:                // a = b.c(argc, argv)
            writef("\tIRcall     %d,%d,%d, argc=%d, argv=%d \n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).index,
                   (code + 4).index,
                   (code + 5).index);
            break;

        case IRcalls:               // a = b.s(argc, argv)
            writef
                ("\tIRcalls     %d,%d,'%s', argc=%d, argv=%d \n",
                (code + 1).index,
                (code + 2).index,
                (code + 3).id.value.string,
                (code + 4).index,
                (code + 5).index);
            break;

        case IRcallscope:           // a = s(argc, argv)
            writef
                ("\tIRcallscope %d,'%s', argc=%d, argv=%d \n",
                (code + 1).index,
                (code + 2).id.value.string,
                (code + 3).index,
                (code + 4).index);
            break;

        case IRputcall:                // a = b.c(argc, argv)
            writef("\tIRputcall  %d,%d,%d, argc=%d, argv=%d \n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).index,
                   (code + 4).index,
                   (code + 5).index);
            break;

        case IRputcalls:               // a = b.s(argc, argv)
            writef
                ("\tIRputcalls  %d,%d,'%s', argc=%d, argv=%d \n",
                (code + 1).index,
                (code + 2).index,
                (code + 3).id.value.string,
                (code + 4).index,
                (code + 5).index);
            break;

        case IRputcallscope:           // a = s(argc, argv)
            writef
                ("\tIRputcallscope %d,'%s', argc=%d, argv=%d \n",
                (code + 1).index,
                (code + 2).id.value.string,
                (code + 3).index,
                (code + 4).index);
            break;

        case IRcallv:               // a = v(argc, argv)
            writef("\tIRcallv    %d, %d(argc=%d, argv=%d)\n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).index,
                   (code + 4).index);
            break;

        case IRputcallv:               // a = v(argc, argv)
            writef("\tIRputcallv %d, %d(argc=%d, argv=%d)\n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).index,
                   (code + 4).index);
            break;

        case IRnew:         // a = new b(argc, argv)
            writef("\tIRnew      %d,%d, argc=%d, argv=%d \n",
                   (code + 1).index,
                   (code + 2).index,
                   (code + 3).index,
                   (code + 4).index);
            break;

        case IRpush:
            writef("\tIRpush    %d\n", (code + 1).index);
            break;

        case IRpop:
            writef("\tIRpop\n");
            break;

        case IRret:
            writef("\tIRret\n");
            return;

        case IRretexp:
            writef("\tIRretexp    %d\n", (code + 1).index);
            return;

        case IRimpret:
            writef("\tIRimpret    %d\n", (code + 1).index);
            return;

        case IRthrow:
            writef("\tIRthrow     %d\n", (code + 1).index);
            break;

        case IRassert:
            writef("\tIRassert    %d\n", (code + 1).index);
            break;
		case IRcheckref:
			writef("\tIRcheckref  %d\n",(code+1).index);
			break;
        case IRtrycatch:
            writef("\tIRtrycatch  %d, '%s'\n", (code + 1).offset + address, (code + 2).id.value.string);
            break;

        case IRtryfinally:
            writef("\tIRtryfinally %d\n", (code + 1).offset + address);
            break;

        case IRfinallyret:
            writef("\tIRfinallyret\n");
            break;

        default:
            writef("2: Unrecognized IR instruction %d\n", code.opcode);
            assert(0);              // unrecognized IR instruction
        }
    }

    /*********************************
     * Give size of opcode.
     */

    static uint size(uint opcode)
    {
        uint sz = 9999;

        switch(opcode)
        {
        case IRerror:
        case IRnop:
        case IRend:
            sz = 1;
            break;

        case IRget:                 // a = b.c
        case IRaddass:
            sz = 4;
            break;

        case IRput:                 // b.c = a
            sz = 4;
            break;

        case IRgets:                // a = b.s
        case IRaddasss:
            sz = 4;
            break;

        case IRgetscope:            // a = s
            sz = 3;
            break;

        case IRaddassscope:
            sz = 4;
            break;

        case IRputs:                // b.s = a
            sz = 4;
            break;

        case IRputscope:        // s = a
        case IRputdefault:      // b = a
            sz = 3;
            break;

        case IRputthis:             // a = s
            sz = 3;
            break;

        case IRmov:                 // a = b
            sz = 3;
            break;

        case IRstring:              // a = "string"
            sz = 3;
            break;

        case IRobject:              // a = object
            sz = 3;
            break;

        case IRthis:                // a = this
            sz = 2;
            break;

        case IRnumber:              // a = number
            sz = 2 + d_number.sizeof/Op.sizeof;
            break;

        case IRboolean:             // a = boolean
            sz = 3;
            break;

        case IRnull:                // a = null
            sz = 2;
            break;
			
		case IRcheckref:
        case IRundefined:           // a = undefined
            sz = 2;
            break;
		

        case IRthisget:             // a = othis.ident
            sz = 3;
            break;
		
        case IRneg:                 // a = -a
        case IRpos:                 // a = a
        case IRcom:                 // a = ~a
        case IRnot:                 // a = !a
        case IRtypeof:              // a = typeof a
            sz = 2;
            break;

        case IRinstance:            // a = b instanceof c
        case IRadd:                 // a = b + c
        case IRsub:                 // a = b - c
        case IRmul:                 // a = b * c
        case IRdiv:                 // a = b / c
        case IRmod:                 // a = b % c
        case IRshl:                 // a = b << c
        case IRshr:                 // a = b >> c
        case IRushr:                // a = b >>> c
        case IRand:                 // a = b & c
        case IRor:                  // a = b | c
        case IRxor:                 // a = b ^ c
		case IRin:                  // a = b in c
            sz = 4;
            break;

        case IRpreinc:             // a = ++b.c
        case IRpreincs:            // a = ++b.s
        case IRpredec:             // a = --b.c
        case IRpredecs:            // a = --b.s
        case IRpostinc:            // a = b.c++
        case IRpostincs:           // a = b.s++
        case IRpostdec:            // a = b.c--
        case IRpostdecs:           // a = b.s--
            sz = 4;
            break;

        case IRpostincscope:        // a = s++
        case IRpostdecscope:        // a = s--
            sz = 3;
            break;

        case IRpreincscope:     // a = ++s
        case IRpredecscope:     // a = --s
            sz = 4;
            break;

        case IRdel:                 // a = delete b.c
        case IRdels:                // a = delete b.s
            sz = 4;
            break;

        case IRdelscope:            // a = delete s
            sz = 3;
            break;

        case IRclt:                 // a = (b <   c)
        case IRcle:                 // a = (b <=  c)
        case IRcgt:                 // a = (b >   c)
        case IRcge:                 // a = (b >=  c)
        case IRceq:                 // a = (b ==  c)
        case IRcne:                 // a = (b !=  c)
        case IRcid:                 // a = (b === c)
        case IRcnid:                // a = (b !== c)
        case IRjlt:                 // if (b < c) goto t
        case IRjle:                 // if (b <= c) goto t
            sz = 4;
            break;

        case IRjltc:                // if (b < constant) goto t
        case IRjlec:                // if (b <= constant) goto t
            sz = 3 + d_number.sizeof/Op.sizeof;
            break;

        case IRjt:                  // if (b) goto t
        case IRjf:                  // if (!b) goto t
        case IRjtb:                 // if (b) goto t
        case IRjfb:                 // if (!b) goto t
            sz = 3;
            break;

        case IRjmp:
            sz = 2;
            break;

        case IRiter:                // a = iter(b)
            sz = 3;
            break;

        case IRnext:                // a, b.c, iter
        case IRnexts:               // a, b.s, iter
            sz = 5;
            break;

        case IRnextscope:           // a, s, iter
            sz = 4;
            break;

        case IRcall:                // a = b.c(argc, argv)
        case IRcalls:               // a = b.s(argc, argv)
        case IRputcall:             //  b.c(argc, argv) = a
        case IRputcalls:            //  b.s(argc, argv) = a
            sz = 6;
            break;

        case IRcallscope:           // a = s(argc, argv)
        case IRputcallscope:        // s(argc, argv) = a
        case IRcallv:
        case IRputcallv:
            sz = 5;
            break;

        case IRnew:                 // a = new b(argc, argv)
            sz = 5;
            break;

        case IRpush:
            sz = 2;
            break;

        case IRpop:
            sz = 1;
            break;

        case IRfinallyret:
        case IRret:
            sz = 1;
            break;

        case IRretexp:
        case IRimpret:
        case IRthrow:
            sz = 2;
            break;

        case IRtrycatch:
            sz = 3;
            break;

        case IRtryfinally:
            sz = 2;
            break;

        case IRassert:
            sz = 2;
            break;

        default:
            writef("3: Unrecognized IR instruction %d, IRMAX = %d\n", opcode, IRMAX);
            assert(0);              // unrecognized IR instruction
        }
        assert(sz <= 6);
        return sz;
    }

    static void printfunc(IR *code)
    {
        IR *codestart = code;

        for(;; )
        {
            //writef("%2d(%d):", code - codestart, code.linnum);
            writef("%2d:", code - codestart);
            print(cast(uint)(code - codestart), code);
            if(code.opcode == IRend)
                return;
            code += size(code.opcode);
        }
    }

    /***************************************
     * Verify that it is a correct sequence of code.
     * Useful for isolating memory corruption bugs.
     */

    static uint verify(uint linnum, IR *codestart)
    {
        debug(VERIFY)
        {
            uint checksum = 0;
            uint sz;
            uint i;
            IR *code;

            // Verify code
            for(code = codestart;; )
            {
                switch(code.opcode)
                {
                case IRend:
                    return checksum;

                case IRerror:
                    writef("verify failure line %u\n", linnum);
                    assert(0);
                    break;

                default:
                    if(code.opcode >= IRMAX)
                    {
                        writef("undefined opcode %d in code %p\n", code.opcode, codestart);
                        assert(0);
                    }
                    sz = IR.size(code.opcode);
                    for(i = 0; i < sz; i++)
                    {
                        checksum += code.opcode;
                        code++;
                    }
                    break;
                }
            }
        }
        else
            return 0;
    }
}
