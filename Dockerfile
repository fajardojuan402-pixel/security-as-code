FROM python:3.11-slim

WORKDIR /app

# Actualizar herramientas de empaquetado para mitigar CVEs de la imagen base (wheel y jaraco.context)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel jaraco.context

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
ENV PYTHONUNBUFFERED=1
CMD ["python", "src/app.py"]
