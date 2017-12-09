/* Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 *
 * extending.d - experimental facility for ease of extending DMDScript 
 *
 * written by Dmitry Olshansky 2010
 * 
 * DMDScript is implemented in the D Programming Language,
 * http://www.digitalmars.com/d/
 *
 * For a C++ implementation of DMDScript, including COM support, see
 * http://www.digitalmars.com/dscript/cppscript.html
 */
module dmdscript.extending;

import dmdscript.script;
import dmdscript.value;
import dmdscript.dobject;
import dmdscript.dfunction;
import dmdscript.dnative;
import dmdscript.program;
import dmdscript.property;
import dmdscript.threadcontext;

import std.typecons;
import std.traits;
import std.typetuple;
import std.file;


T convert(T)(Value* v, CallContext* cc){
	static if(is(T == int)){
		return v.toInt32(cc);
    }else static if(isSomeString!T ){
        return v.toString(cc);   
	}else{
		assert(0);	
	}
}

void convertPut(T)(ref T what,Value* v){
    static if(isIntegral!T || isFloatingPoint!T){
        v.putVnumber(what);
    }
}

//experimental stuff, eventually will be moved to the main library
void extendGlobal(alias fn)(Program pg, string name)
if(isCallable!fn) {
    alias ParameterTypeTuple!fn Args;
    alias ReturnType!fn R;
    alias staticMap!(Unqual,Args) Uargs;
    static void* embedded(Dobject pthis, CallContext* cc,
                          Dobject othis, Value* ret, Value[] arglist){
       
        Tuple!(Uargs) tup = convertAll!(Uargs)(arglist, cc);
        if(arglist.length < tup.length){
            auto len = arglist.length;
            arglist.length = tup.length;
            arglist[len .. $] = vundefined;
        }
        arglist = arglist[0..tup.length];
        
        static if(is(R == void)){
            fn(tup.expand);
        }else{
            R r = fn(tup.expand);
            convertPut(r,ret);
        }
        return null;
    }

    NativeFunctionData[] nfd = [
        {
            name,
            &embedded,
            Args.length
        }
    ];

    DnativeFunction.initialize(pg.callcontext.global,pg.callcontext,nfd,DontEnum);
}
                                    
void fitArray(T...)(ref Value[] arglist){
    enum staticLen = T.length;
    if(arglist.length < staticLen){
        auto len = arglist.length;
        arglist.length = staticLen;
        arglist[len .. $] = vundefined;
    }
    arglist = arglist[0..staticLen];
}
                 
void extendMethod(T,alias fn)(Dobject obj, CallContext* cc, string name)
if(is(T == class) && isCallable!fn){
    alias ParameterTypeTuple!fn Args;
    alias ReturnType!fn R;
    alias staticMap!(Unqual,Args) Uargs;
	static void* embedded(Dobject pthis, CallContext* cc,
                          Dobject othis, Value* ret,	Value[] arglist){

        static if(Uargs.length){
            Tuple!(Uargs) tup = convertAll!(Uargs)(arglist, cc);
        
            fitArray(arglist);
        }
        assert(cast(T)othis,"Wrong this pointer in external func ");
        static if(Uargs.length){
             auto dg = (){ mixin("(cast(T)othis).wrapped."~(&fn).stringof[2..$]~"(tup.expand);"); };
        } else{
             auto dg = (){ mixin("(cast(T)othis).wrapped."~(&fn).stringof[2..$]~"();"); };   
        }
        
        static if(is(R == void)){
            dg();
        }else{
            R r = dg();
            convertPut(r,ret);
        }
        return null;
    }
    NativeFunctionData[] nfd = [
        {
            name,
            &embedded,
            Args.length
        }
    ];
    DnativeFunction.initialize(obj,cc,nfd,DontEnum);
}                          
class Wrap(Which,string ClassName,Base=Dobject): Base{
    Which wrapped;
    static Wrap _prototype;
    static Constructor _constructor;
    static class Constructor: Dfunction{
        this(CallContext* cc){
            super(cc, ConstructorArgs.length, cc.tc.Dfunction_prototype);
            name = ClassName;
        }

        override void *Construct(CallContext *cc, Value *ret, Value[] arglist){
            fitArray!(ConstructorArgs)(arglist);
            Dobject o = new Wrap(cc, convertAll!(UConstructorArgs)(arglist, cc).expand);
            ret.putVobject(o);
            return null;
        }

        override void *Call(CallContext *cc, Dobject othis, Value* ret, Value[] arglist){
            return Construct(cc,ret,arglist);
        }
    
    }
    static void initialize(CallContext* cc){
         _prototype = new Wrap(cc, Base.getPrototype(cc));
        _constructor = new Constructor(cc);
        _prototype.Put(cc, "constructor", _constructor, DontEnum);
        _constructor.Put(cc, "prototype", _prototype, DontEnum | DontDelete | ReadOnly);

        // we need to directly store the constructor, because this will be
        // called after the global object has already been created
        //cc.tc.ctorTable[ClassName] = _constructor;
        cc.global.Put(cc, ClassName, _constructor, DontEnum);
    }
    static this(){
        threadInitTable ~= cc => initialize(cc);
    }
    private this(CallContext* cc, Dobject prototype){ 
        super(cc, prototype); 
        classname = ClassName;
        //Put(TEXT_constructor,
    }
    alias ParameterTypeTuple!(Which.__ctor) ConstructorArgs;
    alias staticMap!(Unqual,ConstructorArgs) UConstructorArgs;
    this(CallContext* cc, ConstructorArgs args){
        super(cc, _prototype);
        static if (is(Which == struct)){
            wrapped = Which(args);
        } 
    }
    static void methods(Methods...)(){
        static if(Methods.length >= 1){
            threadInitTable ~= (cc) {
                extendMethod!(Wrap,Methods[0])(_prototype,cc,(&Methods[0]).stringof[2..$]);
            };
        
            methods!(Methods[1..$])();
        }
    }
}       
                        
auto convertAll(Args...)(Value[] dest, CallContext* cc){
    static if(Args.length > 1){
        return tuple(convert!(Args[0])(&dest[0], cc),convertAll!(Args[1..$])(dest[1..$], cc).expand);  
    }else 
        return tuple(convert!(Args[0])(&dest[0], cc));
}

