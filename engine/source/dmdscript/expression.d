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

module dmdscript.expression;

import std.string;
import std.algorithm;
import std.string;
import std.range;
import std.exception;
import std.stdio;

import dmdscript.script;
import dmdscript.lexer;
import dmdscript.scopex;
import dmdscript.text;
import dmdscript.errmsgs;
import dmdscript.functiondefinition;
import dmdscript.irstate;
import dmdscript.ir;
import dmdscript.opcodes;
import dmdscript.identifier;

/******************************** Expression **************************/

class Expression
{
    enum uint EXPRESSION_SIGNATURE = 0x3AF31E3F;
    uint signature = EXPRESSION_SIGNATURE;

    Loc loc;                    // file location
    TOK op;

    this(Loc loc, TOK op)
    {
        this.loc = loc;
        this.op = op;
        signature = EXPRESSION_SIGNATURE;
    }

    invariant()
    {
        assert(signature == EXPRESSION_SIGNATURE);
        assert(op != TOKreserved && op < TOKmax);
    }

    /**************************
     * Semantically analyze Expression.
     * Determine types, fold constants, e
     */

    Expression semantic(Scope *sc)
    {
        return this;
    }

    override d_string toString()
    {
        char[] buf;

        toBuffer(buf);
        return assumeUnique(buf);
    }

    void toBuffer(ref char[] buf)
    {
        buf ~= toString();
    }

    void checkLvalue(Scope *sc)
    {
        d_string buf;

        //writefln("checkLvalue(), op = %d", op);
        if(sc.funcdef)
        {
            if(sc.funcdef.isAnonymous)
                buf = "anonymous";
            else if(sc.funcdef.name)
                buf = sc.funcdef.name.toString();
        }
        buf ~= std.string.format("(%d) : Error: ", loc);
        buf ~= std.string.format(errmsgtbl[ERR_CANNOT_ASSIGN_TO], toString());

        if(!sc.errinfo.message)
        {
            sc.errinfo.message = buf;
            sc.errinfo.linnum = loc;
            sc.errinfo.srcline = Lexer.locToSrcline(sc.getSource().ptr, loc);
        }
    }

    // Do we match for purposes of optimization?

    int match(Expression e)
    {
        return false;
    }

    // Is the result of the expression guaranteed to be a boolean?

    int isBooleanResult()
    {
        return false;
    }

    void toIR(IRstate *irs, uint ret)
    {
        writef("Expression::toIR('%s')\n", toString());
    }

    void toLvalue(IRstate *irs, out uint base, IR *property, out int opoff)
    {
        base = irs.alloc(1);
        toIR(irs, base);
        property.index = 0;
        opoff = 3;
    }
}

/******************************** RealExpression **************************/

class RealExpression : Expression
{
    real_t value;

    this(Loc loc, real_t value)
    {
        super(loc, TOKreal);
        this.value = value;
    }

    override d_string toString()
    {
        d_string buf;
        long i;

        i = cast(long)value;
        if(i == value)
            buf = std.string.format("%d", i);
        else
            buf = std.string.format("%g", value);
        return buf;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= std.string.format("%g", value);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        //writef("RealExpression::toIR(%g)\n", value);

        static assert(value.sizeof == 2 * uint.sizeof);
        if(ret)
            irs.genX(loc, IRnumber, ret, value);
    }
}

/******************************** IdentifierExpression **************************/

class IdentifierExpression : Expression
{
    Identifier *ident;

    this(Loc loc, Identifier * ident)
    {
        super(loc, TOKidentifier);
        this.ident = ident;
    }

    override Expression semantic(Scope *sc)
    {
        return this;
    }

    override d_string toString()
    {
        return ident.toString();
    }

    override void checkLvalue(Scope *sc)
    {
    }

    override int match(Expression e)
    {
        if(e.op != TOKidentifier)
            return 0;

        IdentifierExpression ie = cast(IdentifierExpression)(e);

        return ident == ie.ident;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        Identifier* id = ident;

        assert(id.sizeof == IRstate.Op.sizeof);
        if(ret)
            irs.gen2(loc, IRgetscope, ret, cast(IRstate.Op)id);
        else
            irs.gen1(loc,IRcheckref, cast(IRstate.Op)id);
    }

