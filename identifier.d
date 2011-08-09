
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

module dmdscript.identifier;

import dmdscript.script;
import dmdscript.value;

/* An Identifier is a special case of a Value - it is a V_STRING
 * and has the hash value computed and set.
 */

struct Identifier
{
    Value value;

    tchar[] toString()
    {
        return value.string;
    }

    int opEquals(Identifier *id)
    {
        return this is id || value.string == id.value.string;
    }

    static Identifier* build(tchar[] s)
    {   Identifier* id = new Identifier;
        id.value.putVstring(s);
        id.value.toHash();
        return id;
    }

    uint toHash()
    {
        return value.hash;
    }
}


