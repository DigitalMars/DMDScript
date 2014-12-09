; Simple build script that just calls dub for each sub-package
dub build --arch=x86 dmdscript:engine
dub build --arch=x86 dmdscript:ds
dub build --arch=x86 dmdscript:ds-ext
copy ds\dmdscript_ds.exe dmdscript.exe
copy ds-ext\dmdscript_ds-ext.exe dmdscript-ext.exe