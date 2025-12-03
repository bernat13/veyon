#!/bin/bash

# ==============================================================================
# SCRIPT DE INSTALACIÓN DESATENDIDA DE VEYON SERVICE (CLIENTE) PARA LINUX MINT
# ==============================================================================
# Descripción:
# 1. Agrega el repositorio oficial (PPA) de Veyon para tener la última versión.
# 2. Instala Veyon.
# 3. Descarga la clave pública desde una URL.
# 4. Configura Veyon para autenticación por clave y ajusta el firewall (UFW).
# ==============================================================================

# --- CONFIGURACIÓN (EDITA ESTO) ---
NOMBRE_CLAVE="Lab_Aula_Informatica"
URL_CLAVE_PUBLICA="http://tu-servidor-o-web.com/public_key.pem"
# ----------------------------------

# Definición de colores para la salida
VERDE='\033[0;32m'
AZUL='\033[0;36m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${AZUL}======================================================${NC}"
echo -e "${AZUL}   INICIANDO INSTALACIÓN DE VEYON (CLIENTE LINUX)    ${NC}"
echo -e "${AZUL}======================================================${NC}"

# 1. Comprobar si somos root (Administrador)
if [ "$EUID" -ne 0 ]; then
  echo -e "${ROJO}[ERROR] Por favor, ejecuta este script como root (sudo).${NC}"
  exit 1
fi

# 2. Agregar repositorio oficial (PPA) y actualizar
# Esto asegura que no instalamos una versión obsoleta del repositorio de Mint por defecto
echo -e "${AMARILLO}[INFO] Agregando repositorio oficial de Veyon...${NC}"
add-apt-repository ppa:veyon/stable -y > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${VERDE}[OK] Repositorio agregado.${NC}"
else
    echo -e "${ROJO}[ERROR] Falló al agregar el repositorio.${NC}"
    exit 1
fi

echo -e "${AMARILLO}[INFO] Actualizando lista de paquetes...${NC}"
apt-get update -qq

# 3. Instalar Veyon
echo -e "${AMARILLO}[INFO] Instalando Veyon Service...${NC}"
apt-get install veyon -y -qq
if [ $? -eq 0 ]; then
    echo -e "${VERDE}[OK] Veyon instalado correctamente.${NC}"
else
    echo -e "${ROJO}[ERROR] Falló la instalación de Veyon.${NC}"
    exit 1
fi

# 4. Detener el servicio momentáneamente para configurar
systemctl stop veyon.service

# 5. Descargar la Clave Pública
echo -e "${AMARILLO}[INFO] Descargando clave pública desde $URL_CLAVE_PUBLICA...${NC}"
wget -q -O /tmp/public_key.pem "$URL_CLAVE_PUBLICA"

if [ -f /tmp/public_key.pem ]; then
    echo -e "${VERDE}[OK] Clave descargada.${NC}"
else
    echo -e "${ROJO}[ERROR] No se pudo descargar la clave. Verifica la URL.${NC}"
    exit 1
fi

# 6. Configurar Veyon (veyon-cli)
echo -e "${AMARILLO}[INFO] Aplicando configuración...${NC}"

# Borrar claves viejas si existen para evitar conflictos
veyon-cli authkeys delete "$NOMBRE_CLAVE" > /dev/null 2>&1

# Importar la nueva clave
veyon-cli authkeys import "$NOMBRE_CLAVE" /tmp/public_key.pem
if [ $? -eq 0 ]; then
    echo -e "${VERDE}[OK] Clave '$NOMBRE_CLAVE' importada.${NC}"
else
    echo -e "${ROJO}[ERROR] Falló la importación de la clave.${NC}"
fi

# Configurar método de autenticación a KeyFile (Archivo de clave)
veyon-cli config set Authentication/Method KeyFile

# 7. Configurar Firewall (UFW)
# Veyon necesita el puerto 11100 TCP abierto
if command -v ufw > /dev/null; then
    echo -e "${AMARILLO}[INFO] Configurando Firewall (UFW)...${NC}"
    ufw allow 11100/tcp comment 'Veyon Service' > /dev/null
    echo -e "${VERDE}[OK] Puerto 11100 abierto en UFW.${NC}"
else
    echo -e "${AMARILLO}[AVISO] UFW no está instalado. Asegúrate de abrir el puerto 11100 manualmente si usas otro firewall.${NC}"
fi

# 8. Limpieza y Reinicio del servicio
rm /tmp/public_key.pem
echo -e "${AMARILLO}[INFO] Iniciando servicio Veyon...${NC}"
systemctl enable veyon.service > /dev/null 2>&1
systemctl start veyon.service

echo -e "${AZUL}======================================================${NC}"
echo -e "${VERDE}   ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!             ${NC}"
echo -e "${AZUL}======================================================${NC}"