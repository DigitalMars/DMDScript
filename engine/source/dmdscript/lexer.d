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

/* Lexical Analyzer
 */

module dmdscript.lexer;

import std.range;
import std.algorithm;
import std.stdio;
import std.string;
import std.utf;
import std.outbuffer;
import std.ascii;
import core.stdc.stdlib;

import dmdscript.script;
import dmdscript.text;
import dmdscript.identifier;
import dmdscript.scopex;
import dmdscript.errmsgs;
import dmdscript.utf;

/* Tokens:
        (	)
        [	]
        {	}
        <	>	<=	>=	==	!=
        ===     !==
        <<	>>	<<=	>>=	>>>	>>>=
 +	-	+=	-=
 *	/	%	*=	/=	%=
        &	|   ^	&=	|=	^=
        =	!	~
 ++	--
        .	:	,
        ?	&&	||
 */

alias int TOK;

enum
{
    TOKreserved,

    // Other
    TOKlparen, TOKrparen,
    TOKlbracket, TOKrbracket,
    TOKlbrace, TOKrbrace,
    TOKcolon, TOKneg,
    TOKpos,
    TOKsemicolon, TOKeof,
    TOKarray, TOKcall,
    TOKarraylit, TOKobjectlit,
    TOKcomma, TOKassert,

    // Operators
    TOKless, TOKgreater,
    TOKlessequal, TOKgreaterequal,
    TOKequal, TOKnotequal,
    TOKidentity, TOKnonidentity,
    TOKshiftleft, TOKshiftright,
    TOKshiftleftass, TOKshiftrightass,
    TOKushiftright, TOKushiftrightass,
    TOKplus, TOKminus, TOKplusass, TOKminusass,
    TOKmultiply, TOKdivide, TOKpercent,
    TOKmultiplyass, TOKdivideass, TOKpercentass,
    TOKand, TOKor, TOKxor,
    TOKandass, TOKorass, TOKxorass,
    TOKassign, TOKnot, TOKtilde,
    TOKplusplus, TOKminusminus, TOKdot,
    TOKquestion, TOKandand, TOKoror,

    // Leaf operators
    TOKnumber, TOKidentifier, TOKstring,
    TOKregexp, TOKreal,

    // Keywords
    TOKbreak, TOKcase, TOKcontinue,
    TOKdefault, TOKdelete, TOKdo,
    TOKelse, TOKexport, TOKfalse,
    TOKfor, TOKfunction, TOKif,
    TOKimport, TOKin, TOKnew,
    TOKnull, TOKreturn, 
	TOKswitch, TOKthis, TOKtrue, 
	TOKtypeof, TOKvar, TOKvoid, 
	TOKwhile, TOKwith,

    // Reserved for ECMA extensions
    TOKcatch, TOKclass,
    TOKconst, TOKdebugger,
    TOKenum, TOKextends,
    TOKfinally, TOKsuper,
    TOKthrow, TOKtry,

    // Java keywords reserved for unknown reasons
    TOKabstract, TOKboolean,
    TOKbyte, TOKchar,
    TOKdouble, TOKfinal,
    TOKfloat, TOKgoto,
    TOKimplements, TOKinstanceof,
    TOKint, TOKinterface,
    TOKlong, TOKnative,
    TOKpackage, TOKprivate,
    TOKprotected, TOKpublic,
    TOKshort, TOKstatic,
    TOKsynchronized,
    TOKtransient,

    TOKmax
};

int isoctal(dchar c)
{
    return('0' <= c && c <= '7');
}
int isasciidigit(dchar c)
{
    return('0' <= c && c <= '9');
}
int isasciilower(dchar c)
{
    return('a' <= c && c <= 'z');
}
int isasciiupper(dchar c)
{
    return('A' <= c && c <= 'Z');
}
int ishex(dchar c)
{
    return
        ('0' <= c && c <= '9') ||
        ('a' <= c && c <= 'f') ||
        ('A' <= c && c <= 'F');
}


/******************************************************/

struct Token
{
    Token *next;
           immutable(tchar) *ptr;       // pointer to first character of this token within buffer
    uint   linnum;
    TOK    value;
           immutable(tchar) *sawLineTerminator; // where we saw the last line terminator
    union
    {
        number_t    intvalue;
        real_t      realvalue;
        d_string    string;
        Identifier *ident;
    };

    static d_string[TOKmax] tochars;

    void print()
    {
        writefln(toString());
    }

    d_string toString()
    {
        d_string p;

        switch(value)
        {
        case TOKnumber:
            p = std.string.format("%d", intvalue);
            break;

        case TOKreal:
            long l = cast(long)realvalue;
            if(l == realvalue)
                p = std.string.format("%s", l);
            else
                p = std.string.format("%s", realvalue);
            break;

        case TOKstring:
        case TOKregexp:
            p = string;
            break;

        case TOKidentifier:
            p = ident.toString();
            break;

        default:
            p = toString(value);
            break;
        }
        return p;
    }

