#!/bin/bash
# =============================================================================
# Taller Cloud Computing - AVSA: TODO EN UNA SOLA EC2 (costo minimo)
#   SQL Server 2022 Express + MongoDB 7 + Backend Java + Backend Python
#   en Docker. El Frontend se publica en Amazon S3.
# Lo descarga y ejecuta el user data de taller-cloud-barato.yaml
# Variables: BUCKET (bucket S3 del frontend), PUBLIC_IP (IP elastica), DOCKER_USER
# Log: /var/log/taller.log
# =============================================================================
exec > >(tee -a /var/log/taller.log) 2>&1
: "${BUCKET:?falta BUCKET}" "${PUBLIC_IP:?falta PUBLIC_IP}"
DOCKER_USER="${DOCKER_USER:-anthonygala}"

# URL base de los archivos de datos en GitHub (carpeta datos/)
SCRIPT_BASE="${SCRIPT_URL%/scripts/*}"
RAW="${SCRIPT_BASE}/datos"

SQL_PASS='Avsa@Admin12345'
MONGO_USER=admin; MONGO_PASS=Mongo12345; DB_MONGO=db_avsa; DB_SQL=avsa_db

IMG_SQL=mcr.microsoft.com/mssql/server:2022-latest
IMG_MONGO=mongo:7.0
IMG_BACK1="$DOCKER_USER/avsa-backend:1.0"
IMG_BACK2="$DOCKER_USER/avsa-analytics:1.0"
IMG_FRONT="$DOCKER_USER/avsa-frontend:1.0"

log() { echo "[$(date +%H:%M:%S)] [TALLER] $*"; }
export DEBIAN_FRONTEND=noninteractive
echo 'DPkg::Lock::Timeout "600";' > /etc/apt/apt.conf.d/99taller-lock

# ---------- Swap de 2 GB: la EC2 de 4 GB aguanta los 4 contenedores
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ---------- Descargas en PARALELO con la instalacion de Docker
mkdir -p /root/datos
curl -fsSL --retry 5 "$RAW/init_sqlserver_completo.sql" -o /root/datos/init_sqlserver.sql & P1=$!
curl -fsSL --retry 5 "$RAW/init_mongodb_completo.js" -o /root/datos/init_mongodb.js & P2=$!
curl -fsSL --retry 5 https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip & P3=$!
apt-get update -y && apt-get install -y --no-install-recommends docker.io unzip curl
systemctl enable --now docker
wait $P1 $P2 $P3
unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install >/dev/null
T=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 300')
export AWS_DEFAULT_REGION="$(curl -s -H "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/placement/region)"
log "Docker, AWS CLI y archivos de datos listos"

# ---------- Imagenes de los 5 contenedores en paralelo
PIDS=()
for img in "$IMG_SQL" "$IMG_MONGO" "$IMG_BACK1" "$IMG_BACK2" "$IMG_FRONT"; do
  ( for i in 1 2 3 4 5; do docker pull -q "$img" >/dev/null && exit 0; sleep 10; done; exit 1 ) & PIDS+=($!)
done
wait "${PIDS[@]}"
log "Imagenes descargadas"

# ---------- Red Docker interna
docker network create avsa-net 2>/dev/null || true

# ---------- SQL Server Express (licencia gratuita)
docker run -d --name mssql --network avsa-net --restart always \
  -e ACCEPT_EULA=Y -e MSSQL_PID=Express -e MSSQL_SA_PASSWORD="$SQL_PASS" -e MSSQL_MEMORY_LIMIT_MB=1100 \
  -v mssql-data:/var/opt/mssql "$IMG_SQL"

# ---------- MongoDB 7
docker run -d --name mongo --network avsa-net --restart always \
  -e MONGO_INITDB_ROOT_USERNAME="$MONGO_USER" -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASS" \
  -v mongo-data:/data/db "$IMG_MONGO" --wiredTigerCacheSizeGB 0.25

# ---------- Cargar datos SQL Server
SQLCMD=""
until SQLCMD=$(docker exec mssql bash -c 'ls /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd 2>/dev/null | head -1') && [ -n "$SQLCMD" ] \
      && docker exec mssql "$SQLCMD" -C -S localhost -U sa -P "$SQL_PASS" -Q "SELECT 1" >/dev/null 2>&1; do
  log "Esperando a SQL Server..."; sleep 5
