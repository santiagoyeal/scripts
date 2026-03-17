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
    $existingName = ""
    $existingEmail = ""
    try { $existingName = (& $gitExe config --global user.name) -as [string] } catch {}
    try { $existingEmail = (& $gitExe config --global user.email) -as [string] } catch {}

    if ($existingName) {
        $keep = Read-Host "Git user.name actual: '$existingName'. Mantener? [Y/n]"
        if ($keep -match '^[Nn]') {
            $newName = Read-Host "Nuevo user.name para Git:"
            if ($newName) { & $gitExe config --global user.name $newName }
        } else {
            Write-Host "[OK] Manteniendo user.name: $existingName" -ForegroundColor Green
        }
    } else {
        $newName = Read-Host "Introduce user.name para Git (requerido):"
        if ($newName) { & $gitExe config --global user.name $newName }
    }

    if ($existingEmail) {
        $keep = Read-Host "Git user.email actual: '$existingEmail'. Mantener? [Y/n]"
        if ($keep -match '^[Nn]') {
            $newEmail = Read-Host "Nuevo user.email para Git:"
            if ($newEmail) { & $gitExe config --global user.email $newEmail }
        } else {
            Write-Host "[OK] Manteniendo user.email: $existingEmail" -ForegroundColor Green
        }
    } else {
        $newEmail = Read-Host "Introduce user.email para Git (requerido):"
        if ($newEmail) { & $gitExe config --global user.email $newEmail }
    }

    Write-Host "[OK] Git configurado" -ForegroundColor Green
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
}

