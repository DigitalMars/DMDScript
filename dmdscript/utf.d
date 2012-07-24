/*
 * Excert from Phobos standart library for D2, this one uses immutable destanation string
*/
module dmdscript.utf;
public import std.utf;

///encodes dchar ch and appends it to array s
void encode(ref immutable(char)[] s, dchar c)
{
    immutable(char)[] r = s;

    if(c <= 0x7F)
    {
        assert(isValidDchar(c));
        r ~= cast(char)c;
    }
    else
    {
        char[4] buf;
        uint L;

        if(c <= 0x7FF)
        {
            assert(isValidDchar(c));
            buf[0] = cast(char)(0xC0 | (c >> 6));
            buf[1] = cast(char)(0x80 | (c & 0x3F));
            L = 2;
        }
        else if(c <= 0xFFFF)
        {
            if(0xD800 <= c && c <= 0xDFFF)
                throw new UtfException(
                    "encoding a surrogate code point in UTF-8", c);
            assert(isValidDchar(c));
            buf[0] = cast(char)(0xE0 | (c >> 12));
            buf[1] = cast(char)(0x80 | ((c >> 6) & 0x3F));
            buf[2] = cast(char)(0x80 | (c & 0x3F));
            L = 3;
        }
        else if(c <= 0x10FFFF)
        {
            assert(isValidDchar(c));
            buf[0] = cast(char)(0xF0 | (c >> 18));
            buf[1] = cast(char)(0x80 | ((c >> 12) & 0x3F));
            buf[2] = cast(char)(0x80 | ((c >> 6) & 0x3F));
            buf[3] = cast(char)(0x80 | (c & 0x3F));
            L = 4;
        }
        else
        {
            assert(!isValidDchar(c));
            throw new UtfException(
                "encoding an invalid code point in UTF-8", c);
        }
        r ~= buf[0 .. L];
    }
    s = r;
}