FROM python:3.11-slim

WORKDIR /app

# 1. Actualizar librerías base del sistema operativo (Debian)
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# 2. Instalar dependencias de la aplicación
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y setuptools wheel

# 3. Copiar código de la aplicación
COPY src/ ./src/
ENV PYTHONUNBUFFERED=1
CMD ["python", "src/app.py"]
