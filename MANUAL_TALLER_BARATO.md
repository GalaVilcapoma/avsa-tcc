# Manual clic por clic — Taller de Cloud Computing al mínimo costo

**Proyecto:** AVSA - Sistema de Gestión Agroquímica  
**Meta:** SQL Server, MongoDB, Backend Java, Backend Python y Frontend en AWS con **4 servicios** y el **menor costo mensual**, desplegado con un solo archivo CloudFormation.

| Servicio AWS | Para qué |
|:--|:--|
| **Amazon EC2** | 1 sola instancia con 4 contenedores Docker: SQL Server Express, MongoDB, Backend Java y Backend Python |
| **Amazon EBS** | Disco de 16 GiB gp3 de esa EC2 |
| **Amazon S3** | Frontend React como sitio web estático |
| **Amazon VPC** | Red propia, grupo de seguridad e IP elástica |

```
Navegador ──► Amazon S3 (Frontend) ──► EC2 avsa-taller-todo-en-uno ──► Docker: Backend Java :8081
                                         (IP elástica, VPC)             Docker: Backend Python :8000
                                                                        Docker: SQL Server Express (interno)
                                                                        Docker: MongoDB 7 (interno)
```

> Costo estimado: ver `COSTOS_CALCULADORA.md`

---

## 1. Learner Lab ⏱ min 0

- [ ] **Start Lab** → esperar el círculo verde → clic **AWS**
- [ ] Región: **N. Virginia (us-east-1)**
- [ ] Antes de empezar, **apagar o borrar** instancias de otros laboratorios

## 2. Crear todo con CloudFormation ⏱ min 1

- [ ] Buscar **CloudFormation** → **Create stack** → **With new resources (standard)**
- [ ] **Choose an existing template** → **Upload a template file** → **Choose file** → `taller-cloud-barato.yaml` → **Next**
- [ ] Stack name: `avsa-taller` → en **Parameters** dejar:
  - `Capacidad` = **OnDemand** (Spot si quieren ahorrar)
  - `InstanceType` = `t3a.medium`
  - `DockerUser` = `anthonygala`
  - `ScriptUrl` = URL del script en su repo de GitHub
- [ ] **Next** → **Next** → **Submit**
- [ ] Esperar **CREATE_COMPLETE** (~3 min)

> Si falla con error de Spot: **Delete** el stack y crear con `Capacidad = OnDemand`.

## 3. Esperar la instalación ⏱ min 4

- [ ] **EC2 → Instances →** marcar `avsa-taller-todo-en-uno` → **Connect** → **EC2 Instance Connect** → usuario `ubuntu` → **Connect**
- [ ] Ver el avance:

```bash
tail -f /var/log/taller.log
```

Esperar la línea **`TALLER LISTO`** (~8–10 min). Salir con **Ctrl+C**.

```bash
cat /home/ubuntu/URLS.txt
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
free -m
```

Deben verse 4 contenedores **Up**: `mssql`, `mongo`, `backend-analitico` y `backend-transaccional`.

## 4. Abrir la aplicación

Pestaña **Outputs** del stack `avsa-taller`:

- **Frontend** → sitio web en S3 (`http://….s3-website-us-east-1.amazonaws.com`)
- **BackendJavaSwagger** → `http://IP:8081/swagger-ui.html`
- **BackendPythonDocs** → `http://IP:8000/docs`

> Los backends tardan ~1–2 min en responder después de `TALLER LISTO`.

## 5. Evidencias para el video (cámara activa)

### a) Los 4 servicios en la consola de AWS

| Servicio | Dónde mostrarlo |
|:--|:--|
| EC2 | **EC2 → Instances**: `avsa-taller-todo-en-uno` en **Running**, tipo `t3a.medium` |
| EBS | **EC2 → Volumes**: 1 volumen **gp3** de **16 GiB** |
| S3 | **S3 →** bucket → archivos y **Properties → Static website hosting** |
| VPC | **VPC → Your VPCs** (`avsa-taller-vpc`), **Security Groups** y **Elastic IPs** |

### b) Bases de datos (en la terminal de la EC2)

```bash
# SQL Server
docker exec mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Avsa@Admin12345' \
  -Q "SELECT name FROM sys.databases"

docker exec mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Avsa@Admin12345' \
  -d avsa_db -Q "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'"

# MongoDB
docker exec mongo mongosh "mongodb://admin:Mongo12345@localhost:27017/db_avsa?authSource=admin" \
  --quiet --eval "db.getCollectionNames().forEach(c => print(c, db[c].countDocuments()))"
```

### c) Backends

- Backend Java: abrir `http://IP:8081/swagger-ui.html` → ejecutar `GET /api/agrochemicals`
- Backend Python: abrir `http://IP:8000/docs` → ejecutar un endpoint de analytics

### d) Frontend

Abrir el sitio de S3 y navegar por el dashboard. Mostrar login y recorrido.

**Credenciales de admin:**
- Usuario: `admin` / Contraseña: `admin123`
- Usuario: `anthony` / Contraseña: `admin123`
- Usuario: `pierre` / Contraseña: `admin123`
- Usuario: `alexandra` / Contraseña: `admin123`

### e) Costo

Seguir `COSTOS_CALCULADORA.md` y mostrar la calculadora con el total ≈ **$29/mes** (OnDemand).

## 6. Al terminar (¡en este orden!)

1. **Cancelar solicitud Spot** (solo si usaron Spot): **EC2 → Spot Requests** → cancelar
2. **Vaciar bucket S3:** **S3 →** bucket → **Empty** → escribir `permanently delete`
3. **CloudFormation → `avsa-taller` → Delete**

> Si no vacían el bucket, el stack no se puede borrar.

---

## Problemas frecuentes

| Síntoma | Solución |
|:--|:--|
| Stack en `ROLLBACK_COMPLETE` | Ver error en **Events**, **Delete** y crear de nuevo. Si es Spot → `Capacidad = OnDemand` |
| No existe `/var/log/taller.log` | La URL del script es incorrecta o el repo no es público |
| `mssql` en `Restarting` | Falta memoria: usar `t3a.medium` (4 GB) |
| Frontend carga pero sin datos | Esperar 1–2 min; verificar `http://IP:8081/actuator/health` |
| Navegador no abre Swagger | Usar `http://` (no https) con la IP elástica |
