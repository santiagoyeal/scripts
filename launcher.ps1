$ErrorActionPreference = "Continue"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   CONFIGURANDO ENTORNO PORTABLE" -ForegroundColor Cyan
Write-Host "========================================="
Write-Host ""

# -------------------------
# 0. DETECTAR USB ROOT
# -------------------------
$usbRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "USB ROOT: $usbRoot" -ForegroundColor Gray
Write-Host ""

# -------------------------
# 1. DETECTAR VAULT (MEJORADO REAL)
# -------------------------
Write-Host "Buscando vault de Cryptomator..." -ForegroundColor Cyan

$vault = $null

# Obtener TODAS las unidades reales (incluye red)
$drives = Get-CimInstance Win32_LogicalDisk | Where-Object {
    $_.DriveType -eq 2 -or  # USB
    $_.DriveType -eq 3 -or  # Disco local
    $_.DriveType -eq 4      # RED (Cryptomator)
}

foreach ($drive in $drives) {

    $root = $drive.DeviceID + "\"

    Write-Host "Revisando: $root" -ForegroundColor DarkGray

    if (Test-Path "$root\.devusb") {
        Write-Host "[OK] .devusb encontrado en $root" -ForegroundColor Green
        $vault = $root
        break
    }

    # fallback por estructura
    if ((Test-Path "$root\Desarrollo") -and (Test-Path "$root\scripts")) {
        Write-Host "[OK] Estructura detectada en $root" -ForegroundColor Green
        $vault = $root
        break
    }
}

# EXTRA: detectar rutas tipo UNC (Cryptomator WebDAV)
if (-not $vault) {

    Write-Host "Buscando en rutas UNC (Cryptomator WebDAV)..." -ForegroundColor Yellow

    try {
        $uncPaths = Get-ChildItem "\\cryptomator-vault\" -ErrorAction Stop

        foreach ($p in $uncPaths) {
            $testRoot = $p.FullName + "\"

            if (Test-Path "$testRoot\.devusb") {
                Write-Host "[OK] Vault detectado en $testRoot" -ForegroundColor Green
                $vault = $testRoot
                break
            }
        }
    } catch {
        Write-Host "No se encontraron rutas UNC (normal si no aplica)" -ForegroundColor DarkGray
    }
}

# ERROR FINAL
if (-not $vault) {
    Write-Host ""
    Write-Host "[ERROR] No se encontró el vault." -ForegroundColor Red
    Write-Host "Asegúrate de que Cryptomator esté desbloqueado." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Unidades detectadas:" -ForegroundColor Gray
    $drives | ForEach-Object { Write-Host " - $($_.DeviceID)" }

    return
}

Write-Host ""
Write-Host "[OK] Vault detectado en: $vault" -ForegroundColor Green
Write-Host ""

# -------------------------
# 2. CONFIGURAR GIT
# -------------------------
Write-Host "Configurando Git..." -ForegroundColor Cyan

$gitExe = "$usbRoot\apps\git\bin\git.exe"

if (-not (Test-Path $gitExe)) {
    $gitInPath = Get-Command git -ErrorAction SilentlyContinue
    if ($gitInPath) {
        $gitExe = $gitInPath.Source
        Write-Host "[OK] Usando git desde PATH: $gitExe" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Git portable no encontrado" -ForegroundColor Yellow
        $gitBinDir = Split-Path $gitExe -Parent
        New-Item -ItemType Directory -Path $gitBinDir -Force | Out-Null
        $wrapper = Join-Path $gitBinDir "git.cmd"
        if (-not (Test-Path $wrapper)) {
            '@echo off
 echo Git no encontrado. Instale Git en el sistema o agregue "git" al PATH.' | Out-File -FilePath $wrapper -Encoding ASCII -Force
        }
        $gitExe = $wrapper
    }
}

