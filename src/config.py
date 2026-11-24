"""Configuración segura: lectura de credenciales desde variables de entorno."""

import os

# Obtención del token desde la variable de entorno sin credenciales embebidas
APP_API_TOKEN = os.getenv("APP_API_TOKEN", "")
