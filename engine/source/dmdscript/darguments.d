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


module dmdscript.darguments;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.identifier;
import dmdscript.value;
import dmdscript.text;
import dmdscript.property;

// The purpose of Darguments is to implement "value sharing"
// per ECMA 10.1.8 between the activation object and the
// arguments object.
// We implement it by forwarding the property calls from the
// arguments object to the activation object.

class Darguments : Dobject
{
    Dobject actobj;             // activation object
    Identifier*[] parameters;

    override int isDarguments() const
    {
        return true;
    }

    this(CallContext* cc, Dobject caller, Dobject callee, Dobject actobj,
         Identifier *[] parameters, Value[] arglist)

    {
        super(cc, Dobject.getPrototype(cc));

        this.actobj = actobj;
        this.parameters = parameters;

        if(caller)
            Put(cc, TEXT_caller, caller, DontEnum);
        else
            Put(cc, TEXT_caller, &vnull, DontEnum);

        Put(cc, TEXT_callee, callee, DontEnum);
        Put(cc, TEXT_length, arglist.length, DontEnum);

        for(uint a = 0; a < arglist.length; a++)
        {
            Put(cc, a, &arglist[a], DontEnum);
        }
    }

    override Value* Get(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.Get(index)
               : Dobject.Get(PropertyName);
    }

    override Value* Get(d_uint32 index)
    {
        return (index < parameters.length)
               ? actobj.Get(index)
               : Dobject.Get(index);
    }

    override Value* Get(d_uint32 index, Value* vindex)
    {
        return (index < parameters.length)
               ? actobj.Get(index, vindex)
               : Dobject.Get(index, vindex);
    }

    override Value* Put(CallContext* cc, string PropertyName, Value* value, uint attributes)
    {
        d_uint32 index;

        if(StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(cc, PropertyName, value, attributes);
        else
            return Dobject.Put(cc, PropertyName, value, attributes);
    }

    override Value* Put(CallContext* cc, Identifier* key, Value* value, uint attributes)
    {
        d_uint32 index;

        if(StringToIndex(key.value.string, index) && index < parameters.length)
            return actobj.Put(cc, key, value, attributes);
        else
            return Dobject.Put(cc, key, value, attributes);
    }

    override Value* Put(CallContext* cc, string PropertyName, Dobject o, uint attributes)
    {
        d_uint32 index;

        if(StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(cc, PropertyName, o, attributes);
        else
            return Dobject.Put(cc, PropertyName, o, attributes);
    }

    override Value* Put(CallContext* cc, string PropertyName, d_number n, uint attributes)
    {
        d_uint32 index;

        if(StringToIndex(PropertyName, index) && index < parameters.length)
            return actobj.Put(cc, PropertyName, n, attributes);
        else
            return Dobject.Put(cc, PropertyName, n, attributes);
    }

    override Value* Put(CallContext* cc, d_uint32 index, Value* vindex, Value* value, uint attributes)
    {
        if(index < parameters.length)
            return actobj.Put(cc, index, vindex, value, attributes);
        else
            return Dobject.Put(cc, index, vindex, value, attributes);
    }

    override Value* Put(CallContext* cc, d_uint32 index, Value* value, uint attributes)
    {
        if(index < parameters.length)
            return actobj.Put(cc, index, value, attributes);
        else
            return Dobject.Put(cc, index, value, attributes);
    }

    override int CanPut(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.CanPut(PropertyName)
               : Dobject.CanPut(PropertyName);
    }

    override int HasProperty(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.HasProperty(PropertyName)
               : Dobject.HasProperty(PropertyName);
    }

    override int Delete(d_string PropertyName)
    {
        d_uint32 index;

        return (StringToIndex(PropertyName, index) && index < parameters.length)
               ? actobj.Delete(PropertyName)
               : Dobject.Delete(PropertyName);
    }
}

