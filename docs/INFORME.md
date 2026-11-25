# Informe individual — Laboratorio Security as Code

## 1. Datos de entrega
- **Estudiante:** Juan Fajardo (`fajardojuan402-pixel`)
- **Repositorio:** `https://github.com/fajardojuan402-pixel/security-as-code.git`
- **Rama de trabajo:** `feature/security-lab`
- **Pull Request:** `https://github.com/fajardojuan402-pixel/security-as-code/pull/1`
- **Fecha de realización:** 24 de noviembre de 2026

---

## 2. Análisis inicial

A continuación se resumen los hallazgos de seguridad identificados en el estado base del proyecto mediante las herramientas de análisis estático y escaneo de vulnerabilidades:

| Herramienta | Archivo/recurso | Hallazgo / regla / CVE | Severidad | Riesgo | Evidencia |
|---|---|---|---|---|---|
| **Gitleaks** (v8.30.1) | `src/config.py` (línea 5) | Regla `github-pat` / `generic-api-key` (`ghp_000000000000000000000000000000000000`) | **ALTA** | Exposición de credenciales/tokens en el repositorio de código. Si fuese un secreto real, permitiría a cualquier persona con acceso al repositorio autenticarse y comprometer servicios de GitHub o APIs externas. | `evidence/gitleaks-before.png`<br>`evidence/gitleaks-before.txt` |
| **Checkov** (v3.4.10) | `infra/main.tf`<br>- `aws_s3_bucket.lab_data`<br>- `aws_s3_bucket_acl.lab_data_acl`<br>- `aws_s3_bucket_public_access_block.lab_data` | `CKV_AWS_20`: Bucket ACL allows public READ<br>`CKV_AWS_53`: Block public ACLs disabled<br>`CKV_AWS_54`: Block public policy disabled<br>`CKV_AWS_55`: Ignore public ACLs disabled<br>`CKV_AWS_56`: Restrict public buckets disabled<br>`CKV2_AWS_6`: Public access block missing<br>`CKV_AWS_21`: S3 Bucket versioning disabled<br>`CKV_AWS_145`: S3 not KMS encrypted | **ALTA / CRÍTICA** | Fuga masiva de información confidencial hacia internet público (Data Leak), manipulación de datos sin trazabilidad o eliminación accidental/maliciosa de objetos sin versión histórica. | `evidence/checkov-before.png`<br>`evidence/checkov-before.txt` |
| **Trivy** (v0.76.2) | `requirements.txt` (`urllib3==1.25.3`) | **7 CVEs detectadas:**<br>- `CVE-2020-7212`<br>- `CVE-2023-43804`<br>- `CVE-2025-66418`<br>- `CVE-2025-66471`<br>- `CVE-2026-21441`<br>- `CVE-2026-44431`<br>- `CVE-2026-97689` | **HIGH** | Denegación de servicio (DoS) por consumo de CPU/memoria no acotada en descompresión HTTP, bypass de protecciones contra "decompression bombs", y fuga de credenciales/cookies en redirecciones HTTP cross-origin. | `evidence/trivy-before.png`<br>`evidence/trivy-before.txt` |

---

## 3. Correcciones realizadas

### 3.1. Detección y gestión de secretos (Gitleaks)
- **Causa:** El archivo `src/config.py` contenía un token asignado directamente como constante (`APP_API_TOKEN = "ghp_000000000000000000000000000000000000"`).
- **Cambio realizado:** 
  1. Se eliminó el string embebido y se reemplazó por la lectura dinámica de la variable de entorno mediante `os.getenv("APP_API_TOKEN", "")`.
  2. Se aseguró que `src/app.py` valide la presencia de la variable sin exponer su valor en pantalla ni en logs.
  3. Se confirmó la exclusión de `.env` y variantes en `.gitignore`.
- **Por qué reduce el riesgo:** Al desacoplar la configuración sensible del código fuente, ningún secreto queda almacenado en el sistema de control de versiones (Git), evitando que quede expuesto a colaboradores, forks o atacantes.
- **Resultado del nuevo análisis:** Gitleaks reporta `0 leaks found` (`evidence/gitleaks-after.png` y `evidence/gitleaks-after.txt`).

