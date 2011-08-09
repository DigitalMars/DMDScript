
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


module dmdscript.parse;

import dmdscript.script;
import dmdscript.lexer;
import dmdscript.functiondefinition;
import dmdscript.expression;
import dmdscript.statement;
import dmdscript.identifier;
import dmdscript.ir;
import dmdscript.errmsgs;

class Parser : Lexer
{
    uint flags;

    enum
    {
        normal          = 0,
        initial         = 1,

        allowIn         = 0,
        noIn            = 2,

        // Flag if we're in the for statement header, as
        // automatic semicolon insertion is suppressed inside it.
        inForHeader     = 4,
    }

    FunctionDefinition lastnamedfunc;


    this(char[] sourcename, tchar[] base, int useStringtable)
    {
        //writefln("Parser.this(base = '%s')", base);
        super(sourcename, base, useStringtable);
        nextToken();            // start up the scanner
    }

    ~this()
    {
        lastnamedfunc = null;
    }


    /**********************************************
     * Return !=0 on error, and fill in *perrinfo.
     */

    static int parseFunctionDefinition(out FunctionDefinition pfd,
            d_string params, d_string bdy, out ErrInfo perrinfo)
    {
        Parser p;
        Identifier*[] parameters;
        TopStatement[] topstatements;
        FunctionDefinition fd = null;
        int result;

        p = new Parser("anonymous", params, 0);

        // Parse FormalParameterList
        while (p.token.value != TOKeof)
        {
            if (p.token.value != TOKidentifier)
            {
                p.error(errmsgtbl[ERR_FPL_EXPECTED_IDENTIFIER], p.token.toString());
                goto Lreturn;
            }
            parameters ~= p.token.ident;
            p.nextToken();
            if (p.token.value == TOKcomma)
                p.nextToken();
            else if (p.token.value == TOKeof)
                break;
            else
            {
                p.error(errmsgtbl[ERR_FPL_EXPECTED_COMMA], p.token.toString());
                goto Lreturn;
            }
        }
        if (p.errinfo.message)
            goto Lreturn;

        delete p;

        // Parse StatementList
        p = new Parser("anonymous", bdy, 0);
        for (;;)
        {   TopStatement ts;

            if (p.token.value == TOKeof)
                break;
            ts = p.parseStatement();
            topstatements ~= ts;
        }

        fd = new FunctionDefinition(0, 0, null, parameters, topstatements);
        fd.isanonymous = 1;

    Lreturn:
        pfd = fd;
        perrinfo = p.errinfo;
        result = (p.errinfo.message != null);
        delete p;
        p = null;
        return result;
    }

    /**********************************************
     * Return !=0 on error, and fill in *perrinfo.
     */

    int parseProgram(out TopStatement[] topstatements, ErrInfo *perrinfo)
    {
        topstatements = parseTopStatements();
        check(TOKeof);
        //writef("parseProgram done\n");
        *perrinfo = errinfo;
        //clearstack();
        return errinfo.message != null;
    }

    TopStatement[] parseTopStatements()
    {
        TopStatement[] topstatements;
        TopStatement ts;

        //writefln("parseTopStatements()");
        for (;;)
        {
            switch (token.value)
            {
                case TOKfunction:
                    ts = parseFunction(0);
                    topstatements ~= ts;
                    break;

                case TOKeof:
                    return topstatements;

                case TOKrbrace:
                    return topstatements;

                default:
                    ts = parseStatement();
                    topstatements ~= ts;
                    break;
            }
        }
        assert(0);
    }

    /***************************
     * flag:
     *  0       Function statement
     *  1       Function literal
     */

