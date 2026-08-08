# setup.ps1 - Automated 1-Click Setup Script for VLC Link Opener
$ProjectRoot = $PSScriptRoot
$NativeHostDir = Join-Path $ProjectRoot "native_host"
$ExtensionDir = Join-Path $ProjectRoot "extension"
$ManifestPath = Join-Path $NativeHostDir "com.vlc.open.json"
$BatPath = Join-Path $NativeHostDir "vlc_host.bat"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   ZipLoot.app - VLC Link Opener Setup    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Helper function to check Python
function Test-PythonInstalled {
    try {
        $ver = & python --version 2>&1
        if ($ver -like "*Python*") { return $true }
    } catch {}
    try {
        $ver = & py --version 2>&1
        if ($ver -like "*Python*") { return $true }
    } catch {}
    $userPy = Get-ChildItem "$env:USERPROFILE\AppData\Local\Programs\Python\Python*" -ErrorAction SilentlyContinue
    if ($userPy) { return $true }
    return $false
}

# Helper function to auto-install Python
function Install-PythonAuto {
    Write-Host "[!] Python not found. Attempting automatic installation..." -ForegroundColor Yellow
    # Try winget first
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "--> Installing Python 3.12 via winget..." -ForegroundColor Cyan
            winget install --id Python.Python.3.12 --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (Test-PythonInstalled) { return $true }
        }
    } catch {}

    # Fallback direct download
    try {
        Write-Host "--> Downloading Python installer from python.org..." -ForegroundColor Cyan
        $url = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe"
        $installer = Join-Path $env:TEMP "python-installer.exe"
        Invoke-WebRequest -Uri $url -OutFile $installer
        Write-Host "--> Running Python quiet installation..." -ForegroundColor Cyan
        Start-Process -FilePath $installer -ArgumentList "/quiet PrependPath=1" -Wait
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } catch {
        Write-Host "[X] Could not auto-install Python. Please install Python manually from python.org" -ForegroundColor Red
        return $false
    }
    return (Test-PythonInstalled)
}

# Helper function to check VLC
function Test-VLCInstalled {
    $vlc1 = "$env:ProgramFiles\VideoLAN\VLC\vlc.exe"
    $vlc2 = "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
    if ((Test-Path $vlc1) -or (Test-Path $vlc2)) { return $true }
    try {
        $cmd = Get-Command vlc -ErrorAction SilentlyContinue
        if ($cmd) { return $true }
    } catch {}
    return $false
}

# Helper function to auto-install VLC
function Install-VLCAuto {
    Write-Host "[!] VLC Media Player not found. Attempting automatic installation..." -ForegroundColor Yellow
    # Try winget first
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "--> Installing VLC via winget..." -ForegroundColor Cyan
            winget install --id VideoLAN.VLC --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
            if (Test-VLCInstalled) { return $true }
        }
    } catch {}

    # Fallback direct download
    try {
        Write-Host "--> Downloading VLC installer from videolan.org..." -ForegroundColor Cyan
        $url = "https://get.videolan.org/vlc/3.0.21/win64/vlc-3.0.21-win64.exe"
        $installer = Join-Path $env:TEMP "vlc-installer.exe"
        Invoke-WebRequest -Uri $url -OutFile $installer
        Write-Host "--> Running VLC quiet installation..." -ForegroundColor Cyan
        Start-Process -FilePath $installer -ArgumentList "/S" -Wait
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[X] Could not auto-install VLC. Please install VLC manually from videolan.org" -ForegroundColor Red
        return $false
    }
    return (Test-VLCInstalled)
}

# 1. Clean up broken .venv if present
$VenvDir = Join-Path $ProjectRoot ".venv"
if (Test-Path $VenvDir) {
    Write-Host "Removing legacy .venv directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $VenvDir -ErrorAction SilentlyContinue
}

# 2. Check & Install Python
Write-Host "Checking for Python..." -NoNewline
if (Test-PythonInstalled) {
    Write-Host " [FOUND]" -ForegroundColor Green
} else {
    Write-Host " [NOT FOUND]" -ForegroundColor Yellow
    $pySuccess = Install-PythonAuto
    if ($pySuccess) {
        Write-Host "Python successfully installed!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Python setup incomplete." -ForegroundColor Red
    }
}

# 3. Check & Install VLC
Write-Host "Checking for VLC Media Player..." -NoNewline
if (Test-VLCInstalled) {
    Write-Host " [FOUND]" -ForegroundColor Green
} else {
    Write-Host " [NOT FOUND]" -ForegroundColor Yellow
    $vlcSuccess = Install-VLCAuto
    if ($vlcSuccess) {
        Write-Host "VLC Media Player successfully installed!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: VLC setup incomplete." -ForegroundColor Red
    }
}

# 4. Update com.vlc.open.json dynamically with the current path (UTF-8 No BOM)
Write-Host "Updating configuration paths..."
if (Test-Path $ManifestPath) {
    $json = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $json.path = $BatPath
    
    $formattedJson = $json | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ManifestPath, $formattedJson, $utf8NoBom)
    
    Write-Host "Updated host path in com.vlc.open.json to: $BatPath" -ForegroundColor Green
} else {
    Write-Host "ERROR: com.vlc.open.json not found at $ManifestPath" -ForegroundColor Red
    Exit 1
}

# 5. Register Native Messaging Host in Windows Registry (Chrome, Edge, Brave)
$RegistryPaths = @(
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.vlc.open",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\com.vlc.open",
    "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.vlc.open"
)

Write-Host "Registering Native Messaging Host in Registry..."
foreach ($RegPath in $RegistryPaths) {
    try {
        if (!(Test-Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }
        Set-Item -Path $RegPath -Value $ManifestPath
        Write-Host "Registry entry updated: $RegPath" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not update $RegPath" -ForegroundColor Yellow
    }
}

# 6. Open Extension folder in Explorer for easy loading
if (Test-Path $ExtensionDir) {
    Invoke-Item $ExtensionDir
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "   SETUP COMPLETED SUCCESSFULLY!           " -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Next Step: Open chrome://extensions in your browser," -ForegroundColor Yellow
Write-Host "Turn ON 'Developer mode', click 'Load unpacked', and" -ForegroundColor Yellow
Write-Host "select the 'extension' folder that just opened!" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
