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


module dmdscript.dfunction;

import std.string;
import core.stdc.stdlib;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.protoerror;
import dmdscript.threadcontext;
import dmdscript.text;
import dmdscript.errmsgs;
import dmdscript.property;
import dmdscript.scopex;
import dmdscript.dnative;
import dmdscript.functiondefinition;
import dmdscript.parse;
import dmdscript.ddeclaredfunction;

/* ===================== Dfunction_constructor ==================== */

class DfunctionConstructor : Dfunction
{
    this()
    {
        super(1, Dfunction_prototype);

        // Actually put in later by Dfunction::initialize()
        //unsigned attributes = DontEnum | DontDelete | ReadOnly;
        //Put(TEXT_prototype, Dfunction::getPrototype(), attributes);
    }

    override void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.3.2.1
        immutable(char)[] bdy;
        immutable(char)[] P;
        FunctionDefinition fd;
        ErrInfo errinfo;

        //writef("Dfunction_constructor::Construct()\n");

        // Get parameter list (P) and body from arglist[]
        if(arglist.length)
        {
            bdy = arglist[arglist.length - 1].toString();
            if(arglist.length >= 2)
            {
                for(uint a = 0; a < arglist.length - 1; a++)
                {
                    if(a)
                        P ~= ',';
                    P ~= arglist[a].toString();
                }
            }
        }

        if(Parser.parseFunctionDefinition(fd, P, bdy, errinfo))
            goto Lsyntaxerror;

        if(fd)
        {
            Scope sc;

            sc.ctor(fd);
            fd.semantic(&sc);
            errinfo = sc.errinfo;
            if(errinfo.message)
                goto Lsyntaxerror;
            fd.toIR(null);
            Dfunction fobj = new DdeclaredFunction(fd);
            assert(cc.scoperoot <= cc.scopex.length);
            fobj.scopex = cc.scopex[0..cc.scoperoot].dup;
            ret.putVobject(fobj);
        }
        else
            ret.putVundefined();

        return null;

        Lsyntaxerror:
        Dobject o;

        ret.putVundefined();
        o = new syntaxerror.D0(&errinfo);
        Value* v = new Value;
        v.putVobject(o);
        return v;
    }

    override void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.3.1
        return Construct(cc, ret, arglist);
    }
}


/* ===================== Dfunction_prototype_toString =============== */

void* Dfunction_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    immutable(char)[] s;
    Dfunction f;

    //writef("function.prototype.toString()\n");
    // othis must be a Function
    if(!othis.isClass(TEXT_Function))
    {
        ErrInfo errinfo;
        ret.putVundefined();
        return Dobject.RuntimeError(&errinfo, ERR_TS_NOT_TRANSFERRABLE);
    }
    else
    {
        // Generate string that looks like a FunctionDeclaration
        // FunctionDeclaration:
        //	function Identifier (Identifier, ...) Block

        // If anonymous function, the name should be "anonymous"
        // per ECMA 15.3.2.1.19

        f = cast(Dfunction)othis;
        s = f.toString();
        ret.putVstring(s);
    }
    return null;
}

/* ===================== Dfunction_prototype_apply =============== */

void* Dfunction_prototype_apply(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.3.4.3

    Value* thisArg;
    Value* argArray;
    Dobject o;
    void* v;

    thisArg = &vundefined;
    argArray = &vundefined;
    switch(arglist.length)
    {
    case 0:
        break;
    default:
        argArray = &arglist[1];
        goto case;
    case 1:
        thisArg = &arglist[0];
        break;
    }

    if(thisArg.isUndefinedOrNull())
        o = cc.global;
    else
        o = thisArg.toObject();

    if(argArray.isUndefinedOrNull())
    {
        v = othis.Call(cc, o, ret, null);
    }
    else
    {
        if(argArray.isPrimitive())
        {
            Ltypeerror:
            ret.putVundefined();
            ErrInfo errinfo;
            return Dobject.RuntimeError(&errinfo, ERR_ARRAY_ARGS);
        }
        Dobject a;

        a = argArray.toObject();

        // Must be array or arguments object
        if(!a.isDarray() && !a.isDarguments())
            goto Ltypeerror;

        uint len;
        uint i;
        Value[] alist;
        Value* x;

        x = a.Get(TEXT_length);
        len = x ? x.toUint32() : 0;

        Value[] p1;
        Value* v1;
        if(len < 128)
            v1 = cast(Value*)alloca(len * Value.sizeof);
        if(v1)
            alist = v1[0 .. len];
        else
        {
            p1 = new Value[len];
            alist = p1;
        }

        for(i = 0; i < len; i++)
        {
            x = a.Get(i);
            Value.copy(&alist[i], x);
        }

        v = othis.Call(cc, o, ret, alist);

        delete p1;
    }
    return v;
}