try {
    & $gitExe config --global user.name "TuNombre"
    & $gitExe config --global user.email "tu@email.com"
    Write-Host "[OK] Git configurado"
} catch {
    Write-Host "[WARN] No se pudo configurar Git (no disponible o fallo)" -ForegroundColor Yellow
}

if (Test-Path "$vault\git\.gitconfig") {
    Copy-Item "$vault\git\.gitconfig" "$env:USERPROFILE\.gitconfig" -Force
    Write-Host "[OK] .gitconfig cargado desde vault"
}

Write-Host ""

# -------------------------
# 3. CONFIGURAR SSH
# -------------------------
Write-Host "Configurando SSH..." -ForegroundColor Cyan

$sshSource = "$vault\ssh"
$sshDest = "$env:USERPROFILE\.ssh"

if (-not (Test-Path $sshSource)) {
    Write-Host "[WARN] No se encontro carpeta SSH en vault. Creando..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $sshSource -Force | Out-Null

    $sshKey = Join-Path $sshSource "id_rsa"
    if (-not (Test-Path $sshKey)) {
        $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue
        if ($sshKeygen) {
            & $sshKeygen -q -t rsa -b 2048 -N "" -f $sshKey | Out-Null
            Write-Host "[OK] Clave SSH generada en vault" -ForegroundColor Green
        } else {
            Write-Host "[WARN] ssh-keygen no disponible. Cree claves en $sshSource manualmente." -ForegroundColor Yellow
        }
    }
}

if (Test-Path $sshDest) {
    Remove-Item $sshDest -Recurse -Force
}

Copy-Item $sshSource $sshDest -Recurse -Force

try {
    icacls $sshDest /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
} catch {}

Write-Host "[OK] SSH listo"

Write-Host ""

# -------------------------
# 4. CONFIGURAR VS CODE
# -------------------------
Write-Host "Configurando VS Code..." -ForegroundColor Cyan

$vscodeUser = "$env:APPDATA\Code\User"

if (!(Test-Path $vscodeUser)) {
    New-Item -ItemType Directory -Path $vscodeUser -Force | Out-Null
}

if (Test-Path "$vault\vscode\settings.json") {
    Copy-Item "$vault\vscode\settings.json" "$vscodeUser\settings.json" -Force
    Write-Host "[OK] settings.json aplicado"
}

Write-Host ""

# -------------------------
# 5. VARIABLES DE ENTORNO
# -------------------------
Write-Host "Configurando PATH..." -ForegroundColor Cyan

$gitPath = "$usbRoot\apps\git\bin"

if (Test-Path $gitPath) {
    $env:PATH = "$gitPath;$env:PATH"
    Write-Host "[OK] PATH actualizado"
}

Write-Host ""

# -------------------------
# 6. ABRIR VS CODE
# -------------------------
Write-Host "Abriendo VS Code..." -ForegroundColor Cyan

$vscodeExe = "$usbRoot\apps\vscode\Code.exe"

$codeCmd = Get-Command code -ErrorAction SilentlyContinue

if (Test-Path $vscodeExe) {
    Start-Process $vscodeExe
    Write-Host "[OK] VS Code iniciado"
} elseif ($codeCmd) {
    Start-Process $codeCmd.Source
    Write-Host "[OK] VS Code (sistema) iniciado"
} else {
    Write-Host "[WARN] No se encontro VS Code portable ni comando 'code' en PATH" -ForegroundColor Yellow
    $vscodeDir = Split-Path $vscodeExe -Parent
    New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    $stub = Join-Path $vscodeDir "Code.cmd"
    if (-not (Test-Path $stub)) {
        '@echo off
        echo VS Code no encontrado. Instale VS Code o copie una version portable en este directorio.' | Out-File -FilePath $stub -Encoding ASCII -Force
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "   ENTORNO LISTO" -ForegroundColor Green
Write-Host "========================================="
Write-Host ""

Read-Host "Presiona ENTER para salir"
