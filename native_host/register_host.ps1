# PowerShell script to register com.vlc.open native messaging host
$ManifestPath = Join-Path $PSScriptRoot "com.vlc.open.json"
$RegistryPaths = @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.vlc.open",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.vlc.open",
    "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.vlc.open"
)

Write-Host "Registering Native Messaging Host..."
Write-Host "Manifest Path: $ManifestPath"

foreach ($RegPath in $RegistryPaths) {
    try {
        if (!(Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        Set-Item -Path $RegPath -Value $ManifestPath
        Write-Host "Registry successfully configured for: $RegPath"
    } catch {
        Write-Host "Warning: Could not update $RegPath"
    }
}

