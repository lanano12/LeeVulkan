param(
    [string]$OutputFile = "build_audit.txt"
)

# Function to get tool version
function Get-ToolVersion {
    param([string]$Command, [string]$VersionArg = "--version")

    try {
        $version = & $Command $VersionArg 2>$null | Select-Object -First 1
        if ($LASTEXITCODE -eq 0) {
            return $version.Trim()
        }
    }
    catch {
        # Tool not found or failed
    }
    return "Not found"
}

# Function to get file version (for Windows executables)
function Get-FileVersion {
    param([string]$FilePath)

    try {
        if (Test-Path $FilePath) {
            $version = (Get-Item $FilePath).VersionInfo.FileVersion
            return $version
        }
    }
    catch {
        # File not found or version info not available
    }
    return "Not found"
}

# Get current timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Get system information
$osInfo = Get-CimInstance Win32_OperatingSystem
$computerInfo = Get-CimInstance Win32_ComputerSystem

# Get tool versions
$cmakeVersion = Get-ToolVersion "cmake"
$ninjaVersion = Get-ToolVersion "ninja"
$gccVersion = Get-ToolVersion "gcc"
$gppVersion = Get-ToolVersion "g++"
$clVersion = Get-ToolVersion "cl"

# Find Qt installation
$qtPath = $null
$qtVersion = "Not found"
$possibleQtPaths = @(
    "${env:QT_DIR}",
    "${env:QTDIR}",
    "C:\Qt",
    "C:\Qt6",
    "C:\Qt5"
)

foreach ($path in $possibleQtPaths) {
    if ($path -and (Test-Path $path)) {
        $qtPath = $path
        try {
            # Try to find qmake or qtpaths
            $qmakePath = Get-ChildItem -Path $path -Recurse -Filter "qmake.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($qmakePath) {
                $qtVersion = Get-ToolVersion $qmakePath.FullName
                break
            }
        }
        catch {
            # Continue searching
        }
    }
}

# Get project information
$projectName = "QtHelloWorld"  # Default, could be extracted from CMakeLists.txt
$cmakeListsPath = ".\CMakeLists.txt"
if (Test-Path $cmakeListsPath) {
    $cmakeContent = Get-Content $cmakeListsPath
    $projectLine = $cmakeContent | Where-Object { $_ -match "project\(([^)]+)\)" }
    if ($projectLine) {
        $projectName = $matches[1].Split()[0]
    }
}

# Get Git information
$gitCommit = "Not available"
$gitBranch = "Not available"
try {
    $gitCommit = & git rev-parse HEAD 2>$null
    $gitBranch = & git rev-parse --abbrev-ref HEAD 2>$null
}
catch {
    # Git not available
}

# Generate audit content
$auditContent = @"
BUILD AUDIT REPORT
==================

Generated: $timestamp
Project: $projectName
Build Directory: $(Get-Location)\build

SYSTEM INFORMATION
==================
Operating System: $($osInfo.Caption) $($osInfo.Version)
Architecture: $($computerInfo.SystemType)
Hostname: $($env:COMPUTERNAME)
Username: $($env:USERNAME)

BUILD TOOLS
===========
CMake Version: $cmakeVersion
Ninja Version: $ninjaVersion
GCC Version: $gccVersion
G++ Version: $gppVersion
MSVC CL Version: $clVersion

QT INFORMATION
==============
Qt Path: $(if ($qtPath) { $qtPath } else { "Not found" })
Qt Version: $qtVersion

VERSION CONTROL
===============
Git Commit: $gitCommit
Git Branch: $gitBranch

BUILD CONFIGURATION
===================
Generator: Ninja
Build Type: Default (Debug)
Source Directory: $(Get-Location)
Build Directory: $(Get-Location)\build

DEPENDENCIES
============
"@

# Try to extract dependencies from CMakeLists.txt
if (Test-Path $cmakeListsPath) {
    $cmakeContent = Get-Content $cmakeListsPath
    $findPackageLines = $cmakeContent | Where-Object { $_ -match "find_package\(([^)]+)\)" }

    if ($findPackageLines) {
        $auditContent += "`nCMake find_package() calls:`n"
        foreach ($line in $findPackageLines) {
            if ($line -match "find_package\(([^)]+)\)") {
                $packageInfo = $matches[1]
                $auditContent += "- $packageInfo`n"
            }
        }
    }
}

$auditContent += @"

ENVIRONMENT VARIABLES
=====================
PATH: $($env:PATH -split ';' | Where-Object { $_ -match "(cmake|qt|ninja|gcc|mingw)" } | ForEach-Object { "`n  $_" })

COMPILER INFORMATION
====================
"@

# Get detailed compiler information
if ($gccVersion -ne "Not found") {
    try {
        $gccInfo = & gcc --version 2>$null | Select-Object -First 3
        $auditContent += "`nGCC Details:`n$($gccInfo -join "`n")"
    }
    catch {
        $auditContent += "`nGCC: Version info not available"
    }
}

if ($clVersion -ne "Not found") {
    try {
        $clInfo = & cl 2>$null | Select-Object -First 3
        $auditContent += "`n`nMSVC CL Details:`n$($clInfo -join "`n")"
    }
    catch {
        $auditContent += "`nMSVC CL: Version info not available"
    }
}

# Write to output file
$auditContent | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "Build audit generated: $OutputFile"
Write-Host "Audit includes system info, tool versions, and build configuration."