done
docker cp /root/datos/init_sqlserver.sql mssql:/tmp/init.sql
docker exec mssql "$SQLCMD" -C -S localhost -U sa -P "$SQL_PASS" -b -i /tmp/init.sql && log "SQL SERVER POBLADO"

# ---------- Cargar datos MongoDB
MURI="mongodb://$MONGO_USER:$MONGO_PASS@localhost:27017/?authSource=admin"
until docker exec mongo mongosh "$MURI" --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; do log "Esperando a MongoDB..."; sleep 3; done
docker cp /root/datos/init_mongodb.js mongo:/tmp/init.js
docker exec mongo mongosh "$MURI" --quiet --file /tmp/init.js >/dev/null && log "MONGODB POBLADO"

# ---------- Backend Python Analytics (FastAPI + uvicorn, puerto 8000)
MONGO_URI="mongodb://$MONGO_USER:$MONGO_PASS@mongo:27017/$DB_MONGO?authSource=admin"
docker run -d --name backend-analitico --network avsa-net --restart always -p 8000:8000 \
  -e MONGODB_URI="$MONGO_URI" \
  -e DATABASE_NAME="$DB_MONGO" \
  -e SQLSERVER_HOST=mssql \
  -e SQLSERVER_PORT=1433 \
  -e SQLSERVER_DATABASE="$DB_SQL" \
  -e SQLSERVER_USER=sa \
  -e SQLSERVER_PASSWORD="$SQL_PASS" \
  -e PORT=8000 \
  "$IMG_BACK2"

# ---------- Backend Java Spring Boot (puerto 8081)
docker run -d --name backend-transaccional --network avsa-net --restart always -p 8081:8081 \
  -e JAVA_TOOL_OPTIONS="-Xms128m -Xmx320m -XX:+UseSerialGC" \
  -e SERVER_PORT=8081 \
  -e R2DBC_URL="r2dbc:mssql://mssql:1433/$DB_SQL?trustServerCertificate=true" \
  -e R2DBC_USERNAME=sa \
  -e R2DBC_PASSWORD="$SQL_PASS" \
  -e MONGODB_URI="$MONGO_URI" \
  "$IMG_BACK1"
log "Backends iniciados"

# ---------- Frontend: extraer del Docker image y subir a S3
mkdir -p /root/fe
docker create --name fe-temp "$IMG_FRONT"
docker cp fe-temp:/usr/share/nginx/html/. /root/fe/
docker rm fe-temp

# Inyectar config.js con las URLs reales de la EC2
cat > /root/fe/config.js <<EOC
// Configuracion inyectada en deploy - apunta a la EC2 de AWS
window.API_URL = "http://$PUBLIC_IP:8081";
window.ANALYTICS_URL = "http://$PUBLIC_IP:8000";
EOC

# Asegurar que index.html cargue config.js ANTES de los scripts de la app
if ! grep -q 'config.js' /root/fe/index.html; then
  sed -i 's#</head>#<script src="/config.js"></script>\n</head>#' /root/fe/index.html
fi

# Subir a S3
for i in 1 2 3 4 5; do aws s3 sync /root/fe "s3://$BUCKET" --delete --only-show-errors && break; sleep 10; done
log "FRONTEND PUBLICADO EN S3"

# ---------- Verificacion y resumen
code() { curl -s -o /dev/null -m 10 -w '%{http_code}' "$1"; }
for i in $(seq 40); do [ "$(code http://localhost:8081/actuator/health)" = 200 ] && break; sleep 8; done

cat > /home/ubuntu/URLS.txt <<EOT
==================== AVSA - TALLER CLOUD (COSTO MINIMO) ====================
Frontend (Amazon S3) .... http://$BUCKET.s3-website-$AWS_DEFAULT_REGION.amazonaws.com
Backend Java Swagger .... http://$PUBLIC_IP:8081/swagger-ui.html
Backend Python Docs ..... http://$PUBLIC_IP:8000/docs
Backend Java Health ..... http://$PUBLIC_IP:8081/actuator/health
Chequeo: backend-java=$(code http://localhost:8081/actuator/health)  backend-python=$(code http://localhost:8000/)
=========================================================================
EOT
chown ubuntu:ubuntu /home/ubuntu/URLS.txt
cat /home/ubuntu/URLS.txt; docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; free -m | head -2
log "TALLER LISTO"
