/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2010 by Digital Mars
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 * written by Walter Bright
 * http://www.digitalmars.com
 *
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */


module dmdscript.symbol;

import std.stdio;

import dmdscript.script;
import dmdscript.identifier;
import dmdscript.scopex;
import dmdscript.statement;
import dmdscript.irstate;
import dmdscript.opcodes;
import dmdscript.errmsgs;

/****************************** Symbol ******************************/

class Symbol
{
    Identifier *ident;

    this()
    {
    }

    this(Identifier *ident)
    {
        this.ident = ident;
    }

    int opEquals(Object o)
    {   Symbol s;

        if (this == o)
            return true;
        s = cast(Symbol)o;
        if (s && ident == s.ident)
            return true;
        return false;
    }

    tchar[] toString()
    {
        return ident ? "__ident" : "__anonymous";
    }

    void semantic(Scope *sc)
    {
        assert(0);
    }

    Symbol search(Identifier *ident)
    {
        assert(0);
        //error(DTEXT("%s.%s is undefined"),toString(), ident.toString());
        return this;
    }

    void toBuffer(inout tchar[] buf)
    {
        buf ~= toString();
    }
}


/********************************* ScopeSymbol ****************************/

// Symbol that generates a scope

class ScopeSymbol : Symbol
{
    Symbol[] members;           // all Symbol's in this scope
    SymbolTable *symtab;        // member[] sorted into table

    this()
    {
        super();
    }

    this(Identifier *id)
    {
        super(id);
    }

    Symbol search(Identifier *ident)
    {   Symbol s;

        //writef("ScopeSymbol::search(%s, '%s')\n", toString(), ident.toString());
        // Look in symbols declared in this module
        s = symtab ? symtab.lookup(ident) : null;
        if (s)
            writef("\ts = '%s.%s'\n",toString(),s.toString());
        return s;
    }
}


/****************************** SymbolTable ******************************/

// Table of Symbol's

struct SymbolTable
{
    Symbol[Identifier*] members;

    // Look up Identifier. Return Symbol if found, NULL if not.
    Symbol lookup(Identifier *ident)
    {
        Symbol *ps;

        ps = ident in members;
        if (ps)
            return *ps;
        return null;
    }

    // Insert Symbol in table. Return NULL if already there.
    Symbol insert(Symbol s)
    {
        Symbol *ps;

        ps = s.ident in members;
        if (ps)
            return null;        // already in table
        members[s.ident] = s;
        return s;
    }

    // Look for Symbol in table. If there, return it.
    // If not, insert s and return that.
    Symbol update(Symbol s)
    {
        members[s.ident] = s;
        return s;
    }
}


/****************************** FunctionSymbol ******************************/

class FunctionSymbol : ScopeSymbol
{
    Loc loc;

    Identifier*[] parameters;           // array of Identifier's
    TopStatement[] topstatements;       // array of TopStatement's

    SymbolTable labtab;         // symbol table for LabelSymbol's

    IR *code;
    uint nlocals;

    this(Loc loc, Identifier* ident, Identifier*[] parameters,
        TopStatement[] topstatements)
    {
        super(ident);
        this.loc = loc;
        this.parameters = parameters;
        this.topstatements = topstatements;
    }

    void semantic(Scope *sc)
    {
    }
}


/****************************** LabelSymbol ******************************/

class LabelSymbol : Symbol
{   Loc loc;
    LabelStatement statement;

    this(Loc loc, Identifier* ident, LabelStatement statement)
    {
        super(ident);
        this.loc = loc;
        this.statement = statement;
    }
}