    static d_string toString(TOK value)
    {
        d_string p;

        p = tochars[value];
        if(!p)
            p = std.string.format("TOK%d", value);
        return p;
    }
}




/*******************************************************************/

class Lexer
{
    Identifier[d_string] stringtable;
    Token* freelist;

    d_string sourcename;        // for error message strings

    d_string base;              // pointer to start of buffer
    immutable(char) * end;      // past end of buffer
    immutable(char) * p;        // current character
    uint currentline;
    Token token;
    OutBuffer stringbuffer;
    int useStringtable;         // use for Identifiers

    ErrInfo errinfo;            // syntax error information
    static bool inited;


    Token*  allocToken()
    {
        Token *t;

        if(freelist)
        {
            t = freelist;
            freelist = t.next;
            return t;
        }

        return new Token();
    }


    this(d_string sourcename, d_string base, int useStringtable)
    {
        import core.stdc.string : memset;
        //writefln("Lexer::Lexer(base = '%s')\n",base);
        if(!inited)
            init();

        memset(&token, 0, token.sizeof);
        this.useStringtable = useStringtable;
        this.sourcename = sourcename;
        if(!base.length || (base[$ - 1] != 0 && base[$ - 1] != 0x1A))
            base ~= cast(tchar)0x1A;
        this.base = base;
        this.end = base.ptr + base.length;
        p = base.ptr;
        currentline = 1;
        freelist = null;
    }


    ~this()
    {
        //writef(L"~Lexer()\n");
        freelist = null;
        sourcename = null;
        base = null;
        end = null;
        p = null;
    }

    dchar get(immutable(tchar)* p)
    {
        size_t idx = p - base.ptr;
        return std.utf.decode(base, idx);
    }

    immutable(tchar) * inc(immutable(tchar) * p)
    {
        size_t idx = p - base.ptr;
        std.utf.decode(base, idx);
        return base.ptr + idx;
    }

    void error(ARGS...)(int msgnum, ARGS args)
    {
        error(errmsgtbl[msgnum], args);
    }

    void error(ARGS...)(.string fmt, ARGS args)
    {
        import std.format : format, formattedWrite;

        uint linnum = 1;
        immutable(tchar) * s;
        immutable(tchar) * slinestart;
        immutable(tchar) * slineend;
        d_string buf;

        //FuncLog funclog(L"Lexer.error()");
        //writefln("TEXT START ------------\n%ls\nTEXT END ------------------", base);

        // Find the beginning of the line
        slinestart = base.ptr;
        for(s = base.ptr; s != p; s++)
        {
            if(*s == '\n')
            {
                linnum++;
                slinestart = s + 1;
            }
        }

        // Find the end of the line
        for(;; )
        {
            switch(*s)
            {
            case '\n':
            case 0:
            case 0x1A:
                break;
            default:
                s++;
                continue;
            }
            break;
        }
        slineend = s;

        buf = format("%s(%d) : Error: ", sourcename, linnum);

        void putc(dchar c)
        {
            dmdscript.utf.encode(buf, c);
        }

        formattedWrite(&putc, fmt, args);

        if(!errinfo.message)
        {
            size_t len;

            errinfo.message = buf;
            errinfo.linnum = linnum;
            errinfo.charpos = cast(uint)(p - slinestart);

            len = slineend - slinestart;
            errinfo.srcline = slinestart[0 .. len];
        }

        // Consume input until the end
        while(*p != 0x1A && *p != 0)
            p++;
        token.next = null;              // dump any lookahead

        version(none)
        {
            writefln(errinfo.message);
            fflush(stdout);
            exit(EXIT_FAILURE);
        }
    }

    /************************************************
     * Given source text, convert loc to a string for the corresponding line.
     */

    static d_string locToSrcline(immutable(char) *src, Loc loc)
    {
        immutable(char) * slinestart;
        immutable(char) * slineend;
        immutable(char) * s;
        uint linnum = 1;
        size_t len;

        if(!src)
            return null;
        slinestart = src;
        for(s = src;; s++)
        {
            switch(*s)
            {
            case '\n':
                if(linnum == loc)
                {
                    slineend = s;
                    break;
                }
                slinestart = s + 1;
                linnum++;
                continue;

            case 0:
            case 0x1A:
                slineend = s;
                break;

            default:
                continue;
            }
            break;
        }

        // Remove trailing \r's
        while(slinestart < slineend && slineend[-1] == '\r')
            --slineend;

        len = slineend - slinestart;
        return slinestart[0 .. len];
    }


    TOK nextToken()
    {
        Token *t;

        if(token.next)
        {
            t = token.next;
            token = *t;
            t.next = freelist;
            freelist = t;
        }
        else
        {
            scan(&token);
        }
        //token.print();
        return token.value;
    }

    Token *peek(Token *ct)
    {
        Token *t;

        if(ct.next)
            t = ct.next;
        else
        {
            t = allocToken();
            scan(t);
            t.next = null;
            ct.next = t;
        }
        return t;
    }

