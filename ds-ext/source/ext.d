import dmdscript.program;
import dmdscript.script;
import dmdscript.extending;

import std.stdio;
import std.typecons;
import std.stdio;
import std.file;

int func(int a,int b){ return a*b;  }
                   
struct A{
    int magic;
    this(int m){ magic = m; }
    void f(string a){ 
        writeln(magic,":",a);
    }    
}
                         

void main(){
    Program p = new Program;
    extendGlobal!func(p,"mul");
    auto src  = cast(string)std.file.read("ext.ds");
    void function(string) fn = &A.f;
    Wrap!(A,"A").methods!(A.f)();
    
    p.compile("TestExtending",src,null);
    p.execute(null);    
}
