"""Aplicación mínima para ilustrar configuración segura por entorno."""

import os
from config import APP_API_TOKEN


def main() -> None:
    token = os.getenv("APP_API_TOKEN", APP_API_TOKEN)
    if not token:
        print("APP_API_TOKEN no está configurado.")
        return

    # No imprimir el token ni incluirlo en logs.
    print("Aplicación de demostración iniciada.")
    print(f"Token configurado: {'sí' if bool(token) else 'no'}")


if __name__ == "__main__":
    main()