    void insertSemicolon(immutable(tchar) *loc)
    {
        // Push current token back into the input, and
        // create a new current token that is a semicolon
        Token *t;

        t = allocToken();
        *t = token;
        token.next = t;
        token.value = TOKsemicolon;
        token.ptr = loc;
        token.sawLineTerminator = null;
    }

    /**********************************
     * Horrible kludge to support disambiguating TOKregexp from TOKdivide.
     * The idea is, if we are looking for a TOKdivide, and find instead
     * a TOKregexp, we back up and rescan.
     */

    void rescan()
    {
        token.next = null;      // no lookahead
        // should put on freelist
        p = token.ptr + 1;
    }


    /****************************
     * Turn next token in buffer into a token.
     */

    void scan(Token *t)
    {
        static import std.ascii;
        static import std.uni;

        tchar c;
        dchar d;
        d_string id;

        //writefln("Lexer.scan()");
        t.sawLineTerminator = null;
        for(;; )
        {
            t.ptr = p;
            //t.linnum = currentline;
            //writefln("p = %x",cast(uint)p);
            //writefln("p = %x, *p = x%02x, '%s'",cast(uint)p,*p,*p);
            switch(*p)
            {
            case 0:
            case 0x1A:
                t.value = TOKeof;               // end of file
                return;

            case ' ':
            case '\t':
            case '\v':
            case '\f':
            case 0xA0:                          // no-break space
                p++;
                continue;                       // skip white space

            case '\n':                          // line terminator
                currentline++;
                goto case;
            case '\r':
                t.sawLineTerminator = p;
                p++;
                continue;

            case '"':
            case '\'':
                t.string = string(*p);
                t.value = TOKstring;
                return;

            case '0':       case '1':   case '2':   case '3':   case '4':
            case '5':       case '6':   case '7':   case '8':   case '9':
                t.value = number(t);
                return;

            case 'a':       case 'b':   case 'c':   case 'd':   case 'e':
            case 'f':       case 'g':   case 'h':   case 'i':   case 'j':
            case 'k':       case 'l':   case 'm':   case 'n':   case 'o':
            case 'p':       case 'q':   case 'r':   case 's':   case 't':
            case 'u':       case 'v':   case 'w':   case 'x':   case 'y':
            case 'z':
            case 'A':       case 'B':   case 'C':   case 'D':   case 'E':
            case 'F':       case 'G':   case 'H':   case 'I':   case 'J':
            case 'K':       case 'L':   case 'M':   case 'N':   case 'O':
            case 'P':       case 'Q':   case 'R':   case 'S':   case 'T':
            case 'U':       case 'V':   case 'W':   case 'X':   case 'Y':
            case 'Z':
            case '_':
            case '$':
                Lidentifier:
                {
                  id = null;

                  static bool isidletter(dchar d)
                  {
                      return std.ascii.isAlphaNum(d) || d == '_' || d == '$' || (d >= 0x80 && std.uni.isAlpha(d));
                  }

                  do
                  {
                      p = inc(p);
                      d = get(p);
                      if(d == '\\' && p[1] == 'u')
                      {
                          Lidentifier2:
                          id = t.ptr[0 .. p - t.ptr].idup;
                          auto ps = p;
                          p++;
                          d = unicode();
                          if(!isidletter(d))
                          {
                              p = ps;
                              break;
                          }
                          dmdscript.utf.encode(id, d);
                          for(;; )
                          {
                              d = get(p);
                              if(d == '\\' && p[1] == 'u')
                              {
                                  auto pstart = p;
                                  p++;
                                  d = unicode();
                                  if(isidletter(d))
                                      dmdscript.utf.encode(id, d);
                                  else
                                  {
                                      p = pstart;
                                      goto Lidentifier3;
                                  }
                              }
                              else if(isidletter(d))
                              {
                                  dmdscript.utf.encode(id, d);
                                  p = inc(p);
                              }
                              else
                                  goto Lidentifier3;
                          }
                      }
                  } while(isidletter(d));
                  id = t.ptr[0 .. p - t.ptr];
                  Lidentifier3:
                  //printf("id = '%.*s'\n", id);
                  t.value = isKeyword(id);
                  if(t.value)
                      return;
                  if(useStringtable)
                  {     //Identifier* i = &stringtable[id];
                      Identifier* i = id in stringtable;
                      if(!i)
                      {
                          stringtable[id] = Identifier.init;
                          i = id in stringtable;
                      }
                      i.value.putVstring(id);
                      i.value.hashString();
                      t.ident = i;
                  }
                  else
                      t.ident = Identifier.build(id);
                  t.value = TOKidentifier;
                  return; }

            case '/':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKdivideass;
                    return;
                }
                else if(c == '*')
                {
                    p++;
                    for(;; p++)
                    {
                        c = *p;
                        Lcomment:
                        switch(c)
                        {
                        case '*':
                            p++;
                            c = *p;
                            if(c == '/')
                            {
                                p++;
                                break;
                            }
                            goto Lcomment;

                        case '\n':
                            currentline++;
                            goto case;
                        case '\r':
                            t.sawLineTerminator = p;
                            continue;

                        case 0:
                        case 0x1A:
                            error(ERR_BAD_C_COMMENT);
                            t.value = TOKeof;
                            return;

                        default:
                            continue;
                        }
                        break;
                    }
                    continue;
                }
                else if(c == '/')
                {
                    auto r = p[0..end-p];
                    uint j;
                    do{
                        r.popFront();
                        j = startsWith(r,'\n','\r','\0',0x1A,'\u2028','\u2029');
                        
                    }while(!j);
                    p = &r[0];
                    switch(j){
                        case 1: 
                            currentline++;
                            goto case;
                        case 2: case 5: case 6:
                            t.sawLineTerminator = p;
                            break;
                        case 3: case 4:
                            t.value = TOKeof;
                            return;
                        default:
                            assert(0);                            
                    }
                    p = inc(p);
                    continue;
                    /*for(;; )
                    {
                        p++;
                        switch(*p)
                        {
                        case '\n':
                            currentline++;
                        case '\r':
                            t.sawLineTerminator = p;
                            break;

                        case 0:
                        case 0x1A:                              // end of file
                            t.value = TOKeof;
                            return;

                        default:
                            continue;
                        }
                        break;
                    }
                    p++;
                    continue;*/
                }
                else if((t.string = regexp()) != null)
                    t.value = TOKregexp;
                else
                    t.value = TOKdivide;
                return;

            case '.':
                immutable(tchar) * q;
                q = p + 1;
                c = *q;
                if(std.ascii.isDigit(c))
                    t.value = number(t);
                else
                {
                    t.value = TOKdot;
                    p = q;
                }
                return;

            case '&':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKandass;
                }
                else if(c == '&')
                {
                    p++;
                    t.value = TOKandand;
                }
                else
                    t.value = TOKand;
                return;

            case '|':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKorass;
                }
                else if(c == '|')
                {
                    p++;
                    t.value = TOKoror;
                }
                else
                    t.value = TOKor;
                return;

