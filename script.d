
/* Digital Mars DMDScript source code.
 * Copyright (c) 2000-2002 by Chromium Communications
 * D version Copyright (c) 2004-2006 by Digital Mars
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


module dmdscript.script;

import std.ctype;
import std.string;
import std.c.stdlib;
import std.c.stdarg;

/* =================== Configuration ======================= */

const uint MAJOR_VERSION = 5;   // ScriptEngineMajorVersion
const uint MINOR_VERSION = 5;   // ScriptEngineMinorVersion

const uint BUILD_VERSION = 1;   // ScriptEngineBuildVersion

const uint JSCRIPT_CATCH_BUG = 1;       // emulate Jscript's bug in scoping of
                                        // catch objects in violation of ECMA
const uint JSCRIPT_ESCAPEV_BUG = 0;     // emulate Jscript's bug where \v is
                                        // not recognized as vertical tab

//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

alias char tchar;

alias ulong number_t;
alias double real_t;

alias uint Loc;                 // file location (line number)

struct ErrInfo
{
    tchar[] message;            // error message (null if no error)
    tchar[] srcline;            // string of source line (null if not known)
    uint linnum;                // source line number (1 based, 0 if not available)
    int charpos;                // character position (1 based, 0 if not available)
    int code;                   // error code (0 if not known)
}

class ScriptException : Exception
{
    ErrInfo ei;

    this(tchar[] msg)
    {   ei.message = msg;
        super(msg);
    }

    this(ErrInfo* pei)
    {
        ei = *pei;
        super(ei.message);
    }
}

int logflag;    // used for debugging


// Aliases for script primitive types
alias uint      d_boolean;
alias double    d_number;
alias int       d_int32;
alias uint      d_uint32;
alias ushort    d_uint16;
alias tchar[]   d_string;

import dmdscript.value;
import dmdscript.dobject;
import dmdscript.program;
import dmdscript.text;

struct CallContext
{
    Dobject[] scopex;   // current scope chain
    Dobject variable;   // object for variable instantiation
    Dobject global;     // global object
    uint scoperoot;     // number of entries in scope[] starting from 0
                        // to copy onto new scopes
    uint globalroot;    // number of entries in scope[] starting from 0
                        // that are in the "global" context. Always <= scoperoot
    void* lastnamedfunc;  // points to the last named function added as an event
    Program prog;
    Dobject callerothis;        // caller's othis
    Dobject caller;             // caller function

    char[16] value;     // place to store exception; must be same size as Value
    uint linnum;        // source line number of exception (1 based, 0 if not available)

    int finallyret;     // !=0 if IRfinallyret was executed
    int Interrupt;      // !=0 if cancelled due to interrupt
}

struct Global
{
    tchar[] copyright = "Copyright (c) 1999-2006 by Digital Mars";
    tchar[] written = "written by Walter Bright";
}

Global global;

tchar[] banner()
{
    return std.string.format(
        "Digital Mars DMDScript 1.11\n",
        "www.digitalmars.com\n",
        "Compiled by Digital Mars DMD D compiler\n",
        global.copyright, "\n",
        global.written);
}

int isStrWhiteSpaceChar(dchar c)
{
    switch (c)
    {
        case ' ':
        case '\t':
        case 0xA0:      // <NBSP>
        case '\f':
        case '\v':
        case '\r':
        case '\n':
        case 0x2028:    // <LS>
        case 0x2029:    // <PS>
        case 0x2001:    // <USP>
        case 0x2000:    // should we do this one?
            return 1;

        default:
            break;
    }
    return 0;
}


/************************
 * Convert d_string to an index, if it is one.
 * Returns:
 *      true    it's an index, and *index is set
 *      false   it's not an index
 */

int StringToIndex(d_string name, out d_uint32 index)
{
    if (name.length)
    {
        d_uint32 i = 0;

        for (uint j = 0; j < name.length; j++)
        {   tchar c = name[j];

            switch (c)
            {
                case '0':
                case '1':
                case '2':
                case '3':
                case '4':
                case '5':
                case '6':
                case '7':
                case '8':
                case '9':
                    if ((i == 0 && j) ||                // if leading zeros
                        i >= 0xFFFFFFFF / 10)   // or overflow
                        goto Lnotindex;
                    i = i * 10 + c - '0';
                    break;

                default:
                    goto Lnotindex;
            }
        }
        index = i;
        return true;
    }

  Lnotindex:
    return false;
}


/********************************
 * Parse string numeric literal into a number.
 * Input:
 *      parsefloat      0: convert per ECMA 9.3.1
 *                      1: convert per ECMA 15.1.2.3 (global.parseFloat())
 */

d_number StringNumericLiteral(d_string string, out size_t endidx, int parsefloat)
{
    // Convert StringNumericLiteral using ECMA 9.3.1
    d_number number;
    int sign = 0;
    size_t i;
    size_t len;
    size_t eoff;

    // Skip leading whitespace
    eoff = string.length;
    foreach (size_t j, dchar c; string)
    {
        if (!isStrWhiteSpaceChar(c))
        {
            eoff = j;
            break;
        }
    }
    string = string[eoff .. length];
    len = string.length;

    // Check for [+|-]
    i = 0;
    if (len)
    {
        switch (string[0])
        {   case '+':
                sign = 0;
                i++;
                break;

            case '-':
                sign = 1;
                i++;
                break;

            default:
                sign = 0;
                break;
        }
    }

    size_t inflen = TEXT_Infinity.length;
    if (len - i >= inflen &&
        string[i .. i + inflen] == TEXT_Infinity)
    {
        number = sign ? -d_number.infinity : d_number.infinity;
        endidx = eoff + i + inflen;
    }
    else if (len - i >= 2 &&
             string[i] == '0' && (string[i + 1] == 'x' || string[i + 1] == 'X'))
    {
        // Check for 0[x|X]HexDigit...
        number = 0;
        if (parsefloat)
        {   // Do not recognize the 0x, treat it as if it's just a '0'
            i += 1;
        }
        else
        {
            i += 2;
            for (; i < len; i++)
            {   tchar c;

                c = string[i];          // don't need to decode UTF here
                if ('0' <= c && c <= '9')
                    number = number * 16 + (c - '0');
                else if ('a' <= c && c <= 'f')
                    number = number * 16 + (c - 'a' + 10);
                else if ('A' <= c && c <= 'F')
                    number = number * 16 + (c - 'A' + 10);
                else
                    break;
            }
        }
        if (sign)
            number = -number;
        endidx = eoff + i;
    }
    else
    {   char* endptr;
        char* s = std.string.toStringz(string[i .. len]);

        endptr = s;
        number = std.c.stdlib.strtod(s, &endptr);
        endidx = (endptr - s) + i;

        //printf("s = '%s', endidx = %d, eoff = %d, number = %g\n", s, endidx, eoff, number);

        // Correctly produce a -0 for the
        // string "-1e-2000"
        if (sign)
            number = -number;
        if (endidx == i && (parsefloat || i != 0))
            number = d_number.nan;
        endidx += eoff;
    }

    return number;
}




int localeCompare(CallContext *cc, d_string s1, d_string s2)
{   // no locale support here
    return std.string.cmp(s1, s2);
}

