
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

// Program to generate string files in script data structures.
// Saves much tedious typing, and eliminates typo problems.
// Generates:
//      text.d

import std.c.stdio;
import std.c.stdlib;
import std.stdio;


struct Msgtable
{
        char[] name;
        int value;
        char[] ident;
}


Msgtable errtable[] =
[
    { "DMDScript fatal runtime error: ",                         0, "ERR_RUNTIME_PREFIX" },
    { "No default value for COM object",                         0, "ERR_COM_NO_DEFAULT_VALUE" },
    { "%s does not have a [[Construct]] property",               0, "ERR_COM_NO_CONSTRUCT_PROPERTY" },
    { "argument type mismatch for %s",                           0, "ERR_DISP_E_TYPEMISMATCH" },
    { "wrong number of arguments for %s",                        0, "ERR_DISP_E_BADPARAMCOUNT" },
    { "%s Invoke() fails with COM error %x",                     0, "ERR_COM_FUNCTION_ERROR" },
    { "Dcomobject: %s.%s fails with COM error %x",               0, "ERR_COM_OBJECT_ERROR" },
    { "unrecognized switch '%s'",                                0, "ERR_BAD_SWITCH" },
    { "undefined label '%s' in function '%s'",                   0, "ERR_UNDEFINED_LABEL" },
    { "unterminated /* */ comment",                              0, "ERR_BAD_C_COMMENT" },
    { "<!-- comment does not end in newline",                    0, "ERR_BAD_HTML_COMMENT" },
    { "unsupported char '%s'",                                   0, "ERR_BAD_CHAR_C" },
    { "unsupported char 0x%02x",                                 0, "ERR_BAD_CHAR_X" },
    { "escape hex sequence requires 2 hex digits",               0, "ERR_BAD_HEX_SEQUENCE" },
    { "undefined escape sequence \\\\%c",                        0, "ERR_UNDEFINED_ESC_SEQUENCE" },
    { "string is missing an end quote %s",                       0, "ERR_STRING_NO_END_QUOTE" },
    { "end of file before end of string",                        0, "ERR_UNTERMINATED_STRING" },
    { "\\\\u sequence must be followed by 4 hex characters",     0, "ERR_BAD_U_SEQUENCE" },
    { "unrecognized numeric literal",                            0, "ERR_UNRECOGNIZED_N_LITERAL" },
    { "Identifier expected in FormalParameterList, not %s",      0, "ERR_FPL_EXPECTED_IDENTIFIER" },
    { "comma expected in FormalParameterList, not %s",           0, "ERR_FPL_EXPECTED_COMMA" },
    { "identifier expected",                                     0, "ERR_EXPECTED_IDENTIFIER" },
    { "found '%s' when expecting '%s'",                          0, "ERR_EXPECTED_GENERIC" },
    { "identifier expected instead of '%s'",                     0, "ERR_EXPECTED_IDENTIFIER_PARAM" },
    { "identifier expected following '%s', not '%s'",            0, "ERR_EXPECTED_IDENTIFIER_2PARAM" },
    { "EOF found before closing ']' of block statement",         0, "ERR_UNTERMINATED_BLOCK" },
    { "only one variable can be declared for 'in', not %d",      0, "ERR_TOO_MANY_IN_VARS" },
    { "';' or 'in' expected, not '%s'",                          0, "ERR_IN_EXPECTED" },
    { "label expected after goto, not '%s'",                     0, "ERR_GOTO_LABEL_EXPECTED" },
    { "catch or finally expected following try",                 0, "ERR_TRY_CATCH_EXPECTED" },
    { "found '%s' instead of statement",                         0, "ERR_STATEMENT_EXPECTED" },
    { "expression expected, not '%s'",                           0, "ERR_EXPECTED_EXPRESSION" },
    { "Object literal in initializer",                           0, "ERR_OBJ_LITERAL_IN_INITIALIZER" },
    { "label '%s' is already defined",                           0, "ERR_LABEL_ALREADY_DEFINED" },
    { "redundant case %s",                                       0, "ERR_SWITCH_REDUNDANT_CASE" },
    { "case %s: is not in a switch statement",                   0, "ERR_MISPLACED_SWITCH_CASE" },
    { "redundant default in switch statement",                   0, "ERR_SWITCH_REDUNDANT_DEFAULT" },
    { "default is not in a switch statement",                    0, "ERR_MISPLACED_SWITCH_DEFAULT" },
    { "init statement must be expression or var",                0, "ERR_INIT_NOT_EXPRESSION" },
    { "can only break from within loop or switch",               0, "ERR_MISPLACED_BREAK" },
    { "continue is not in a loop",                               0, "ERR_MISPLACED_CONTINUE" },
    { "Statement label '%s' is undefined",                       0, "ERR_UNDEFINED_STATEMENT_LABEL" },
    { "cannot goto into with statement",                         0, "ERR_GOTO_INTO_WITH" },
    { "can only return from within function",                    0, "ERR_MISPLACED_RETURN" },
    { "no expression for throw",                                 0, "ERR_NO_THROW_EXPRESSION" },
    { "%s.%s is undefined",                                      0, "ERR_UNDEFINED_OBJECT_SYMBOL" },
    { "Number.prototype.%s() expects a Number not a %s",         0, "ERR_FUNCTION_WANTS_NUMBER" },
    { "String.prototype.%s() expects a String not a %s",         0, "ERR_FUNCTION_WANTS_STRING" },
    { "Date.prototype.%s() expects a Date not a %s",             0, "ERR_FUNCTION_WANTS_DATE" },
    { "%s %s is undefined and has no Call method",               0, "ERR_UNDEFINED_NO_CALL2"},
    { "%s %s.%s is undefined and has no Call method",            0, "ERR_UNDEFINED_NO_CALL3"},
    { "Boolean.prototype.%s() expects a Boolean not a %s",       0, "ERR_FUNCTION_WANTS_BOOL" },
    { "arg to Array(len) must be 0 .. 2**32-1, not %.16g",       0, "ERR_ARRAY_LEN_OUT_OF_BOUNDS" },
    { "Number.prototype.%s() %s out of range",                   0, "ERR_VALUE_OUT_OF_RANGE" },
    { "TypeError in %s",                                         0, "ERR_TYPE_ERROR" },
    { "Error compiling regular expression",                      0, "ERR_REGEXP_COMPILE" },
    { "%s not transferrable",                                    0, "ERR_NOT_TRANSFERRABLE" },
    { "%s %s cannot convert to Object",                          0, "ERR_CANNOT_CONVERT_TO_OBJECT2" },
    { "%s %s.%s cannot convert to Object",                       0, "ERR_CANNOT_CONVERT_TO_OBJECT3" },
    { "cannot convert %s to Object",                             0, "ERR_CANNOT_CONVERT_TO_OBJECT4" },
    { "cannot assign to %s",                                     0, "ERR_CANNOT_ASSIGN_TO" },
    { "cannot assign %s to %s",                                  0, "ERR_CANNOT_ASSIGN" },
    { "cannot assign to %s.%s",                                  0, "ERR_CANNOT_ASSIGN_TO2" },
    { "cannot assign to function",                               0, "ERR_FUNCTION_NOT_LVALUE"},
    { "RHS of %s must be an Object, not a %s",                   0, "ERR_RHS_MUST_BE_OBJECT" },
    { "can't Put('%s', %s) to a primitive %s",                   0, "ERR_CANNOT_PUT_TO_PRIMITIVE" },
    { "can't Put(%u, %s) to a primitive %s",                     0, "ERR_CANNOT_PUT_INDEX_TO_PRIMITIVE" },
    { "object cannot be converted to a primitive type",          0, "ERR_OBJECT_CANNOT_BE_PRIMITIVE" },
    { "can't Get(%s) from primitive %s(%s)",                     0, "ERR_CANNOT_GET_FROM_PRIMITIVE" },
    { "can't Get(%d) from primitive %s(%s)",                     0, "ERR_CANNOT_GET_INDEX_FROM_PRIMITIVE" },
    { "primitive %s has no Construct method",                    0, "ERR_PRIMITIVE_NO_CONSTRUCT" },
    { "primitive %s has no Call method",                         0, "ERR_PRIMITIVE_NO_CALL" },
    { "for-in must be on an object, not a primitive",            0, "ERR_FOR_IN_MUST_BE_OBJECT" },
    { "assert() line %d",                                        0, "ERR_ASSERT"},
    { "object does not have a [[Call]] property",                0, "ERR_OBJECT_NO_CALL"},
    { "%s: %s",                                                  0, "ERR_S_S"},
    { "no Default Put for object",                               0, "ERR_NO_DEFAULT_PUT"},
    { "%s does not have a [[Construct]] property",               0, "ERR_S_NO_CONSTRUCT"},
    { "%s does not have a [[Call]] property",                    0, "ERR_S_NO_CALL"},
    { "%s does not have a [[HasInstance]] property",             0, "ERR_S_NO_INSTANCE"},
    { "length property must be an integer",                      0, "ERR_LENGTH_INT"},
    { "Array.prototype.toLocaleString() not transferrable",      0, "ERR_TLS_NOT_TRANSFERRABLE"},
    { "Function.prototype.toString() not transferrable",         0, "ERR_TS_NOT_TRANSFERRABLE"},
    { "Function.prototype.apply(): argArray must be array or arguments object", 0, "ERR_ARRAY_ARGS"},
    { ".prototype must be an Object, not a %s",                  0, "ERR_MUST_BE_OBJECT"},
    { "VBArray expected, not a %s",                              0, "ERR_VBARRAY_EXPECTED"},
    { "VBArray subscript out of range",                          0, "ERR_VBARRAY_SUBSCRIPT"},
    { "Type mismatch",                                           0, "ERR_ACTIVEX"},
    { "no property %s",                                          0, "ERR_NO_PROPERTY"},
    { "Put of %s failed",                                        0, "ERR_PUT_FAILED"},
    { "Get of %s failed",                                        0, "ERR_GET_FAILED"},
    { "argument not a collection",                               0, "ERR_NOT_COLLECTION"},
    { "%s.%s expects a valid UTF codepoint not \\\\u%x",         0, "ERR_NOT_VALID_UTF"},

// COM error messages
    { "Unexpected",                                              0, "ERR_E_UNEXPECTED"},
];

int main()
{
    FILE* fp;
    uint i;

    fp = fopen("errmsgs.d","w");
    if (!fp)
    {
        printf("can't open errmsgs.d\n");
        exit(EXIT_FAILURE);
    }

    fprintf(fp, "// File generated by textgen.d\n");
    fprintf(fp, "//\n");

    fprintf(fp, "// *** ERROR MESSAGES ***\n");
    fprintf(fp, "//\n");
    fprintf(fp, "module dmdscript.errmsgs;\n");
    fprintf(fp, "enum {\n");
    for (i = 0; i < errtable.length; i++)
    {   char[] id = errtable[i].ident;

        if (!id)
            id = errtable[i].name;
        fwritefln(fp,"\t%s = %d,", id, i);
    }
    fprintf(fp, "};\n");

    fprintf(fp, "// *** ERROR MESSAGES ***\n");
    fprintf(fp, "//\n");
    fprintf(fp, "char[][] errmsgtbl = [\n");
    for (i = 0; i < errtable.length; i++)
    {   char[] id = errtable[i].ident;
        char[] p = errtable[i].name;

        fwritefln(fp,"\t\"%s\",", p);
    }
    fprintf(fp, "];\n");

    fclose(fp);

    return EXIT_SUCCESS;
}