### 3.2. Seguridad en Infraestructura como Código (Checkov)
- **Causa:** `infra/main.tf` configuraba una ACL `public-read` y deshabilitaba intencionalmente los 4 controles del bloque de acceso público (`block_public_* = false`, `ignore_public_acls = false`), carecía de cifrado KMS gestionado, sin versionamiento y sin ciclo de vida de objetos.
- **Cambio realizado:**
  1. **Control de Acceso Público:** Se configuraron en `true` los cuatro parámetros de `aws_s3_bucket_public_access_block` (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`).
  2. **Propiedad y Eliminación de ACLs:** Se agregó `aws_s3_bucket_ownership_controls` con `BucketOwnerEnforced`, deshabilitando por completo las ACLs en favor de IAM policies (estándar recomendado por AWS). Se removió el recurso `aws_s3_bucket_acl` inseguro.
  3. **Versionamiento:** Se activó `aws_s3_bucket_versioning` con `status = "Enabled"`.
  4. **Cifrado KMS Dedicado:** Se definió un recurso `aws_kms_key` con rotación automática habilitada (`enable_key_rotation = true`) y política de clave restringida al Account Root, vinculado al bucket mediante `aws_s3_bucket_server_side_encryption_configuration` (`sse_algorithm = "aws:kms"`).
  5. **Ciclo de vida:** Se añadió `aws_s3_bucket_lifecycle_configuration` para cancelar cargas multipart fallidas tras 7 días.
  6. **Supresiones justificadas (`#checkov:skip`):** Se suprimieron explícitamente `CKV_AWS_144` (Cross-region replication) y `CKV_AWS_18` (Access logging hacia bucket destino externo) y `CKV2_AWS_62` (Notificaciones de eventos), documentando que requieren componentes y costos de infraestructura fuera del alcance de este laboratorio unitario.
- **Por qué reduce el riesgo:** Cierra completamente la superficie de ataque pública a nivel de red y políticas de AWS S3, asegura confidencialidad mediante KMS con rotación, previene ransomware/borrado accidental mediante versionado y evita fugas de costos por fragmentos de subida abandonados.
- **Resultado del nuevo análisis:** Checkov finaliza con **18 controles aprobados (PASSED), 0 fallidos (FAILED) y 3 suprimidos justificadamente (SKIPPED)** con código de salida `0` (`evidence/checkov-after.png` y `evidence/checkov-after.txt`).

### 3.3. Vulnerabilidades en dependencias y contenedores (Trivy)
- **Causa:** El archivo `requirements.txt` fijaba `urllib3==1.25.3`, una versión obsoleta afectada por 7 vulnerabilidades de severidad alta.
- **Cambio realizado:** Se actualizó `requirements.txt` a la versión `urllib3==2.8.0` (versión libre de las CVEs reportadas).
- **Por qué reduce el riesgo:** Se aplican los parches de seguridad desarrollados por los mantenedores de la biblioteca, mitigando ataques de Denegación de Servicio (DoS) por compresión no controlada y protegiendo cabeceras sensibles (`Authorization`, `Cookie`) en redirecciones HTTP entre dominios.
- **Resultado del nuevo análisis:** Trivy analiza `requirements.txt` reportando **0 vulnerabilidades (Clean)** (`evidence/trivy-after.png` y `evidence/trivy-after.txt`).

---

## 4. Integración continua

### 4.1. Análisis del workflow `.github/workflows/security.yml`
El pipeline de GitHub Actions automatiza el paradigma de **Security as Code** mediante tres fases de escaneo ejecutadas en contenedores Ubuntu:

```
[Disparadores: Pull Request a main / Push a main]
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
[gitleaks]  [checkov]   [trivy]
  Secretos     IaC      Imagen Docker
```

- **Disparadores (Triggers):**
  - `pull_request: branches: [ "main" ]`: Evalúa cada propuesta de cambio antes de que se fusione con la rama principal, actuando como compuerta de calidad (Quality Gate).
  - `push: branches: [ "main" ]`: Verifica la integridad de la rama principal tras cualquier fusión directa.
- **Principio de Privilegio Mínimo:**
  - Se declara globalmente `permissions: contents: read`, asegurando que el token de ejecución `GITHUB_TOKEN` no tenga permisos de escritura en el repositorio ni de administración.
- **Jobs implementados:**
  1. `gitleaks`: Realiza un checkout completo (`fetch-depth: 0`) para inspeccionar todo el historial de commits y cambios en el árbol de trabajo mediante `gitleaks/gitleaks-action@v2`.
  2. `checkov`: Analiza estáticamente el directorio `infra/` enfocado en el framework `terraform` usando `bridgecrewio/checkov-action@v12`.
  3. `trivy`: Compila la imagen Docker del proyecto (`docker build -t security-as-code-lab:${{ github.sha }} .`) y ejecuta el escáner `aquasecurity/trivy-action@0.28.0` con severidad `HIGH,CRITICAL` y `exit-code: '1'`, garantizando que la presencia de vulnerabilidades críticas aborte el despliegue.

### 4.2. Resultado del Pull Request
Al abrir el Pull Request desde `feature/security-lab` hacia `main`:
- Los tres jobs se ejecutan concurrentemente.
- Con las correcciones implementadas, los tres análisis terminan en estado exitoso (**verde / check verde**).
- El Pull Request queda habilitado para merge sin advertencias de seguridad (`evidence/github-actions.png` y `evidence/pull-request.png`).

---

## 5. Decisiones del desarrollador

En este laboratorio se tomaron deliberadamente dos decisiones técnicas críticas:

1. **Gestión de supresiones en Checkov (`#checkov:skip`) frente a la sobredimensión de infraestructura:**
   - *Situación:* Checkov sugería advertencias para `CKV_AWS_144` (Cross-Region Replication) y `CKV_AWS_18` (Access Logging).
   - *Decisión tomada:* En lugar de crear un segundo bucket en otra región y un bucket de logging (lo que aumentaría drásticamente los costos de nube, la complejidad de red y el tiempo de despliegue para una aplicación mínima), se tomó la decisión consciente de **suprimir estas reglas a nivel de recurso** documentando la justificación técnica en el código.
   - *Justificación:* En seguridad es tan peligroso ignorar alertas como aplicar ciegamente recomendaciones que no se ajustan al modelo de amenazas del servicio ni a su presupuesto operativo.
2. **Adopción de `BucketOwnerEnforced` en lugar de una ACL `private`:**
   - *Situación:* La documentación clásica sugiere cambiar `acl = "public-read"` por `acl = "private"`.
   - *Decisión tomada:* Se eliminó el recurso de ACL y se implementó `aws_s3_bucket_ownership_controls` con `rule { object_ownership = "BucketOwnerEnforced" }`.
   - *Justificación:* AWS considera las ACLs un mecanismo heredado propenso a desconfiguraciones accidentales. Deshabilitar las ACLs por completo garantiza que las políticas de IAM y bucket policies sean la única fuente de verdad para el control de acceso, cumpliendo con la política más estricta `CKV2_AWS_65`.
3. **Manejo de variables de entorno sin archivo `.env` en el repositorio:**
   - *Situación:* Algunos asistentes sugieren proveer un archivo `.env` con valores por defecto para facilitar la ejecución.
   - *Decisión tomada:* No incluir ningún archivo `.env` en el repositorio y mantener `.env` estrictamente ignorado en `.gitignore`, ofreciendo únicamente `.env.example` con marcadores vacíos.
   - *Justificación:* Previene que durante el ciclo de vida del desarrollo algún programador reemplace accidentalmente valores locales con credenciales de prueba que luego terminen indexadas en Git.

---

## 6. Evidencias

Todas las evidencias se encuentran archivadas en la carpeta `evidence/`:

- **Gitleaks Antes:**
  - Registro de texto: [`evidence/gitleaks-before.txt`](../evidence/gitleaks-before.txt)
  - Captura terminal: ![Gitleaks Antes](../evidence/gitleaks-before.png)
- **Gitleaks Después:**
  - Registro de texto: [`evidence/gitleaks-after.txt`](../evidence/gitleaks-after.txt)
  - Captura terminal: ![Gitleaks Después](../evidence/gitleaks-after.png)
- **Checkov Antes:**
  - Registro de texto: [`evidence/checkov-before.txt`](../evidence/checkov-before.txt)
  - Captura terminal: ![Checkov Antes](../evidence/checkov-before.png)
- **Checkov Después:**
  - Registro de texto: [`evidence/checkov-after.txt`](../evidence/checkov-after.txt)
  - Captura terminal: ![Checkov Después](../evidence/checkov-after.png)
- **Trivy Antes:**
  - Registro de texto: [`evidence/trivy-before.txt`](../evidence/trivy-before.txt)
  - Captura terminal: ![Trivy Antes](../evidence/trivy-before.png)
- **Trivy Después:**
  - Registro de texto: [`evidence/trivy-after.txt`](../evidence/trivy-after.txt)
  - Captura terminal: ![Trivy Después](../evidence/trivy-after.png)
- **GitHub Actions (Pipeline en verde):**
  - Captura del flujo: ![GitHub Actions](../evidence/github-actions.png)
- **Pull Request (Integración y checks aprobados):**
  - Captura de Pull Request: ![Pull Request](../evidence/pull-request.png)

---

## 7. Reflexión

### 1. ¿Qué diferencia hay entre encontrar un problema y prevenir que vuelva a introducirse?
Encontrar un problema (enfoque *reactivo*) se limita a una auditoría puntual o escaneo tardío sobre el código existente; si no se establecen controles, cualquier nuevo commit o desarrollador puede volver a cometer el mismo error (por ejemplo, subir otra credencial o reactivar una ACL pública). 

Prevenir que vuelva a introducirse (enfoque *preventivo / Security as Code*) implica integrar mecanismos automatizados en el ciclo de vida del desarrollo: **pre-commit hooks** en el equipo local, **compuertas de CI/CD** (GitHub Actions) que bloquean los merges si se detectan secretos o políticas inseguras, y **políticas como código** que hacen fallar las construcciones antes de llegar a cualquier entorno.

### 2. ¿Qué riesgos no cubren estos tres escáneres?
Aunque Gitleaks, Checkov y Trivy forman una tríada de defensa muy robusta, no cubren:
- **Vulnerabilidades lógicas del negocio:** Fallos en el control de acceso funcional (ej. un usuario cambiando el ID en una URL para ver la cuenta de otro / BOLA/IDOR).
- **Vulnerabilidades en tiempo de ejecución (DAST / IAST):** SQL Injections complejas o vulnerabilidades dependientes del estado de la memoria o del flujo de entrada HTTP.
- **Ataques de ingeniería social o phishing:** Compromiso de credenciales de desarrolladores fuera del código.
- **Ataques a la cadena de suministro de paquetes no identificados:** Paquetes maliciosos tipo *typosquatting* o *zero-days* que aún no tienen una CVE registrada en la base de datos de Trivy.
- **Configuración en caliente (Drift):** Cambios manuales realizados directamente en la consola web de AWS que difieren del código Terraform versionado.

### 3. ¿Por qué no basta con que el pipeline esté en verde?
Un pipeline en verde indica únicamente que el código **superó los umbrales de las reglas previamente configuradas**. Sin embargo:
- Puede haber reglas desactivadas o mal configuradas.
- Existen falsos negativos si las herramientas no reconocen formatos propietarios de credenciales o bibliotecas no indexadas.
- La ausencia de errores sintácticos o de configuración no garantiza que la arquitectura global sea resiliente ni que el diseño sea seguro.
- Un ataque de día cero (*Zero-Day*) no disparará alertas porque no existe aún una firma o CVE en los escáneres estáticos.

### 4. ¿Qué control agregarías a un proyecto real y por qué?
En un entorno de producción añadiría **Pre-commit Hooks con validación criptográfica y Branch Protection Rules en GitHub**, complementados con **Manejo Centralizado de Secretos (como HashiCorp Vault o AWS Secrets Manager)** con rotación automática.

*Motivo:* El eslabón más vulnerable es el commit inicial. Si un secreto se sube a un commit, aunque se borre en el commit siguiente, queda grabado de por vida en el historial de Git (requiriendo `git-filter-repo` y revocar inmediatamente la credencial). Los *pre-commit hooks* bloquean el comando `git commit` en la máquina del desarrollador impidiendo físicamente que el secreto toque el grafo de Git, garantizando seguridad en el origen (*Shift-Left puro*).
