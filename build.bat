; Simple build script that just calls dub for each sub-package
set BUILD=release
dub build --build=%BUILD% dmdscript:engine
dub build --build=%BUILD% dmdscript:ds
dub build --build=%BUILD% dmdscript:ds-ext
copy ds\dmdscript_ds.exe dmdscript.exe
copy ds-ext\dmdscript_ds-ext.exe dmdscript-ext.exe