    TopStatement parseFunction(int flag)
    {   Identifier* name;
        Identifier*[] parameters;
        TopStatement[] topstatements;
        FunctionDefinition f;
        Expression e = null;
        Loc loc;

        //writef("parseFunction()\n");
        loc = currentline;
        nextToken();
        name = null;
        if (token.value == TOKidentifier)
        {
            name = token.ident;
            nextToken();

            if (!flag && token.value == TOKdot)
            {
                // Regard:
                //      function A.B() { }
                // as:
                //      A.B = function() { }
                // This is not ECMA, but a jscript feature

                e = new IdentifierExpression(loc, name);
                name = null;

                while (token.value == TOKdot)
                {
                    nextToken();
                    if (token.value == TOKidentifier)
                    {   e = new DotExp(loc, e, token.ident);
                        nextToken();
                    }
                    else
                    {
                        error(errmsgtbl[ERR_EXPECTED_IDENTIFIER_2PARAM], ".", token.toString());
                        break;
                    }
                }
            }
        }

        check(TOKlparen);
        if (token.value == TOKrparen)
            nextToken();
        else
        {
            for (;;)
            {
                if (token.value == TOKidentifier)
                {
                    parameters ~= token.ident;
                    nextToken();
                    if (token.value == TOKcomma)
                    {   nextToken();
                        continue;
                    }
                    if (!check(TOKrparen))
                        break;
                }
                else
                    error(ERR_EXPECTED_IDENTIFIER);
                break;
            }
        }

        check(TOKlbrace);
        topstatements = parseTopStatements();
        check(TOKrbrace);

        f = new FunctionDefinition(loc, 0, name, parameters, topstatements);

        lastnamedfunc = f;

        //writef("parseFunction() done\n");
        if (!e)
            return f;

        // Construct:
        //      A.B = function() { }

        Expression e2 = new FunctionLiteral(loc, f);

        e = new AssignExp(loc, e, e2);

        Statement s = new ExpStatement(loc, e);

        return s;
    }

    /*****************************************
     */