/* ===================== Dfunction_prototype_call =============== */

void* Dfunction_prototype_call(Dobject pthis, CallContext *cc, Dobject othis, Value *ret, Value[] arglist)
{
    // ECMA v3 15.3.4.4
    Value* thisArg;
    Dobject o;
    void* v;

    if(arglist.length == 0)
    {
        o = cc.global;
        v = othis.Call(cc, o, ret, arglist);
    }
    else
    {
        thisArg = &arglist[0];
        if(thisArg.isUndefinedOrNull())
            o = cc.global;
        else
            o = thisArg.toObject();
        v = othis.Call(cc, o, ret, arglist[1 .. $]);
    }
    return v;
}

/* ===================== Dfunction_prototype ==================== */

class DfunctionPrototype : Dfunction
{
    this()
    {
        super(0, Dobject_prototype);

        uint attributes = DontEnum;

        classname = TEXT_Function;
        name = "prototype";
        Put(TEXT_constructor, Dfunction_constructor, attributes);

        static enum NativeFunctionData[] nfd =
        [
            { TEXT_toString, &Dfunction_prototype_toString, 0 },
            { TEXT_apply, &Dfunction_prototype_apply, 2 },
            { TEXT_call, &Dfunction_prototype_call, 1 },
        ];

        DnativeFunction.initialize(this, nfd, attributes);
    }

    override void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA v3 15.3.4
        // Accept any arguments and return "undefined"
        ret.putVundefined();
        return null;
    }
}


/* ===================== Dfunction ==================== */

class Dfunction : Dobject
{ const (char)[] name;
  Dobject[] scopex;     // Function object's scope chain per 13.2 step 7

  this(d_uint32 length)
  {
      this(length, Dfunction.getPrototype());
  }

  this(d_uint32 length, Dobject prototype)
  {
      super(prototype);
      classname = TEXT_Function;
      name = TEXT_Function;
      Put(TEXT_length, length, DontDelete | DontEnum | ReadOnly);
      Put(TEXT_arity, length, DontDelete | DontEnum | ReadOnly);
  }

  override immutable(char)[] getTypeof()
  {     // ECMA 11.4.3
      return TEXT_function;
  }

  override string toString()
  {
      // Native overrides of this function replace Identifier with the actual name.
      // Don't need to do parameter list, though.
      immutable(char)[] s;

      s = std.string.format("function %s() { [native code] }", name);
      return s;
  }

  override void *HasInstance(Value* ret, Value* v)
  {
      // ECMA v3 15.3.5.3
      Dobject V;
      Value* w;
      Dobject o;

      if(v.isPrimitive())
          goto Lfalse;
      V = v.toObject();
      w = Get(TEXT_prototype);
      if(w.isPrimitive())
      {
          ErrInfo errinfo;
          return RuntimeError(&errinfo, errmsgtbl[ERR_MUST_BE_OBJECT], w.getType());
      }
      o = w.toObject();
      for(;; )
      {
          V = V.internal_prototype;
          if(!V)
              goto Lfalse;
          if(o == V)
              goto Ltrue;
      }

      Ltrue:
      ret.putVboolean(true);
      return null;

      Lfalse:
      ret.putVboolean(false);
      return null;
  }

  static Dfunction isFunction(Value* v)
  {
      Dfunction r;
      Dobject o;

      r = null;
      if(!v.isPrimitive())
      {
          o = v.toObject();
          if(o.isClass(TEXT_Function))
              r = cast(Dfunction)o;
      }
      return r;
  }


  static Dfunction getConstructor()
  {
      return Dfunction_constructor;
  }

  static Dobject getPrototype()
  {
      return Dfunction_prototype;
  }

  static void initialize()
  {
      Dfunction_constructor = new DfunctionConstructor();
      Dfunction_prototype = new DfunctionPrototype();

      Dfunction_constructor.Put(TEXT_prototype, Dfunction_prototype, DontEnum | DontDelete | ReadOnly);

      Dfunction_constructor.internal_prototype = Dfunction_prototype;
      Dfunction_constructor.proptable.previous = Dfunction_prototype.proptable;
  }
}
