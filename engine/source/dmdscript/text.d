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


module dmdscript.text;


enum string TEXT_ = "";
enum string TEXT_source = "source";
enum string TEXT_global = "global";
enum string TEXT_ignoreCase = "ignoreCase";
enum string TEXT_multiline = "multiline";
enum string TEXT_lastIndex = "lastIndex";
enum string TEXT_input = "input";
enum string TEXT_lastMatch = "lastMatch";
enum string TEXT_lastParen = "lastParen";
enum string TEXT_leftContext = "leftContext";
enum string TEXT_rightContext = "rightContext";
enum string TEXT_prototype = "prototype";
enum string TEXT_constructor = "constructor";
enum string TEXT_toString = "toString";
enum string TEXT_toLocaleString = "toLocaleString";
enum string TEXT_toSource = "toSource";
enum string TEXT_valueOf = "valueOf";
enum string TEXT_message = "message";
enum string TEXT_description = "description";
enum string TEXT_Error = "Error";
enum string TEXT_name = "name";
enum string TEXT_length = "length";
enum string TEXT_NaN = "NaN";
enum string TEXT_Infinity = "Infinity";
enum string TEXT_negInfinity = "-Infinity";
enum string TEXT_bobjectb = "[object]";
enum string TEXT_undefined = "undefined";
enum string TEXT_null = "null";
enum string TEXT_true = "true";
enum string TEXT_false = "false";
enum string TEXT_object = "object";
enum string TEXT_string = "enum string";
enum string TEXT_number = "number";
enum string TEXT_boolean = "boolean";
enum string TEXT_Object = "Object";
enum string TEXT_String = "String";
enum string TEXT_Number = "Number";
enum string TEXT_Boolean = "Boolean";
enum string TEXT_Date = "Date";
enum string TEXT_Array = "Array";
enum string TEXT_RegExp = "RegExp";
enum string TEXT_arity = "arity";
enum string TEXT_arguments = "arguments";
enum string TEXT_callee = "callee";
enum string TEXT_caller = "caller";                  // extension
enum string TEXT_EvalError = "EvalError";
enum string TEXT_RangeError = "RangeError";
enum string TEXT_ReferenceError = "ReferenceError";
enum string TEXT_SyntaxError = "SyntaxError";
enum string TEXT_TypeError = "TypeError";
enum string TEXT_URIError = "URIError";
enum string TEXT_this = "this";
enum string TEXT_fromCharCode = "fromCharCode";
enum string TEXT_charAt = "charAt";
enum string TEXT_charCodeAt = "charCodeAt";
enum string TEXT_concat = "concat";
enum string TEXT_indexOf = "indexOf";
enum string TEXT_lastIndexOf = "lastIndexOf";
enum string TEXT_localeCompare = "localeCompare";
enum string TEXT_match = "match";
enum string TEXT_replace = "replace";
enum string TEXT_search = "search";
enum string TEXT_slice = "slice";
enum string TEXT_split = "split";
enum string TEXT_substr = "substr";
enum string TEXT_substring = "substring";
enum string TEXT_toLowerCase = "toLowerCase";
enum string TEXT_toLocaleLowerCase = "toLocaleLowerCase";
enum string TEXT_toUpperCase = "toUpperCase";
enum string TEXT_toLocaleUpperCase = "toLocaleUpperCase";
enum string TEXT_hasOwnProperty = "hasOwnProperty";
enum string TEXT_isPrototypeOf = "isPrototypeOf";
enum string TEXT_propertyIsEnumerable = "propertyIsEnumerable";
enum string TEXT_dollar1 = "$1";
enum string TEXT_dollar2 = "$2";
enum string TEXT_dollar3 = "$3";
enum string TEXT_dollar4 = "$4";
enum string TEXT_dollar5 = "$5";
enum string TEXT_dollar6 = "$6";
enum string TEXT_dollar7 = "$7";
enum string TEXT_dollar8 = "$8";
enum string TEXT_dollar9 = "$9";
enum string TEXT_index = "index";
enum string TEXT_compile = "compile";
enum string TEXT_test = "test";
enum string TEXT_exec = "exec";
enum string TEXT_MAX_VALUE = "MAX_VALUE";
enum string TEXT_MIN_VALUE = "MIN_VALUE";
enum string TEXT_NEGATIVE_INFINITY = "NEGATIVE_INFINITY";
enum string TEXT_POSITIVE_INFINITY = "POSITIVE_INFINITY";
enum string TEXT_dash = "-";
enum string TEXT_toFixed = "toFixed";
enum string TEXT_toExponential = "toExponential";
enum string TEXT_toPrecision = "toPrecision";
enum string TEXT_abs = "abs";
enum string TEXT_acos = "acos";
enum string TEXT_asin = "asin";
enum string TEXT_atan = "atan";
enum string TEXT_atan2 = "atan2";
enum string TEXT_ceil = "ceil";
enum string TEXT_cos = "cos";
enum string TEXT_exp = "exp";
enum string TEXT_floor = "floor";
enum string TEXT_log = "log";
enum string TEXT_max = "max";
enum string TEXT_min = "min";
enum string TEXT_pow = "pow";
enum string TEXT_random = "random";
enum string TEXT_round = "round";
enum string TEXT_sin = "sin";
enum string TEXT_sqrt = "sqrt";
enum string TEXT_tan = "tan";
enum string TEXT_E = "E";
enum string TEXT_LN10 = "LN10";
enum string TEXT_LN2 = "LN2";
enum string TEXT_LOG2E = "LOG2E";
enum string TEXT_LOG10E = "LOG10E";
enum string TEXT_PI = "PI";
enum string TEXT_SQRT1_2 = "SQRT1_2";
enum string TEXT_SQRT2 = "SQRT2";
enum string TEXT_parse = "parse";
enum string TEXT_UTC = "UTC";

