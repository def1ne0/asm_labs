@echo off
cd bin
del /q *.*
tasm /o ..\%1.asm
tlink /3 %1.obj
cd ..
