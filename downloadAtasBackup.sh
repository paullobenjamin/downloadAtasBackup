#!/bin/bash


#######################################################################
##                                                                   ##
##  Este projeto é licenciado sob os termos da Apache License,       ##
##  Versão 2.0. Consulte o arquivo LICENSE para obter mais detalhes. ##
##                                                                   ##
#######################################################################
set -euo pipefail

CONFIG_FILE="download.config"

### -------------------------------------------------
### Instala dependências
### -------------------------------------------------

install_if_missing() {
  CMD=$1
  PKG=$2

  if ! command -v "$CMD" &>/dev/null; then
    echo "Instalando $PKG..."
    sudo apt update
    sudo apt install -y "$PKG"
  fi
}

install_if_missing jq jq
install_if_missing tmux tmux

if ! command -v yq &>/dev/null; then
  echo "Instalando yq..."
  sudo snap install yq
fi

if ! command -v atlas &>/dev/null; then
  echo "Instalando MongoDB Atlas CLI..."
  curl -fsSL https://pgp.mongodb.com/server-6.0.asc | \
    sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg \
    --dearmor

  echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.com/apt/ubuntu $(lsb_release -cs)/mongodb-atlas-cli multiverse" | \
    sudo tee /etc/apt/sources.list.d/mongodb-atlas-cli.list

  sudo apt update
  sudo apt install -y mongodb-atlas-cli
fi

### -------------------------------------------------
### TMUX
### -------------------------------------------------

if [ -z "${TMUX:-}" ]; then
  RAND=$(printf "%02d" $((RANDOM % 100)))
  SESSION="downloadAtlasBackup${RAND}"

  tmux new-session -d -s "$SESSION" "$0"
  tmux attach -t "$SESSION"
  exit 0
fi

### -------------------------------------------------
### Lê YAML
### -------------------------------------------------

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Arquivo download.cfg não encontrado."
  exit 1
fi

PROJECT_ID=$(yq '.project_id' "$CONFIG_FILE")
CLUSTER_NAME=$(yq '.cluster_name' "$CONFIG_FILE")
START_DATE=$(yq '.date_range.start' "$CONFIG_FILE")
END_DATE=$(yq '.date_range.end' "$CONFIG_FILE")
WEEKDAY=$(yq '.weekday' "$CONFIG_FILE")
PARALLEL=$(yq '.parallel // 4' "$CONFIG_FILE")
DOWNLOAD_DIR=$(yq '.download_dir // "./atlas_backups"' "$CONFIG_FILE")
MIN_DISK_GB=$(yq '.min_disk_gb // 10' "$CONFIG_FILE")

mkdir -p "$DOWNLOAD_DIR"

echo "Configuração carregada:"
echo "Project: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Período: $START_DATE até $END_DATE"
echo "Dia da semana: $WEEKDAY"
echo "Paralelo: $PARALLEL"

### -------------------------------------------------
### Validação disco
### -------------------------------------------------

AVAILABLE_GB=$(df -BG "$DOWNLOAD_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')

if [ "$AVAILABLE_GB" -lt "$MIN_DISK_GB" ]; then
  echo "Espaço insuficiente. Necessário pelo menos ${MIN_DISK_GB}GB."
  exit 1
fi

echo "Espaço disponível: ${AVAILABLE_GB}GB"

### -------------------------------------------------
### Conversão weekday
### -------------------------------------------------

if [ "$WEEKDAY" -eq 1 ]; then
  TARGET_LINUX_WEEKDAY=7
else
  TARGET_LINUX_WEEKDAY=$((WEEKDAY - 1))
fi

TMP_FILE=$(mktemp)

atlas backups list \
  --projectId "$PROJECT_ID" \
  --clusterName "$CLUSTER_NAME" \
  --output json | \
jq -c '.results[] | select(.snapshotType=="FULL")' | \
while read -r snapshot
do
    SNAPSHOT_ID=$(echo "$snapshot" | jq -r '.id')
    CREATED_AT=$(echo "$snapshot" | jq -r '.createdAt')

    SNAP_DATE=$(date -d "$CREATED_AT" +"%Y-%m-%d")
    SNAP_WEEKDAY=$(date -d "$CREATED_AT" +%u)

    if [[ "$SNAP_DATE" < "$START_DATE" || "$SNAP_DATE" > "$END_DATE" ]]; then
        continue
    fi

    if [ "$SNAP_WEEKDAY" -ne "$TARGET_LINUX_WEEKDAY" ]; then
        continue
    fi

    FILE="$DOWNLOAD_DIR/backup_${SNAPSHOT_ID}.tar.gz"

    if [ -f "$FILE" ]; then
        echo "Já existe: $FILE"
        continue
    fi

    echo "$SNAPSHOT_ID" >> "$TMP_FILE"
done

TOTAL=$(wc -l < "$TMP_FILE")

if [ "$TOTAL" -eq 0 ]; then
  echo "Nenhum snapshot elegível."
  tmux kill-session -t "$(tmux display-message -p '#S')"
  exit 0
fi

echo "Snapshots para download: $TOTAL"

cat "$TMP_FILE" | xargs -I {} -P "$PARALLEL" bash -c '
  SNAP_ID="{}"
  OUT_FILE="'"$DOWNLOAD_DIR"'/backup_${SNAP_ID}.tar.gz"

  echo "Baixando $SNAP_ID..."
  atlas backups snapshots download \
    --projectId "'"$PROJECT_ID"'" \
    --clusterName "'"$CLUSTER_NAME"'" \
    --snapshotId "$SNAP_ID" \
    --out "$OUT_FILE"
'

rm -f "$TMP_FILE"

echo "Downloads finalizados."

SESSION_NAME=$(tmux display-message -p '#S')
tmux kill-session -t "$SESSION_NAME"