enum string TEXT_getTime = "getTime";
enum string TEXT_getYear = "getYear";
enum string TEXT_getFullYear = "getFullYear";
enum string TEXT_getUTCFullYear = "getUTCFullYear";
enum string TEXT_getDate = "getDate";
enum string TEXT_getUTCDate = "getUTCDate";
enum string TEXT_getMonth = "getMonth";
enum string TEXT_getUTCMonth = "getUTCMonth";
enum string TEXT_getDay = "getDay";
enum string TEXT_getUTCDay = "getUTCDay";
enum string TEXT_getHours = "getHours";
enum string TEXT_getUTCHours = "getUTCHours";
enum string TEXT_getMinutes = "getMinutes";
enum string TEXT_getUTCMinutes = "getUTCMinutes";
enum string TEXT_getSeconds = "getSeconds";
enum string TEXT_getUTCSeconds = "getUTCSeconds";
enum string TEXT_getMilliseconds = "getMilliseconds";
enum string TEXT_getUTCMilliseconds = "getUTCMilliseconds";
enum string TEXT_getTimezoneOffset = "getTimezoneOffset";
enum string TEXT_getVarDate = "getVarDate";

enum string TEXT_setTime = "setTime";
enum string TEXT_setYear = "setYear";
enum string TEXT_setFullYear = "setFullYear";
enum string TEXT_setUTCFullYear = "setUTCFullYear";
enum string TEXT_setDate = "setDate";
enum string TEXT_setUTCDate = "setUTCDate";
enum string TEXT_setMonth = "setMonth";
enum string TEXT_setUTCMonth = "setUTCMonth";
enum string TEXT_setDay = "setDay";
enum string TEXT_setUTCDay = "setUTCDay";
enum string TEXT_setHours = "setHours";
enum string TEXT_setUTCHours = "setUTCHours";
enum string TEXT_setMinutes = "setMinutes";
enum string TEXT_setUTCMinutes = "setUTCMinutes";
enum string TEXT_setSeconds = "setSeconds";
enum string TEXT_setUTCSeconds = "setUTCSeconds";
enum string TEXT_setMilliseconds = "setMilliseconds";
enum string TEXT_setUTCMilliseconds = "setUTCMilliseconds";