# Si ya existe una clave en la ubicación del usuario, no la generamos.
if (Test-Path (Join-Path $sshDest "id_ed25519")) {
    Write-Host "[OK] Clave SSH existente encontrada en $sshDest" -ForegroundColor Green
} else {
    $sshKeygenPath = (Get-Command ssh-keygen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    if ($sshKeygenPath) {
        Write-Host "[INFO] Generando nueva clave SSH en la ubicación por defecto ($sshDest) ..." -ForegroundColor Cyan
        & $sshKeygenPath -t ed25519 -C "pc-temporal"
        Write-Host "[OK] Generación completada (ubicación por defecto)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] ssh-keygen no disponible. Cree claves en $sshDest manualmente." -ForegroundColor Yellow
    }

    # Si se generó en la ubicación por defecto, copia una copia al vault para portabilidad
    if (Test-Path (Join-Path $sshDest "id_ed25519")) {
        try {
            Copy-Item -Path (Join-Path $sshDest "*") -Destination $sshSource -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Copia de seguridad de claves al vault: $sshSource" -ForegroundColor Green
        } catch {}
    }
}

# Sincronizar: si el vault tiene claves, sobreescribir la ubicación del usuario; si no, asegurarnos que $sshDest existe y respaldar en vault.
if ((Test-Path $sshSource) -and ((Get-ChildItem $sshSource -Force | Measure-Object).Count -gt 0)) {
    if (Test-Path $sshDest) { Remove-Item $sshDest -Recurse -Force }
    Copy-Item $sshSource $sshDest -Recurse -Force
} else {
    if (-not (Test-Path $sshDest)) { New-Item -ItemType Directory -Path $sshDest -Force | Out-Null }
    if (Test-Path (Join-Path $sshDest "id_ed25519")) {
        try { Copy-Item -Path (Join-Path $sshDest "*") -Destination $sshSource -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
}

try {
    icacls $sshDest /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
} catch {}

# Asegurarse de tener una clave publica para GitHub (ed25519 preferida)
$pubKeyPath = Join-Path $sshDest "id_ed25519.pub"
$privKeyPath = Join-Path $sshDest "id_ed25519"

if (-not (Test-Path $pubKeyPath)) {
    $pubKeyPath = Join-Path $sshDest "id_rsa.pub"
    $privKeyPath = Join-Path $sshDest "id_rsa"
}

if (-not (Test-Path $pubKeyPath)) {
    # Generar par de claves si no existe (usar ubicación por defecto)
    $sshKeygenPath = (Get-Command ssh-keygen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    if ($sshKeygenPath) {
        Write-Host "[INFO] Generando par de claves SSH en la ubicación por defecto ($sshDest)..." -ForegroundColor Cyan
        & $sshKeygenPath -t ed25519 -C "pc-temporal"
        $pubKeyPath = Join-Path $sshDest "id_ed25519.pub"
        Write-Host "[OK] Clave SSH generada en: $pubKeyPath" -ForegroundColor Green
        if (Test-Path $sshSource) {
            try { Copy-Item -Path (Join-Path $sshDest "*") -Destination $sshSource -Recurse -Force -ErrorAction SilentlyContinue } catch {}
        }
    } else {
        Write-Host "[WARN] No se encontro ssh-keygen. Genera una clave manualmente:" -ForegroundColor Yellow
        Write-Host "      ssh-keygen -t ed25519 -f $sshDest\id_ed25519" -ForegroundColor Yellow
    }
}

# Mostrar instrucción para agregar la clave a GitHub
if (Test-Path $pubKeyPath) {
    Write-Host "" 
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host "Clave publica SSH (copiar al portapapeles):" -ForegroundColor Green
    Write-Host "URL: https://github.com/settings/keys" -ForegroundColor Cyan
    Write-Host "" 
    Get-Content $pubKeyPath | ForEach-Object { Write-Host $_ }
    Write-Host "---" -ForegroundColor DarkGray

    # Intentar copiar al portapapeles
    try {
        Get-Content $pubKeyPath | Set-Clipboard
        Write-Host "La clave se copio al portapapeles. Pega en GitHub." -ForegroundColor Green
    } catch {
        Write-Host "No se pudo copiar al portapapeles. Copia manualmente desde el archivo." -ForegroundColor Yellow
    }

    # Probar si la clave está autorizada en GitHub
    try {
        $sshTest = & ssh -T -o BatchMode=yes git@github.com 2>&1
    } catch {
        $sshTest = $_.Exception.Message
    }

    if ($sshTest -match "successfully authenticated" -or $sshTest -match "Hi ") {
        Write-Host "[OK] La clave SSH está autorizada en GitHub." -ForegroundColor Green
    } else {
        Write-Host "[WARN] La clave SSH NO parece estar autorizada en GitHub." -ForegroundColor Yellow
        $resp = Read-Host "Deseas generar una nueva clave y sobrescribir la existente? [y/N]"
        if ($resp -match '^[Yy]') {
            $sshKeygenPath = (Get-Command ssh-keygen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
            if ($sshKeygenPath) {
                Write-Host "Generando nueva clave (sobrescribiendo) en $sshDest ..." -ForegroundColor Cyan
                & $sshKeygenPath -q -t ed25519 -C "pc-temporal" -N "" -f "$privKeyPath" | Out-Null
                $pubKeyPath = "$privKeyPath.pub"
                Write-Host "[OK] Nueva clave generada: $pubKeyPath" -ForegroundColor Green
                try { Get-Content $pubKeyPath | Set-Clipboard; Write-Host "La nueva clave se copio al portapapeles." -ForegroundColor Green } catch {}
                if (Test-Path $sshSource) { try { Copy-Item -Path (Join-Path $sshDest "*") -Destination $sshSource -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
            } else {
                Write-Host "No se encontro ssh-keygen para generar nueva clave." -ForegroundColor Yellow
            }
        } else {
            Write-Host "De acuerdo, no se sobrescribirá la clave. Agrega la clave pública a GitHub manualmente si quieres." -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "[WARN] No se encontro clave publica SSH (id_ed25519.pub o id_rsa.pub)." -ForegroundColor Yellow
    Write-Host "Crea una con: ssh-keygen -t ed25519 -f $sshDest\id_ed25519" -ForegroundColor Yellow
}

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
