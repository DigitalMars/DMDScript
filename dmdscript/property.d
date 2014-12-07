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


module dmdscript.property;

import dmdscript.script;
import dmdscript.value;
import dmdscript.identifier;

import dmdscript.RandAA;

import std.c.string;
import std.stdio;

// attribute flags
enum
{
    ReadOnly       = 0x001,
    DontEnum       = 0x002,
    DontDelete     = 0x004,
    Internal       = 0x008,
    Deleted        = 0x010,
    Locked         = 0x020,
    DontOverride   = 0x040,
    KeyWord        = 0x080,
    DebugFree      = 0x100,       // for debugging help
    Instantiate    = 0x200,       // For COM named item namespace support
}

struct Property
{
    uint  attributes;

    Value value;
}

extern (C)
{
/* These functions are part of the internal implementation of Phobos
 * associative arrays. It's faster to use them when we have precomputed
 * values to use.
 */

struct Array
{
    int   length;
    void* ptr;
}

struct aaA
{
    aaA *  left;
    aaA *  right;
    hash_t hash;
    /* key   */
    /* value */
}

struct BB
{
    aaA*[] b;
    size_t nodes;       // total number of aaA nodes
}

struct AA
{
    BB* a;
    version(X86_64)
    {
    }
    else
    {
        // This is here only to retain binary compatibility with the
        // old way we did AA's. Should eventually be removed.
        int reserved;
    }
}

long _aaRehash(AA* paa, TypeInfo keyti);

/************************
 * Alternate Get() version
 */

Property* _aaGetY(hash_t hash, Property[Value]* bb, Value* key)
{
    aaA* e;
    auto aa = cast(AA*)bb;

    if(!aa.a)
        aa.a = new BB();

    auto aalen = aa.a.b.length;
    if(!aalen)
    {
        alias aaA *pa;

        aalen = 97;
        aa.a.b = new pa[aalen];
    }

    //printf("hash = %d\n", hash);
    size_t i = hash % aalen;
    auto pe = &aa.a.b[i];
    size_t nodes;
    while((e = *pe) != null)
    {
        if(hash == e.hash)
        {
            Value* v = cast(Value*)(e + 1);
            if(key.vtype == V_NUMBER)
            {
                if(v.vtype == V_NUMBER && key.number == v.number)
                    goto Lret;
            }
            else if(key.vtype == V_STRING)
            {
                if(v.vtype == V_STRING && key.string is v.string)
                    goto Lret;
            }
            auto c = key.opCmp(*v);
            if(c == 0)
                goto Lret;
            pe = (c < 0) ? &e.left : &e.right;
        }
        else
            pe = (hash < e.hash) ? &e.left : &e.right;
    }

    // Not found, create new elem
    //printf("\tcreate new one\n");
    e = cast(aaA *)cast(void*)new void[aaA.sizeof + Value.sizeof + Property.sizeof];
    std.c.string.memcpy(e + 1, key, Value.sizeof);
    e.hash = hash;
    *pe = e;

    nodes = ++aa.a.nodes;
    //printf("length = %d, nodes = %d\n", (*aa).length, nodes);
    if(nodes > aalen * 4)
    {
        _aaRehash(aa, typeid(Value));
    }

    Lret:
    return cast(Property*)(cast(void *)(e + 1) + Value.sizeof);
}

/************************************
 * Alternate In() with precomputed values.
 */

Property* _aaInY(hash_t hash, Property[Value] bb, Value* key)
{
    size_t i;
    AA aa = *cast(AA*)&bb;

    //printf("_aaIn(), aa.length = %d, .ptr = %x\n", aa.length, cast(uint)aa.ptr);
    if(aa.a && aa.a.b.length)
    {
        //printf("hash = %d\n", hash);
        i = hash % aa.a.b.length;
        auto e = aa.a.b[i];
        while(e != null)
        {
            if(hash == e.hash)
            {
                Value* v = cast(Value*)(e + 1);
                int c;
                if(key.vtype == V_NUMBER && v.vtype == V_NUMBER &&
                   key.number == v.number)
                    goto Lfound;
                c = key.opCmp(*v);
                if(c == 0)
                {
                    Lfound:
                    return cast(Property*)(cast(void *)(e + 1) + Value.sizeof);
                }
                else
                    e = (c < 0) ? e.left : e.right;
            }
            else
                e = (hash < e.hash) ? e.left : e.right;
        }
    }

    // Not found
    return null;
}
}

/*********************************** PropTable *********************/

struct PropTable
{
    //Property[Value] table;
    RandAA!(Value, Property) table;
    PropTable* previous;

    int        opApply(int delegate(ref Property) dg)
    {
        initialize();
        int result;
        foreach(ref Property p; table)
        {
            result = dg(p);
            if(result)
                break;
        }
        return result;
    }

    int opApply(int delegate(ref Value, ref Property) dg)
    {
        initialize();
        int result;

        foreach(Value key, ref Property p; table)
        {
            result = dg(key, p);
            if(result)
                break;
        }
        return result;
    }

    /*******************************
     * Look up name and get its corresponding Property.
     * Return null if not found.
     */

    Property *getProperty(d_string name)
    {
        Value* v;
        Property *p;

        v = get(name, Value.calcHash(name));
        if(!v)
            return null;

        // Work backwards from &p->value to p
        p = cast(Property *)(cast(char *)v - uint.sizeof /*Property.value.offsetof*/);

        return p;
    }

