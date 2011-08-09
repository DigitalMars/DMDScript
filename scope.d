
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


module dmdscript.scope;

import dmdscript.script;
import dmdscript.program;
import dmdscript.symbol;
import dmdscript.functiondefinition;

struct Scope
{
    Scope* enclosing;           // enclosing Scope

    char[] src;                 // source text
    Program program;            // Root module
    ScopeSymbol *scopesym;      // current symbol
    FunctionDefinition funcdef; // what function we're in
    SymbolTable **plabtab;      // pointer to label symbol table

    ScopeStatement scopeContext;        // nesting of scope statements
    Statement continueTarget;
    Statement breakTarget;
    SwitchStatement switchTarget;

    ErrInfo errinfo;            // semantic() puts error messages here

    void zero()
    {
        enclosing = null;

        src = null;
        program = null;
        scopesym = null;
        funcdef = null;
        plabtab = null;

        scopeContext = null;
        continueTarget = null;
        breakTarget = null;
        switchTarget = null;
    }

    void ctor(Scope* enclosing)
    {
        zero();
        this.program = enclosing.program;
        this.funcdef = enclosing.funcdef;
        this.plabtab = enclosing.plabtab;
        this.enclosing = enclosing;
    }

    void ctor(Program program, FunctionDefinition fd)
    {   // Create root scope

        zero();
        this.program = program;
        this.funcdef = fd;
        this.plabtab = &fd.labtab;
    }

    void ctor(FunctionDefinition fd)
    {   // Create scope for anonymous function fd

        zero();
        this.funcdef = fd;
        this.plabtab = &fd.labtab;
    }

    void dtor()
    {
        // Help garbage collector
        zero();
    }

    Scope* push()
    {   Scope* s;

        s = new Scope;
        s.ctor(this);
        return s;
    }

    Scope* push(FunctionDefinition fd)
    {   Scope* s;

        s = push();
        s.funcdef = fd;
        s.plabtab = &fd.labtab;
        return s;
    }

    void pop()
    {
        if (enclosing && !enclosing.errinfo.message)
            enclosing.errinfo = errinfo;
        zero();                 // aid GC
    }


    Symbol search(Identifier *ident)
    {   Symbol s;
        Scope* sc;

        //writef("Scope.search(%p, '%s')\n", this, ident.toString());
        for (sc = this; sc; sc = sc.enclosing)
        {
            s = sc.scopesym.search(ident);
            if (s)
                return s;
        }

        assert(0);
        //error("Symbol '%s' is not defined", ident.toString());
        return null;
    }

    Symbol insert(Symbol s)
    {
        if (!scopesym.symtab)
            scopesym.symtab = new SymbolTable();
        return scopesym.symtab.insert(s);
    }

    LabelSymbol searchLabel(Identifier *ident)
    {
        SymbolTable *st;
        LabelSymbol ls;

        //writef("Scope::searchLabel('%ls')\n", ident.toDchars());
        assert(plabtab);
        st = *plabtab;
        if (!st)
        {
            st = new SymbolTable();
            *plabtab = st;
        }
        ls = cast(LabelSymbol )st.lookup(ident);
        return ls;
    }

    LabelSymbol insertLabel(LabelSymbol ls)
    {
        SymbolTable *st;

        //writef("Scope::insertLabel('%s')\n", ls.toString());
        assert(plabtab);
        st = *plabtab;
        if (!st)
        {
            st = new SymbolTable();
            *plabtab = st;
        }
        ls = cast(LabelSymbol )st.insert(ls);
        return ls;
    }

    tchar[] getSource()
    {   Scope* sc;

        for (sc = this; sc; sc = sc.enclosing)
        {
            if (sc.src)
                return sc.src;
        }

        return null;
    }
}