    Statement parseStatement()
    {   Statement s;
        Token *t;
        Loc loc;

        //writefln("parseStatement()");
        loc = currentline;
        switch (token.value)
        {
            case TOKidentifier:
            case TOKthis:
                // Need to look ahead to see if it is a declaration, label, or expression
                t = peek(&token);
                if (t.value == TOKcolon && token.value == TOKidentifier)
                {   // It's a label
                    Identifier *ident;

                    ident = token.ident;
                    nextToken();
                    nextToken();
                    s = parseStatement();
                    s = new LabelStatement(loc, ident, s);
                }
                else if (t.value == TOKassign ||
                         t.value == TOKdot ||
                         t.value == TOKlbracket)
                {   Expression exp;

                    exp = parseExpression();
                    parseOptionalSemi();
                    s = new ExpStatement(loc, exp);
                }
                else
                {   Expression exp;

                    exp = parseExpression(initial);
                    parseOptionalSemi();
                    s = new ExpStatement(loc, exp);
                }
                break;

            case TOKreal:
            case TOKstring:
            case TOKdelete:
            case TOKlparen:
            case TOKplusplus:
            case TOKminusminus:
            case TOKplus:
            case TOKminus:
            case TOKnot:
            case TOKtilde:
            case TOKtypeof:
            case TOKnull:
            case TOKnew:
            case TOKtrue:
            case TOKfalse:
            case TOKvoid:
            {   Expression exp;

                exp = parseExpression(initial);
                parseOptionalSemi();
                s = new ExpStatement(loc, exp);
                break;
            }

            case TOKvar:
            {
                Identifier *ident;
                Expression init;
                VarDeclaration v;
                VarStatement vs;

                vs = new VarStatement(loc);
                s = vs;

                nextToken();
                for (;;)
                {   loc = currentline;

                    if (token.value != TOKidentifier)
                    {
                        error(errmsgtbl[ERR_EXPECTED_IDENTIFIER_PARAM], token.toString());
                        break;
                    }
                    ident = token.ident;
                    init = null;
                    nextToken();
                    if (token.value == TOKassign)
                    {   uint flags_save;

                        nextToken();
                        flags_save = flags;
                        flags &= ~initial;
                        init = parseAssignExp();
                        flags = flags_save;
                    }
                    v = new VarDeclaration(loc, ident, init);
                    vs.vardecls ~= v;
                    if (token.value != TOKcomma)
                        break;
                    nextToken();
                }
                if (!(flags & inForHeader))
                    parseOptionalSemi();
                break;
            }

            case TOKlbrace:
            {   BlockStatement bs;

                nextToken();
                bs = new BlockStatement(loc);
                while (token.value != TOKrbrace)
                {
                    if (token.value == TOKeof)
                    {   /* { */
                        error(ERR_UNTERMINATED_BLOCK);
                        break;
                    }
                    bs.statements ~= parseStatement();
                }
                s = bs;
                nextToken();

                // The following is to accommodate the jscript bug:
                //      if (i) {return(0);}; else ...
                if (token.value == TOKsemicolon)
                    nextToken();

                break;
            }

            case TOKif:
            {   Expression condition;
                Statement ifbody;
                Statement elsebody;

                nextToken();
                condition = parseParenExp();
                ifbody = parseStatement();
                if (token.value == TOKelse)
                {
                    nextToken();
                    elsebody = parseStatement();
                }
                else
                    elsebody = null;
                s = new IfStatement(loc, condition, ifbody, elsebody);
                break;
            }

            case TOKswitch:
            {   Expression condition;
                Statement bdy;

                nextToken();
                condition = parseParenExp();
                bdy = parseStatement();
                s = new SwitchStatement(loc, condition, bdy);
                break;
            }

            case TOKcase:
            {   Expression exp;

                nextToken();
                exp = parseExpression();
                check(TOKcolon);
                s = new CaseStatement(loc, exp);
                break;
            }

            case TOKdefault:
                nextToken();
                check(TOKcolon);
                s = new DefaultStatement(loc);
                break;

            case TOKwhile:
            {   Expression condition;
                Statement bdy;

                nextToken();
                condition = parseParenExp();
                bdy = parseStatement();
                s = new WhileStatement(loc, condition, bdy);
                break;
            }

            case TOKsemicolon:
                nextToken();
                s = new EmptyStatement(loc);
                break;

            case TOKdo:
            {   Statement bdy;
                Expression condition;

                nextToken();
                bdy = parseStatement();
                check(TOKwhile);
                condition = parseParenExp();
                parseOptionalSemi();
                s = new DoStatement(loc, bdy, condition);
                break;
            }

            case TOKfor:
            {
                Statement init;
                Statement bdy;

                nextToken();
                flags |= inForHeader;
                check(TOKlparen);
                if (token.value == TOKvar)
                {
                    init = parseStatement();
                }
                else
                {   Expression e;

                    e = parseOptionalExpression(noIn);
                    init = e ? new ExpStatement(loc, e) : null;
                }

                if (token.value == TOKsemicolon)
                {   Expression condition;
                    Expression increment;

                    nextToken();
                    condition = parseOptionalExpression();
                    check(TOKsemicolon);
                    increment = parseOptionalExpression();
                    check(TOKrparen);
                    flags &= ~inForHeader;

                    bdy = parseStatement();
                    s = new ForStatement(loc, init, condition, increment, bdy);
                }
                else if (token.value == TOKin)
                {   Expression inexp;
                    VarStatement vs;

                    // Check that there's only one VarDeclaration
                    // in init.
                    if (init.st == VARSTATEMENT)
                    {
                        vs = cast(VarStatement)init;
                        if (vs.vardecls.length != 1)
                            error(errmsgtbl[ERR_TOO_MANY_IN_VARS], vs.vardecls.length);
                    }

                    nextToken();
                    inexp = parseExpression();
                    check(TOKrparen);
                    flags &= ~inForHeader;
                    bdy = parseStatement();
                    s = new ForInStatement(loc, init, inexp, bdy);
                }
                else
                {
                    error(errmsgtbl[ERR_IN_EXPECTED], token.toString());
                    s = null;
                }
                break;
            }

            case TOKwith:
            {   Expression exp;
                Statement bdy;

                nextToken();
                exp = parseParenExp();
                bdy = parseStatement();
                s = new WithStatement(loc, exp, bdy);
                break;
            }

            case TOKbreak:
            {   Identifier *ident;

                nextToken();
                if (token.sawLineTerminator && token.value != TOKsemicolon)
                {   // Assume we saw a semicolon
                    ident = null;
                }
                else
                {
                    if (token.value == TOKidentifier)
                    {   ident = token.ident;
                        nextToken();
                    }
                    else
                        ident = null;
                    parseOptionalSemi();
                }
                s = new BreakStatement(loc, ident);
                break;
            }

            case TOKcontinue:
            {   Identifier *ident;

                nextToken();
                if (token.sawLineTerminator && token.value != TOKsemicolon)
                {   // Assume we saw a semicolon
                    ident = null;
                }
                else
                {
                    if (token.value == TOKidentifier)
                    {   ident = token.ident;
                        nextToken();
                    }
                    else
                        ident = null;
                    parseOptionalSemi();
                }
                s = new ContinueStatement(loc, ident);
                break;
            }

            case TOKgoto:
            {   Identifier *ident;

                nextToken();
                if (token.value != TOKidentifier)
                {   error(errmsgtbl[ERR_GOTO_LABEL_EXPECTED], token.toString());
                    s = null;
                    break;
                }
                ident = token.ident;
                nextToken();
                parseOptionalSemi();
                s = new GotoStatement(loc, ident);
                break;
            }

            case TOKreturn:
            {   Expression exp;

                nextToken();
                if (token.sawLineTerminator && token.value != TOKsemicolon)
                {   // Assume we saw a semicolon
                    s = new ReturnStatement(loc, null);
                }
                else
                {   exp = parseOptionalExpression();
                    parseOptionalSemi();
                    s = new ReturnStatement(loc, exp);
                }
                break;
            }

            case TOKthrow:
            {   Expression exp;

                nextToken();
                exp = parseExpression();
                parseOptionalSemi();
                s = new ThrowStatement(loc, exp);
                break;
            }

            case TOKtry:
            {   Statement bdy;
                Identifier *catchident;
                Statement catchbody;
                Statement finalbody;

                nextToken();
                bdy = parseStatement();
                if (token.value == TOKcatch)
                {
                    nextToken();
                    check(TOKlparen);
                    catchident = null;
                    if (token.value == TOKidentifier)
                        catchident = token.ident;
                    check(TOKidentifier);
                    check(TOKrparen);
                    catchbody = parseStatement();
                }
                else
                {   catchident = null;
                    catchbody = null;
                }

                if (token.value == TOKfinally)
                {   nextToken();
                    finalbody = parseStatement();
                }
                else
                    finalbody = null;

                if (!catchbody && !finalbody)
                {   error(ERR_TRY_CATCH_EXPECTED);
                    s = null;
                }
                else
                {
                    s = new TryStatement(loc, bdy, catchident, catchbody, finalbody);
                }
                break;
            }

            default:
                error(errmsgtbl[ERR_STATEMENT_EXPECTED], token.toString());
                nextToken();
                s = null;
                break;
        }

        //writefln("parseStatement() done");
        return s;
    }



