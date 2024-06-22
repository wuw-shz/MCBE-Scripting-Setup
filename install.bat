@echo off
setlocal enabledelayedexpansion

call:GetTime
set start_time=%timestamp%

echo [ 🚀 ] Setting up Minecraft Bedrock Scripting Project . . .

echo [ 🔃 ] Fetching latest modules . . .

call:GetBetaVersion @minecraft/server
call:subString "%beta_version%" "beta"
set server_beta=%result%
call:GetBetaVersion @minecraft/server-ui
call:subString "%beta_version%" "beta"
set server_ui_beta=%result%

call:GenUUID
set headerUUID=%UUID%
call:GenUUID
set dataUUID=%UUID%
call:GenUUID
set scriptUUID=%UUID%

call npm ls --save-dev -g typescript > nul 2>&1
if %errorlevel% neq 0 (
    echo [ ⚠️ ] Not found TypeScript
    echo [ 🔽 ] Installing TypeScript . . .
    call npm i --silent --save-dev -g typescript
    echo [ ✅ ] Installed TypeScript successfully
) else (
    echo [ ✅ ] TypeScript is already installed
)

call npm ls @minecraft/server@beta > nul 2>&1
if %errorlevel% neq 0 (
    echo [ ⚠️ ] Not found Minecraft Server
    echo [ 🔽 ] Installing Minecraft Server . . .
    call npm i --silent @minecraft/server@beta
    echo [ ✅ ] Installed Minecraft Server
) else (
    echo [ ✅ ] Minecraft Server is already installed
)

call npm ls @minecraft/server-ui@beta > nul 2>&1
if %errorlevel% neq 0 (
    echo [ ⚠️ ] Not found Minecraft Server UI
    echo [ 🔽 ] Installing Minecraft Server UI . . .
    call npm i --silent @minecraft/server-ui@beta
    echo [ ✅ ] Installed Minecraft Server UI
) else (
    echo [ ✅ ] Minecraft Server UI is already installed
)

echo [ 🔧 ] Setting up project . . .

call mkdir src 2> nul
if not exist src\index.ts (
    echo // index.ts > src/index.ts
)

if not exist tsconfig.json (
    (
        echo {
        echo   "compilerOptions": {
        echo       "module": "ES2020",
        echo       "moduleResolution": "node",
        echo       "target": "ES2021",
        echo       "lib": ["ES2020", "DOM"],
        echo       "allowSyntheticDefaultImports": true,
        echo       "noImplicitAny": true,
        echo       "preserveConstEnums": true,
        echo       "sourceMap": false,
        echo       "outDir": "./scripts",
        echo       "allowJs": true,
        echo       "rootDir": "src",
        echo       "baseUrl": "./src"
        echo   },
        echo   "include": [
        echo       "./src"
        echo   ]
        echo }
    ) > tsconfig.json
    echo [ ✅ ] Created tsconfig.json
) else (
    echo [ ✅ ] tsconfig.json is already exists
)

if not exist compile.bat (
    (
        echo @echo off
        echo call tsc -w
    ) > compile.bat
    echo [ ✅ ] Created compile.bat
) else (
    echo [ ✅ ] compile.bat is already exists
)

if not exist manifest.json (
    (
        echo {
        echo     "format_version": 2,
        echo     "header": {
        echo         "name": "Name",
        echo         "description": "Description",
        echo         "uuid": "%headerUUID%",
        echo         "version": [
        echo             1,
        echo             0,
        echo             0
        echo         ],
        echo         "min_engine_version": [
        echo             1,
        echo             21,
        echo             0
        echo         ]
        echo     },
        echo     "modules": [
        echo         {
        echo             "description": "Item And Entity Definitions",
        echo             "type": "data",
        echo             "uuid": "%dataUUID%",
        echo             "version": [
        echo                 1,
        echo                 0,
        echo                 0
        echo             ]
        echo         },
        echo         {
        echo             "description": "@minecraft/server | @minecraft/server-ui",
        echo             "type": "script",
        echo             "language": "javascript",
        echo             "uuid": "%scriptUUID%",
        echo             "version": [
        echo                 1,
        echo                 0,
        echo                 0
        echo             ],
        echo             "entry": "scripts/index.js"
        echo         }
        echo     ],
        echo     "capabilities": [
        echo         "script_eval"
        echo     ],
        echo     "dependencies": [
        echo         {
        echo             "module_name": "@minecraft/server",
        echo             "version": "%server_beta%"
        echo         },
        echo         {
        echo             "module_name": "@minecraft/server-ui",
        echo             "version": "%server_ui_beta%"
        echo         }
        echo     ]
        echo }
    ) > manifest.json
    echo [ ✅ ] Created manifest.json
) else (
    echo [ ✅ ] manifest.json is already exists
)

if not exist scripts\index.js (
    call tsc
    echo [ ✅ ] Compiled TypeScript to JavaScript
)

call:GetTime
set end_time=%timestamp%

for /f "usebackq tokens=*" %%a in (`powershell -Command "(%end_time% - %start_time%) / 1000"`) do (
    set time_diff=%%a
)
for /f "tokens=1,2 delims=." %%a in ("%time_diff%") do (
    set integer=%%a
    set decimal=%%b
)
set decimal=%decimal:~0,2%
set time_diff=%integer%.%decimal%

echo [ ❇️ ] All set up successfully in 🕑 %time_diff% secs, You can start coding now at src/index.ts
pause

:GetTime
    for /f "delims=" %%a in ('powershell -Command "(Get-Date).ToUniversalTime().Ticks / 10000"') do set timestamp=%%a
exit /b

:GenUUID
    for /f "delims=" %%A in ('powershell -command "[guid]::NewGuid().ToString()"') do set UUID=%%A
exit /b

:GetBetaVersion
    set package=%1
    for /f "delims=" %%A in ('npm show %package% dist-tags.beta') do set beta_version=%%A
    call:subString "%beta_version%" "beta"
    set beta_version=%result%
exit /b

:subString
    set input=%~1
    set search=%~2
    for /l %%i in (0,1,255) do (
        if "!input:~%%i,4!"=="%search%" (
            set pos=%%i
            goto :found
        )
    )
exit /b

:found
   set /a end_pos=%pos% + 4
   set result=!input:~0,%end_pos%!
exit /b

endlocal