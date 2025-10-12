Set-StrictMode -Version Latest

# ───────────────────────────────────────────────
# Utility Functions
# ───────────────────────────────────────────────

function Write-Log {
   param(
      [string]$Message,
      [string]$Icon = "ℹ️"
   )
   Write-Host "[ $Icon ] $Message"
}

function Invoke-CommandLine {
   param(
      [string]$Command,
      [string]$ErrorMessage = "Command failed"
   )
   try {
      $output = cmd /c $Command
      if ($LASTEXITCODE -ne 0) {
         throw "$ErrorMessage (ExitCode: $LASTEXITCODE)"
      }
      return $output
   }
   catch {
      Write-Error $_
      exit 1
   }
}

function Test-BunInstalled {
   if (Get-Command bun -ErrorAction SilentlyContinue) {
      $localVersion = (bun --version).Trim()

      try {
         $latestVersion = (Invoke-RestMethod "https://api.github.com/repos/oven-sh/bun/releases/latest").tag_name.TrimStart("bun-v")
      }
      catch {
         Write-Log "Could not fetch latest Bun version, skipping version check" "⚠️"
         $latestVersion = $null
      }

      if ($latestVersion -and $localVersion -ne $latestVersion) {
         Write-Log "Updating Bun from $localVersion → $latestVersion . . ." "🔄"
         Invoke-CommandLine "bun upgrade --silent" -ErrorMessage "Failed to upgrade Bun"
         Write-Log "Bun upgraded to $latestVersion" "✅"
      }
      elseif (-not $latestVersion) {
         Invoke-CommandLine "bun upgrade --silent" -ErrorMessage "Failed to upgrade Bun"
         Write-Log "Bun upgraded (latest version unknown)" "✅"
      }
      else {
         Write-Log "Bun is already installed ($localVersion)" "✅"
      }
   }
   else {
      Write-Log "Installing Bun . . ." "🔽"
      Invoke-CommandLine "npm install --silent --global bun" -ErrorMessage "Failed to install Bun"
      Write-Log "Installed Bun successfully" "✅"
   }
}

function Get-Time {
   [math]::Round(((Get-Date).ToUniversalTime().Ticks / 10000))
}

function New-UUID {
   [guid]::NewGuid().ToString()
}

function Get-Version {
   param([string]$PackageName)

   $version = bun -e @"
      const { execSync } = require('child_process');
      const json = execSync('npm view $PackageName versions --json', { encoding: 'utf8' });
      const versions = JSON.parse(json);
      const stable = versions.filter(v => v.endsWith('-stable')).at(-1);
      console.log(stable ?? versions.at(-1));
"@

   return $version.Trim()
}

function Get-Substring {
   param (
      [string]$InputString,
      [string]$SearchString
   )

   $result = bun -e @"
      const input = '$InputString';
      const search = '$SearchString';
      const pos = input.indexOf(search);
      if (pos >= 0) {
         console.log(input.substring(0, pos + search.length));
      }
"@
   if ($result) {
      return $result.Trim()
   } else {
      return $null
   }
}

function Test-FileExistsOrCreate {
   param(
      [string]$Path,
      [string]$Content
   )
   if (-not (Test-Path $Path)) {
      bun -e "Bun.write('$Path', ``$Content``);"
      Write-Log "Created $(Split-Path -Leaf $Path)" "✅"
   }
   else {
      Write-Log "$(Split-Path -Leaf $Path) already exists" "✅"
   }
}

function Save-Json {
   param(
      [string]$Path,
      [object]$Object
   )
   $json = $Object | ConvertTo-Json -Depth 10 -Compress
   $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
   bun -e "Bun.write('$Path', JSON.stringify(JSON.parse(Buffer.from('$b64','base64').toString()), null, 2));"
   Write-Log "Created $(Split-Path -Leaf $Path)" "✅"
}

# ───────────────────────────────────────────────
# Script Start
# ───────────────────────────────────────────────

$folderName = Read-Host "Enter the folder name for your project"
$startTime = Get-Time