    override void toLvalue(IRstate *irs, out uint base, IR *property, out int opoff)
    {
        //irs.gen1(loc, IRthis, base);
        property.id = ident;
        opoff = 2;
        base = ~0u;
    }
}

/******************************** ThisExpression **************************/

class ThisExpression : Expression
{
    this(Loc loc)
    {
        super(loc, TOKthis);
    }

    override d_string toString()
    {
        return TEXT_this;
    }

    override Expression semantic(Scope *sc)
    {
        return this;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        if(ret)
            irs.gen1(loc, IRthis, ret);
    }
}

/******************************** NullExpression **************************/

class NullExpression : Expression
{
    this(Loc loc)
    {
        super(loc, TOKnull);
    }

    override d_string toString()
    {
        return TEXT_null;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        if(ret)
            irs.gen1(loc, IRnull, ret);
    }
}

/******************************** StringExpression **************************/

class StringExpression : Expression
{
    static import std.ascii;
    import std.format : format;

    d_string string;

    this(Loc loc, d_string string)
    {
        //writefln("StringExpression('%s')", string);
        super(loc, TOKstring);
        this.string = string;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= '"';
        foreach(dchar c; string)
        {
            switch(c)
            {
            case '"':
                buf ~= '\\';
                goto Ldefault;

            default:
                Ldefault:
                if(c & ~0xFF)
                    buf ~= format("\\u%04x", c);
                else if(std.ascii.isPrintable(c))
                    buf ~= cast(tchar)c;
                else
                    buf ~= format("\\x%02x", c);
                break;
            }
        }
        buf ~= '"';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        static assert((Identifier*).sizeof == IRstate.Op.sizeof);
        if(ret)
        {
            auto u = cast(IRstate.Op)Identifier.build(string);
            irs.gen2(loc, IRstring, ret, u);
        }
    }
}

/******************************** RegExpLiteral **************************/

class RegExpLiteral : Expression
{
    d_string string;

    this(Loc loc, d_string string)
    {
        //writefln("RegExpLiteral('%s')", string);
        super(loc, TOKregexp);
        this.string = string;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= string;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        d_string pattern;
        d_string attribute = null;
        sizediff_t e;

        uint argc;
        uint argv;
        uint b;

        // Regular expression is of the form:
        //	/pattern/attribute

        // Parse out pattern and attribute strings
        assert(string[0] == '/');
        e = std.string.lastIndexOf(string, '/');
        assert(e != -1);
        pattern = string[1 .. e];
        argc = 1;
        if(e + 1 < string.length)
        {
            attribute = string[e + 1 .. $];
            argc++;
        }

        // Generate new Regexp(pattern [, attribute])

        b = irs.alloc(1);
        Identifier* re = Identifier.build(TEXT_RegExp);
        irs.gen2(loc, IRgetscope, b, cast(IRstate.Op)re);
        argv = irs.alloc(argc);
        irs.gen2(loc, IRstring, argv, cast(IRstate.Op)Identifier.build(pattern));
        if(argc == 2)
            irs.gen2(loc, IRstring, argv + 1 * INDEX_FACTOR, cast(IRstate.Op)Identifier.build(attribute));
        irs.gen4(loc, IRnew, ret, b, argc, argv);
        irs.release(b, argc + 1);
    }
}

/******************************** BooleanExpression **************************/

class BooleanExpression : Expression
{
    int boolean;

    this(Loc loc, int boolean)
    {
        super(loc, TOKboolean);
        this.boolean = boolean;
    }

    override d_string toString()
    {
        return boolean ? "true" : "false";
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= toString();
    }

    override int isBooleanResult()
    {
        return true;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        if(ret)
            irs.gen2(loc, IRboolean, ret, boolean);
    }
}

/******************************** ArrayLiteral **************************/

