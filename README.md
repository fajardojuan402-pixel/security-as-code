# Laboratorio individual: Security as Code

**Modalidad:** trabajo individual en casa · **Duración estimada:** 1–2 horas  
**Objetivo:** identificar, corregir y automatizar controles de seguridad en un proyecto pequeño usando Gitleaks, Checkov, Trivy y GitHub Actions.

> Este repositorio contiene vulnerabilidades y configuraciones inseguras **intencionales**. No lo despliegues en producción. El token del ejemplo es ficticio y no concede acceso a ningún servicio. Nunca introduzcas credenciales reales.

## 1. Flujo de trabajo

1. Haz **Fork** de este repositorio en tu cuenta de GitHub.
2. Clona tu fork localmente.
3. Crea una rama `feature/security-lab`.
4. Ejecuta cada escáner sobre el estado inicial y conserva evidencias.
5. Corrige los hallazgos, vuelve a ejecutar los escáneres y conserva evidencias posteriores.
6. Configura/verifica el workflow de GitHub Actions.
7. Abre un Pull Request desde tu rama hacia `main` en tu fork.
8. Completa `docs/INFORME.md` y sube las evidencias a `evidence/`.

## 2. Requisitos

- Git y una cuenta de GitHub.
- Python 3.11 o superior (para ejecutar el ejemplo).
- Docker Desktop o Docker Engine (para construir la imagen).
- Gitleaks, Checkov y Trivy.
- Visual Studio Code u otro editor.

Instala las herramientas siguiendo sus instrucciones oficiales:
- Gitleaks: https://github.com/gitleaks/gitleaks
- Checkov: https://www.checkov.io/2.Basics/Installing%20Checkov.html
- Trivy: https://trivy.dev/latest/getting-started/installation/
- Docker: https://docs.docker.com/get-docker/

No necesitas crear una cuenta de nube ni desplegar infraestructura. Checkov analiza los archivos Terraform localmente.

## 3. Preparar tu copia

En GitHub, pulsa **Fork**. Luego clona la URL de TU fork:

```bash
git clone https://github.com/TU-USUARIO/security-as-code-lab.git
cd security-as-code-lab
git switch -c feature/security-lab
```

Configura tu identidad Git si aún no lo has hecho:

```bash
git config user.name "Tu nombre"
git config user.email "tu-correo@example.com"
```

Registra el estado inicial:

```bash
git status
git log --oneline -5
```

## 4. Actividad 1 — Detección de secretos con Gitleaks

El archivo `src/config.py` contiene un token de demostración deliberadamente falso.

Desde la raíz del repositorio:

```bash
gitleaks dir .
gitleaks git .
```

Si tu versión de Gitleaks utiliza otra sintaxis, consulta `gitleaks --help` y registra la versión (`gitleaks version`).

**Registra antes de corregir:**
- archivo y línea reportados;
- regla que detectó el valor;
- por qué un secreto en el código o en el historial Git es un riesgo;
- captura del resultado.

**Corrige:**
1. Elimina el token ficticio del código.
2. Sustitúyelo por lectura desde una variable de entorno (`os.getenv`).
3. Añade `.env` a `.gitignore`; no subas archivos `.env`.
4. Ejecuta de nuevo ambos análisis.

Ejemplo de ejecución local:

```bash
# Linux/macOS
export APP_API_TOKEN="valor-local-no-versionado"
python src/app.py

# PowerShell
$env:APP_API_TOKEN = "valor-local-no-versionado"
python src/app.py
```

El valor mostrado es solo de ejemplo. No uses una credencial real para esta práctica.

**Importante:** eliminar un secreto de la última versión no elimina automáticamente su presencia en el historial Git. En un incidente real, revoca/rota la credencial inmediatamente y gestiona la limpieza del historial según el procedimiento de la organización. En este laboratorio el valor es ficticio.

## 5. Actividad 2 — Infraestructura como código con Checkov

El archivo `infra/main.tf` declara intencionalmente un bucket S3 con acceso público habilitado.

Ejecuta:

```bash
checkov -d ./infra
```

**Registra antes de corregir:**
- recurso y archivo afectados;
- identificador de la política que falla;
- impacto potencial;
- captura del resultado.

**Corrige:**
- deshabilita ACL públicas;
- bloquea el acceso público a nivel del bucket;
- conserva el cifrado;
- vuelve a ejecutar Checkov y guarda el resultado.

No ejecutes `terraform apply`. El objetivo es analizar archivos, no crear recursos en AWS.

## 6. Actividad 3 — Análisis de imagen con Trivy

Construye la imagen local:

```bash
docker build -t security-as-code-lab:local .
```

Analiza vulnerabilidades altas y críticas:

```bash
trivy image --scanners vuln --severity HIGH,CRITICAL security-as-code-lab:local
```

El `requirements.txt` inicial fija una versión antigua de `urllib3` para que el escáner pueda identificar dependencias que requieren actualización. Los resultados exactos dependen de la base de datos de vulnerabilidades vigente.

**Registra antes de corregir:**
- paquete;
- CVE (si aparece);
- severidad;
- versión instalada y versión corregida sugerida;
- captura del resultado.

**Corrige:** actualiza la dependencia a una versión corregida compatible (preferiblemente una versión estable vigente), reconstruye la imagen y repite el análisis. Explica cualquier hallazgo que permanezca.

Si Docker no está disponible, realiza Gitleaks y Checkov, y documenta la limitación. No inventes resultados de Trivy.

## 7. Actividad 4 — Seguridad en CI con GitHub Actions

El workflow `.github/workflows/security.yml` ejecuta los análisis en cada Pull Request hacia `main` y en pushes a `main`.

1. Revisa el YAML y explica qué hace cada job.
2. Comprueba que los permisos del `GITHUB_TOKEN` sean mínimos.
3. Sube tu rama:

```bash
git add .
git commit -m "lab: document initial security findings"
git push -u origin feature/security-lab
```

4. En GitHub, abre un Pull Request hacia `main` dentro de tu fork.
5. Revisa la pestaña **Actions** y registra el resultado de cada job.
6. Corrige el código/configuración hasta que los controles pasen. Si el workflow falla por una vulnerabilidad introducida intencionalmente, eso forma parte del diagnóstico: documenta el fallo y corrígelo.

No desactives un control para obtener una marca verde. Si necesitas una excepción, justifícala en el informe y limita su alcance.

## 8. Evidencias y entrega

Guarda capturas PNG/JPG dentro de `evidence/` y completa `docs/INFORME.md`.

Entrega:
- URL pública de tu fork;
- rama y URL del Pull Request;
- informe diligenciado;
- evidencia Gitleaks antes/después;
- evidencia Checkov antes/después;
- evidencia Trivy antes/después (o explicación de por qué no fue posible);
- evidencia de GitHub Actions;
- decisiones técnicas propias y reflexión final.

**No subas** tokens reales, contraseñas, archivos `.env`, claves privadas ni datos personales.

## 9. Criterios sugeridos (100 puntos)

| Criterio | Puntos |
|---|---:|
| Preparación del repositorio y trazabilidad de commits | 10 |
| Gitleaks: análisis, corrección y explicación | 20 |
| Checkov: análisis, corrección y explicación | 20 |
| Trivy: análisis e interpretación | 15 |
| GitHub Actions: integración y verificación | 20 |
| Informe, evidencias y reflexión crítica | 15 |
| **Total** | **100** |

Se evalúa la capacidad de interpretar los hallazgos y justificar decisiones, no simplemente obtener cero alertas.