    Expression parseOptionalExpression(uint flags = 0)
    {
        Expression e;

        if (token.value == TOKsemicolon || token.value == TOKrparen)
            e = null;
        else
            e = parseExpression(flags);
        return e;
    }

    // Follow ECMA 7.8.1 rules for inserting semicolons
    void parseOptionalSemi()
    {
        if (token.value != TOKeof &&
            token.value != TOKrbrace &&
            !(token.sawLineTerminator && (flags & inForHeader) == 0)
           )
            check(TOKsemicolon);
    }

    int check(TOK value)
    {
        if (token.value != value)
        {
            error(errmsgtbl[ERR_EXPECTED_GENERIC], token.toString(), Token.toString(value));
            return 0;
        }
        nextToken();
        return 1;
    }

    /********************************* Expression Parser ***************************/


    Expression parseParenExp()
    {   Expression e;

        check(TOKlparen);
        e = parseExpression();
        check(TOKrparen);
        return e;
    }

    Expression parsePrimaryExp(int innew)
    {   Expression e;
        Loc loc;

        loc = currentline;
        switch (token.value)
        {
            case TOKthis:
                e = new ThisExpression(loc);
                nextToken();
                break;

            case TOKnull:
                e = new NullExpression(loc);
                nextToken();
                break;

            case TOKtrue:
                e = new BooleanExpression(loc, 1);
                nextToken();
                break;

            case TOKfalse:
                e = new BooleanExpression(loc, 0);
                nextToken();
                break;

            case TOKreal:
                e = new RealExpression(loc, token.realvalue);
                nextToken();
                break;

            case TOKstring:
                e = new StringExpression(loc, token.string);
                token.string = null;    // release to gc
                nextToken();
                break;

            case TOKregexp:
                e = new RegExpLiteral(loc, token.string);
                token.string = null;    // release to gc
                nextToken();
                break;

            case TOKidentifier:
                e = new IdentifierExpression(loc, token.ident);
                token.ident = null;             // release to gc
                nextToken();
                break;

            case TOKlparen:
                e = parseParenExp();
                break;

            case TOKlbracket:
                e = parseArrayLiteral();
                break;

            case TOKlbrace:
                if (flags & initial)
                {
                    error(ERR_OBJ_LITERAL_IN_INITIALIZER);
                    nextToken();
                    return null;
                }
                e = parseObjectLiteral();
                break;

            case TOKfunction:
    //      if (flags & initial)
    //          goto Lerror;
                e = parseFunctionLiteral();
                break;

            case TOKnew:
            {   Expression newarg;
                Expression[] arguments;

                nextToken();
                newarg = parsePrimaryExp(1);
                arguments = parseArguments();
                e = new NewExp(loc, newarg, arguments);
                break;
            }

            default:
    //  Lerror:
                error(errmsgtbl[ERR_EXPECTED_EXPRESSION], token.toString());
                nextToken();
                return null;
        }
        return parsePostExp(e, innew);
    }

