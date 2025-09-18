# Script to extract executable name from CMakeLists.txt
param(
    [string]$CMakeListsPath = ".\CMakeLists.txt"
)

if (Test-Path $CMakeListsPath) {
    $cmakeContent = Get-Content $CMakeListsPath

    # Look for project() command
    $projectLine = $cmakeContent | Where-Object { $_ -match "project\(([^)]+)\)" }
    if ($projectLine) {
        if ($projectLine -match "project\(([^)\s]+)") {
            $projectName = $matches[1]
            Write-Output $projectName
            exit 0
        }
    }

    # If no project found, look for add_executable
    $executableLine = $cmakeContent | Where-Object { $_ -match "add_executable\(([^)]+)\)" }
    if ($executableLine) {
        if ($executableLine -match "add_executable\(([^)\s]+)") {
            $executableName = $matches[1]
            Write-Output $executableName
            exit 0
        }
    }
}

# Fallback to workspace folder basename
$fallbackName = Split-Path -Leaf (Get-Location)
Write-Output $fallbackName
exit 0
