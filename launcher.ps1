$ErrorActionPreference = "SilentlyContinue"

Write-Host "Configurando entorno portable..." -ForegroundColor Cyan
Write-Host ""

# -------------------------
# 0. DETECTAR USB ROOT
# -------------------------
$usbRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# -------------------------
# 1. DETECTAR VAULT AUTOMÁTICAMENTE (MEJORADO)
# -------------------------
Write-Host "Buscando vault de Cryptomator..." -ForegroundColor Cyan

$vault = $null

# 1️⃣ Buscar en unidades normales (C:, D:, etc.)
$drives = Get-PSDrive -PSProvider FileSystem

foreach ($drive in $drives) {

    $root = $drive.Root

    if (Test-Path $root) {

        if (Test-Path "$root\.devusb") {
            $vault = $root
            break
        }

        # fallback por estructura
        if (Test-Path "$root\Desarrollo" -and Test-Path "$root\scripts") {
            $vault = $root
            break
        }
    }
}

# 2️⃣ Buscar en rutas tipo Cryptomator (WebDAV)
if (-not $vault) {

    Write-Host "Buscando rutas tipo Cryptomator..." -ForegroundColor Yellow

    try {
        $cryptPaths = Get-ChildItem "\\cryptomator-vault\" -ErrorAction Stop

        foreach ($p in $cryptPaths) {

            $testRoot = $p.FullName

            if (Test-Path "$testRoot\.devusb") {
                $vault = $testRoot
                break
            }
        }
    } catch {
        # No pasa nada si no existe la ruta
    }
}

# 3️⃣ FALLBACK FINAL (si sabes que es D:)
if (-not $vault) {

    if (Test-Path "D:\.devusb") {
        $vault = "D:\"
    }
}

# ERROR FINAL
if (-not $vault) {
    Write-Host "ERROR: No se encontró el vault." -ForegroundColor Red
    Write-Host "Verifica que esté abierto en Cryptomator." -ForegroundColor Yellow

    Write-Host "Unidades detectadas:" -ForegroundColor Gray
    $drives | ForEach-Object { Write-Host " - $($_.Root)" }

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