    Expression[] parseArguments()
    {
        Expression[] arguments = null;

        if (token.value == TOKlparen)
        {
            nextToken();
            if (token.value != TOKrparen)
            {
                for (;;)
                {   Expression arg;

                    arg = parseAssignExp();
                    arguments ~= arg;
                    if (token.value == TOKrparen)
                        break;
                    if (!check(TOKcomma))
                        break;
                }
            }
            nextToken();
        }
        return arguments;
    }

    Expression parseArrayLiteral()
    {
        Expression e;
        Expression[] elements;
        Loc loc;

        //writef("parseArrayLiteral()\n");
        loc = currentline;
        check(TOKlbracket);
        if (token.value != TOKrbracket)
        {
            for (;;)
            {
                if (token.value == TOKcomma)
                    // Allow things like [1,2,,,3,]
                    // Like Explorer 4, and unlike Netscape, the
                    // trailing , indicates another null element.
                    elements ~= cast(Expression)null;
                else if (token.value == TOKrbracket)
                {
                    elements ~= cast(Expression)null;
                    break;
                }
                else
                {   e = parseAssignExp();
                    elements ~= e;
                    if (token.value != TOKcomma)
                        break;
                }
                nextToken();
            }
        }
        check(TOKrbracket);
        e = new ArrayLiteral(loc, elements);
        return e;
    }

    Expression parseObjectLiteral()
    {
        Expression e;
        Field[] fields;
        Loc loc;

        //writef("parseObjectLiteral()\n");
        loc = currentline;
        check(TOKlbrace);
        if (token.value == TOKrbrace)
            nextToken();
        else
        {
            for (;;)
            {   Field f;
                Identifier* ident;

                if (token.value != TOKidentifier)
                {   error(ERR_EXPECTED_IDENTIFIER);
                    break;
                }
                ident = token.ident;
                nextToken();
                check(TOKcolon);
                f = new Field(ident, parseAssignExp());
                fields ~= f;
                if (token.value != TOKcomma)
                    break;
                nextToken();
            }
            check(TOKrbrace);
        }
        e = new ObjectLiteral(loc, fields);
        return e;
    }

    Expression parseFunctionLiteral()
    {   FunctionDefinition f;
        Loc loc;

        loc = currentline;
        f = cast(FunctionDefinition)parseFunction(1);
        return new FunctionLiteral(loc, f);
    }

    Expression parsePostExp(Expression e, int innew)
    {   Loc loc;

        for (;;)
        {
            loc = currentline;
            //loc = (Loc)token.ptr;
            switch (token.value)
            {
                case TOKdot:
                    nextToken();
                    if (token.value == TOKidentifier)
                    {
                        e = new DotExp(loc, e, token.ident);
                    }
                    else
                    {
                        error(errmsgtbl[ERR_EXPECTED_IDENTIFIER_2PARAM], ".", token.toString());
                        return e;
                    }
                    break;

                case TOKplusplus:
                    if (token.sawLineTerminator && !(flags & inForHeader))
                        goto Linsert;
                    e = new PostIncExp(loc, e);
                    break;

                case TOKminusminus:
                    if (token.sawLineTerminator && !(flags & inForHeader))
                    {
                    Linsert:
                        // insert automatic semicolon
                        insertSemicolon(token.sawLineTerminator);
                        return e;
                    }
                    e = new PostDecExp(loc, e);
                    break;

                case TOKlparen:
                {   // function call
                    Expression[] arguments;

                    if (innew)
                        return e;
                    arguments = parseArguments();
                    e = new CallExp(loc, e, arguments);
                    continue;
                }

                case TOKlbracket:
                {   // array dereference
                    Expression index;

                    nextToken();
                    index = parseExpression();
                    check(TOKrbracket);
                    e = new ArrayExp(loc, e, index);
                    continue;
                }

                default:
                    return e;
            }
            nextToken();
        }
        assert(0);
    }

