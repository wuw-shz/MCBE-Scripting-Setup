Set-StrictMode -Version Latest

function Get-Time {
   return [math]::Round(((Get-Date).ToUniversalTime().Ticks / 10000))
}

function GenerateUUID {
   return [guid]::NewGuid().ToString()
}

function CheckNpmInstalled {
   param (
      [string]$npmPackage,
      [string]$installOptions
   )
   $isInstalled = -not (npm ls $installOptions --depth=0 $npmPackage 2>&1 | Select-String 'empty')
   if ($isInstalled -eq "True") {
      Write-Host "[ ✅ ] $npmPackage is already installed"
   }
   else {
      Write-Host "[ ⚠️ ] Not found $npmPackage"
      Write-Host "[ 🔽 ] Installing $npmPackage . . ."
      npm install --silent $installOptions $npmPackage
      Write-Host "[ ✅ ] Installed $npmPackage successfully"
   }
}

function Get-Substring {
   param (
      [string]$InputString,
      [string]$SearchString
   )

   # Initialize position
   $pos = -1

   # Search for the substring
   for ($i = 0; $i -le $InputString.Length - $SearchString.Length; $i++) {
      if ($InputString.Substring($i, $SearchString.Length) -eq $SearchString) {
         $pos = $i
         break
      }
   }

   if ($pos -ge 0) {
      # Found the substring, calculate end position
      $endPos = $pos + $SearchString.Length
      $result = $InputString.Substring(0, $endPos)
      return $result
   }
   else {
      # Substring not found
      Write-Output "Substring '$SearchString' not found."
      return $null
   }
}

function Get-BetaVersion {
   param (
      [string]$packageName
   )
   $betaVersion = Get-Substring -InputString (npm show $packageName dist-tags.beta) -SearchString "beta"
   return $betaVersion
}

function ConvertTo-CompactJson {
   param (
      [Parameter(ValueFromPipeline = $true)]
      $InputObject
   )
   process {
      $json = $InputObject | ConvertTo-Json -Depth 10
      $json -replace '(?<!\\)(\t)', ' '
   }
}

# Main script starts here

$startTime = Get-Time

Write-Host "[ 🚀 ] Setting up Minecraft Bedrock Scripting Project . . ."

Write-Host "[ 🔃 ] Fetching latest modules . . ."
npm update --silent -g npm@latest

$serverBeta = Get-BetaVersion -packageName "@minecraft/server"
$serverUiBeta = Get-BetaVersion -packageName "@minecraft/server-ui"

$headerUUID = GenerateUUID
$dataUUID = GenerateUUID
$scriptUUID = GenerateUUID

CheckNpmInstalled -npmPackage "typescript" -installOptions "-g"
CheckNpmInstalled -npmPackage "@minecraft/server@beta"
CheckNpmInstalled -npmPackage "@minecraft/server-ui@beta"

Write-Host "[ 🔧 ] Setting up project . . ."

if (-not (Test-Path -Path "src")) {
   New-Item -ItemType Directory -Path "src" *>$null
}

if (-not (Test-Path -Path "src/index.ts")) {
   New-Item -ItemType File -Path "src/index.ts" -Value "// index.ts" *>$null
}

if (-not (Test-Path -Path "tsconfig.json")) {
   $tsconfigContent = [ordered]@{
      "compilerOptions" = [ordered]@{
         "module"                       = "ES2020"
         "moduleResolution"             = "node"
         "target"                       = "ES2021"
         "lib"                          = @("ES2020", "DOM")
         "allowSyntheticDefaultImports" = $true
         "noImplicitAny"                = $true
         "preserveConstEnums"           = $true
         "sourceMap"                    = $false
         "outDir"                       = "./scripts"
         "allowJs"                      = $true
         "rootDir"                      = "src"
         "baseUrl"                      = "./src"
      }
      "include"         = @("./src")
   }
   $json = $tsconfigContent | ConvertTo-Json
   $json = $json -replace '    ', ' '
   Set-Content -Path "tsconfig.json" -Value $json
   Write-Host "[ ✅ ] Created tsconfig.json"
}
else {
   Write-Host "[ ✅ ] tsconfig.json already exists"
}

if (-not (Test-Path -Path "compile.bat")) {
   $compileContent = "@echo off`ncall tsc -w"
   Set-Content -Path "compile.bat" -Value $compileContent *>$null
   Write-Host "[ ✅ ] Created compile.bat"
}
else {
   Write-Host "[ ✅ ] compile.bat already exists"
}
if (-not (Test-Path -Path "manifest.json")) {
   $manifestContent = [ordered]@{
      "format_version" = 2
      "header"         = [ordered]@{
         "name"               = "Name"
         "description"        = "Description"
         "uuid"               = $headerUUID
         "version"            = @(1, 0, 0)
         "min_engine_version" = @(1, 21, 0)
      }
      "modules"        = @(
         [ordered]@{
            "description" = "Item And Entity Definitions"
            "type"        = "data"
            "uuid"        = $dataUUID
            "version"     = @(1, 0, 0)
         },
         [ordered]@{
            "description" = "@minecraft/server | @minecraft/server-ui"
            "type"        = "script"
            "language"    = "javascript"
            "uuid"        = $scriptUUID
            "version"     = @(1, 0, 0)
            "entry"       = "scripts/index.js"
         }
      )
      "capabilities"   = @("script_eval")
      "dependencies"   = @(
         [ordered]@{
            "module_name" = "@minecraft/server"
            "version"     = $serverBeta
         },
         [ordered]@{
            "module_name" = "@minecraft/server-ui"
            "version"     = $serverUiBeta
         }
      )
   }
   $json = $manifestContent | ConvertTo-Json -Depth 10
   $json = $json -replace '    ', ' '
   Set-Content -Path "manifest.json" -Value $json
   Write-Host "[ ✅ ] Created manifest.json"
}
else {
   Write-Host "[ ✅ ] manifest.json already exists"
}

if (-not (Test-Path -Path "scripts/index.js")) {
   tsc
   Write-Host "[ ✅ ] Compiled TypeScript to JavaScript"
}

$endTime = Get-Time
$timeDiff = ($endTime - $startTime) / 1000
Write-Host ("[ 🎉 ] Done in 🕑 {0:N2} secs, You can start coding now at src/index.ts" -f $timeDiff)
Pause