Write-Log "Setting up Minecraft Bedrock Scripting Project . . ." "🚀"

Test-BunInstalled

Write-Log "Fetching latest versions . . ." "🔍"

$serverLatest = Get-Version "@minecraft/server"
Write-Log "@minecraft/server ($serverLatest)" "⏫"

$serverUiLatest = Get-Version "@minecraft/server-ui"
Write-Log "@minecraft/server-ui ($serverUiLatest)" "⏫"

$headerUUID = New-UUID
$dataUUID = New-UUID
$scriptUUID = New-UUID

Test-FileExistsOrCreate "$folderName/package.json" "{}"

Set-Location -Path $folderName

bun pm pkg set scripts.build="bun build src/*.ts --outdir scripts --packages external --external @minecraft/server --external @minecraft/server-ui --external @minecraft/server-net --external @minecraft/server-admin"
bun pm pkg set scripts.dev="bun --watch build src/*.ts --outdir scripts --packages external --external @minecraft/server --external @minecraft/server-ui --external @minecraft/server-net --external @minecraft/server-admin"
bun pm pkg set dependencies.@minecraft/server=$serverLatest
bun pm pkg set dependencies.@minecraft/server-ui=$serverUiLatest

Write-Log "Installing dependencies . . ." "🔽"
Invoke-CommandLine "bun install --silent" -ErrorMessage "Failed to Bun install dependencies"
Remove-Item '.\node_modules\@minecraft\server-ui\node_modules' -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "Installed dependencies successfully" "✅"

# ───────────────────────────────────────────────
# Project Scaffolding
# ───────────────────────────────────────────────

Test-FileExistsOrCreate "src/index.ts" ""

Test-FileExistsOrCreate "compile.bat" "@echo off`ncall bun run dev"

$tsconfig = [ordered]@{
   compilerOptions = [ordered]@{
      module                       = "ES2020"
      moduleResolution             = "node"
      target                       = "ES2021"
      lib                          = @("ES2020", "DOM")
      allowSyntheticDefaultImports = $true
      noImplicitAny                = $true
      preserveConstEnums           = $true
      sourceMap                    = $false
      outDir                       = "./scripts"
      allowJs                      = $true
      rootDir                      = "src"
      baseUrl                      = "./src"
   }
   include         = @("./src")
}
Save-Json "tsconfig.json" $tsconfig

$manifest = [ordered]@{
   format_version = 2
   header         = [ordered]@{
      name               = $folderName
      description        = $folderName
      uuid               = $headerUUID
      version            = @(1, 0, 0)
      min_engine_version = @(1, 21, 0)
   }
   modules        = @(
      [ordered]@{
         description = "Item And Entity Definitions"
         type        = "data"
         uuid        = $dataUUID
         version     = @(1, 0, 0)
      },
      [ordered]@{
         description = "@minecraft/server | @minecraft/server-ui"
         type        = "script"
         language    = "javascript"
         uuid        = $scriptUUID
         version     = @(1, 0, 0)
         entry       = "scripts/index.js"
      }
   )
   capabilities   = @("script_eval")
   dependencies   = @(
      [ordered]@{
         module_name = "@minecraft/server"
         version     = (Get-Substring -InputString $serverLatest -SearchString "beta")
      },
      [ordered]@{
         module_name = "@minecraft/server-ui"
         version     = (Get-Substring -InputString $serverUiLatest -SearchString "beta")
      }
   )
}
Save-Json "manifest.json" $manifest

# ───────────────────────────────────────────────
# Build
# ───────────────────────────────────────────────

Invoke-CommandLine "bun run build" -ErrorMessage "TypeScript compilation failed"
Write-Log "Compiled TypeScript to JavaScript" "✅"

Set-Location -Path ".."

$endTime = Get-Time
$timeDiff = ($endTime - $startTime) / 1000
Write-Log ("Done in {0:N2} secs, You can start coding now at src/index.ts" -f $timeDiff) "🎉"

Pause