class ArrayLiteral : Expression
{
    Expression[] elements;

    this(Loc loc, Expression[] elements)
    {
        super(loc, TOKarraylit);
        this.elements = elements;
    }

    override Expression semantic(Scope *sc)
    {
        foreach(ref Expression e; elements)
        {
            if(e)
                e = e.semantic(sc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        uint i;

        buf ~= '[';
        foreach(Expression e; elements)
        {
            if(i)
                buf ~= ',';
            i = 1;
            if(e)
                e.toBuffer(buf);
        }
        buf ~= ']';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint argc;
        uint argv;
        uint b;
        uint v;

        b = irs.alloc(1);
        static Identifier* ar;
        if(!ar)
            ar = Identifier.build(TEXT_Array);
        irs.gen2(loc, IRgetscope, b, cast(IRstate.Op)ar);
        if(elements.length)
        {
            Expression e;

            argc = cast(uint)elements.length;
            argv = irs.alloc(argc);
            if(argc > 1)
            {
                uint i;

                // array literal [a, b, c] is equivalent to:
                //	new Array(a,b,c)
                for(i = 0; i < argc; i++)
                {
                    e = elements[i];
                    if(e)
                    {
                        e.toIR(irs, argv + i * INDEX_FACTOR);
                    }
                    else
                        irs.gen1(loc, IRundefined, argv + i * INDEX_FACTOR);
                }
                irs.gen4(loc, IRnew, ret, b, argc, argv);
            }
            else
            {   //	[a] translates to:
                //	ret = new Array(1);
                //  ret[0] = a
                irs.genX(loc, IRnumber, argv, 1.0);
                irs.gen4(loc, IRnew, ret, b, argc, argv);

                e = elements[0];
                v = irs.alloc(1);
                if(e)
                    e.toIR(irs, v);
                else
                    irs.gen1(loc, IRundefined, v);
                irs.gen3(loc, IRputs, v, ret, cast(IRstate.Op)Identifier.build(TEXT_0));
                irs.release(v, 1);
            }
            irs.release(argv, argc);
        }
        else
        {
            // Generate new Array()
            irs.gen4(loc, IRnew, ret, b, 0, 0);
        }
        irs.release(b, 1);
    }
}

/******************************** FieldLiteral **************************/

class Field
{
    Identifier* ident;
    Expression exp;

    this(Identifier * ident, Expression exp)
    {
        this.ident = ident;
        this.exp = exp;
    }
}

/******************************** ObjectLiteral **************************/

class ObjectLiteral : Expression
{
    Field[] fields;

    this(Loc loc, Field[] fields)
    {
        super(loc, TOKobjectlit);
        this.fields = fields;
    }

    override Expression semantic(Scope *sc)
    {
        foreach(Field f; fields)
        {
            f.exp = f.exp.semantic(sc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        uint i;

        buf ~= '{';
        foreach(Field f; fields)
        {
            if(i)
                buf ~= ',';
            i = 1;
            buf ~= f.ident.toString();
            buf ~= ':';
            f.exp.toBuffer(buf);
        }
        buf ~= '}';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint b;

        b = irs.alloc(1);
        //irs.gen2(loc, IRstring, b, TEXT_Object);
        Identifier* ob = Identifier.build(TEXT_Object);
        irs.gen2(loc, IRgetscope, b, cast(IRstate.Op)ob);
        // Generate new Object()
        irs.gen4(loc, IRnew, ret, b, 0, 0);
        if(fields.length)
        {
            uint x;

            x = irs.alloc(1);
            foreach(Field f; fields)
            {
                f.exp.toIR(irs, x);
                irs.gen3(loc, IRputs, x, ret, cast(IRstate.Op)(f.ident));
            }
        }
    }
}

/******************************** FunctionLiteral **************************/

class FunctionLiteral : Expression
{ FunctionDefinition func;

  this(Loc loc, FunctionDefinition func)
  {
      super(loc, TOKobjectlit);
      this.func = func;
  }

  override Expression semantic(Scope *sc)
  {
      func = cast(FunctionDefinition)(func.semantic(sc));
      return this;
  }

  override void toBuffer(ref tchar[] buf)
  {
      func.toBuffer(buf);
  }

  override void toIR(IRstate *irs, uint ret)
  {
      func.toIR(null);
      irs.gen2(loc, IRobject, ret, cast(IRstate.Op)cast(void*)func);
  }
}

/***************************** UnaExp *************************************/

class UnaExp : Expression
{
    Expression e1;

    this(Loc loc, TOK op, Expression e1)
    {
        super(loc, op);
        this.e1 = e1;
    }

    override Expression semantic(Scope *sc)
    {
        e1 = e1.semantic(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= Token.toString(op);
        buf ~= ' ';
        e1.toBuffer(buf);
    }
}

/***************************** BinExp *************************************/

class BinExp : Expression
{
    Expression e1;
    Expression e2;

    this(Loc loc, TOK op, Expression e1, Expression e2)
    {
        super(loc, op);
        this.e1 = e1;
        this.e2 = e2;
    }

    override Expression semantic(Scope *sc)
    {
        e1 = e1.semantic(sc);
        e2 = e2.semantic(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= ' ';
        buf ~= Token.toString(op);
        buf ~= ' ';
        e2.toBuffer(buf);
    }

    void binIR(IRstate *irs, uint ret, uint ircode)
    {
        uint b;
        uint c;

        if(ret)
        {
            b = irs.alloc(1);
            e1.toIR(irs, b);
            if(e1.match(e2))
            {
                irs.gen3(loc, ircode, ret, b, b);
            }
            else
            {
                c = irs.alloc(1);
                e2.toIR(irs, c);
                irs.gen3(loc, ircode, ret, b, c);
                irs.release(c, 1);
            }
            irs.release(b, 1);
        }
        else
        {
            e1.toIR(irs, 0);
            e2.toIR(irs, 0);
        }
    }
}

/************************************************************/

/* Handle ++e and --e
 */

class PreExp : UnaExp
{
    uint ircode;

    this(Loc loc, uint ircode, Expression e)
    {
        super(loc, TOKplusplus, e);
        this.ircode = ircode;
    }

    override Expression semantic(Scope *sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= Token.toString(op);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint base;
        IR property;
        int opoff;

        //writef("PreExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        assert(opoff != 3);
        if(opoff == 2)
        {
            //irs.gen2(loc, ircode + 2, ret, property.index);
            irs.gen3(loc, ircode + 2, ret, property.index, property.id.toHash());
        }
        else
            irs.gen3(loc, ircode + opoff, ret, base, property.index);
    }
}

/************************************************************/

class PostIncExp : UnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKplusplus, e);
    }

    override Expression semantic(Scope *sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= Token.toString(op);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint base;
        IR property;
        int opoff;

        //writef("PostIncExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        assert(opoff != 3);
        if(opoff == 2)
        {
            if(ret)
            {
                irs.gen2(loc, IRpostincscope, ret, property.index);
            }
            else
            {
                //irs.gen2(loc, IRpreincscope, ret, property.index);
                irs.gen3(loc, IRpreincscope, ret, property.index, property.id.toHash());
            }
        }
        else
            irs.gen3(loc, (ret ? IRpostinc : IRpreinc) + opoff, ret, base, property.index);
    }
}

/****************************************************************/

class PostDecExp : UnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKplusplus, e);
    }

