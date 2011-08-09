
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


module dmdscript.ddate;

import std.math;
import std.date;

import dmdscript.script;
import dmdscript.dobject;
import dmdscript.value;
import dmdscript.threadcontext;
import dmdscript.dfunction;
import dmdscript.dnative;
import dmdscript.property;
import dmdscript.text;
import dmdscript.errmsgs;

version = DATETOSTRING;                 // use DateToString

enum TIMEFORMAT
{
        String,
        DateString,
        TimeString,
        LocaleString,
        LocaleDateString,
        LocaleTimeString,
        UTCString,
}

d_time parseDateString(CallContext *cc, d_string s)
{
    return std.date.parse(s);
}

d_string dateToString(CallContext *cc, d_time t, TIMEFORMAT tf)
{   tchar[] p;

    if (t == d_time_nan)
        p = "Invalid Date";
    else
    {
        switch (tf)
        {
            case TIMEFORMAT.String:
                t = std.date.LocalTimetoUTC(t);
                p = std.date.toString(t);
                break;

            case TIMEFORMAT.DateString:
                t = std.date.LocalTimetoUTC(t);
                p = std.date.toDateString(t);
                break;

            case TIMEFORMAT.TimeString:
                t = std.date.LocalTimetoUTC(t);
                p = std.date.toTimeString(t);
                break;

            case TIMEFORMAT.LocaleString:
                //p = std.date.toLocaleString(t);
                p = std.date.toString(t);
                break;

            case TIMEFORMAT.LocaleDateString:
                //p = std.date.toLocaleDateString(t);
                p = std.date.toDateString(t);
                break;

            case TIMEFORMAT.LocaleTimeString:
                //p = std.date.toLocaleTimeString(t);
                p = std.date.toTimeString(t);
                break;

            case TIMEFORMAT.UTCString:
                p = std.date.toUTCString(t);
                //p = std.date.toString(t);
                break;

            default:
                assert(0);
        }
    }
    return p;
}


/* ===================== Ddate.constructor functions ==================== */

void* Ddate_parse(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{

    // ECMA 15.9.4.2
    d_string s;
    d_time n;

    if (arglist.length == 0)
        n = d_time_nan;
    else
    {
        s = arglist[0].toString();
        n = parseDateString(cc, s);
    }

    ret.putVtime(n);
    return null;
}

void* Ddate_UTC(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.4.3 - 15.9.4.10

    d_time n;

    d_time year;
    d_time month = 0;
    d_time date = 0;
    d_time hours = 0;
    d_time minutes = 0;
    d_time seconds = 0;
    d_time ms = 0;

    d_time day;
    d_time time = 0;

    switch (arglist.length)
    {
        default:
        case 7:
            ms = arglist[6].toDtime();
        case 6:
            seconds = arglist[5].toDtime();
        case 5:
            minutes = arglist[4].toDtime();
        case 4:
            hours = arglist[3].toDtime();
            time = std.date.MakeTime(hours, minutes, seconds, ms);
        case 3:
            date = arglist[2].toDtime();
        case 2:
            month = arglist[1].toDtime();
        case 1:
            year = arglist[0].toDtime();

            if (year != d_time_nan && year >= 0 && year <= 99)
                year += 1900;
            day = std.date.MakeDay(year, month, date);
            n = std.date.TimeClip(std.date.MakeDate(day,time));
            break;

        case 0:
            n = std.date.getUTCtime();
            break;
    }
    ret.putVtime(n);
    return null;
}

/* ===================== Ddate_constructor ==================== */

class Ddate_constructor : Dfunction
{
    this(ThreadContext *tc)
    {
        super(7, tc.Dfunction_prototype);
        name = "Date";

        static NativeFunctionData nfd[] =
        [
            { &TEXT_parse, &Ddate_parse, 1 },
            { &TEXT_UTC, &Ddate_UTC, 7 },
        ];

        DnativeFunction.init(this, nfd, 0);
    }

    void *Construct(CallContext *cc, Value *ret, Value[] arglist)
    {
        // ECMA 15.9.3
        Dobject o;
        d_time n;

        d_time year;
        d_time month;
        d_time date = 0;
        d_time hours = 0;
        d_time minutes = 0;
        d_time seconds = 0;
        d_time ms = 0;

        d_time day;
        d_time time = 0;

        //writefln("Ddate_constructor.Construct()");
        switch (arglist.length)
        {
            default:
            case 7:
                ms = arglist[6].toDtime();
            case 6:
                seconds = arglist[5].toDtime();
            case 5:
                minutes = arglist[4].toDtime();
            case 4:
                hours = arglist[3].toDtime();
                time = std.date.MakeTime(hours, minutes, seconds, ms);
            case 3:
                date = arglist[2].toDtime();
            case 2:
                month = arglist[1].toDtime();
                year = arglist[0].toDtime();

                if (year != d_time_nan && year >= 0 && year <= 99)
                    year += 1900;
                day = std.date.MakeDay(year, month, date);
                n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(day, time)));
                break;

            case 1:
                arglist[0].toPrimitive(ret, null);
                if (ret.getType() == TypeString)
                {
                    n = parseDateString(cc, ret.string);
                }
                else
                {
                    n = ret.toDtime();
                    n = std.date.TimeClip(n);
                }
                break;

            case 0:
                n = std.date.getUTCtime();
                break;
        }
        //writefln("\tn = %s", n);
        o = new Ddate(n);
        ret.putVobject(o);
        return null;
    }

    void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
    {
        // ECMA 15.9.2
        // return string as if (new Date()).toString()
        d_string s;
        d_time t;

        version (DATETOSTRING)
        {
            t = std.date.getUTCtime();
            t = std.date.UTCtoLocalTime(t);
            s = dateToString(cc, t, TIMEFORMAT.String);
        }
        else
        {
            t = std.date.time();
            s = std.date.toString(t);
        }
        ret.putVstring(s);
        return null;
    }
}


