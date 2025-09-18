# Script to update launch.json with the correct executable name from CMakeLists.txt

# Get the executable name from CMakeLists.txt
$exeName = & "$PSScriptRoot\get-executable-name.ps1"

if ($exeName) {
    $launchJsonPath = "$PSScriptRoot\launch.json"

    if (Test-Path $launchJsonPath) {
        # Read the launch.json content
        $content = Get-Content $launchJsonPath -Raw

        # Replace the executable name (assuming it contains QtHelloWorld.exe)
        $updatedContent = $content -replace 'QtHelloWorld\.exe', "$exeName.exe"

        # Write back to the file
        $updatedContent | Set-Content $launchJsonPath -Encoding UTF8

        Write-Host "Updated launch.json to use executable: $exeName.exe"
    } else {
        Write-Error "launch.json not found at $launchJsonPath"
        exit 1
    }
} else {
    Write-Error "Could not determine executable name from CMakeLists.txt"
    exit 1
}