    Expression parseUnaryExp()
    {   Expression e;
        Loc loc;

        loc = currentline;
        switch (token.value)
        {
            case TOKplusplus:
                nextToken();
                e = parseUnaryExp();
                e = new PreExp(loc, IRpreinc, e);
                break;

            case TOKminusminus:
                nextToken();
                e = parseUnaryExp();
                e = new PreExp(loc, IRpredec, e);
                break;

            case TOKminus:
                nextToken();
                e = parseUnaryExp();
                e = new XUnaExp(loc, TOKneg, IRneg, e);
                break;

            case TOKplus:
                nextToken();
                e = parseUnaryExp();
                e = new XUnaExp(loc, TOKpos, IRpos, e);
                break;

            case TOKnot:
                nextToken();
                e = parseUnaryExp();
                e = new NotExp(loc, e);
                break;

            case TOKtilde:
                nextToken();
                e = parseUnaryExp();
                e = new XUnaExp(loc, TOKtilde, IRcom, e);
                break;

            case TOKdelete:
                nextToken();
                e = parsePrimaryExp(0);
                e = new DeleteExp(loc, e);
                break;

            case TOKtypeof:
                nextToken();
                e = parseUnaryExp();
                e = new XUnaExp(loc, TOKtypeof, IRtypeof, e);
                break;

            case TOKvoid:
                nextToken();
                e = parseUnaryExp();
                e = new XUnaExp(loc, TOKvoid, IRundefined, e);
                break;

            default:
                e = parsePrimaryExp(0);
                break;
        }
        return e;
    }