/* ===================== Ddate.prototype functions =============== */

void *checkdate(Value* ret, tchar[] name, Dobject othis)
{
    ret.putVundefined();
    ErrInfo errinfo;
    return Dobject.RuntimeError(&errinfo, errmsgtbl[ERR_FUNCTION_WANTS_DATE],
            name, othis.classname);
}

int getThisTime(Value* ret, Dobject othis, out d_time n)
{   d_number x;

    n = cast(d_time)othis.value.number;
    ret.putVtime(n);
    return (n == d_time_nan) ? 1 : 0;
}

int getThisLocalTime(Value* ret, Dobject othis, out d_time n)
{   int isn = 1;

    n = cast(d_time)othis.value.number;
    if (n != d_time_nan)
    {   isn = 0;
        n = std.date.UTCtoLocalTime(n);
    }
    ret.putVtime(n);
    return isn;
}

void* Ddate_prototype_toString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.2
    d_time n;
    d_string s;

    //writefln("Ddate_prototype_toString()");
    if (!othis.isDdate())
        return checkdate(ret, TEXT_toString, othis);

  version (DATETOSTRING)
  {
    getThisLocalTime(ret, othis, n);
    s = dateToString(cc, n, TIMEFORMAT.String);
  }
  else
  {
    getThisTime(ret, othis, n);
    s = std.date.ToString(n);
  }
    ret.putVstring(s);
    return null;
}

void* Ddate_prototype_toDateString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.3
    d_time n;
    d_string s;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_toDateString, othis);

    version (DATETOSTRING)
    {
        getThisLocalTime(ret, othis, n);
        s = dateToString(cc, n, TIMEFORMAT.DateString);
    }
    else
    {
        getThisTime(ret, othis, n);
        s = std.date.ToDateString(n);
    }
    ret.putVstring(s);
    return null;
}

void* Ddate_prototype_toTimeString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.4
    d_time n;
    d_string s;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_toTimeString, othis);

    version (DATETOSTRING)
    {
        getThisLocalTime(ret, othis, n);
        s = dateToString(cc, n, TIMEFORMAT.TimeString);
    }
    else
    {
        getThisTime(ret, othis, n);
        s = std.date.ToTimeString(n);
    }
    //s = std.date.ToTimeString(n);
    ret.putVstring(s);
    return null;
}