    override Expression semantic(Scope *sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= Token.toString(op);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint base;
        IR property;
        int opoff;

        //writef("PostDecExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        assert(opoff != 3);
        if(opoff == 2)
        {
            if(ret)
            {
                irs.gen2(loc, IRpostdecscope, ret, property.index);
            }
            else
            {
                //irs.gen2(loc, IRpredecscope, ret, property.index);
                irs.gen3(loc, IRpredecscope, ret, property.index, property.id.toHash());
            }
        }
        else
            irs.gen3(loc, (ret ? IRpostdec : IRpredec) + opoff, ret, base, property.index);
    }
}

/************************************************************/

class DotExp : UnaExp
{
    Identifier *ident;

    this(Loc loc, Expression e, Identifier * ident)
    {
        super(loc, TOKdot, e);
        this.ident = ident;
    }

    override void checkLvalue(Scope *sc)
    {
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= '.';
        buf ~= ident.toString();
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint base;

        //writef("DotExp::toIR('%s')\n", toChars());
        version(all)
        {
            // Some test cases depend on things like:
            //		foo.bar;
            // generating a property get even if the result is thrown away.
            base = irs.alloc(1);
            e1.toIR(irs, base);
            irs.gen3(loc, IRgets, ret, base, cast(IRstate.Op)ident);
        }
        else
        {
            if(ret)
            {
                base = irs.alloc(1);
                e1.toIR(irs, base);
                irs.gen3(loc, IRgets, ret, base, cast(IRstate.Op)ident);
            }
            else
                e1.toIR(irs, 0);
        }
    }

