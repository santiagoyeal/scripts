$ErrorActionPreference = "Continue"

Write-Host "Iniciando limpieza de informacion de desarrollo..."
Write-Host ""

# 1 Borrar historial PowerShell
try {
    $psHistory = (Get-PSReadlineOption).HistorySavePath
    if (Test-Path $psHistory) {
        Remove-Item $psHistory -Force
        Write-Host "OK Historial de PowerShell eliminado"
    } else {
        Write-Host "INFO No existe historial de PowerShell"
    }
} catch {
    Write-Host "ERROR limpiando historial PowerShell"
}

# 2 Borrar historial Git Bash
try {
    $bashHistory = "$env:USERPROFILE\.bash_history"
    if (Test-Path $bashHistory) {
        Remove-Item $bashHistory -Force
        Write-Host "OK Historial de Git Bash eliminado"
    } else {
        Write-Host "INFO No existe historial de Git Bash"
    }
} catch {
    Write-Host "ERROR eliminando bash history"
}

# 3 Borrar configuracion global Git
try {
    $gitConfig = "$env:USERPROFILE\.gitconfig"
    if (Test-Path $gitConfig) {
        Remove-Item $gitConfig -Force
        Write-Host "OK .gitconfig eliminado"
    } else {
        Write-Host "INFO No existe .gitconfig"
    }
} catch {
    Write-Host "ERROR eliminando gitconfig"
}

# 4 Borrar llaves SSH
try {
    $sshFolder = "$env:USERPROFILE\.ssh"
    if (Test-Path $sshFolder) {
        Remove-Item $sshFolder -Recurse -Force
        Write-Host "OK llaves SSH eliminadas"
    } else {
        Write-Host "INFO No existe carpeta .ssh"
    }
} catch {
    Write-Host "ERROR eliminando SSH"
}

# 5 Borrar screenshots
try {
    $screenshots = "$env:USERPROFILE\Pictures\Screenshots"
    if (Test-Path $screenshots) {
        Remove-Item "$screenshots\*" -Recurse -Force
        Write-Host "OK screenshots eliminados"
    } else {
        Write-Host "INFO no existe carpeta screenshots"
    }
} catch {
    Write-Host "ERROR eliminando screenshots"
}

# 6 Eliminar credenciales GitHub
try {
    $creds = cmdkey /list | Select-String "github"
    foreach ($cred in $creds) {
        $target = $cred.ToString().Split(":")[1].Trim()
        cmdkey /delete:$target | Out-Null
    }
    Write-Host "OK credenciales GitHub eliminadas"
} catch {
    Write-Host "ERROR eliminando credenciales GitHub"
}

# 7 Vaciar papelera
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "OK papelera de reciclaje vaciada"
} catch {
    Write-Host "ERROR vaciando papelera"
}

# 8 Limpiar datos de Arc Browser

# 8 Limpiar completamente datos de Arc Browser (historial, sesiones, contraseñas y extension Bitwarden)

$bitwardenExtensionId = "nngceckbapebfimnlniiiahkandclblb"

