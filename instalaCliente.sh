<#
.SYNOPSIS
    Script de instalación y configuración desatendida de Veyon Service (Cliente/Alumno).
.DESCRIPTION
    1. Descarga el instalador oficial de Veyon.
    2. Instala Veyon en modo silencioso (solo servicio, sin consola Master).
    3. Descarga la Clave Pública desde una URL especificada.
    4. Importa la clave y configura Veyon para usar autenticación por clave.
    5. Configura el Firewall de Windows.
.NOTES
    Debes ejecutar este script como ADMINISTRADOR.
#>

# -----------------------------------------------------------
# ⚙️ CONFIGURACIÓN - EDITA ESTA SECCIÓN
# -----------------------------------------------------------

# Nombre de tu par de claves (Debe coincidir con el nombre que diste al crearlas en el Master)
$NombreClave = "Lab_Aula_Informatica" 

# URL directa donde está alojada tu clave PÚBLICA (.pem)
$UrlClavePublica = "http://tu-servidor-o-web.com/public_key.pem"

# URL del instalador de Veyon (Si lo dejas así, descarga la última versión estable)
$UrlInstaller = "https://github.com/veyon/veyon/releases/download/v4.9.0/veyon-4.9.0.0-win64-setup.exe"

# -----------------------------------------------------------
# 🚀 INICIO DEL SCRIPT
# -----------------------------------------------------------

Write-Host "Iniciando despliegue de Veyon Service..." -ForegroundColor Cyan

# 1. Verificación de permisos de Administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script necesita ejecutarse como Administrador."
    Break
}

# Directorios temporales
$TempDir = $env:TEMP
$InstallerPath = "$TempDir\veyon-setup.exe"
$KeyPath = "$TempDir\public_key.pem"

# 2. Descargar Instalador
try {
    Write-Host "Descargando Veyon desde $UrlInstaller..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $UrlInstaller -OutFile $InstallerPath
    Write-Host "Instalador descargado correctamente." -ForegroundColor Green
}
catch {
    Write-Error "Error al descargar el instalador. Verifica tu conexión o la URL."
    Break
}

# 3. Instalar Veyon (Modo Silencioso y Sin Master)
# /S = Silencioso
# /NoMaster = No instala la consola del profesor (ahorra espacio y evita confusiones)
# /NoStart = No iniciar todavía para poder configurar
Write-Host "Instalando Veyon (esto puede tardar unos minutos)..." -ForegroundColor Yellow
Start-Process -FilePath $InstallerPath -ArgumentList "/S", "/NoMaster", "/NoStart" -Wait -NoNewWindow

# Verificar si se instaló correctamente buscando el CLI
$VeyonCliPath = "C:\Program Files\Veyon\veyon-cli.exe"
if (-not (Test-Path $VeyonCliPath)) {
    Write-Error "No se encontró veyon-cli.exe. La instalación pudo haber fallado."
    Break
}

# 4. Descargar la Clave Pública
try {
    Write-Host "Descargando clave pública..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $UrlClavePublica -OutFile $KeyPath
    Write-Host "Clave descargada." -ForegroundColor Green
}
catch {
    Write-Error "Error al descargar la clave pública. Verifica la URL: $UrlClavePublica"
    Break
}

# 5. Configuración de Veyon mediante CLI
Write-Host "Configurando Veyon..." -ForegroundColor Yellow

# Eliminar claves anteriores si existen para evitar conflictos (opcional)
& $VeyonCliPath authkeys delete $NombreClave *>$null

# Importar la nueva clave pública
& $VeyonCliPath authkeys import $NombreClave $KeyPath
if ($LASTEXITCODE -eq 0) {
    Write-Host "Clave '$NombreClave' importada exitosamente." -ForegroundColor Green
} else {
    Write-Error "Fallo al importar la clave."
}

# Configurar el método de autenticación para usar Archivo de Clave (KeyFile)
# Esto es CRÍTICO. Si no se pone, usa LogonAuthentication por defecto.
& $VeyonCliPath config set Authentication/Method KeyFile

# Asegurar que el servicio arranque automáticamente
Set-Service -Name "VeyonService" -StartupType Automatic

# 6. Reglas de Firewall (Importante para que el Master vea al Alumno)
Write-Host "Abriendo puertos en Firewall..." -ForegroundColor Yellow
# Veyon usa el puerto 11100 por defecto para el servicio
New-NetFirewallRule -DisplayName "Veyon Service" -Direction Inbound -LocalPort 11100 -Protocol TCP -Action Allow -Program "C:\Program Files\Veyon\veyon-service.exe" -ErrorAction SilentlyContinue | Out-Null

# 7. Finalización y Limpieza
Write-Host "Iniciando servicio Veyon..." -ForegroundColor Yellow
& $VeyonCliPath service start

# Borrar archivos temporales
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
Remove-Item $KeyPath -Force -ErrorAction SilentlyContinue

Write-Host "`n-------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  ¡INSTALACIÓN COMPLETADA CON ÉXITO! " -ForegroundColor Green
Write-Host "  El ordenador está listo para ser supervisado."
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan

# Pausa para que leas el resultado si lo lanzaste con doble clic
Read-Host "Presiona Enter para salir"