            case '-':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKminusass;
                }
                else if(c == '-')
                {
                    p++;

                    // If the last token in the file is -. then
                    // treat it as EOF. This is to accept broken
                    // scripts that forgot to protect the closing -.
                    // with a // comment.
                    if(*p == '>')
                    {
                        // Scan ahead to see if it's the last token
                        immutable(tchar) * q;

                        q = p;
                        for(;; )
                        {
                            switch(*++q)
                            {
                            case 0:
                            case 0x1A:
                                t.value = TOKeof;
                                p = q;
                                return;

                            case ' ':
                            case '\t':
                            case '\v':
                            case '\f':
                            case '\n':
                            case '\r':
                            case 0xA0:                  // no-break space
                                continue;

                            default:
                                assert(0);
                            }
                        }
                    }
                    t.value = TOKminusminus;
                }
                else
                    t.value = TOKminus;
                return;

            case '+':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKplusass;
                }
                else if(c == '+')
                {
                    p++;
                    t.value = TOKplusplus;
                }
                else
                    t.value = TOKplus;
                return;

            case '<':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKlessequal;
                }
                else if(c == '<')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = TOKshiftleftass;
                    }
                    else
                        t.value = TOKshiftleft;
                }
                else if(c == '!' && p[1] == '-' && p[2] == '-')
                {       // Special comment to end of line
                    p += 2;
                    for(;; )
                    {
                        p++;
                        switch(*p)
                        {
                        case '\n':
                            currentline++;
                            goto case;
                        case '\r':
                            t.sawLineTerminator = p;
                            break;

                        case 0:
                        case 0x1A:                              // end of file
                            error(ERR_BAD_HTML_COMMENT);
                            t.value = TOKeof;
                            return;

                        default:
                            continue;
                        }
                        break;
                    }
                    p++;
                    continue;
                }
                else
                    t.value = TOKless;
                return;

            case '>':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKgreaterequal;
                }
                else if(c == '>')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = TOKshiftrightass;
                    }
                    else if(c == '>')
                    {
                        p++;
                        c = *p;
                        if(c == '=')
                        {
                            p++;
                            t.value = TOKushiftrightass;
                        }
                        else
                            t.value = TOKushiftright;
                    }
                    else
                        t.value = TOKshiftright;
                }
                else
                    t.value = TOKgreater;
                return;

            case '(': p++; t.value = TOKlparen;    return;
            case ')': p++; t.value = TOKrparen;    return;
            case '[': p++; t.value = TOKlbracket;  return;
            case ']': p++; t.value = TOKrbracket;  return;
            case '{': p++; t.value = TOKlbrace;    return;
            case '}': p++; t.value = TOKrbrace;    return;
            case '~': p++; t.value = TOKtilde;     return;
            case '?': p++; t.value = TOKquestion;  return;
            case ',': p++; t.value = TOKcomma;     return;
            case ';': p++; t.value = TOKsemicolon; return;
            case ':': p++; t.value = TOKcolon;     return;

            case '*':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKmultiplyass;
                }
                else
                    t.value = TOKmultiply;
                return;

            case '%':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKpercentass;
                }
                else
                    t.value = TOKpercent;
                return;

            case '^':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    t.value = TOKxorass;
                }
                else
                    t.value = TOKxor;
                return;

            case '=':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = TOKidentity;
                    }
                    else
                        t.value = TOKequal;
                }
                else
                    t.value = TOKassign;
                return;

            case '!':
                p++;
                c = *p;
                if(c == '=')
                {
                    p++;
                    c = *p;
                    if(c == '=')
                    {
                        p++;
                        t.value = TOKnonidentity;
                    }
                    else
                        t.value = TOKnotequal;
                }
                else
                    t.value = TOKnot;
                return;

            case '\\':
                if(p[1] == 'u')
                {
                    // \uXXXX starts an identifier
                    goto Lidentifier2;
                }
                goto default;
            default:
                d = get(p);
                if(d >= 0x80 && std.uni.isAlpha(d))
                    goto Lidentifier;
                else if(isStrWhiteSpaceChar(d))
                {
                    p = inc(p);            //also skip unicode whitespace
                    continue;
                }
                else
                {
                    if(std.ascii.isPrintable(d))
                        error(errmsgtbl[ERR_BAD_CHAR_C], d);
                    else
                        error(errmsgtbl[ERR_BAD_CHAR_X], d);
                }
                continue;
            }
        }
    }

    /*******************************************
     * Parse escape sequence.
     */

    dchar escapeSequence()
    {
        uint c;
        int n;

        c = *p;
        p++;
        switch(c)
        {
        case '\'':
        case '"':
        case '?':
        case '\\':
            break;
        case 'a':
            c = 7;
            break;
        case 'b':
            c = 8;
            break;
        case 'f':
            c = 12;
            break;
        case 'n':
            c = 10;
            break;
        case 'r':
            c = 13;
            break;
        case 't':
            c = 9;
            break;

        case 'v':
            version(JSCRIPT_ESCAPEV_BUG)
            {
            }
            else
            {
                c = 11;
            }
            break;

        case 'x':
            c = *p;
            p++;
            if(ishex(c))
            {
                uint v;

                n = 0;
                v = 0;
                for(;; )
                {
                    if(std.ascii.isDigit(c))
                        c -= '0';
                    else if(std.ascii.isLower(c))
                        c -= 'a' - 10;
                    else            // 'A' <= c && c <= 'Z'
                        c -= 'A' - 10;
                    v = v * 16 + c;
                    c = *p;
                    if(++n >= 2 || !ishex(c))
                        break;
                    p++;
                }
                if(n == 1)
                    error(ERR_BAD_HEX_SEQUENCE);
                c = v;
            }
            else
                error(errmsgtbl[ERR_UNDEFINED_ESC_SEQUENCE], c);
            break;

        default:
            if(c > 0x7F)
            {
                p--;
                c = get(p);
                p = inc(p);
            }
            if(isoctal(c))
            {
                uint v;

                n = 0;
                v = 0;
                for(;; )
                {
                    v = v * 8 + (c - '0');
                    c = *p;
                    if(++n >= 3 || !isoctal(c))
                        break;
                    p++;
                }
                c = v;
            }
            // Don't throw error, just accept it
            //error("undefined escape sequence \\%c\n",c);
            break;
        }
        return c;
    }

    /**************************************
     */

    d_string string(tchar quote)
    {
        tchar c;
        dchar d;
        d_string stringbuffer;

        //printf("Lexer.string('%c')\n", quote);
        p++;
        for(;; )
        {
            c = *p;
            switch(c)
            {
            case '"':
            case '\'':
                p++;
                if(c == quote)
                    return stringbuffer;
                break;

            case '\\':
                p++;
                if(*p == 'u')
                    d = unicode();
                else
                    d = escapeSequence();
                dmdscript.utf.encode(stringbuffer, d);
                continue;

            case '\n':
            case '\r':
                p++;
                error(errmsgtbl[ERR_STRING_NO_END_QUOTE], quote);
                return null;

            case 0:
            case 0x1A:
                error(ERR_UNTERMINATED_STRING);
                return null;

            default:
                p++;
                break;
            }
            stringbuffer ~= c;
        }
        assert(0);
    }

    /**************************************
     * Scan regular expression. Return null with buffer
     * pointer intact if it is not a regexp.
     */

    d_string regexp()
    {
        tchar c;
        immutable(tchar) * s;
        immutable(tchar) * start;

        /*
            RegExpLiteral:  RegExpBody RegExpFlags
              RegExpFlags:
                  empty
         |  RegExpFlags ContinuingIdentifierCharacter
              RegExpBody:  / RegExpFirstChar RegExpChars /
              RegExpFirstChar:
                  OrdinaryRegExpFirstChar
         |  \ NonTerminator
              OrdinaryRegExpFirstChar:  NonTerminator except \ | / | *
              RegExpChars:
                  empty
         |  RegExpChars RegExpChar
              RegExpChar:
                  OrdinaryRegExpChar
         |  \ NonTerminator
              OrdinaryRegExpChar: NonTerminator except \ | /
         */

        //writefln("Lexer.regexp()\n");
        start = p - 1;
        s = p;

        // Do RegExpBody
        for(;; )
        {
            c = *s;
            s++;
            switch(c)
            {
            case '\\':
                if(s == p)
                    return null;
                c = *s;
                switch(c)
                {
                case '\r':
                case '\n':                      // new line
                case 0:                         // end of file
                case 0x1A:                      // end of file
                    return null;                // not a regexp
                default:
                    break;
                }
                s++;
                continue;

            case '/':
                if(s == p + 1)
                    return null;
                break;

            case '\r':
            case '\n':                          // new line
            case 0:                             // end of file
            case 0x1A:                          // end of file
                return null;                    // not a regexp

            case '*':
                if(s == p + 1)
                    return null;
                goto default;
            default:
                continue;
            }
            break;
        }

        // Do RegExpFlags
        for(;; )
        {
            c = *s;
            if(std.ascii.isAlphaNum(c) || c == '_' || c == '$')
            {
                s++;
            }
            else
                break;
        }

        // Finish pattern & return it
        p = s;
        return start[0 .. s - start].idup;
    }

    /***************************************
     */

    dchar unicode()
    {
        dchar value;
        uint n;
        dchar c;

        value = 0;
        p++;
        for(n = 0; n < 4; n++)
        {
            c = *p;
            if(!ishex(c))
            {
                error(ERR_BAD_U_SEQUENCE);
                break;
            }
            p++;
            if(std.ascii.isDigit(c))
                c -= '0';
            else if(isasciilower(c))
                c -= 'a' - 10;
            else    // 'A' <= c && c <= 'Z'
                c -= 'A' - 10;
            value <<= 4;
            value |= c;
        }
        return value;
    }

    /********************************************
     * Read a number.
     */

    TOK number(Token *t)
    {
        immutable(tchar) * start;
        number_t intvalue;
        real realvalue;
        int base = 10;
        tchar c;

        start = p;
        for(;; )
        {
            c = *p;
            p++;
            switch(c)
            {
            case '0':
                // ECMA grammar implies that numbers with leading 0
                // like 015 are illegal. But other scripts allow them.
                if(p - start == 1)              // if leading 0
                    base = 8;
                goto case;
            case '1': case '2': case '3': case '4': case '5':
            case '6': case '7':
                break;

            case '8': case '9':                         // decimal digits
                if(base == 8)                           // and octal base
                    base = 10;                          // means back to decimal base
                break;

            default:
                p--;
                Lnumber:
                if(base == 0)
                    base = 10;
                intvalue = 0;
                foreach(tchar v; start[0 .. p - start])
                {
                    if('0' <= v && v <= '9')
                        v -= '0';
                    else if('a' <= v && v <= 'f')
                        v -= ('a' - 10);
                    else if('A' <= v && v <= 'F')
                        v -= ('A' - 10);
                    else
                        assert(0);
                    assert(v < base);
                    if((number_t.max - v) / base < intvalue)
                    {
                        realvalue = 0;
                        foreach(tchar w; start[0 .. p - start])
                        {
                            if('0' <= w && w <= '9')
                                w -= '0';
                            else if('a' <= w && w <= 'f')
                                w -= ('a' - 10);
                            else if('A' <= w && w <= 'F')
                                w -= ('A' - 10);
                            else
                                assert(0);
                            realvalue *= base;
                            realvalue += v;
                        }
                        t.realvalue = realvalue;
                        return TOKreal;
                    }
                    intvalue *= base;
                    intvalue += v;
                }
                t.realvalue = cast(double)intvalue;
                return TOKreal;

            case 'x':
            case 'X':
                if(p - start != 2 || !ishex(*p))
                    goto Lerr;
                do
                    p++;
                while(ishex(*p));
                start += 2;
                base = 16;
                goto Lnumber;

            case '.':
                while(std.ascii.isDigit(*p))
                    p++;
                if(*p == 'e' || *p == 'E')
                {
                    p++;
                    goto Lexponent;
                }
                goto Ldouble;

            case 'e':
            case 'E':
                Lexponent:
                if(*p == '+' || *p == '-')
                    p++;
                if(!std.ascii.isDigit(*p))
                    goto Lerr;
                do
                    p++;
                while(std.ascii.isDigit(*p));
                goto Ldouble;

                Ldouble:
                // convert double
                realvalue = core.stdc.stdlib.strtod(toStringz(start[0 .. p - start]), null);
                t.realvalue = realvalue;
                return TOKreal;
            }
        }

        Lerr:
        error(ERR_UNRECOGNIZED_N_LITERAL);
        return TOKeof;
    }

    static TOK isKeyword(const (tchar)[] s)
    {
        if(s[0] >= 'a' && s[0] <= 'w')
            switch(s.length)
            {
            case 2:
                if(s[0] == 'i')
                {
                    if(s[1] == 'f')
                        return TOKif;
                    if(s[1] == 'n')
                        return TOKin;
                }
                else if(s[0] == 'd' && s[1] == 'o')
                    return TOKdo;
                break;

            case 3:
                switch(s[0])
                {
                case 'f':
                    if(s[1] == 'o' && s[2] == 'r')
                        return TOKfor;
                    break;
                case 'i':
                    if(s[1] == 'n' && s[2] == 't')
                        return TOKint;
                    break;
                case 'n':
                    if(s[1] == 'e' && s[2] == 'w')
                        return TOKnew;
                    break;
                case 't':
                    if(s[1] == 'r' && s[2] == 'y')
                        return TOKtry;
                    break;
                case 'v':
                    if(s[1] == 'a' && s[2] == 'r')
                        return TOKvar;
                    break;
                default:
                    break;
                }
                break;

            case 4:
                switch(s[0])
                {
                case 'b':
                    if(s[1] == 'y' && s[2] == 't' && s[3] == 'e')
                        return TOKbyte;
                    break;
                case 'c':
                    if(s[1] == 'a' && s[2] == 's' && s[3] == 'e')
                        return TOKcase;
                    if(s[1] == 'h' && s[2] == 'a' && s[3] == 'r')
                        return TOKchar;
                    break;
                case 'e':
                    if(s[1] == 'l' && s[2] == 's' && s[3] == 'e')
                        return TOKelse;
                    if(s[1] == 'n' && s[2] == 'u' && s[3] == 'm')
                        return TOKenum;
                    break;
                case 'g':
                    if(s[1] == 'o' && s[2] == 't' && s[3] == 'o')
                        return TOKgoto;
                    break;
                case 'l':
                    if(s[1] == 'o' && s[2] == 'n' && s[3] == 'g')
                        return TOKlong;
                    break;
                case 'n':
                    if(s[1] == 'u' && s[2] == 'l' && s[3] == 'l')
                        return TOKnull;
                    break;
                case 't':
                    if(s[1] == 'h' && s[2] == 'i' && s[3] == 's')
                        return TOKthis;
                    if(s[1] == 'r' && s[2] == 'u' && s[3] == 'e')
                        return TOKtrue;
                    break;
                case 'w':
                    if(s[1] == 'i' && s[2] == 't' && s[3] == 'h')
                        return TOKwith;
                    break;
                case 'v':
                    if(s[1] == 'o' && s[2] == 'i' && s[3] == 'd')
                        return TOKvoid;
                    break;
                default:
                    break;
                }
                break;

            case 5:
                switch(s)
                {
                case "break":               return TOKbreak;
                case "catch":               return TOKcatch;
                case "class":               return TOKclass;
                case "const":               return TOKconst;
                case "false":               return TOKfalse;
                case "final":               return TOKfinal;
                case "float":               return TOKfloat;
                case "short":               return TOKshort;
                case "super":               return TOKsuper;
                case "throw":               return TOKthrow;
                case "while":               return TOKwhile;
                default:
                    break;
                }
                break;

            case 6:
                switch(s)
                {
                case "delete":              return TOKdelete;
                case "double":              return TOKdouble;
                case "export":              return TOKexport;
                case "import":              return TOKimport;
                case "native":              return TOKnative;
                case "public":              return TOKpublic;
                case "return":              return TOKreturn;
                case "static":              return TOKstatic;
                case "switch":              return TOKswitch;
                case "typeof":              return TOKtypeof;
                default:
                    break;
                }
                break;

            case 7:
                switch(s)
                {
                case "boolean":             return TOKboolean;
                case "default":             return TOKdefault;
                case "extends":             return TOKextends;
                case "finally":             return TOKfinally;
                case "package":             return TOKpackage;
                case "private":             return TOKprivate;
                default:
                    break;
                }
                break;

            case 8:
                switch(s)
                {
                case "abstract":    return TOKabstract;
                case "continue":    return TOKcontinue;
                case "debugger":    return TOKdebugger;
                case "function":    return TOKfunction;
                default:
                    break;
                }
                break;

            case 9:
                switch(s)
                {
                case "interface":   return TOKinterface;
                case "protected":   return TOKprotected;
                case "transient":   return TOKtransient;
                default:
                    break;
                }
                break;

            case 10:
                switch(s)
                {
                case "implements":  return TOKimplements;
                case "instanceof":  return TOKinstanceof;
                default:
                    break;
                }
                break;

            case 12:
                if(s == "synchronized")
                    return TOKsynchronized;
                break;

            default:
                break;
            }
        return TOKreserved;             // not a keyword
    }
}