    override void toLvalue(IRstate *irs, out uint base, IR *property, out int opoff)
    {
        base = irs.alloc(1);
        e1.toIR(irs, base);
        property.id = ident;
        opoff = 1;
    }
}

/************************************************************/

class CallExp : UnaExp
{
    Expression[] arguments;

    this(Loc loc, Expression e, Expression[] arguments)
    {
        //writef("CallExp(e1 = %x)\n", e);
        super(loc, TOKcall, e);
        this.arguments = arguments;
    }

    override Expression semantic(Scope *sc)
    {
        IdentifierExpression ie;

        //writef("CallExp(e1=%x, %d, vptr=%x)\n", e1, e1.op, *(uint *)e1);
        //writef("CallExp(e1='%s')\n", e1.toString());
        e1 = e1.semantic(sc);
        /*if(e1.op != TOKcall)
            e1.checkLvalue(sc);
*/
        foreach(ref Expression e; arguments)
        {
            e = e.semantic(sc);
        }
        if(arguments.length == 1)
        {
            if(e1.op == TOKidentifier)
            {
                ie = cast(IdentifierExpression )e1;
                if(ie.ident.toString() == "assert")
                {
                    return new AssertExp(loc, arguments[0]);
                }
            }
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= '(';
        for(size_t u = 0; u < arguments.length; u++)
        {
            if(u)
                buf ~= ", ";
            arguments[u].toBuffer(buf);
        }
        buf ~= ')';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        // ret = base.property(argc, argv)
        // CALL ret,base,property,argc,argv
        uint base;
        uint argc;
        uint argv;
        IR property;
        int opoff;

        //writef("CallExp::toIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);

        if(arguments.length)
        {
            uint u;

            argc = cast(uint)arguments.length;
            argv = irs.alloc(argc);
            for(u = 0; u < argc; u++)
            {
                Expression e;

                e = arguments[u];
                e.toIR(irs, argv + u * INDEX_FACTOR);
            }
            arguments[] = null;         // release to GC
            arguments = null;
        }
        else
        {
            argc = 0;
            argv = 0;
        }

        if(opoff == 3)
            irs.gen4(loc, IRcallv, ret, base, argc, argv);
        else if(opoff == 2)
            irs.gen4(loc, IRcallscope, ret, property.index, argc, argv);
        else
            irs.genX(loc, IRcall + opoff, ret, base, property, argc, argv);
        irs.release(argv, argc);
    }
}

/************************************************************/

class AssertExp : UnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKassert, e);
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= "assert(";
        e1.toBuffer(buf);
        buf ~= ')';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint linnum;
        uint u;
        uint b;

        b = ret ? ret : irs.alloc(1);

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen2(loc, IRjt, 0, b);
        linnum = cast(uint)loc;
        irs.gen1(loc, IRassert, linnum);
        irs.patchJmp(u, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

/************************* NewExp ***********************************/

class NewExp : UnaExp
{
    Expression[] arguments;

    this(Loc loc, Expression e, Expression[] arguments)
    {
        super(loc, TOKnew, e);
        this.arguments = arguments;
    }

    override Expression semantic(Scope *sc)
    {
        e1 = e1.semantic(sc);
        for(size_t a = 0; a < arguments.length; a++)
        {
            arguments[a] = arguments[a].semantic(sc);
        }
        return this;
    }

    override void toBuffer(ref tchar[] buf)
    {
        buf ~= Token.toString(op);
        buf ~= ' ';

        e1.toBuffer(buf);
        buf ~= '(';
        for(size_t a = 0; a < arguments.length; a++)
        {
            arguments[a].toBuffer(buf);
        }
        buf ~= ')';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        // ret = new b(argc, argv)
        // CALL ret,b,argc,argv
        uint b;
        uint argc;
        uint argv;

        //writef("NewExp::toIR('%s')\n", toChars());
        b = irs.alloc(1);
        e1.toIR(irs, b);
        if(arguments.length)
        {
            uint u;

            argc = cast(uint)arguments.length;
            argv = irs.alloc(argc);
            for(u = 0; u < argc; u++)
            {
                Expression e;

                e = arguments[u];
                e.toIR(irs, argv + u * INDEX_FACTOR);
            }
        }
        else
        {
            argc = 0;
            argv = 0;
        }

        irs.gen4(loc, IRnew, ret, b, argc, argv);
        irs.release(argv, argc);
        irs.release(b, 1);
    }
}

/************************************************************/

class XUnaExp : UnaExp
{
    uint ircode;

    this(Loc loc, TOK op, uint ircode, Expression e)
    {
        super(loc, op, e);
        this.ircode = ircode;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        e1.toIR(irs, ret);
        if(ret)
            irs.gen1(loc, ircode, ret);
    }
}

class NotExp : XUnaExp
{
    this(Loc loc, Expression e)
    {
        super(loc, TOKnot, IRnot, e);
    }

    override int isBooleanResult()
    {
        return true;
    }
}

class DeleteExp : UnaExp
{
    bool lval;
    this(Loc loc, Expression e)
    {
        super(loc, TOKdelete, e);
    }

    override Expression semantic(Scope *sc)
    {
        e1.checkLvalue(sc);
        lval = sc.errinfo.message == null;
        //delete don't have to operate on Lvalue, while slightly stupid but perfectly by the standard
        if(!lval)
               sc.errinfo.message = null;
        return this;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint base;
        IR property;
        int opoff;

        if(lval){
            e1.toLvalue(irs, base, &property, opoff);
        
            assert(opoff != 3);
            if(opoff == 2)
                irs.gen2(loc, IRdelscope, ret, property.index);
            else
                irs.gen3(loc, IRdel + opoff, ret, base, property.index);
        }else{
            //e1.toIR(irs,ret);
            irs.gen2(loc,IRboolean,ret,true);
        }
    }
}

/************************* CommaExp ***********************************/

class CommaExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKcomma, e1, e2);
    }

    override void checkLvalue(Scope *sc)
    {
        e2.checkLvalue(sc);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        e1.toIR(irs, 0);
        e2.toIR(irs, ret);
    }
}