    Expression parseMulExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseUnaryExp();
        for (;;)
        {
            switch (token.value)
            {
                case TOKmultiply:
                    nextToken();
                    e2 = parseUnaryExp();
                    e = new XBinExp(loc, TOKmultiply, IRmul, e, e2);
                    continue;

                case TOKregexp:
                    // Rescan as if it was a "/"
                    rescan();
                case TOKdivide:
                    nextToken();
                    e2 = parseUnaryExp();
                    e = new XBinExp(loc, TOKdivide, IRdiv, e, e2);
                    continue;

                case TOKpercent:
                    nextToken();
                    e2 = parseUnaryExp();
                    e = new XBinExp(loc, TOKpercent, IRmod, e, e2);
                    continue;

                default:
                    break;
            }
            break;
        }
        return e;
    }

    Expression parseAddExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseMulExp();
        for (;;)
        {
            switch (token.value)
            {
                case TOKplus:
                    nextToken();
                    e2 = parseMulExp();
                    e = new AddExp(loc, e, e2);
                    continue;

                case TOKminus:
                    nextToken();
                    e2 = parseMulExp();
                    e = new XBinExp(loc, TOKminus, IRsub, e, e2);
                    continue;

                default:
                    break;
            }
            break;
        }
        return e;
    }

    Expression parseShiftExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseAddExp();
        for (;;)
        {   uint ircode;
            TOK op = token.value;

            switch (op)
            {
                case TOKshiftleft:      ircode = IRshl;         goto L1;
                case TOKshiftright:     ircode = IRshr;         goto L1;
                case TOKushiftright:    ircode = IRushr;        goto L1;

                L1: nextToken();
                    e2 = parseAddExp();
                    e = new XBinExp(loc, op, ircode, e, e2);
                    continue;

                default:
                    break;
            }
            break;
        }
        return e;
    }

    Expression parseRelExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseShiftExp();
        for (;;)
        {   uint ircode;
            TOK op = token.value;

            switch (op)
            {
                case TOKless:           ircode = IRclt; goto L1;
                case TOKlessequal:      ircode = IRcle; goto L1;
                case TOKgreater:        ircode = IRcgt; goto L1;
                case TOKgreaterequal:   ircode = IRcge; goto L1;

                L1:
                    nextToken();
                    e2 = parseShiftExp();
                    e = new CmpExp(loc, op, ircode, e, e2);
                    continue;

                case TOKinstanceof:
                    nextToken();
                    e2 = parseShiftExp();
                    e = new XBinExp(loc, TOKinstanceof, IRinstance, e, e2);
                    continue;

                case TOKin:
                    if (flags & noIn)
                        break;          // disallow
                    nextToken();
                    e2 = parseShiftExp();
                    e = new InExp(loc, e, e2);
                    continue;

                default:
                    break;
            }
            break;
        }
        return e;
    }

    Expression parseEqualExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseRelExp();
        for (;;)
        {   uint ircode;
            TOK op = token.value;

            switch (op)
            {
                case TOKequal:       ircode = IRceq;        goto L1;
                case TOKnotequal:    ircode = IRcne;        goto L1;
                case TOKidentity:    ircode = IRcid;        goto L1;
                case TOKnonidentity: ircode = IRcnid;       goto L1;

                L1:
                    nextToken();
                    e2 = parseRelExp();
                    e = new CmpExp(loc, op, ircode, e, e2);
                    continue;

                default:
                    break;
            }
            break;
        }
        return e;
    }

    Expression parseAndExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseEqualExp();
        while (token.value == TOKand)
        {
            nextToken();
            e2 = parseEqualExp();
            e = new XBinExp(loc, TOKand, IRand, e, e2);
        }
        return e;
    }

    Expression parseXorExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseAndExp();
        while (token.value == TOKxor)
        {
            nextToken();
            e2 = parseAndExp();
            e = new XBinExp(loc, TOKxor, IRxor, e, e2);
        }
        return e;
    }

    Expression parseOrExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseXorExp();
        while (token.value == TOKor)
        {
            nextToken();
            e2 = parseXorExp();
            e = new XBinExp(loc, TOKor, IRor, e, e2);
        }
        return e;
    }

    Expression parseAndAndExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseOrExp();
        while (token.value == TOKandand)
        {
            nextToken();
            e2 = parseOrExp();
            e = new AndAndExp(loc, e, e2);
        }
        return e;
    }

    Expression parseOrOrExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseAndAndExp();
        while (token.value == TOKoror)
        {
            nextToken();
            e2 = parseAndAndExp();
            e = new OrOrExp(loc, e, e2);
        }
        return e;
    }

    Expression parseCondExp()
    {   Expression e;
        Expression e1;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseOrOrExp();
        if (token.value == TOKquestion)
        {
            nextToken();
            e1 = parseAssignExp();
            check(TOKcolon);
            e2 = parseAssignExp();
            e = new CondExp(loc, e, e1, e2);
        }
        return e;
    }

    Expression parseAssignExp()
    {   Expression e;
        Expression e2;
        Loc loc;

        loc = currentline;
        e = parseCondExp();
        for (;;)
        {   uint ircode;
            TOK op = token.value;

            switch (op)
            {
                case TOKassign:
                    nextToken();
                    e2 = parseAssignExp();
                    e = new AssignExp(loc, e, e2);
                    continue;

                case TOKplusass:
                    nextToken();
                    e2 = parseAssignExp();
                    e = new AddAssignExp(loc, e, e2);
                    continue;

                case TOKminusass:       ircode = IRsub;  goto L1;
                case TOKmultiplyass:    ircode = IRmul;  goto L1;
                case TOKdivideass:      ircode = IRdiv;  goto L1;
                case TOKpercentass:     ircode = IRmod;  goto L1;
                case TOKandass:         ircode = IRand;  goto L1;
                case TOKorass:          ircode = IRor;   goto L1;
                case TOKxorass:         ircode = IRxor;  goto L1;
                case TOKshiftleftass:   ircode = IRshl;  goto L1;
                case TOKshiftrightass:  ircode = IRshr;  goto L1;
                case TOKushiftrightass: ircode = IRushr; goto L1;

                L1: nextToken();
                    e2 = parseAssignExp();
                    e = new BinAssignExp(loc, op, ircode, e, e2);
                    continue;

                default:
                    break;
            }
            break;
        }
        return e;
    }

    Expression parseExpression(uint flags = 0)
    {   Expression e;
        Expression e2;
        Loc loc;
        uint flags_save;

        //writefln("Parser.parseExpression()");
        flags_save = this.flags;
        this.flags = flags;
        loc = currentline;
        e = parseAssignExp();
        while (token.value == TOKcomma)
        {
            nextToken();
            e2 = parseAssignExp();
            e = new CommaExp(loc, e, e2);
        }
        this.flags = flags_save;
        return e;
    }

}

/********************************* ***************************/

