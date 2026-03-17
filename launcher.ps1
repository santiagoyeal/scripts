$ErrorActionPreference = "SilentlyContinue"

Write-Host "Configurando entorno portable..." -ForegroundColor Cyan

# Detectar ruta del USB
$usbRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Ruta del vault montado (AJUSTA la letra si cambia)
$vault = "X:\"   # <- IMPORTANTE

# -------------------------
# 1. CONFIGURAR GIT
# -------------------------
Write-Host "Configurando Git..."

$gitExe = "$usbRoot\apps\git\bin\git.exe"

& $gitExe config --global user.name "TuNombre"
& $gitExe config --global user.email "tu@email.com"

# Usar gitconfig desde vault
Copy-Item "$vault\git\.gitconfig" "$env:USERPROFILE\.gitconfig" -Force

# -------------------------
# 2. CONFIGURAR SSH
# -------------------------
Write-Host "Configurando SSH..."

$sshSource = "$vault\ssh"
$sshDest = "$env:USERPROFILE\.ssh"

if (Test-Path $sshDest) {
    Remove-Item $sshDest -Recurse -Force
}

Copy-Item $sshSource $sshDest -Recurse -Force

# Permisos (importante)
icacls $sshDest /inheritance:r /grant:r "$($env:USERNAME):(R,W)"

# -------------------------
# 3. CONFIGURAR VS CODE
# -------------------------
Write-Host "Configurando VS Code..."

$vscodeUser = "$env:APPDATA\Code\User"

if (!(Test-Path $vscodeUser)) {
    New-Item -ItemType Directory -Path $vscodeUser -Force
}

Copy-Item "$vault\vscode\settings.json" "$vscodeUser\settings.json" -Force

# -------------------------
# 4. VARIABLES DE ENTORNO TEMPORALES
# -------------------------
Write-Host "Configurando PATH..."

$env:PATH = "$usbRoot\apps\git\bin;$env:PATH"

# -------------------------
# 5. ABRIR VS CODE
# -------------------------
Write-Host "Abriendo VS Code..."

Start-Process "$usbRoot\apps\vscode\Code.exe"

Write-Host ""
Write-Host "Entorno listo 🚀" -ForegroundColor Green