/************************* ArrayExp ***********************************/

class ArrayExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKarray, e1, e2);
    }

    override Expression semantic(Scope *sc)
    {
        checkLvalue(sc);
        return this;
    }

    override void checkLvalue(Scope *sc)
    {
    }

    override void toBuffer(ref tchar[] buf)
    {
        e1.toBuffer(buf);
        buf ~= '[';
        e2.toBuffer(buf);
        buf ~= ']';
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint base;
        IR property;
        int opoff;

        if(ret)
        {
            toLvalue(irs, base, &property, opoff);
            assert(opoff != 3);
            if(opoff == 2)
                irs.gen2(loc, IRgetscope, ret, property.index);
            else
                irs.gen3(loc, IRget + opoff, ret, base, property.index);
        }
        else
        {
            e1.toIR(irs, 0);
            e2.toIR(irs, 0);
        }
    }

    override void toLvalue(IRstate *irs, out uint base, IR *property, out int opoff)
    {
        uint index;

        base = irs.alloc(1);
        e1.toIR(irs, base);
        index = irs.alloc(1);
        e2.toIR(irs, index);
        property.index = index;
        opoff = 0;
    }
}

/************************* AssignExp ***********************************/

class AssignExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKassign, e1, e2);
    }

    override Expression semantic(Scope *sc)
    {
        //writefln("AssignExp.semantic()");
        super.semantic(sc);
        if(e1.op != TOKcall)            // special case for CallExp lvalue's
            e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint b;

        //writef("AssignExp::toIR('%s')\n", toChars());
        if(e1.op == TOKcall)            // if CallExp
        {
            assert(cast(CallExp)(e1));  // make sure we got it right

            // Special case a function call as an lvalue.
            // This can happen if:
            //	foo() = 3;
            // A Microsoft extension, it means to assign 3 to the default property of
            // the object returned by foo(). It only has meaning for com objects.
            // This functionality should be worked into toLvalue() if it gets used
            // elsewhere.

            uint base;
            uint argc;
            uint argv;
            IR property;
            int opoff;
            CallExp ec = cast(CallExp)e1;

            if(ec.arguments.length)
                argc = cast(uint)ec.arguments.length + 1;
            else
                argc = 1;

            argv = irs.alloc(argc);

            e2.toIR(irs, argv + (argc - 1) * INDEX_FACTOR);

            ec.e1.toLvalue(irs, base, &property, opoff);

            if(ec.arguments.length)
            {
                uint u;

                for(u = 0; u < ec.arguments.length; u++)
                {
                    Expression e;

                    e = ec.arguments[u];
                    e.toIR(irs, argv + (u + 0) * INDEX_FACTOR);
                }
                ec.arguments[] = null;          // release to GC
                ec.arguments = null;
            }

            if(opoff == 3)
                irs.gen4(loc, IRputcallv, ret, base, argc, argv);
            else if(opoff == 2)
                irs.gen4(loc, IRputcallscope, ret, property.index, argc, argv);
            else
                irs.genX(loc, IRputcall + opoff, ret, base, property, argc, argv);
            irs.release(argv, argc);
        }
        else
        {
            uint base;
            IR property;
            int opoff;

            b = ret ? ret : irs.alloc(1);
            e2.toIR(irs, b);

            e1.toLvalue(irs, base, &property, opoff);
            assert(opoff != 3);
            if(opoff == 2)
                irs.gen2(loc, IRputscope, b, property.index);
            else
                irs.gen3(loc, IRput + opoff, b, base, property.index);
            if(!ret)
                irs.release(b, 1);
        }
    }
}

