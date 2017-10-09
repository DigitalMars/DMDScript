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


module dmdscript.functiondefinition;

import std.stdio;

import dmdscript.script;
import dmdscript.identifier;
import dmdscript.statement;
import dmdscript.dfunction;
import dmdscript.scopex;
import dmdscript.irstate;
import dmdscript.opcodes;
import dmdscript.ddeclaredfunction;
import dmdscript.symbol;
import dmdscript.dobject;
import dmdscript.ir;
import dmdscript.errmsgs;
import dmdscript.value;
import dmdscript.property;

/* ========================== FunctionDefinition ================== */

class FunctionDefinition : TopStatement
{
    // Maybe the following two should be done with derived classes instead
    int isglobal;                 // !=0 if the global anonymous function
    int isliteral;                // !=0 if function literal
    int iseval;                   // !=0 if eval function

    Identifier* name;             // null for anonymous function
    Identifier*[] parameters;     // array of Identifier's
    TopStatement[] topstatements; // array of TopStatement's

    Identifier*[] varnames;       // array of Identifier's
    FunctionDefinition[] functiondefinitions;
    FunctionDefinition enclosingFunction;
    int nestDepth;
    int withdepth;              // max nesting of ScopeStatement's

    SymbolTable *labtab;        // symbol table for LabelSymbol's

    IR *code;
    uint nlocals;


    this(TopStatement[] topstatements)
    {
        super(0);
        st = FUNCTIONDEFINITION;
        this.isglobal = 1;
        this.topstatements = topstatements;
    }

    this(Loc loc, int isglobal,
         Identifier * name, Identifier *[] parameters,
         TopStatement[] topstatements)
    {
        super(loc);

        //writef("FunctionDefinition('%ls')\n", name ? name.string : L"");
        st = FUNCTIONDEFINITION;
        this.isglobal = isglobal;
        this.name = name;
        this.parameters = parameters;
        this.topstatements = topstatements;
    }
    
    int isAnonymous() { return name is null; }
        
    override Statement semantic(Scope *sc)
    {
        uint i;
        TopStatement ts;
        FunctionDefinition fd;

        //writef("FunctionDefinition::semantic(%s)\n", this);

        // Log all the FunctionDefinition's so we can rapidly
        // instantiate them at runtime
        fd = enclosingFunction = sc.funcdef;

        // But only push it if it is not already in the array
        for(i = 0;; i++)
        {
            if(i == fd.functiondefinitions.length)      // not in the array
            {
                fd.functiondefinitions ~= this;
                break;
            }
            if(fd.functiondefinitions[i] is this)       // already in the array
                break;
        }

        //writefln("isglobal = %d, isanonymous = %d\n", isglobal, isanonymous);
        if(!isglobal)
        {
            sc = sc.push(this);
            sc.nestDepth++;
        }
        nestDepth = sc.nestDepth;
        //writefln("nestDepth = %d", nestDepth);

        if(topstatements.length)
        {
            for(i = 0; i < topstatements.length; i++)
            {
                ts = topstatements[i];
                //writefln("calling semantic routine %d which is %x\n",i, cast(uint)cast(void*)ts);
                if(!ts.done)
                {
                    ts = ts.semantic(sc);
                    if(sc.errinfo.message)
                        break;

                    if(iseval)
                    {
                        // There's an implied "return" on the last statement
                        if((i + 1) == topstatements.length)
                        {
                            ts = ts.ImpliedReturn();
                        }
                    }
                    topstatements[i] = ts;
                    ts.done = 1;
                }
            }

            // Make sure all the LabelSymbol's are defined
            if(labtab)
            {
                foreach(Symbol s; labtab.members)
                {
                    LabelSymbol ls = cast(LabelSymbol)s;
                    if(!ls.statement)
                        error(sc, errmsgtbl[ERR_UNDEFINED_LABEL],
                              ls.toString(), toString());
                }
            }
        }

        if(!isglobal)
            sc.pop();

        FunctionDefinition fdx = this;
        return cast(Statement)cast(void*)fdx;
    }

    override void toBuffer(ref tchar[] buf)
    {
        uint i;

        //writef("FunctionDefinition::toBuffer()\n");
        if(!isglobal)
        {
            buf ~= "function ";
            if(isAnonymous)
                buf ~= "anonymous";
            else if(name)
                buf ~= name.toString();
            buf ~= '(';
            for(i = 0; i < parameters.length; i++)
            {
                if(i)
                    buf ~= ',';
                buf ~= parameters[i].toString();
            }
            buf ~= ")\n{ \n";
        }
        if(topstatements)
        {
            for(i = 0; i < topstatements.length; i++)
            {
                topstatements[i].toBuffer(buf);
            }
        }
        if(!isglobal)
        {
            buf ~= "}\n";
        }
    }

    override void toIR(IRstate *ignore)
    {
        IRstate irs;
        uint i;

        //writefln("FunctionDefinition.toIR() done = %d", done);
        irs.ctor();
        if(topstatements.length)
        {
            for(i = 0; i < topstatements.length; i++)
            {
                TopStatement ts;
                FunctionDefinition fd;

                ts = topstatements[i];
                if(ts.st == FUNCTIONDEFINITION)
                {
                    fd = cast(FunctionDefinition)ts;
                    if(fd.code)
                        continue;
                }
                ts.toIR(&irs);
            }

            // Don't need parse trees anymore, release to garbage collector
            topstatements[] = null;
            topstatements = null;
            labtab = null;                      // maybe delete it?
        }
        irs.gen0(0, IRret);
        irs.gen0(0, IRend);

        //irs.validate();

        irs.doFixups();
        irs.optimize();

        code = cast(IR *)irs.codebuf.data;
        irs.codebuf.data = null;
        nlocals = irs.nlocals;
    }

    void instantiate(CallContext* cc, Dobject[] scopex, Dobject actobj, uint attributes)
    {
        //writefln("FunctionDefinition.instantiate() %s nestDepth = %d", name ? name.toString() : "", nestDepth);

        // Instantiate all the Var's per 10.1.3
        foreach(Identifier* name; varnames)
        {
            // If name is already declared, don't override it
            //writefln("\tVar Put(%s)", name.toString());
            actobj.Put(cc, name.toString(), &vundefined, Instantiate | DontOverride | attributes);
        }

        // Instantiate the Function's per 10.1.3
        foreach(FunctionDefinition fd; functiondefinitions)
        {
            // Set [[Scope]] property per 13.2 step 7
            Dfunction fobject = new DdeclaredFunction(cc, fd);
            fobject.scopex = scopex;

            if(fd.name !is null && !fd.isliteral)        // skip anonymous functions
            {
                //writefln("\tFunction Put(%s)", fd.name.toString());
                actobj.Put(cc, fd.name.toString(), fobject, Instantiate | attributes);
            }
        }
        //writefln("-FunctionDefinition.instantiate()");
    }
}
