// Written in the D programming language.

/**
 * Boilerplate:
 *      $(std_boilerplate.html)
 * Macros:
 *      WIKI = Phobos/StdOutbuffer
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 */
/*          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module dmdscript.outbuffer;

private
{
    import core.memory;
    import std.string;
    import core.stdc.stdio;
    import core.stdc.stdlib;
    import core.stdc.stdarg;
}

/*********************************************
 * OutBuffer provides a way to build up an array of bytes out
 * of raw data. It is useful for things like preparing an
 * array of bytes to write out to a file.
 * OutBuffer's byte order is the format native to the computer.
 * To control the byte order (endianness), use a class derived
 * from OutBuffer.
 */

class OutBuffer
{
    void[] data;
    uint offset;

    invariant()
    {
        //printf("this = %p, offset = %x, data.length = %u\n", this, offset, data.length);
        assert(offset <= data.length);
    }

    this()
    {
        //printf("in OutBuffer constructor\n");
    }

    /*********************************
     * Convert to array
     */

    void[] toBytes() { return data[0 .. offset]; }

    /***********************************
     * Preallocate nbytes more to the size of the internal buffer.
     *
     * This is a
     * speed optimization, a good guess at the maximum size of the resulting
     * buffer will improve performance by eliminating reallocations and copying.
     */


    void reserve(size_t nbytes)
        in
        {
            assert(offset + nbytes >= offset);
        }
        out
        {
            assert(offset + nbytes <= data.length);
        }
        body
        {
            //c.stdio.printf("OutBuffer.reserve: length = %d, offset = %d, nbytes = %d\n", data.length, offset, nbytes);
            if (data.length < offset + nbytes)
            {
                data.length = (offset + nbytes) * 2;
            }
        }

    /*************************************
     * Append data to the internal buffer.
     */

    void write(const(ubyte)[] bytes)
        {
            reserve(bytes.length);
            (cast(ubyte[])data)[offset .. offset + bytes.length] = bytes[0..$];
            offset += bytes.length;
        }

    void write(in wchar[] chars)
        {
        write(cast(ubyte[]) chars);
        }

    void write(const(dchar)[] chars)
        {
        write(cast(ubyte[]) chars);
        }

    void write(ubyte b)         /// ditto
        {
            reserve(ubyte.sizeof);
            *cast(ubyte *)&data[offset] = b;
            offset += ubyte.sizeof;
        }

    void write(byte b) { write(cast(ubyte)b); }         /// ditto
    void write(char c) { write(cast(ubyte)c); }         /// ditto
    void write(dchar c) { write(cast(uint)c); }         /// ditto

    void write(ushort w)                /// ditto
    {
        reserve(ushort.sizeof);
        *cast(ushort *)&data[offset] = w;
        offset += ushort.sizeof;
    }

    void write(short s) { write(cast(ushort)s); }               /// ditto

    void write(wchar c)         /// ditto
    {
        reserve(wchar.sizeof);
        *cast(wchar *)&data[offset] = c;
        offset += wchar.sizeof;
    }

    void write(uint w)          /// ditto
    {
        reserve(uint.sizeof);
        *cast(uint *)&data[offset] = w;
        offset += uint.sizeof;
    }

    void write(int i) { write(cast(uint)i); }           /// ditto

    void write(ulong l)         /// ditto
    {
        reserve(ulong.sizeof);
        *cast(ulong *)&data[offset] = l;
        offset += ulong.sizeof;
    }

    void write(long l) { write(cast(ulong)l); }         /// ditto

    void write(float f)         /// ditto
    {
        reserve(float.sizeof);
        *cast(float *)&data[offset] = f;
        offset += float.sizeof;
    }

    void write(double f)                /// ditto
    {
        reserve(double.sizeof);
        *cast(double *)&data[offset] = f;
        offset += double.sizeof;
    }

    void write(real f)          /// ditto
    {
        reserve(real.sizeof);
        *cast(real *)&data[offset] = f;
        offset += real.sizeof;
    }

    void write(in char[] s)             /// ditto
    {
        write(cast(ubyte[])s);
    }
    // void write(immutable(char)[] s)          /// ditto
    // {
    //     write(cast(ubyte[])s);
    // }

    void write(OutBuffer buf)           /// ditto
    {
        write(cast(ubyte[])buf.toBytes());
    }

    /****************************************
     * Append nbytes of 0 to the internal buffer.
     */

    void fill0(uint nbytes)
    {
        reserve(nbytes);
        auto range = cast(ubyte[])data[offset .. offset + nbytes];
        range[] = 0;
        offset += nbytes;
    }

    /**********************************
     * 0-fill to align on power of 2 boundary.
     */

    void alignSize(uint alignsize)
    in
    {
        assert(alignsize && (alignsize & (alignsize - 1)) == 0);
    }
    out
    {
        assert((offset & (alignsize - 1)) == 0);
    }
    body
    {   uint nbytes;

        nbytes = offset & (alignsize - 1);
        if (nbytes)
            fill0(alignsize - nbytes);
    }

    /****************************************
     * Optimize common special case alignSize(2)
     */

    void align2()
    {
        if (offset & 1)
            write(cast(byte)0);
    }

    /****************************************
     * Optimize common special case alignSize(4)
     */

    void align4()
    {
        if (offset & 3)
        {   uint nbytes = (4 - offset) & 3;
            fill0(nbytes);
        }
    }

    /**************************************
     * Convert internal buffer to array of chars.
     */

    override string toString()
    {
        //printf("OutBuffer.toString()\n");
        return cast(string) data[0 .. offset].idup;
    }


    /*****************************************
     * At offset index into buffer, create nbytes of space by shifting upwards
     * all data past index.
     */

    void spread(size_t index, size_t nbytes)
        in
        {
            assert(index <= offset);
        }
        body
        {
            reserve(nbytes);

            // This is an overlapping copy - should use memmove()
            for (uint i = offset; i > index; )
            {
                --i;
                *cast(ubyte*)&data[i + nbytes] = *cast(ubyte*)&data[i];
            }
            offset += nbytes;
        }
}

unittest
{
    //printf("Starting OutBuffer test\n");

    OutBuffer buf = new OutBuffer();

    //printf("buf = %p\n", buf);
    //printf("buf.offset = %x\n", buf.offset);
    assert(buf.offset == 0);
    buf.write("hello"[]);
    buf.write(cast(byte)0x20);
    buf.write("world"[]);
    //printf("buf = '%.*s'\n", buf.toString());
    assert(cmp(buf.toString(), "hello world") == 0);
}
