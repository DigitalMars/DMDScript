
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


module dmdscript.property;

import dmdscript.script;
import dmdscript.value;
import dmdscript.identifier;

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
    uint attributes;

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
        int length;
        void* ptr;
    }

    struct aaA
    {
        aaA *left;
        aaA *right;
        union
        {
            uint nodes; // used in the head element to store the total # of AA elements
            uint hash;
        }
        /* key   */
        /* value */
    }

    aaA*[] _aaRehash(aaA*[]* paa, TypeInfo keyti);

    /************************
     * Alternate Get() version
     */

    Property* _aaGetY(uint hash, Property[Value]* bb, Value* key)
    {
        uint i;
        aaA *e;
        aaA **pe;
        aaA*[]* aa = cast(aaA*[]*)bb;
        size_t aalen;

        aalen = (*aa).length;
        if (!aalen)
        {
            alias aaA *pa;

            aalen = 97 + 1;
            *aa = new pa[aalen];
            (*aa)[0] = cast(aaA *) cast(void*) new byte[aaA.sizeof];
        }

        //printf("hash = %d\n", hash);
        i = (hash % (aalen - 1)) + 1;
        pe = &(*aa)[i];
        while ((e = *pe) != null)
        {   int c;

            c = hash - e.hash;
            if (c == 0)
            {
                Value* v = cast(Value*)(e + 1);
                if (key.vtype == V_NUMBER)
                {   if (v.vtype == V_NUMBER && key.number == v.number)
                        goto Lret;
                }
                else if (key.vtype == V_STRING)
                {   if (v.vtype == V_STRING && key.string is v.string)
                        goto Lret;
                }
                c = key.opCmp(v);
                if (c == 0)
                    goto Lret;
            }

            if (c < 0)
                pe = &e.left;
            else
                pe = &e.right;
        }

        // Not found, create new elem
        //printf("\tcreate new one\n");
        e = cast(aaA *) cast(void*) new byte[aaA.sizeof + Value.sizeof + Property.sizeof];
        memcpy(e + 1, key, Value.sizeof);
        e.hash = hash;
        *pe = e;

        uint nodes = ++(*aa)[0].nodes;
        //printf("length = %d, nodes = %d\n", (*aa).length, nodes);
        if (nodes > aalen * 4)
        {
            _aaRehash(aa, typeid(Value));
        }

    Lret:
        return cast(Property*)(cast(void *)(e + 1) + Value.sizeof);
    }

    /************************************
     * Alternate In() with precomputed values.
     */

    Property* _aaInY(uint hash, Property[Value] bb, Value* key)
    {
        uint i;
        aaA *e;
        aaA*[] aa = *cast(aaA*[]*)&bb;

        //printf("_aaIn(), aa.length = %d, .ptr = %x\n", aa.length, cast(uint)aa.ptr);
        if (aa.length > 1)
        {
            //printf("hash = %d\n", hash);
            i = (hash % (aa.length - 1)) + 1;
            e = aa[i];
            while (e != null)
            {   int c;

                c = hash - e.hash;
                if (c == 0)
                {
                    Value* v = cast(Value*)(e + 1);
                    if (key.vtype == V_NUMBER && v.vtype == V_NUMBER &&
                        key.number == v.number)
                        goto Lfound;
                    c = key.opCmp(v);
                    if (c == 0)
                    {
                     Lfound:
                        return cast(Property*)(cast(void *)(e + 1) + Value.sizeof);
                    }
                }

                if (c < 0)
                    e = e.left;
                else
                    e = e.right;
            }
        }

        // Not found
        return null;
    }
}

/*********************************** PropTable *********************/

struct PropTable
{
    Property[Value] table;
    PropTable* previous;

    int opApply(int delegate(inout Property) dg)
    {   int result;

        foreach (inout Property p; table)
        {
            result = dg(p);
            if (result)
                break;
        }
        return result;
    }

