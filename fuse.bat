@echo on
set cwd="%~dp0"
set love="%cwd%_bin\love.exe"
set b7z="%cwd%_bin\7z.exe"
set output=murky-mind_ld38
@echo on

%b7z% a -tzip %output%.love %cwd%*.lua %cwd%assets %cwd%libs %cwd%src -mmt -mx0

copy /b %love%+%output%.love %output%.exe

%b7z% a -tzip %output%-win32.zip %cwd%%output%.exe %cwd%_bin/love.dll %cwd%_bin/lua51.dll %cwd%_bin/mpg123.dll %cwd%_bin/OpenAL32.dll %cwd%_bin/SDL2.dll %cwd%_bin/msvcp120.dll %cwd%_bin/msvcr120.dll -mx9

REM del %output%.love
del %output%.exe
pause
