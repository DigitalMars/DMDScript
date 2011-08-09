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

module testscript;

import std.path;
import std.file;
import std.stdio;
import std.c.stdlib;
import std.gc;

import dmdscript.script;
import dmdscript.program;
import dmdscript.errmsgs;

enum
{
        EXITCODE_INIT_ERROR = 1,
        EXITCODE_INVALID_ARGS = 2,
        EXITCODE_RUNTIME_ERROR = 3,
}

version (Windows)
{
    pragma(lib, "dmdscript");
}



/**************************************************
        Usage:

            ds
                will run test.ds

            ds foo
                will run foo.ds

            ds foo.js
                will run foo.js

            ds foo1 foo2 foo.bar
                will run foo1.ds, foo2.ds, foo.bar

        The -iinc flag will prefix the source files with the contents of file inc.
        There can be multiple -i's. The include list is reset to empty any time
        a new -i is encountered that is not preceded by a -i.

            ds -iinc foo
                will prefix foo.ds with inc

            ds -iinc1 -iinc2 foo bar
                will prefix foo.ds with inc1+inc2, and will prefix bar.ds
                with inc1+inc2

            ds -iinc1 -iinc2 foo -iinc3 bar
                will prefix foo.ds with inc1+inc2, and will prefix bar.ds
                with inc3

            ds -iinc1 -iinc2 foo -i bar
                will prefix foo.ds with inc1+inc2, and will prefix bar.ds
                with nothing

 */

int main(char[][] args)
{
    uint errors = 0;
    char[][] includes;
    SrcFile[] srcfiles;
    int result;
    bool verbose;
    ErrInfo errinfo;

    fwritefln(stderr, dmdscript.script.banner());

    for (size_t i = 1; i < args.length; i++)
    {   char[] p = args[i];

        if (p[0] == '-')
        {
            switch (p[1])
            {
                case 'i':
                    if (p[2])
                        includes ~= p[2 .. length];
                    break;

                case 'v':
                    verbose = 1;
                    break;

                default:
                    writefln(errmsgtbl[ERR_BAD_SWITCH],p);
                    errors++;
                    break;
            }
        }
        else
        {
            srcfiles ~= new SrcFile(p, includes);
            includes = null;
        }
    }
    if (errors)
        return EXITCODE_INVALID_ARGS;

    if (srcfiles.length == 0)
    {
        srcfiles ~= new SrcFile("test", null);
    }

    fwritefln(stderr, "%d source files", srcfiles.length);

    // Read files, parse them, execute them
    foreach (SrcFile m; srcfiles)
    {
        if (verbose)
            writefln("read    %s:", m.srcfile);
        m.read();
        if (verbose)
            writefln("compile %s:", m.srcfile);
        m.compile();
        if (verbose)
            writefln("execute %s:", m.srcfile);
        m.execute();
    }

    return EXIT_SUCCESS;
}


class SrcFile
{
    char[] srcfile;
    char[][] includes;

    Program program;
    char[] buffer;

    this(char[] srcfilename, char[][] includes)
    {
        /* DMDScript source files default to a '.ds' extension
         */

        srcfile = std.path.defaultExt(srcfilename, "ds");
        this.includes = includes;
    }

    void read()
    {
        /* Read the source file, prepend the include files,
         * and put it all in buffer[]. Allocate an extra byte
         * to buffer[] and terminate it with a 0x1A.
         * (If the 0x1A isn't at the end, the lexer will put
         * one there, forcing an extra copy to be made of the
         * source text.)
         */

        //writef("read file '%s'\n",srcfile);

        // Read the includes[] files
        size_t i;
        void[] buf;
        ulong len;

        len = std.file.getSize(srcfile);
        foreach (char[] filename; includes)
        {
            len += std.file.getSize(filename);
        }
        len++;                          // leave room for sentinal

        assert(len < uint.max);

        // Prefix the includes[] files

        int sz = cast(int)len;
        buffer = new tchar[sz];

        foreach (char[] filename; includes)
        {
            buf = std.file.read(filename);
            buffer[i .. i + buf.length] = cast(char[])buf[];
            i += buf.length;
        }

        buf = std.file.read(srcfile);
        buffer[i .. i + buf.length] = cast(char[])buf[];
        i += buf.length;

        buffer[i] = 0x1A;               // ending sentinal
        i++;
        assert(i == len);
    }

    void compile()
    {
        /* Create a DMDScript program, and compile our text buffer.
         */

        program = new Program();
        program.compile(srcfile, buffer, null);
    }

    void execute()
    {
        /* Execute the resulting program.
         */

        program.execute(null);
    }
}
