
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


module dmdscript.text;


char[] TEXT_ = "";
char[] TEXT_source = "source";
char[] TEXT_global = "global";
char[] TEXT_ignoreCase = "ignoreCase";
char[] TEXT_multiline = "multiline";
char[] TEXT_lastIndex = "lastIndex";
char[] TEXT_input = "input";
char[] TEXT_lastMatch = "lastMatch";
char[] TEXT_lastParen = "lastParen";
char[] TEXT_leftContext = "leftContext";
char[] TEXT_rightContext = "rightContext";
char[] TEXT_prototype = "prototype";
char[] TEXT_constructor = "constructor";
char[] TEXT_toString = "toString";
char[] TEXT_toLocaleString = "toLocaleString";
char[] TEXT_toSource = "toSource";
char[] TEXT_valueOf = "valueOf";
char[] TEXT_message = "message";
char[] TEXT_description = "description";
char[] TEXT_Error = "Error";
char[] TEXT_name = "name";
char[] TEXT_length = "length";
char[] TEXT_NaN = "NaN";
char[] TEXT_Infinity = "Infinity";
char[] TEXT_negInfinity = "-Infinity";
char[] TEXT_bobjectb = "[object]";
char[] TEXT_undefined = "undefined";
char[] TEXT_null = "null";
char[] TEXT_true = "true";
char[] TEXT_false = "false";
char[] TEXT_object = "object";
char[] TEXT_string = "string";
char[] TEXT_number = "number";
char[] TEXT_boolean = "boolean";
char[] TEXT_Object = "Object";
char[] TEXT_String = "String";
char[] TEXT_Number = "Number";
char[] TEXT_Boolean = "Boolean";
char[] TEXT_Date = "Date";
char[] TEXT_Array = "Array";
char[] TEXT_RegExp = "RegExp";
char[] TEXT_arity = "arity";
char[] TEXT_arguments = "arguments";
char[] TEXT_callee = "callee";
char[] TEXT_caller = "caller";                  // extension
char[] TEXT_EvalError = "EvalError";
char[] TEXT_RangeError = "RangeError";
char[] TEXT_ReferenceError = "ReferenceError";
char[] TEXT_SyntaxError = "SyntaxError";
char[] TEXT_TypeError = "TypeError";
char[] TEXT_URIError = "URIError";
char[] TEXT_this = "this";
char[] TEXT_fromCharCode = "fromCharCode";
char[] TEXT_charAt = "charAt";
char[] TEXT_charCodeAt = "charCodeAt";
char[] TEXT_concat = "concat";
char[] TEXT_indexOf = "indexOf";
char[] TEXT_lastIndexOf = "lastIndexOf";
char[] TEXT_localeCompare = "localeCompare";
char[] TEXT_match = "match";
char[] TEXT_replace = "replace";
char[] TEXT_search = "search";
char[] TEXT_slice = "slice";
char[] TEXT_split = "split";
char[] TEXT_substr = "substr";
char[] TEXT_substring = "substring";
char[] TEXT_toLowerCase = "toLowerCase";
char[] TEXT_toLocaleLowerCase = "toLocaleLowerCase";
char[] TEXT_toUpperCase = "toUpperCase";
char[] TEXT_toLocaleUpperCase = "toLocaleUpperCase";
char[] TEXT_hasOwnProperty = "hasOwnProperty";
char[] TEXT_isPrototypeOf = "isPrototypeOf";
char[] TEXT_propertyIsEnumerable = "propertyIsEnumerable";
char[] TEXT_dollar1 = "$1";
char[] TEXT_dollar2 = "$2";
char[] TEXT_dollar3 = "$3";
char[] TEXT_dollar4 = "$4";
char[] TEXT_dollar5 = "$5";
char[] TEXT_dollar6 = "$6";
char[] TEXT_dollar7 = "$7";
char[] TEXT_dollar8 = "$8";
char[] TEXT_dollar9 = "$9";
char[] TEXT_index = "index";
char[] TEXT_compile = "compile";
char[] TEXT_test = "test";
char[] TEXT_exec = "exec";
char[] TEXT_MAX_VALUE = "MAX_VALUE";
char[] TEXT_MIN_VALUE = "MIN_VALUE";
char[] TEXT_NEGATIVE_INFINITY = "NEGATIVE_INFINITY";
char[] TEXT_POSITIVE_INFINITY = "POSITIVE_INFINITY";
char[] TEXT_dash = "-";
char[] TEXT_toFixed = "toFixed";
char[] TEXT_toExponential = "toExponential";
char[] TEXT_toPrecision = "toPrecision";
char[] TEXT_abs = "abs";
char[] TEXT_acos = "acos";
char[] TEXT_asin = "asin";
char[] TEXT_atan = "atan";
char[] TEXT_atan2 = "atan2";
char[] TEXT_ceil = "ceil";
char[] TEXT_cos = "cos";
char[] TEXT_exp = "exp";
char[] TEXT_floor = "floor";
char[] TEXT_log = "log";
char[] TEXT_max = "max";
char[] TEXT_min = "min";
char[] TEXT_pow = "pow";
char[] TEXT_random = "random";
char[] TEXT_round = "round";
char[] TEXT_sin = "sin";
char[] TEXT_sqrt = "sqrt";
char[] TEXT_tan = "tan";
char[] TEXT_E = "E";
char[] TEXT_LN10 = "LN10";
char[] TEXT_LN2 = "LN2";
char[] TEXT_LOG2E = "LOG2E";
char[] TEXT_LOG10E = "LOG10E";
char[] TEXT_PI = "PI";
char[] TEXT_SQRT1_2 = "SQRT1_2";
char[] TEXT_SQRT2 = "SQRT2";
char[] TEXT_parse = "parse";
char[] TEXT_UTC = "UTC";