/************************* AddAssignExp ***********************************/

class AddAssignExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKplusass, e1, e2);
    }

    override Expression semantic(Scope *sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        /*if(ret == 0 && e2.op == TOKreal &&
           (cast(RealExpression)e2).value == 1)//disabled for better standard conformance
        {
            uint base;
            IR property;
            int opoff;

            //writef("AddAssign to PostInc('%s')\n", toChars());
            e1.toLvalue(irs, base, &property, opoff);
            assert(opoff != 3);
            if(opoff == 2)
                irs.gen2(loc, IRpostincscope, ret, property.index);
            else
                irs.gen3(loc, IRpostinc + opoff, ret, base, property.index);
        }
        else*/
        {
            uint r;
            uint base;
            IR property;
            int opoff;

            //writef("AddAssignExp::toIR('%s')\n", toChars());
            e1.toLvalue(irs, base, &property, opoff);
            assert(opoff != 3);
            r = ret ? ret : irs.alloc(1);
            e2.toIR(irs, r);
            if(opoff == 2)
                irs.gen3(loc, IRaddassscope, r, property.index, property.id.toHash());
            else
                irs.gen3(loc, IRaddass + opoff, r, base, property.index);
            if(!ret)
                irs.release(r, 1);
        }
    }
}

/************************* BinAssignExp ***********************************/

