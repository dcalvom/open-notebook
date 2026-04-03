#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"
TEMPLATE_FILE="$ROOT_DIR/.env.template"
DOCKER_COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

print_header() {
  cat <<'EOF'
─────────────────────────────────────────────
 Open Notebook • Easy Start
─────────────────────────────────────────────
EOF
}

require_command() {
  local cmd="$1"
  local install_hint="${2:-}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] No se encontró el comando '$cmd'." >&2
    if [[ -n "$install_hint" ]]; then
      echo "        $install_hint" >&2
    fi
    exit 1
  fi
}

choose_compose_cmd() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "" # handled later
  fi
}

default_random_key() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    head -c 48 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 48
  fi
}

prompt_value() {
  local var="$1"
  local label="$2"
  local default_value="$3"
  local allow_empty="${4:-false}"
  local value

  while true; do
    if [[ "$allow_empty" == "secret" ]]; then
      read -rsp "$label [default hidden]: " value
      echo
      [[ -z "$value" ]] && value="$default_value"
      break
    else
      local prompt="${label}"
      if [[ -n "$default_value" ]]; then
        prompt+=" [$default_value]"
      fi
      prompt+=" : "
      read -rp "$prompt" value
      if [[ -z "$value" ]]; then
        value="$default_value"
      fi
      if [[ -z "$value" && "$allow_empty" != "true" ]]; then
        echo "  → Se requiere un valor" >&2
        continue
      fi
      break
    fi
  done

  printf -v "$var" '%s' "$value"
}

load_existing_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  elif [[ -f "$TEMPLATE_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$TEMPLATE_FILE"
    set +a
  fi
}

write_env_file() {
  cat > "$ENV_FILE" <<EOF
OPEN_NOTEBOOK_ENCRYPTION_KEY=$OPEN_NOTEBOOK_ENCRYPTION_KEY
OPEN_NOTEBOOK_PASSWORD=$OPEN_NOTEBOOK_PASSWORD
API_PUBLIC_URL=$API_PUBLIC_URL
HOST_UI_PORT=$HOST_UI_PORT
HOST_API_PORT=$HOST_API_PORT
HOST_DB_PORT=$HOST_DB_PORT
SURREAL_DATA_PATH=$SURREAL_DATA_PATH
NOTEBOOK_DATA_PATH=$NOTEBOOK_DATA_PATH
SURREAL_USER=$SURREAL_USER
SURREAL_PASSWORD=$SURREAL_PASSWORD
SURREAL_NAMESPACE=$SURREAL_NAMESPACE
SURREAL_DATABASE=$SURREAL_DATABASE
OPEN_NOTEBOOK_IMAGE=$OPEN_NOTEBOOK_IMAGE
OPEN_NOTEBOOK_IMAGE_TAG=$OPEN_NOTEBOOK_IMAGE_TAG
EOF
}

ensure_directory() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    mkdir -p "$path"
  else
    mkdir -p "$ROOT_DIR/$path"
  fi
}

main() {
  print_header
  require_command docker "Instala Docker: https://docs.docker.com/get-docker/"
  local compose_cmd
  compose_cmd="$(choose_compose_cmd)"
  if [[ -z "$compose_cmd" ]]; then
    echo "[ERROR] No se encontró docker compose (plugin) ni docker-compose." >&2
    exit 1
  fi

  load_existing_env

  local default_key="${OPEN_NOTEBOOK_ENCRYPTION_KEY:-}"
  [[ -z "$default_key" ]] && default_key="$(default_random_key)"
  prompt_value OPEN_NOTEBOOK_ENCRYPTION_KEY "🔐 Clave de cifrado (se usa para almacenar credenciales)" "$default_key"

  local default_password="${OPEN_NOTEBOOK_PASSWORD:-}"
  prompt_value OPEN_NOTEBOOK_PASSWORD "🔑 Password opcional para proteger la UI (Enter para dejarla pública)" "$default_password" true

  local default_api_url="${API_PUBLIC_URL:-http://localhost:5055}"
  prompt_value API_PUBLIC_URL "🌐 URL pública del API/UI (incluye http/https)" "$default_api_url"

  prompt_value HOST_UI_PORT "📺 Puerto local para la UI" "${HOST_UI_PORT:-8502}"
  prompt_value HOST_API_PORT "🛰️ Puerto local para la API" "${HOST_API_PORT:-5055}"
  prompt_value HOST_DB_PORT "🗄️ Puerto local para SurrealDB" "${HOST_DB_PORT:-8000}"

  prompt_value SURREAL_DATA_PATH "📦 Ruta para datos de SurrealDB" "${SURREAL_DATA_PATH:-./surreal_data}"
  prompt_value NOTEBOOK_DATA_PATH "🗃️ Ruta para anexos y archivos" "${NOTEBOOK_DATA_PATH:-./notebook_data}"

  prompt_value SURREAL_USER "👤 Usuario SurrealDB" "${SURREAL_USER:-root}"
  prompt_value SURREAL_PASSWORD "🔏 Password SurrealDB" "${SURREAL_PASSWORD:-root}"
  prompt_value SURREAL_NAMESPACE "🏷️ Namespace SurrealDB" "${SURREAL_NAMESPACE:-open_notebook}"
  prompt_value SURREAL_DATABASE "📚 Base SurrealDB" "${SURREAL_DATABASE:-open_notebook}"

  prompt_value OPEN_NOTEBOOK_IMAGE "🐳 Imagen Docker (backend+frontend)" "${OPEN_NOTEBOOK_IMAGE:-lfnovo/open_notebook}"
  prompt_value OPEN_NOTEBOOK_IMAGE_TAG "🏷️ Tag de la imagen" "${OPEN_NOTEBOOK_IMAGE_TAG:-v1-latest}"

  write_env_file
  echo "→ Configuración guardada en $ENV_FILE"

  ensure_directory "$SURREAL_DATA_PATH"
  ensure_directory "$NOTEBOOK_DATA_PATH"

  echo "→ Creando contenedores (esto puede tomar un momento)…"
  (cd "$ROOT_DIR" && $compose_cmd --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" pull)
  (cd "$ROOT_DIR" && $compose_cmd --env-file "$ENV_FILE" -f "$DOCKER_COMPOSE_FILE" up -d)

  cat <<EOF
✅ Todo listo.

UI:  http://localhost:$HOST_UI_PORT
API: http://localhost:$HOST_API_PORT
DB:  ws://localhost:$HOST_DB_PORT/rpc

Si configuraste un dominio, usa $API_PUBLIC_URL
Para actualizar credenciales de Azure/OpenAI entra a Settings → API Keys.
EOF
}

main "$@"