try {

    Write-Host "Cerrando Arc Browser..."
    Get-Process arc -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2

    $arcPath = "$env:LOCALAPPDATA\Packages"
    $arcFolders = Get-ChildItem $arcPath -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Arc*" }

    foreach ($folder in $arcFolders) {

        $userDataRoot = "$($folder.FullName)\LocalCache\Local\Arc\User Data"

        if (Test-Path $userDataRoot) {
            $profiles = Get-ChildItem $userDataRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }

            foreach ($profile in $profiles) {
                $userData = $profile.FullName

                # historial
                Remove-Item "$userData\History*" -Force -ErrorAction SilentlyContinue

                # cache
                Remove-Item "$userData\Cache" -Recurse -Force -ErrorAction SilentlyContinue

                # cookies
                Remove-Item "$userData\Network\Cookies*" -Force -ErrorAction SilentlyContinue

                # contraseñas guardadas
                Remove-Item "$userData\Login Data*" -Force -ErrorAction SilentlyContinue

                # autofill / datos de formularios
                Remove-Item "$userData\Web Data*" -Force -ErrorAction SilentlyContinue

                # almacenamiento de sesiones
                Remove-Item "$userData\Local Storage" -Recurse -Force -ErrorAction SilentlyContinue

                # tokens de sitios (IndexedDB)
                Remove-Item "$userData\IndexedDB" -Recurse -Force -ErrorAction SilentlyContinue

                # datos de extension Bitwarden (incluye correo/sesion de extension)
                Remove-Item "$userData\Local Extension Settings\$bitwardenExtensionId" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "$userData\Sync Extension Settings\$bitwardenExtensionId" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "$userData\IndexedDB\chrome-extension_$($bitwardenExtensionId)_0.indexeddb.leveldb" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "OK Arc limpiado (historial, sesiones, cookies, contraseñas y datos de Bitwarden)"

} catch {

    Write-Host "ERROR limpiando Arc Browser"

}
try {
    Write-Host ""
    Write-Host "Cerrando Word y Excel para limpiar recientes..."
    Get-Process WINWORD, EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $officeRecent = "$env:APPDATA\Microsoft\Office\Recent"
    if (Test-Path $officeRecent) {
        Remove-Item "$officeRecent\*" -Recurse -Force -ErrorAction SilentlyContinue
    }

    $officeRoot = "HKCU:\Software\Microsoft\Office"
    if (Test-Path $officeRoot) {
        $versions = Get-ChildItem $officeRoot -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\d+\.\d+$' }

        foreach ($ver in $versions) {
            foreach ($app in @("Word", "Excel")) {
                $appRoot = Join-Path $ver.PSPath $app
                if (-not (Test-Path $appRoot)) { continue }

                $mruKeys = Get-ChildItem $appRoot -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.PSChildName -like "*MRU*" }

                foreach ($k in $mruKeys) {
                    $valueNames = (Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue |
                        Get-Member -MemberType NoteProperty |
                        Select-Object -ExpandProperty Name)

                    foreach ($name in $valueNames) {
                        Remove-ItemProperty -LiteralPath $k.PSPath -Name $name -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    Write-Host "OK recientes de Word/Excel eliminados"
} catch {
    Write-Host "ERROR limpiando recientes de Word/Excel"
}
try {
    Write-Host ""
    Write-Host "Limpiando elementos recientes de Windows y Jump Lists..."

    $recent = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recent) {
        Get-ChildItem $recent -Force -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "OK elementos recientes eliminados"
    } else {
        Write-Host "INFO No existe carpeta Recent"
    }

    $auto = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    $custom = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
    foreach ($p in @($auto, $custom)) {
        if (Test-Path $p) {
            Remove-Item "$p\*" -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "OK Jump Lists eliminadas"

} catch {
    Write-Host "ERROR limpiando recientes/Jump Lists"
}

try {
    Write-Host ""
    Write-Host "Cerrando y limpiando datos de VS Code (recientes y workspace storage)..."
    Get-Process Code, 'Code - Insiders' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $vscApp = "$env:APPDATA\Code"
    if (Test-Path $vscApp) {
        $recentFiles = @("$vscApp\User\recentlyOpened.json", "$vscApp\User\recentlyOpenedWorkspaces.json", "$vscApp\User\recentlyOpenedFolders.json")
        foreach ($f in $recentFiles) {
            if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
        }

        $dirs = @("$vscApp\User\workspaceStorage", "$vscApp\Backups", "$vscApp\Local Storage", "$vscApp\Storage", "$vscApp\User\globalStorage")
        foreach ($d in $dirs) {
            if (Test-Path $d) { Remove-Item "$d\*" -Recurse -Force -ErrorAction SilentlyContinue }
        }

        Write-Host "OK VS Code limpiado (recientes y workspace storage)"
    } else {
        Write-Host "INFO No se encontró datos de VS Code en AppData"
    }

} catch {
    Write-Host "ERROR limpiando VS Code"
}
Write-Host ""
Write-Host "Limpieza terminada."
Write-Host ""

Read-Host "Presiona ENTER para cerrar"