/****************************************
 */

struct Keyword
{
    string name;
    TOK    value;
}

static immutable Keyword[] keywords =
[
//    {	"",		TOK		},

    { "break", TOKbreak },
    { "case", TOKcase },
    { "continue", TOKcontinue },
    { "default", TOKdefault },
    { "delete", TOKdelete },
    { "do", TOKdo },
    { "else", TOKelse },
    { "export", TOKexport },
    { "false", TOKfalse },
    { "for", TOKfor },
    { "function", TOKfunction },
    { "if", TOKif },
    { "import", TOKimport },
    { "in", TOKin },
    { "new", TOKnew },
    { "null", TOKnull },
    { "return", TOKreturn },
    { "switch", TOKswitch },
    { "this", TOKthis },
    { "true", TOKtrue },
    { "typeof", TOKtypeof },
    { "var", TOKvar },
    { "void", TOKvoid },
    { "while", TOKwhile },
    { "with", TOKwith },

    { "catch", TOKcatch },
    { "class", TOKclass },
    { "const", TOKconst },
    { "debugger", TOKdebugger },
    { "enum", TOKenum },
    { "extends", TOKextends },
    { "finally", TOKfinally },
    { "super", TOKsuper },
    { "throw", TOKthrow },
    { "try", TOKtry },

    { "abstract", TOKabstract },
    { "boolean", TOKboolean },
    { "byte", TOKbyte },
    { "char", TOKchar },
    { "double", TOKdouble },
    { "final", TOKfinal },
    { "float", TOKfloat },
    { "goto", TOKgoto },
    { "implements", TOKimplements },
    { "instanceof", TOKinstanceof },
    { "int", TOKint },
    { "interface", TOKinterface },
    { "long", TOKlong },
    { "native", TOKnative },
    { "package", TOKpackage },
    { "private", TOKprivate },
    { "protected", TOKprotected },
    { "public", TOKpublic },
    { "short", TOKshort },
    { "static", TOKstatic },
    { "synchronized", TOKsynchronized },
    { "transient", TOKtransient },
];