char[] TEXT_getTime = "getTime";
char[] TEXT_getYear = "getYear";
char[] TEXT_getFullYear = "getFullYear";
char[] TEXT_getUTCFullYear = "getUTCFullYear";
char[] TEXT_getDate = "getDate";
char[] TEXT_getUTCDate = "getUTCDate";
char[] TEXT_getMonth = "getMonth";
char[] TEXT_getUTCMonth = "getUTCMonth";
char[] TEXT_getDay = "getDay";
char[] TEXT_getUTCDay = "getUTCDay";
char[] TEXT_getHours = "getHours";
char[] TEXT_getUTCHours = "getUTCHours";
char[] TEXT_getMinutes = "getMinutes";
char[] TEXT_getUTCMinutes = "getUTCMinutes";
char[] TEXT_getSeconds = "getSeconds";
char[] TEXT_getUTCSeconds = "getUTCSeconds";
char[] TEXT_getMilliseconds = "getMilliseconds";
char[] TEXT_getUTCMilliseconds = "getUTCMilliseconds";
char[] TEXT_getTimezoneOffset = "getTimezoneOffset";
char[] TEXT_getVarDate = "getVarDate";

char[] TEXT_setTime = "setTime";
char[] TEXT_setYear = "setYear";
char[] TEXT_setFullYear = "setFullYear";
char[] TEXT_setUTCFullYear = "setUTCFullYear";
char[] TEXT_setDate = "setDate";
char[] TEXT_setUTCDate = "setUTCDate";
char[] TEXT_setMonth = "setMonth";
char[] TEXT_setUTCMonth = "setUTCMonth";
char[] TEXT_setDay = "setDay";
char[] TEXT_setUTCDay = "setUTCDay";
char[] TEXT_setHours = "setHours";
char[] TEXT_setUTCHours = "setUTCHours";
char[] TEXT_setMinutes = "setMinutes";
char[] TEXT_setUTCMinutes = "setUTCMinutes";
char[] TEXT_setSeconds = "setSeconds";
char[] TEXT_setUTCSeconds = "setUTCSeconds";
char[] TEXT_setMilliseconds = "setMilliseconds";
char[] TEXT_setUTCMilliseconds = "setUTCMilliseconds";

