Set-StrictMode -Version Latest

# ───────────────────────────────────────────────
# Utility Functions
# ───────────────────────────────────────────────

function Get-Time {
   [math]::Round(((Get-Date).ToUniversalTime().Ticks / 10000))
}

function New-UUID {
   [guid]::NewGuid().ToString()
}

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

function Test-NpmInstalled {
   param (
      [string]$Package,
      [string]$Options = ""
   )

   $result = Invoke-CommandLine "npm list $Options --depth=0 $Package" -ErrorMessage "Failed to check $Package"
   if ($result -match "$Package@") {
      Write-Log "$Package is already installed" "✅"
   }
   else {
      Write-Log "Installing $Package . . ." "🔽"
      Invoke-CommandLine "npm install --silent $Options $Package" -ErrorMessage "Failed to install $Package"
      Write-Log "Installed $Package successfully" "✅"
   }
}

function Get-Version {
   param([string]$PackageName)
   $json = Invoke-CommandLine "npm view $PackageName versions --json" -ErrorMessage "Failed to fetch $PackageName versions"
   $versions = $json | ConvertFrom-Json
   $versions | Where-Object { $_ -match '-stable$' } | Select-Object -Last 1
}

function Get-Substring {
   param (
      [string]$InputString,
      [string]$SearchString
   )

   $pos = -1
   for ($i = 0; $i -le $InputString.Length - $SearchString.Length; $i++) {
      if ($InputString.Substring($i, $SearchString.Length) -eq $SearchString) {
         $pos = $i
         break
      }
   }

   if ($pos -ge 0) {
      $endPos = $pos + $SearchString.Length
      return $InputString.Substring(0, $endPos)
   }
   else {
      return $null
   }
}

function Test-FileExistsOrCreate {
   param(
      [string]$Path,
      [string]$Content
   )
   if (-not (Test-Path $Path)) {
      Set-Content -Path $Path -Value $Content -Encoding UTF8 -Force | Out-Null
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
   $json = $Object | ConvertTo-Json -Depth 20 -Compress
   $formatted = $json | node -e "let d=''; process.stdin.on('data',c=>d+=c); process.stdin.on('end',()=>console.log(JSON.stringify(JSON.parse(d), null, 2)))"
   Set-Content -Path $Path -Value $formatted -Encoding UTF8 -Force | Out-Null
   Write-Log "Wrote JSON: $(Split-Path -Leaf $Path)" "✅"
}

# ───────────────────────────────────────────────
# Script Start
# ───────────────────────────────────────────────

$folderName = Read-Host "Enter the folder name for your project"
$startTime = Get-Time

Write-Log "Setting up Minecraft Bedrock Scripting Project . . ." "🚀"

if (-not (Test-Path $folderName)) {
   New-Item -ItemType Directory -Path $folderName -Force | Out-Null
   Write-Log "Created folder: $folderName" "✅"
}
else {
   Write-Log "Folder already exists: $folderName" "✅"
}
Set-Location -Path $folderName

$serverLatest = Get-Version "@minecraft/server"
$serverUiLatest = Get-Version "@minecraft/server-ui"

$headerUUID = New-UUID
$dataUUID = New-UUID
$scriptUUID = New-UUID

Test-NpmInstalled -Package "typescript" -Options "-g"

Test-FileExistsOrCreate "package.json" "{}"

Invoke-CommandLine "npm pkg set dependencies.@minecraft/server=$serverLatest"
Invoke-CommandLine "npm pkg set dependencies.@minecraft/server-ui=$serverUiLatest"
Invoke-CommandLine "npm pkg set overrides.@minecraft/server-ui.@minecraft/server=$serverLatest"

Write-Log "Installing dependencies . . ." "🔽"
Invoke-CommandLine "npm install --silent" -ErrorMessage "Failed to install dependencies"
Write-Log "Installed dependencies successfully" "✅"

# ───────────────────────────────────────────────
# Project Scaffolding
# ───────────────────────────────────────────────

if (-not (Test-Path "src")) {
   New-Item -ItemType Directory -Path "src" -Force | Out-Null
}
Test-FileExistsOrCreate "src/index.ts" ""

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

Test-FileExistsOrCreate "compile.bat" "@echo off`ncall tsc -w"

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

Invoke-CommandLine "tsc" -ErrorMessage "TypeScript compilation failed"
Write-Log "Compiled TypeScript to JavaScript" "✅"

Set-Location -Path ".."

$endTime = Get-Time
$timeDiff = ($endTime - $startTime) / 1000
Write-Log ("Done in {0:N2} secs, You can start coding now at src/index.ts" -f $timeDiff) "🎉"

Pause