void init()
{
    uint u;
    TOK v;

    for(u = 0; u < keywords.length; u++)
    {
        d_string s;

        //writefln("keyword[%d] = '%s'", u, keywords[u].name);
        s = keywords[u].name;
        v = keywords[u].value;

        //writefln("tochars[%d] = '%s'", v, s);
        Token.tochars[v] = s;
    }

    Token.tochars[TOKreserved] = "reserved";
    Token.tochars[TOKeof] = "EOF";
    Token.tochars[TOKlbrace] = "{";
    Token.tochars[TOKrbrace] = "}";
    Token.tochars[TOKlparen] = "(";
    Token.tochars[TOKrparen] = "";
    Token.tochars[TOKlbracket] = "[";
    Token.tochars[TOKrbracket] = "]";
    Token.tochars[TOKcolon] = ":";
    Token.tochars[TOKsemicolon] = ";";
    Token.tochars[TOKcomma] = ",";
    Token.tochars[TOKor] = "|";
    Token.tochars[TOKorass] = "|=";
    Token.tochars[TOKxor] = "^";
    Token.tochars[TOKxorass] = "^=";
    Token.tochars[TOKassign] = "=";
    Token.tochars[TOKless] = "<";
    Token.tochars[TOKgreater] = ">";
    Token.tochars[TOKlessequal] = "<=";
    Token.tochars[TOKgreaterequal] = ">=";
    Token.tochars[TOKequal] = "==";
    Token.tochars[TOKnotequal] = "!=";
    Token.tochars[TOKidentity] = "===";
    Token.tochars[TOKnonidentity] = "!==";
    Token.tochars[TOKshiftleft] = "<<";
    Token.tochars[TOKshiftright] = ">>";
    Token.tochars[TOKushiftright] = ">>>";
    Token.tochars[TOKplus] = "+";
    Token.tochars[TOKplusass] = "+=";
    Token.tochars[TOKminus] = "-";
    Token.tochars[TOKminusass] = "-=";
    Token.tochars[TOKmultiply] = "*";
    Token.tochars[TOKmultiplyass] = "*=";
    Token.tochars[TOKdivide] = "/";
    Token.tochars[TOKdivideass] = "/=";
    Token.tochars[TOKpercent] = "%";
    Token.tochars[TOKpercentass] = "%=";
    Token.tochars[TOKand] = "&";
    Token.tochars[TOKandass] = "&=";
    Token.tochars[TOKdot] = ".";
    Token.tochars[TOKquestion] = "?";
    Token.tochars[TOKtilde] = "~";
    Token.tochars[TOKnot] = "!";
    Token.tochars[TOKandand] = "&&";
    Token.tochars[TOKoror] = "||";
    Token.tochars[TOKplusplus] = "++";
    Token.tochars[TOKminusminus] = "--";
    Token.tochars[TOKcall] = "CALL";

    Lexer.inited = true;
}