char[] TEXT_toDateString = "toDateString";
char[] TEXT_toTimeString = "toTimeString";
char[] TEXT_toLocaleDateString = "toLocaleDateString";
char[] TEXT_toLocaleTimeString = "toLocaleTimeString";
char[] TEXT_toUTCString = "toUTCString";
char[] TEXT_toGMTString = "toGMTString";

char[] TEXT_comma =  ",";
char[] TEXT_join = "join";
char[] TEXT_pop = "pop";
char[] TEXT_push = "push";
char[] TEXT_reverse = "reverse";
char[] TEXT_shift = "shift";
char[] TEXT_sort = "sort";
char[] TEXT_splice = "splice";
char[] TEXT_unshift = "unshift";
char[] TEXT_apply = "apply";
char[] TEXT_call = "call";
char[] TEXT_function = "function";

char[] TEXT_eval = "eval";
char[] TEXT_parseInt = "parseInt";
char[] TEXT_parseFloat = "parseFloat";
char[] TEXT_escape = "escape";
char[] TEXT_unescape = "unescape";
char[] TEXT_isNaN = "isNaN";
char[] TEXT_isFinite = "isFinite";
char[] TEXT_decodeURI = "decodeURI";
char[] TEXT_decodeURIComponent = "decodeURIComponent";
char[] TEXT_encodeURI = "encodeURI";
char[] TEXT_encodeURIComponent = "encodeURIComponent";

char[] TEXT_print = "print";
char[] TEXT_println = "println";
char[] TEXT_readln = "readln";
char[] TEXT_getenv = "getenv";
char[] TEXT_assert = "assert";

char[] TEXT_Function = "Function";
char[] TEXT_Math = "Math";

char[] TEXT_0 = "0";
char[] TEXT_1 = "1";
char[] TEXT_2 = "2";
char[] TEXT_3 = "3";
char[] TEXT_4 = "4";
char[] TEXT_5 = "5";
char[] TEXT_6 = "6";
char[] TEXT_7 = "7";
char[] TEXT_8 = "8";
char[] TEXT_9 = "9";

char[] TEXT_anchor = "anchor";
char[] TEXT_big = "big";
char[] TEXT_blink = "blink";
char[] TEXT_bold = "bold";
char[] TEXT_fixed = "fixed";
char[] TEXT_fontcolor = "fontcolor";
char[] TEXT_fontsize = "fontsize";
char[] TEXT_italics = "italics";
char[] TEXT_link = "link";
char[] TEXT_small = "small";
char[] TEXT_strike = "strike";
char[] TEXT_sub = "sub";
char[] TEXT_sup = "sup";

char[] TEXT_Enumerator = "Enumerator";
char[] TEXT_item = "item";
char[] TEXT_atEnd = "atEnd";
char[] TEXT_moveNext = "moveNext";
char[] TEXT_moveFirst = "moveFirst";

char[] TEXT_VBArray = "VBArray";
char[] TEXT_dimensions = "dimensions";
char[] TEXT_getItem = "getItem";
char[] TEXT_lbound = "lbound";
char[] TEXT_toArray = "toArray";
char[] TEXT_ubound = "ubound";

char[] TEXT_ScriptEngine = "ScriptEngine";
char[] TEXT_ScriptEngineBuildVersion = "ScriptEngineBuildVersion";
char[] TEXT_ScriptEngineMajorVersion = "ScriptEngineMajorVersion";
char[] TEXT_ScriptEngineMinorVersion = "ScriptEngineMinorVersion";
char[] TEXT_DMDScript =  "DMDScript";

char[] TEXT_date = "date";
char[] TEXT_unknown = "unknown";
