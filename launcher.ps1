$ErrorActionPreference = "SilentlyContinue"

Write-Host "Configurando entorno portable..." -ForegroundColor Cyan
Write-Host ""

# -------------------------
# 0. DETECTAR USB ROOT
# -------------------------
$usbRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# -------------------------
# 1. DETECTAR VAULT AUTOMÁTICAMENTE
# -------------------------
Write-Host "Buscando vault de Cryptomator..." -ForegroundColor Cyan

$vault = $null

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object {
    $_.Free -ne $null
}

foreach ($drive in $drives) {

    # OPCIÓN 1: archivo identificador (RECOMENDADO)
    $testPath = "$($drive.Root).devusb"

    # OPCIÓN 2 (fallback): estructura conocida
    $altPath = "$($drive.Root)git\.gitconfig"

    if (Test-Path $testPath -or Test-Path $altPath) {
        $vault = $drive.Root
        break
    }
}

if (-not $vault) {
    Write-Host "ERROR: No se encontró el vault." -ForegroundColor Red
    Write-Host "Asegúrate de desbloquearlo en Cryptomator." -ForegroundColor Yellow
    Read-Host "Presiona ENTER para salir"
    exit
}

Write-Host "Vault detectado en: $vault" -ForegroundColor Green
Write-Host ""

# -------------------------
# 2. CONFIGURAR GIT
# -------------------------
Write-Host "Configurando Git..."

$gitExe = "$usbRoot\apps\git\bin\git.exe"

if (Test-Path $gitExe) {
    & $gitExe config --global user.name "TuNombre"
    & $gitExe config --global user.email "tu@email.com"
}

# Copiar gitconfig desde vault
if (Test-Path "$vault\git\.gitconfig") {
    Copy-Item "$vault\git\.gitconfig" "$env:USERPROFILE\.gitconfig" -Force
}

Write-Host "Git listo"
Write-Host ""

# -------------------------
# 3. CONFIGURAR SSH
# -------------------------
Write-Host "Configurando SSH..."

$sshSource = "$vault\ssh"
$sshDest = "$env:USERPROFILE\.ssh"

if (Test-Path $sshSource) {

    if (Test-Path $sshDest) {
        Remove-Item $sshDest -Recurse -Force
    }

    Copy-Item $sshSource $sshDest -Recurse -Force

    # Permisos seguros
    icacls $sshDest /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null

    Write-Host "SSH listo"
} else {
    Write-Host "No se encontró carpeta SSH en vault"
}

Write-Host ""

# -------------------------
# 4. CONFIGURAR VS CODE
# -------------------------
Write-Host "Configurando VS Code..."

$vscodeUser = "$env:APPDATA\Code\User"

if (!(Test-Path $vscodeUser)) {
    New-Item -ItemType Directory -Path $vscodeUser -Force | Out-Null
}

if (Test-Path "$vault\vscode\settings.json") {
    Copy-Item "$vault\vscode\settings.json" "$vscodeUser\settings.json" -Force
}

Write-Host "VS Code configurado"
Write-Host ""

# -------------------------
# 5. VARIABLES DE ENTORNO
# -------------------------
Write-Host "Configurando PATH..."

$gitPath = "$usbRoot\apps\git\bin"

if (Test-Path $gitPath) {
    $env:PATH = "$gitPath;$env:PATH"
}

Write-Host "PATH listo"
Write-Host ""

# -------------------------
# 6. ABRIR VS CODE
# -------------------------
Write-Host "Abriendo VS Code..."

$vscodeExe = "$usbRoot\apps\vscode\Code.exe"

if (Test-Path $vscodeExe) {
    Start-Process $vscodeExe
} else {
    Write-Host "No se encontró VS Code portable"
}

Write-Host ""
Write-Host "Entorno listo 🚀" -ForegroundColor Green
Write-Host ""