    int opApply(int delegate(inout Value, inout Property) dg)
    {   int result;

        foreach (Value key, inout Property p; table)
        {
            result = dg(key, p);
            if (result)
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
        if (!v)
            return null;

        // Work backwards from &p->value to p
        p = cast(Property *)(cast(char *)v - uint.sizeof /*Property.value.offsetof*/);

        return p;
    }

    Value* get(Value* key, uint hash)
    {
        uint i;
        Property *p;
        PropTable *t;

        //writefln("get(key = '%s', hash = x%x)", key.toString(), hash);
        assert(key.toHash() == hash);
        t = this;
        do
        {
            //writefln("\tt = %x", cast(uint)t);
//          p = *key in t.table;
            p = _aaInY(hash, t.table, key);

            if (p)
            {   //writefln("\tfound");
                //p.value.dump();
                assert(&t.table[*key] == p);
                //p.value.dump();
                return &p.value;
            }
            t = t.previous;
        } while (t);
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

    Value* get(d_string name, uint hash)
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
        Property* p;

        p = *key in table;
        return p && (!enumerable || !(p.attributes & DontEnum));
    }

    int hasproperty(Value* key)
    {
        return (*key in table) != null;
    }

    int hasproperty(d_string name)
    {
        Value v;

        v.putVstring(name);
        return hasproperty(&v);
    }

    Value* put(Value* key, uint hash, Value* value, uint attributes)
    {
        Property* p;

        //writefln("put(key = %s, hash = x%x, value = %s, attributes = x%x)", key.toString(), hash, value.toString(), attributes);
        //writefln("put(key = %s)", key.toString());
//      p = &table[*key];
        p = _aaGetY(hash, &table, key);
/+
    {
        uint i;
        aaA *e;
        aaA **pe;
        aaA*[]* aa = cast(aaA*[]*)&table;
        size_t aalen;

        aalen = (*aa).length;
        if (!aalen)
        {
            alias aaA *pa;

            aalen = 97 + 1;
            *aa = new pa[aalen];
            (*aa)[0] = cast(aaA *) cast(void*) new byte[aaA.sizeof];
        }

        //printf("hash = %d\n", hash);
        i = (hash % (aalen - 1)) + 1;
        pe = &(*aa)[i];
        while ((e = *pe) != null)
        {   int c;

            c = hash - e.hash;
            if (c == 0)
            {
                Value* v = cast(Value*)(e + 1);
                if (key.vtype == V_NUMBER)
                {   if (v.vtype == V_NUMBER && key.number == v.number)
                        goto Lfound;
                }
                else if (key.vtype == V_STRING)
                {   if (v.vtype == V_STRING && key.string is v.string)
                        goto Lfound;
                }
                c = key.opCmp(v);
                if (c == 0)
                {
                Lfound:
                    p = cast(Property*)(v + 1);
                    goto Lx;
                }
            }

            if (c < 0)
                pe = &e.left;
            else
                pe = &e.right;
        }

        // Not found, create new elem
        //printf("\tcreate new one\n");
        e = cast(aaA *) cast(void*) new byte[aaA.sizeof + Value.sizeof + Property.sizeof];
        memcpy(e + 1, key, Value.sizeof);
        e.hash = hash;
        *pe = e;

        uint nodes = ++(*aa)[0].nodes;
        //printf("length = %d, nodes = %d\n", (*aa).length, nodes);
        if (nodes > aalen * 4)
        {
            _aaRehash(aa, typeid(Value));
        }

        p = cast(Property*)(cast(void *)(e + 1) + Value.sizeof);
    }
+/
        if (p.value.vtype != V_NONE)
        {
    Lx:
            if (attributes & DontOverride ||
                p.attributes & ReadOnly)
            {
                if (p.attributes & KeyWord)
                    return null;
                return &vundefined;
            }

            PropTable* t = previous;
            if (t)
            {
                do
                {   Property* q;
        //          q = *key in t.table;
                    q = _aaInY(hash, t.table, key);
                    if (q)
                    {
                        if (q.attributes & ReadOnly)
                        {   p.attributes |= ReadOnly;
                            return &vundefined;
                        }
                        break;
                    }
                    t = t.previous;
                } while (t);
            }

            // Overwrite property with new value
            Value.copy(&p.value, value);
            p.attributes = (attributes & ~DontOverride) | (p.attributes & (DontDelete | DontEnum));
            return null;
        }

        // Not in table; create new entry

        p.attributes = attributes & ~DontOverride;
        Value.copy(&p.value, value);
        //p.value.dump();
        assert(p.value == value);

        return null;                    // success
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

    int canput(Value* key, uint hash)
    {
        Property *p;
        PropTable *t;

        t = this;
        do
        {
//          p = *key in t.table;
            p = _aaInY(hash, t.table, key);
            if (p)
            {   return (p.attributes & ReadOnly)
                        ? false : true;
            }
            t = t.previous;
        } while (t);
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
        Property *p;

        //writef("PropTable::del('%ls')\n", d_string_ptr(key.toString()));
        p = *key in table;
        if (p)
        {
            if (p.attributes & DontDelete)
                return false;
            delete table[*key];
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
}