class BinAssignExp : BinExp
{
    uint ircode = IRerror;

    this(Loc loc, TOK op, uint ircode, Expression e1, Expression e2)
    {
        super(loc, op, e1, e2);
        this.ircode = ircode;
    }

    override Expression semantic(Scope *sc)
    {
        super.semantic(sc);
        e1.checkLvalue(sc);
        return this;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint b;
        uint c;
        uint r;
        uint base;
        IR property;
        int opoff;

        //writef("BinExp::binAssignIR('%s')\n", toChars());
        e1.toLvalue(irs, base, &property, opoff);
        assert(opoff != 3);
        b = irs.alloc(1);
        if(opoff == 2)
            irs.gen2(loc, IRgetscope, b, property.index);
        else
            irs.gen3(loc, IRget + opoff, b, base, property.index);
        c = irs.alloc(1);
        e2.toIR(irs, c);
        r = ret ? ret : irs.alloc(1);
        irs.gen3(loc, ircode, r, b, c);
        if(opoff == 2)
            irs.gen2(loc, IRputscope, r, property.index);
        else
            irs.gen3(loc, IRput + opoff, r, base, property.index);
        if(!ret)
            irs.release(r, 1);
    }
}

/************************* AddExp *****************************/

class AddExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKplus, e1, e2);
    }

    override Expression semantic(Scope *sc)
    {
        return this;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        binIR(irs, ret, IRadd);
    }
}

/************************* XBinExp ***********************************/

class XBinExp : BinExp
{
    uint ircode = IRerror;

    this(Loc loc, TOK op, uint ircode, Expression e1, Expression e2)
    {
        super(loc, op, e1, e2);
        this.ircode = ircode;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        binIR(irs, ret, ircode);
    }
}

/************************* OrOrExp ***********************************/

class OrOrExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKoror, e1, e2);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint u;
        uint b;

        if(ret)
            b = ret;
        else
            b = irs.alloc(1);

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen2(loc, IRjt, 0, b);
        e2.toIR(irs, ret);
        irs.patchJmp(u, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

/************************* AndAndExp ***********************************/

class AndAndExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKandand, e1, e2);
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint u;
        uint b;

        if(ret)
            b = ret;
        else
            b = irs.alloc(1);

        e1.toIR(irs, b);
        u = irs.getIP();
        irs.gen2(loc, IRjf, 0, b);
        e2.toIR(irs, ret);
        irs.patchJmp(u, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

/************************* CmpExp ***********************************/



class CmpExp : BinExp
{
    uint ircode = IRerror;

    this(Loc loc, TOK tok, uint ircode, Expression e1, Expression e2)
    {
        super(loc, tok, e1, e2);
        this.ircode = ircode;
    }

    override int isBooleanResult()
    {
        return true;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        binIR(irs, ret, ircode);
    }
}

/*************************** InExp **************************/

class InExp : BinExp
{
    this(Loc loc, Expression e1, Expression e2)
    {
        super(loc, TOKin, e1, e2);
    }
	override void toIR(IRstate *irs, uint ret)
    {
        binIR(irs, ret, IRin);
    }
}

/****************************************************************/

class CondExp : BinExp
{
    Expression econd;

    this(Loc loc, Expression econd, Expression e1, Expression e2)
    {
        super(loc, TOKquestion, e1, e2);
        this.econd = econd;
    }

    override void toIR(IRstate *irs, uint ret)
    {
        uint u1;
        uint u2;
        uint b;

        if(ret)
            b = ret;
        else
            b = irs.alloc(1);

        econd.toIR(irs, b);
        u1 = irs.getIP();
        irs.gen2(loc, IRjf, 0, b);
        e1.toIR(irs, ret);
        u2 = irs.getIP();
        irs.gen1(loc, IRjmp, 0);
        irs.patchJmp(u1, irs.getIP());
        e2.toIR(irs, ret);
        irs.patchJmp(u2, irs.getIP());

        if(!ret)
            irs.release(b, 1);
    }
}

