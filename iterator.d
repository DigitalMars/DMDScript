
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
 * see www.digitalmars.com/dscript/cppscript.html.
 */


module dmdscript.iterator;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.property;

Dobject getPrototype(Dobject o)
{
    version (all)
    {
        return o.internal_prototype;    // use internal [[Prototype]]
    }
    else
    {
        // use "prototype"
        Value *v;

        v = o.Get(TEXT_prototype);
        if (!v || v.isPrimitive())
            return null;
        o = v.toObject();
        return o;
    }
}

struct Iterator
{
    Value[] keys;
    size_t keyindex;
    Dobject o;
    Dobject ostart;

    debug
    {
        const uint ITERATOR_VALUE = 0x1992836;
        uint foo = ITERATOR_VALUE;
    }

    invariant
    {
        debug assert(foo == ITERATOR_VALUE);
    }

    void ctor(Dobject o)
    {
        debug foo = ITERATOR_VALUE;
        //writef("Iterator: o = %p, p = %p\n", o, p);
        ostart = o;
        this.o = o;
        keys = o.proptable.table.keys.sort;
        keyindex = 0;
    }

    Value *next()
    {   Property* p;

        //writef("Iterator::done() p = %p\n", p);

        for (; ; keyindex++)
        {
            while (keyindex == keys.length)
            {
                delete keys;
                o = getPrototype(o);
                if (!o)
                    return null;
                keys = o.proptable.table.keys.sort;
                keyindex = 0;
            }
            Value* key = &keys[keyindex];
            p = *key in o.proptable.table;
            if (!p)                     // if no longer in property table
                continue;
            if (p.attributes & DontEnum)
                continue;
            else
            {
                // ECMA 12.6.3
                // Do not enumerate those properties in prototypes
                // that are overridden
                if (o != ostart)
                {
                    for (Dobject ot = ostart; ot != o; ot = getPrototype(ot))
                    {
                        // If property p is in t, don't enumerate
                        if (*key in ot.proptable.table)
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