enum string TEXT_toDateString = "toDateString";
enum string TEXT_toTimeString = "toTimeString";
enum string TEXT_toLocaleDateString = "toLocaleDateString";
enum string TEXT_toLocaleTimeString = "toLocaleTimeString";
enum string TEXT_toUTCString = "toUTCString";
enum string TEXT_toGMTString = "toGMTString";

enum string TEXT_comma = ",";
enum string TEXT_join = "join";
enum string TEXT_pop = "pop";
enum string TEXT_push = "push";
enum string TEXT_reverse = "reverse";
enum string TEXT_shift = "shift";
enum string TEXT_sort = "sort";
enum string TEXT_splice = "splice";
enum string TEXT_unshift = "unshift";
enum string TEXT_apply = "apply";
enum string TEXT_call = "call";
enum string TEXT_function = "function";

enum string TEXT_eval = "eval";
enum string TEXT_parseInt = "parseInt";
enum string TEXT_parseFloat = "parseFloat";
enum string TEXT_escape = "escape";
enum string TEXT_unescape = "unescape";
enum string TEXT_isNaN = "isNaN";
enum string TEXT_isFinite = "isFinite";
enum string TEXT_decodeURI = "decodeURI";
enum string TEXT_decodeURIComponent = "decodeURIComponent";
enum string TEXT_encodeURI = "encodeURI";
enum string TEXT_encodeURIComponent = "encodeURIComponent";

enum string TEXT_print = "print";
enum string TEXT_println = "println";
enum string TEXT_readln = "readln";
enum string TEXT_getenv = "getenv";
enum string TEXT_assert = "assert";

enum string TEXT_Function = "Function";
enum string TEXT_Math = "Math";

enum string TEXT_0 = "0";
enum string TEXT_1 = "1";
enum string TEXT_2 = "2";
enum string TEXT_3 = "3";
enum string TEXT_4 = "4";
enum string TEXT_5 = "5";
enum string TEXT_6 = "6";
enum string TEXT_7 = "7";
enum string TEXT_8 = "8";
enum string TEXT_9 = "9";

enum string TEXT_anchor = "anchor";
enum string TEXT_big = "big";
enum string TEXT_blink = "blink";
enum string TEXT_bold = "bold";
enum string TEXT_fixed = "fixed";
enum string TEXT_fontcolor = "fontcolor";
enum string TEXT_fontsize = "fontsize";
enum string TEXT_italics = "italics";
enum string TEXT_link = "link";
enum string TEXT_small = "small";
enum string TEXT_strike = "strike";
enum string TEXT_sub = "sub";
enum string TEXT_sup = "sup";

enum string TEXT_Enumerator = "Enumerator";
enum string TEXT_item = "item";
enum string TEXT_atEnd = "atEnd";
enum string TEXT_moveNext = "moveNext";
enum string TEXT_moveFirst = "moveFirst";

enum string TEXT_VBArray = "VBArray";
enum string TEXT_dimensions = "dimensions";
enum string TEXT_getItem = "getItem";
enum string TEXT_lbound = "lbound";
enum string TEXT_toArray = "toArray";
enum string TEXT_ubound = "ubound";

enum string TEXT_ScriptEngine = "ScriptEngine";
enum string TEXT_ScriptEngineBuildVersion = "ScriptEngineBuildVersion";
enum string TEXT_ScriptEngineMajorVersion = "ScriptEngineMajorVersion";
enum string TEXT_ScriptEngineMinorVersion = "ScriptEngineMinorVersion";
enum string TEXT_DMDScript = "DMDScript";

enum string TEXT_date = "date";
enum string TEXT_unknown = "unknown";
