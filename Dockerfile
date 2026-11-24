FROM python:3.11-slim

WORKDIR /app

# Actualizar paquetes del sistema operativo (Debian) para corregir vulnerabilidades en libpam y util-linux
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Actualizar herramientas de empaquetado de Python para mitigar CVE-2025-47273 en setuptools
RUN pip install --no-cache-dir --upgrade pip "setuptools>=78.1.1" wheel jaraco.context

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
ENV PYTHONUNBUFFERED=1
CMD ["python", "src/app.py"]
