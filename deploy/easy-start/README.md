# Easy Start (One-Command Deploy)

Plantilla minimalista para levantar **Open Notebook** en cualquier servidor con Docker (API + frontend + SurrealDB) usando un solo script interactivo.

## ¿Qué incluye?

- `docker-compose.yml` con dos servicios:
  - `surrealdb`: base de datos persistente
  - `open_notebook`: imagen oficial (`lfnovo/open_notebook`) con API FastAPI + frontend Next.js
- `setup.sh`: script interactivo que genera `.env`, prepara directorios y ejecuta `docker compose up -d`
- `.env.template`: referencia editable de las variables soportadas

## Requisitos

- Docker + plugin `docker compose` (o `docker-compose` clásico)
- Puerto 5055 libre (API), 8502 (UI) y 8000 (SurrealDB) — configurables
- Una cadena secreta para `OPEN_NOTEBOOK_ENCRYPTION_KEY`

## Uso rápido

```bash
cd deploy/easy-start
./setup.sh
```

El script te pedirá:
1. Clave de cifrado (puede generar una automáticamente)
2. Password opcional para proteger la UI
3. URL pública donde estará disponible (http/https)
4. Puertos y rutas de persistencia
5. Credenciales de SurrealDB (defaults `root` / `root` para entornos locales)
6. Imagen/tag de Open Notebook (por defecto `lfnovo/open_notebook:v1-latest`)

Al terminar:
- Crea/actualiza `deploy/easy-start/.env`
- Ejecuta `docker compose pull` + `docker compose up -d`
- Muestra las URLs resultantes

## Variables generadas

| Variable | Descripción |
|----------|-------------|
| `OPEN_NOTEBOOK_ENCRYPTION_KEY` | Requerida para cifrar las credenciales guardadas en Settings → API Keys |
| `OPEN_NOTEBOOK_PASSWORD` | Password opcional para proteger la interfaz |
| `API_PUBLIC_URL` | URL externa que usará el frontend para apuntar al API |
| `HOST_UI_PORT`, `HOST_API_PORT`, `HOST_DB_PORT` | Puertos expuestos en el host |
| `SURREAL_DATA_PATH`, `NOTEBOOK_DATA_PATH` | Rutas (relativas o absolutas) para persistir datos |
| `SURREAL_*` | Credenciales y nombres utilizados por SurrealDB |
| `OPEN_NOTEBOOK_IMAGE`, `OPEN_NOTEBOOK_IMAGE_TAG` | Imagen base para el servicio principal |

Puedes editar `deploy/easy-start/.env` manualmente si necesitas cambiar valores después de correr el script.

## Conectar Azure OpenAI (u otros proveedores)

1. Abre la UI (`http://<tu-dominio>:8502` o el dominio público configurado)
2. Ve a **Settings → API Keys → Add Credential**
3. Selecciona **Azure OpenAI**
4. Pega `API Key`, `Endpoint`, `API Version` y, si aplica, los endpoints específicos por servicio
5. Guarda → **Test Connection** → **Discover Models** → **Register Models**

El resto de provedores (OpenAI, Anthropic, etc.) se configuran desde la misma pantalla.

## Actualizaciones / reinicios

```bash
# Desde deploy/easy-start
./setup.sh        # Actualiza variables y relanza (opcional)
COMPOSE="docker compose"  # o docker-compose
$COMPOSE --env-file .env up -d --pull always
$COMPOSE --env-file .env logs -f
```

Para reiniciar servicios de manera segura:
```bash
$COMPOSE --env-file .env restart
```

## Copias de seguridad

- `SURREAL_DATA_PATH`: contiene la base de datos (rocksdb)
- `NOTEBOOK_DATA_PATH`: archivos de usuarios y adjuntos

Basta con copiar estas carpetas (o montar volúmenes externos) para respaldar.

## Integración con Vercel

Si prefieres alojar el frontend en Vercel y dejar solo la API/DB en tu servidor:
1. Usa este entorno para la API (puedes cerrar el puerto 8502)
2. Despliega `/frontend` en Vercel con `NEXT_PUBLIC_API_URL` apuntando a tu dominio público (por ejemplo `https://notebook.midominio.com/api`)
3. Opcional: agrega un reverse proxy/Nginx delante del contenedor para redirigir `/`→frontend y `/api`→FastAPI

Esta carpeta es un punto de partida; adáptala a tu infraestructura (Traefik, HTTPS automático, backups, etc.).
