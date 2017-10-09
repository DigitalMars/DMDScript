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


module dmdscript.iterator;

import std.algorithm.sorting;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.property;

Dobject getPrototype(Dobject o)
{
    version(all)
    {
        return o.internal_prototype;    // use internal [[Prototype]]
    }
    else
    {
        // use "prototype"
        Value *v;

        v = o.Get(TEXT_prototype);
        if(!v || v.isPrimitive())
            return null;
        o = v.toObject();
        return o;
    }
}

struct Iterator
{
            Value[] keys;
    size_t  keyindex;
    Dobject o;
    Dobject ostart;
    CallContext* callcontext;

    debug
    {
        enum uint ITERATOR_VALUE = 0x1992836;
        uint foo = ITERATOR_VALUE;
    }

    invariant()
    {
        debug assert(foo == ITERATOR_VALUE);
    }

    void ctor(CallContext* cc, Dobject o)
    {
        debug foo = ITERATOR_VALUE;
        //writef("Iterator: o = %p, p = %p\n", o, p);
        ostart = o;
        this.o = o;
        this.callcontext = cc;
        keys = o.proptable.table.keys.sort!((a, b) => a.compare(cc, b) < 0).release;
        keyindex = 0;
    }

    Value *next()
    {
        Property* p;

        //writef("Iterator::done() p = %p\n", p);

        for(;; keyindex++)
        {
            while(keyindex == keys.length)
            {
                delete keys;
                o = getPrototype(o);
                if(!o)
                    return null;
                keys = o.proptable.table.keys.sort!((a, b) => a.compare(this.callcontext, b) < 0).release;
                keyindex = 0;
            }
            Value* key = &keys[keyindex];
            p = *key in o.proptable.table;
            if(!p)                      // if no longer in property table
                continue;
            if(p.attributes & DontEnum)
                continue;
            else
            {
                // ECMA 12.6.3
                // Do not enumerate those properties in prototypes
                // that are overridden
                if(o != ostart)
                {
                    for(Dobject ot = ostart; ot != o; ot = getPrototype(ot))
                    {
                        // If property p is in t, don't enumerate
                        if(*key in ot.proptable.table)
                            goto Lcontinue;
                    }
                }
                keyindex++;
                return key; //&p.value;

                Lcontinue:
                ;
            }
        }
        assert(0);
    }
}