void* Ddate_prototype_valueOf(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.3
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_valueOf, othis);
    getThisTime(ret, othis, n);
    return null;
}

void* Ddate_prototype_getTime(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.4
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getTime, othis);
    getThisTime(ret, othis, n);
    return null;
}

void* Ddate_prototype_getYear(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.5
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getYear, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.YearFromTime(n);
        if (n != d_time_nan)
        {
            n -= 1900;
            version (all) // emulate jscript bug
            {
                if (n < 0 || n >= 100)
                    n += 1900;
            }
        }
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getFullYear(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.6
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getFullYear, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.YearFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCFullYear(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.7
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCFullYear, othis);
    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.YearFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getMonth(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.8
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getMonth, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.MonthFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCMonth(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.9
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCMonth, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.MonthFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getDate(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.10
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getDate, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        //printf("LocalTime = %.16g\n", n);
        //printf("DaylightSavingTA(n) = %d\n", std.date.DaylightSavingTA(n));
        n = std.date.DateFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCDate(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.11
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCDate, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.DateFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getDay(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.12
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getDay, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.WeekDay(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCDay(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.13
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCDay, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.WeekDay(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getHours(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.14
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getHours, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.HourFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCHours(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.15
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCHours, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.HourFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getMinutes(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.16
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getMinutes, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.MinFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCMinutes(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.17
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCMinutes, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.MinFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getSeconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.18
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getSeconds, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.SecFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCSeconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.19
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCSeconds, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.SecFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getMilliseconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.20
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getMilliseconds, othis);

    if (getThisLocalTime(ret, othis, n) == 0)
    {
        n = std.date.msFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getUTCMilliseconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.21
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getUTCMilliseconds, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = std.date.msFromTime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_getTimezoneOffset(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.22
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_getTimezoneOffset, othis);

    if (getThisTime(ret, othis, n) == 0)
    {
        n = (n - std.date.UTCtoLocalTime(n)) / (60 * 1000);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setTime(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.23
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setTime, othis);

    if (!arglist.length)
        n = d_time_nan;
    else
        n = arglist[0].toDtime();
    n = std.date.TimeClip(n);
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

void* Ddate_prototype_setMilliseconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.24

    d_time ms;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setMilliseconds, othis);

    if (getThisLocalTime(ret, othis, t) == 0)
    {
        if (!arglist.length)
            ms = d_time_nan;
        else
            ms = arglist[0].toDtime();
        time = std.date.MakeTime(std.date.HourFromTime(t), std.date.MinFromTime(t), std.date.SecFromTime(t), ms);
        n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(std.date.Day(t),time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setUTCMilliseconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.25
    d_time ms;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCMilliseconds, othis);

    if (getThisTime(ret, othis, t) == 0)
    {
        if (!arglist.length)
            ms = d_time_nan;
        else
            ms = arglist[0].toDtime();
        time = std.date.MakeTime(std.date.HourFromTime(t), std.date.MinFromTime(t), std.date.SecFromTime(t), ms);
        n = std.date.TimeClip(std.date.MakeDate(std.date.Day(t),time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setSeconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.26
    d_time ms;
    d_time seconds;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setSeconds, othis);

    if (getThisLocalTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {
            default:
            case 2:
                ms = arglist[1].toDtime();
                seconds = arglist[0].toDtime();
                break;

            case 1:
                ms = std.date.msFromTime(t);
                seconds = arglist[0].toDtime();
                break;

            case 0:
                ms = std.date.msFromTime(t);
                seconds = d_time_nan;
                break;
        }
        time = std.date.MakeTime(std.date.HourFromTime(t), std.date.MinFromTime(t), seconds, ms);
        n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(std.date.Day(t),time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setUTCSeconds(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.27
    d_time ms;
    d_time seconds;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCSeconds, othis);

    if (getThisTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {
            default:
            case 2:
                ms = arglist[1].toDtime();
                seconds = arglist[0].toDtime();
                break;

            case 1:
                ms = std.date.msFromTime(t);
                seconds = arglist[0].toDtime();
                break;

            case 0:
                ms = std.date.msFromTime(t);
                seconds = d_time_nan;
                break;
        }
        time = std.date.MakeTime(std.date.HourFromTime(t), std.date.MinFromTime(t), seconds, ms);
        n = std.date.TimeClip(std.date.MakeDate(std.date.Day(t),time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setMinutes(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.28
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setMinutes, othis);

    if (getThisLocalTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {
            default:
            case 3:
                ms      = arglist[2].toDtime();
                seconds = arglist[1].toDtime();
                minutes = arglist[0].toDtime();
                break;

            case 2:
                ms      = std.date.msFromTime(t);
                seconds = arglist[1].toDtime();
                minutes = arglist[0].toDtime();
                break;

            case 1:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = arglist[0].toDtime();
                break;

            case 0:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = d_time_nan;
                break;
        }
        time = std.date.MakeTime(std.date.HourFromTime(t), minutes, seconds, ms);
        n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(std.date.Day(t),time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setUTCMinutes(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.29
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCMinutes, othis);

    if (getThisTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {
            default:
            case 3:
                ms      = arglist[2].toDtime();
                seconds = arglist[1].toDtime();
                minutes = arglist[0].toDtime();
                break;

            case 2:
                ms      = std.date.msFromTime(t);
                seconds = arglist[1].toDtime();
                minutes = arglist[0].toDtime();
                break;

            case 1:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = arglist[0].toDtime();
                break;

            case 0:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = d_time_nan;
                break;
        }
        time = std.date.MakeTime(std.date.HourFromTime(t), minutes, seconds, ms);
        n = std.date.TimeClip(std.date.MakeDate(std.date.Day(t),time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setHours(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.30
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time hours;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setHours, othis);

    if (getThisLocalTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {
            default:
            case 4:
                ms      = arglist[3].toDtime();
                seconds = arglist[2].toDtime();
                minutes = arglist[1].toDtime();
                hours   = arglist[0].toDtime();
                break;

            case 3:
                ms      = std.date.msFromTime(t);
                seconds = arglist[2].toDtime();
                minutes = arglist[1].toDtime();
                hours   = arglist[0].toDtime();
                break;

            case 2:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = arglist[1].toDtime();
                hours   = arglist[0].toDtime();
                break;

            case 1:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = std.date.MinFromTime(t);
                hours   = arglist[0].toDtime();
                break;

            case 0:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = std.date.MinFromTime(t);
                hours   = d_time_nan;
                break;
        }
        time = std.date.MakeTime(hours, minutes, seconds, ms);
        n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(std.date.Day(t),time)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setUTCHours(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.31
    d_time ms;
    d_time seconds;
    d_time minutes;
    d_time hours;
    d_time t;
    d_time time;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCHours, othis);

    if (getThisTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {
            default:
            case 4:
                ms      = arglist[3].toDtime();
                seconds = arglist[2].toDtime();
                minutes = arglist[1].toDtime();
                hours   = arglist[0].toDtime();
                break;

            case 3:
                ms      = std.date.msFromTime(t);
                seconds = arglist[2].toDtime();
                minutes = arglist[1].toDtime();
                hours   = arglist[0].toDtime();
                break;

            case 2:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = arglist[1].toDtime();
                hours   = arglist[0].toDtime();
                break;

            case 1:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = std.date.MinFromTime(t);
                hours   = arglist[0].toDtime();
                break;

            case 0:
                ms      = std.date.msFromTime(t);
                seconds = std.date.SecFromTime(t);
                minutes = std.date.MinFromTime(t);
                hours   = d_time_nan;
                break;
        }
        time = std.date.MakeTime(hours, minutes, seconds, ms);
        n = std.date.TimeClip(std.date.MakeDate(std.date.Day(t),time));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setDate(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.32
    d_time date;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setDate, othis);

    if (getThisLocalTime(ret, othis, t) == 0)
    {
        if (!arglist.length)
            date = d_time_nan;
        else
            date = arglist[0].toDtime();
        day = std.date.MakeDay(std.date.YearFromTime(t), std.date.MonthFromTime(t), date);
        n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(day, std.date.TimeWithinDay(t))));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setUTCDate(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.33
    d_time date;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCDate, othis);

    if (getThisTime(ret, othis, t) == 0)
    {
        if (!arglist.length)
            date = d_time_nan;
        else
            date = arglist[0].toDtime();
        day = std.date.MakeDay(std.date.YearFromTime(t), std.date.MonthFromTime(t), date);
        n = std.date.TimeClip(std.date.MakeDate(day, std.date.TimeWithinDay(t)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setMonth(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.34
    d_time date;
    d_time month;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setMonth, othis);

    if (getThisLocalTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {   default:
            case 2:
                month = arglist[0].toDtime();
                date  = arglist[1].toDtime();
                break;

            case 1:
                month = arglist[0].toDtime();
                date  = std.date.DateFromTime(t);
                break;

            case 0:
                month = d_time_nan;
                date  = std.date.DateFromTime(t);
                break;
        }
        day = std.date.MakeDay(std.date.YearFromTime(t), month, date);
        n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(day, std.date.TimeWithinDay(t))));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setUTCMonth(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.35
    d_time date;
    d_time month;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCMonth, othis);

    if (getThisTime(ret, othis, t) == 0)
    {
        switch (arglist.length)
        {   default:
            case 2:
                month = arglist[0].toDtime();
                date  = arglist[1].toDtime();
                break;

            case 1:
                month = arglist[0].toDtime();
                date  = std.date.DateFromTime(t);
                break;

            case 0:
                month = d_time_nan;
                date  = std.date.DateFromTime(t);
                break;
        }
        day = std.date.MakeDay(std.date.YearFromTime(t), month, date);
        n = std.date.TimeClip(std.date.MakeDate(day, std.date.TimeWithinDay(t)));
        othis.value.putVtime(n);
        ret.putVtime(n);
    }
    return null;
}

void* Ddate_prototype_setFullYear(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.36
    d_time date;
    d_time month;
    d_time year;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setFullYear, othis);

    if (getThisLocalTime(ret, othis, t))
        t = 0;

    switch (arglist.length)
    {   default:
        case 3:
            date  = arglist[2].toDtime();
            month = arglist[1].toDtime();
            year  = arglist[0].toDtime();
            break;

        case 2:
            date  = std.date.DateFromTime(t);
            month = arglist[1].toDtime();
            year  = arglist[0].toDtime();
            break;

        case 1:
            date  = std.date.DateFromTime(t);
            month = std.date.MonthFromTime(t);
            year  = arglist[0].toDtime();
            break;

        case 0:
            date  = std.date.DateFromTime(t);
            month = std.date.MonthFromTime(t);
            year  = d_time_nan;
            break;
    }
    day = std.date.MakeDay(year, month, date);
    n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(day, std.date.TimeWithinDay(t))));
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

void* Ddate_prototype_setUTCFullYear(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.37
    d_time date;
    d_time month;
    d_time year;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setUTCFullYear, othis);

    getThisTime(ret, othis, t);
    if (t == d_time_nan)
        t = 0;
    switch (arglist.length)
    {   default:
        case 3:
            month = arglist[2].toDtime();
            date  = arglist[1].toDtime();
            year  = arglist[0].toDtime();
            break;

        case 2:
            month = std.date.MonthFromTime(t);
            date  = arglist[1].toDtime();
            year  = arglist[0].toDtime();
            break;

        case 1:
            month = std.date.MonthFromTime(t);
            date  = std.date.DateFromTime(t);
            year  = arglist[0].toDtime();
            break;

        case 0:
            month = std.date.MonthFromTime(t);
            date  = std.date.DateFromTime(t);
            year  = d_time_nan;
            break;
    }
    day = std.date.MakeDay(year, month, date);
    n = std.date.TimeClip(std.date.MakeDate(day, std.date.TimeWithinDay(t)));
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

void* Ddate_prototype_setYear(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.38
    d_time date;
    d_time month;
    d_time year;
    d_time t;
    d_time day;
    d_time n;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_setYear, othis);

    if (getThisLocalTime(ret, othis, t))
        t = 0;
    switch (arglist.length)
    {   default:
        case 1:
            month = std.date.MonthFromTime(t);
            date  = std.date.DateFromTime(t);
            year  = arglist[0].toDtime();
            if (0 <= year && year <= 99)
                year += 1900;
            day = std.date.MakeDay(year, month, date);
            n = std.date.TimeClip(std.date.LocalTimetoUTC(std.date.MakeDate(day, std.date.TimeWithinDay(t))));
            break;

        case 0:
            n = d_time_nan;
            break;
    }
    othis.value.putVtime(n);
    ret.putVtime(n);
    return null;
}

void* Ddate_prototype_toLocaleString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.39
    d_string s;
    d_time t;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_toLocaleString, othis);

    if (getThisLocalTime(ret, othis, t))
        t = 0;

    s = dateToString(cc, t, TIMEFORMAT.LocaleString);
    ret.putVstring(s);
    return null;
}

void* Ddate_prototype_toLocaleDateString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.6
    d_string s;
    d_time t;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_toLocaleDateString, othis);

    if (getThisLocalTime(ret, othis, t))
        t = 0;

    s = dateToString(cc, t, TIMEFORMAT.LocaleDateString);
    ret.putVstring(s);
    return null;
}

void* Ddate_prototype_toLocaleTimeString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.7
    d_string s;
    d_time t;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_toLocaleTimeString, othis);

    if (getThisLocalTime(ret, othis, t))
        t = 0;
    s = dateToString(cc, t, TIMEFORMAT.LocaleTimeString);
    ret.putVstring(s);
    return null;
}

void* Ddate_prototype_toUTCString(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist)
{
    // ECMA 15.9.5.40
    d_string s;
    d_time t;

    if (!othis.isDdate())
        return checkdate(ret, TEXT_toUTCString, othis);

    if (getThisTime(ret, othis, t))
        t = 0;
    s = dateToString(cc, t, TIMEFORMAT.UTCString);
    ret.putVstring(s);
    return null;
}

/* ===================== Ddate_prototype ==================== */

class Ddate_prototype : Ddate
{
    this(ThreadContext *tc)
    {
        super(tc.Dobject_prototype);

        Dobject f = tc.Dfunction_prototype;

        Put(TEXT_constructor, tc.Ddate_constructor, DontEnum);

        static NativeFunctionData nfd[] =
        [
            {   &TEXT_toString, &Ddate_prototype_toString, 0 },
            {   &TEXT_toDateString, &Ddate_prototype_toDateString, 0 },
            {   &TEXT_toTimeString, &Ddate_prototype_toTimeString, 0 },
            {   &TEXT_valueOf, &Ddate_prototype_valueOf, 0 },
            {   &TEXT_getTime, &Ddate_prototype_getTime, 0 },
            //{ &TEXT_getVarDate, &Ddate_prototype_getVarDate, 0 },
            {   &TEXT_getYear, &Ddate_prototype_getYear, 0 },
            {   &TEXT_getFullYear, &Ddate_prototype_getFullYear, 0 },
            {   &TEXT_getUTCFullYear, &Ddate_prototype_getUTCFullYear, 0 },
            {   &TEXT_getMonth, &Ddate_prototype_getMonth, 0 },
            {   &TEXT_getUTCMonth, &Ddate_prototype_getUTCMonth, 0 },
            {   &TEXT_getDate, &Ddate_prototype_getDate, 0 },
            {   &TEXT_getUTCDate, &Ddate_prototype_getUTCDate, 0 },
            {   &TEXT_getDay, &Ddate_prototype_getDay, 0 },
            {   &TEXT_getUTCDay, &Ddate_prototype_getUTCDay, 0 },
            {   &TEXT_getHours, &Ddate_prototype_getHours, 0 },
            {   &TEXT_getUTCHours, &Ddate_prototype_getUTCHours, 0 },
            {   &TEXT_getMinutes, &Ddate_prototype_getMinutes, 0 },
            {   &TEXT_getUTCMinutes, &Ddate_prototype_getUTCMinutes, 0 },
            {   &TEXT_getSeconds, &Ddate_prototype_getSeconds, 0 },
            {   &TEXT_getUTCSeconds, &Ddate_prototype_getUTCSeconds, 0 },
            {   &TEXT_getMilliseconds, &Ddate_prototype_getMilliseconds, 0 },
            {   &TEXT_getUTCMilliseconds, &Ddate_prototype_getUTCMilliseconds, 0 },
            {   &TEXT_getTimezoneOffset, &Ddate_prototype_getTimezoneOffset, 0 },
            {   &TEXT_setTime, &Ddate_prototype_setTime, 1 },
            {   &TEXT_setMilliseconds, &Ddate_prototype_setMilliseconds, 1 },
            {   &TEXT_setUTCMilliseconds, &Ddate_prototype_setUTCMilliseconds, 1 },
            {   &TEXT_setSeconds, &Ddate_prototype_setSeconds, 2 },
            {   &TEXT_setUTCSeconds, &Ddate_prototype_setUTCSeconds, 2 },
            {   &TEXT_setMinutes, &Ddate_prototype_setMinutes, 3 },
            {   &TEXT_setUTCMinutes, &Ddate_prototype_setUTCMinutes, 3 },
            {   &TEXT_setHours, &Ddate_prototype_setHours, 4 },
            {   &TEXT_setUTCHours, &Ddate_prototype_setUTCHours, 4 },
            {   &TEXT_setDate, &Ddate_prototype_setDate, 1 },
            {   &TEXT_setUTCDate, &Ddate_prototype_setUTCDate, 1 },
            {   &TEXT_setMonth, &Ddate_prototype_setMonth, 2 },
            {   &TEXT_setUTCMonth, &Ddate_prototype_setUTCMonth, 2 },
            {   &TEXT_setFullYear, &Ddate_prototype_setFullYear, 3 },
            {   &TEXT_setUTCFullYear, &Ddate_prototype_setUTCFullYear, 3 },
            {   &TEXT_setYear, &Ddate_prototype_setYear, 1 },
            {   &TEXT_toLocaleString, &Ddate_prototype_toLocaleString, 0 },
            {   &TEXT_toLocaleDateString, &Ddate_prototype_toLocaleDateString, 0 },
            {   &TEXT_toLocaleTimeString, &Ddate_prototype_toLocaleTimeString, 0 },
            {   &TEXT_toUTCString, &Ddate_prototype_toUTCString, 0 },

            // Map toGMTString() onto toUTCString(), per ECMA 15.9.5.41
            {   &TEXT_toGMTString, &Ddate_prototype_toUTCString, 0 },
        ];

        DnativeFunction.init(this, nfd, 0);
        assert(proptable.get("toString", Value.calcHash("toString")));
    }
}


/* ===================== Ddate ==================== */

class Ddate : Dobject
{
    this(d_number n)
    {
        super(Ddate.getPrototype());
        classname = TEXT_Date;
        value.putVnumber(n);
    }

    this(d_time n)
    {
        super(Ddate.getPrototype());
        classname = TEXT_Date;
        value.putVtime(n);
    }

    this(Dobject prototype)
    {
        super(prototype);
        classname = TEXT_Date;
        value.putVnumber(d_number.nan);
    }

    static void init(ThreadContext *tc)
    {
        tc.Ddate_constructor = new Ddate_constructor(tc);
        tc.Ddate_prototype = new Ddate_prototype(tc);

        tc.Ddate_constructor.Put(TEXT_prototype, tc.Ddate_prototype,
                DontEnum | DontDelete | ReadOnly);

        assert(tc.Ddate_prototype.proptable.table.length != 0);
    }

    static Dfunction getConstructor()
    {
        ThreadContext *tc = ThreadContext.getThreadContext();
        assert(tc);
        return tc.Ddate_constructor;
    }

    static Dobject getPrototype()
    {
        ThreadContext *tc = ThreadContext.getThreadContext();
        assert(tc);
        return tc.Ddate_prototype;
    }
}


