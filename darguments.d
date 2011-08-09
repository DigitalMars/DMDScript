
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


module dmdscript.darguments;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.identifier;

// The purpose of Darguments is to implement "value sharing"
// per ECMA 10.1.8 between the activation object and the
// arguments object.
// We implement it by forwarding the property calls from the
// arguments object to the activation object.

class Darguments : Dobject
{
    Dobject actobj;             // activation object
    Identifier*[] parameters;

    int isDarguments() { return true; }

    this(Dobject caller, Dobject callee, Dobject actobj,
            Identifier*[] parameters, Value[] arglist)

    {
        super(Dobject.getPrototype());

        this.actobj = actobj;
        this.parameters = parameters;

        if (caller)
            Put(TEXT_caller, caller, DontEnum);
        else
            Put(TEXT_caller, &vnull, DontEnum);

        Put(TEXT_callee, callee, DontEnum);
        Put(TEXT_length, arglist.length, DontEnum);

        for (uint a = 0; a < arglist.length; a++)
        {
            Put(a, &arglist[a], DontEnum);
        }
    }

    Value* Get(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
            ? actobj.Get(index)
            : Dobject.Get(PropertyName);
    }

    Value* Get(d_uint32 index)
    {
        return (index < parameters.length)
            ? actobj.Get(index)
            : Dobject.Get(index);
    }

    Value* Get(d_uint32 index, Value* vindex)
    {
        return (index < parameters.length)
            ? actobj.Get(index, vindex)
            : Dobject.Get(index, vindex);
    }

    Value* Put(d_string PropertyName, Value* value, uint attributes)
    {
        d_uint32 index;

        if (StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(PropertyName, value, attributes);
        else
            return Dobject.Put(PropertyName, value, attributes);
    }

    Value* Put(Identifier* key, Value* value, uint attributes)
    {
        d_uint32 index;

        if (StringToIndex(key.value.string, index) && index < parameters.length)
            return actobj.Put(key, value, attributes);
        else
            return Dobject.Put(key, value, attributes);
    }

    Value* Put(d_string PropertyName, Dobject o, uint attributes)
    {
        d_uint32 index;

        if (StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(PropertyName, o, attributes);
        else
            return Dobject.Put(PropertyName, o, attributes);
    }

    Value* Put(d_string PropertyName, d_number n, uint attributes)
    {
        d_uint32 index;

        if (StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(PropertyName, n, attributes);
        else
            return Dobject.Put(PropertyName, n, attributes);
    }

    Value* Put(d_uint32 index, Value* vindex, Value* value, uint attributes)
    {
        if (index < parameters.length)
            return actobj.Put(index, vindex, value, attributes);
        else
            return Dobject.Put(index, vindex, value, attributes);
    }

    Value* Put(d_uint32 index, Value* value, uint attributes)
    {
        if (index < parameters.length)
            return actobj.Put(index, value, attributes);
        else
            return Dobject.Put(index, value, attributes);
    }

    int CanPut(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
            ? actobj.CanPut(PropertyName)
            : Dobject.CanPut(PropertyName);
    }

    int HasProperty(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
            ? actobj.HasProperty(PropertyName)
            : Dobject.HasProperty(PropertyName);
    }

    int Delete(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
            ? actobj.Delete(PropertyName)
            : Dobject.Delete(PropertyName);
    }
}