    Value* get(Value* key, hash_t hash)
    {
        uint i;
        Property *p;
        PropTable *t;

        //writefln("get(key = '%s', hash = x%x)", key.toString(), hash);
        assert(key.toHash() == hash);
        t = &this;
        do
        {
            //writefln("\tt = %x", cast(uint)t);
            t.initialize();
            //p = *key in t.table;
            p = t.table.findExistingAlt(*key,hash);

            if(p)
            {
                //TODO: what's that assert for? -- seems to run OK without it
                //bombs with range violation otherwise!
                /*try{
                        assert(t.table[*key] == p);
                   }catch(Error e){
                        writef("get(key = '%s', hash = x%x)", key.toString(), hash);
                        //writefln("\tfound");
                        p.value.dump();
                   }*/
                //p.value.dump();
                return &p.value;
            }
            t = t.previous;
        } while(t);
        //writefln("\tnot found");
        return null;                    // not found
    }

    Value* get(d_uint32 index)
    {
        //writefln("get(index = %d)", index);
        Value key;

        key.putVnumber(index);
        return get(&key, Value.calcHash(index));
    }

    Value* get(Identifier* id)
    {
        //writefln("get('%s', hash = x%x)", name, hash);
        return get(&id.value, id.value.hash);
        //return get(id.value.string, id.value.hash);
    }

    Value* get(d_string name, hash_t hash)
    {
        //writefln("get('%s', hash = x%x)", name, hash);
        Value key;

        key.putVstring(name);
        return get(&key, hash);
    }

    /*******************************
     * Determine if property exists for this object.
     * The enumerable flag means the DontEnum attribute cannot be set.
     */

    int hasownproperty(Value* key, int enumerable)
    {
        initialize();
        Property* p;

        p = *key in table;
        return p && (!enumerable || !(p.attributes & DontEnum));
    }

    int hasproperty(Value* key)
    {
        initialize();
        return (*key in table) != null || (previous && previous.hasproperty(key));
    }

    int hasproperty(d_string name)
    {
        Value v;

        v.putVstring(name);
        return hasproperty(&v);
    }

    Value* put(Value* key, hash_t hash, Value* value, uint attributes)
    {
        initialize();
        Property* p;
        //writefln("table contains %d properties",table.length);
        //writefln("put(key = %s, hash = x%x, value = %s, attributes = x%x)", key.toString(), hash, value.toString(), attributes);
        //writefln("put(key = %s)", key.toString());

        //p = &table[*key];
        //version(none){
        //writeln(cast(void*)table);
        //p = *key in table;
        p = table.findExistingAlt(*key,hash);
        
 
        if(p)
        {
            Lx:
            if(attributes & DontOverride && p.value.vtype != V_REF_ERROR ||
               p.attributes & ReadOnly)
            {
                if(p.attributes & KeyWord)
                    return null;
                return &vundefined;
            }

            PropTable* t = previous;
            if(t)
            {
                do
                {
                    Property* q;
                    t.initialize();
                    //q = *key in t.table;
                    q = t.table.findExistingAlt(*key,hash);
                    if(q)
                    {
                        if(q.attributes & ReadOnly)
                        {
                            p.attributes |= ReadOnly;
                            return &vundefined;
                        }
                        break;
                    }
                    t = t.previous;
                } while(t);
            }

            // Overwrite property with new value
            Value.copy(&p.value, value);
            p.attributes = (attributes & ~DontOverride) | (p.attributes & (DontDelete | DontEnum));
            return null;
        }
		else{		
            //table[*key] = Property(attributes & ~DontOverride,*value);
            auto v = Property(attributes & ~DontOverride,*value);
			table.insertAlt(*key, v, hash);
			return null; // success
		}
    }

    Value* put(d_string name, Value* value, uint attributes)
    {
        Value key;

        key.putVstring(name);

        //writef("PropTable::put(%p, '%ls', hash = x%x)\n", this, d_string_ptr(name), key.toHash());
        return put(&key, Value.calcHash(name), value, attributes);
    }

    Value* put(d_uint32 index, Value* value, uint attributes)
    {
        Value key;

        key.putVnumber(index);

        //writef("PropTable::put(%d)\n", index);
        return put(&key, Value.calcHash(index), value, attributes);
    }

    Value* put(d_uint32 index, d_string string, uint attributes)
    {
        Value key;
        Value value;

        key.putVnumber(index);
        value.putVstring(string);

        return put(&key, Value.calcHash(index), &value, attributes);
    }

    int canput(Value* key, hash_t hash)
    {
        initialize();
        Property *p;
        PropTable *t;

        t = &this;
        do
        {
            //p = *key in t.table;
             p = t.table.findExistingAlt(*key,hash);
            if(p)
            {
                return (p.attributes & ReadOnly)
                       ? false : true;
            }
            t = t.previous;
        } while(t);
        return true;                    // success
    }

    int canput(d_string name)
    {
        Value v;

        v.putVstring(name);

        return canput(&v, v.toHash());
    }

    int del(Value* key)
    {
        initialize();
        Property *p;

        //writef("PropTable::del('%ls')\n", d_string_ptr(key.toString()));
        p = *key in table;
        if(p)
        {
            if(p.attributes & DontDelete)
                return false;
            table.remove(*key);
        }
        return true;                    // not found
    }

    int del(d_string name)
    {
        Value v;

        v.putVstring(name);

        //writef("PropTable::del('%ls')\n", d_string_ptr(name));
        return del(&v);
    }

    int del(d_uint32 index)
    {
        Value v;

        v.putVnumber(index);

        //writef("PropTable::del(%d)\n", index);
        return del(&v);
    }
    void initialize()
    {
        if(!table)
            table = new RandAA!(Value, Property);
    }
}


