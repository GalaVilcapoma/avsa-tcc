# AVSA - Despliegue Taller Cloud Computing (Costo Mínimo)

Despliegue completo del proyecto AVSA (Sistema de Gestión Agroquímica) en AWS con **4 servicios** y el **menor costo mensual posible**.

## Arquitectura

```
Navegador ──► Amazon S3 (Frontend React) ──► EC2 avsa-taller ──► Docker: Backend Java :8081
                                                (IP elástica)      Docker: Backend Python :8000
                                                                   Docker: SQL Server Express (interno)
                                                                   Docker: MongoDB 7 (interno)
```

## 4 Servicios AWS

| Servicio | Uso | Costo aprox. |
|----------|-----|-------------|
| EC2 (t3a.medium) | 4 contenedores Docker | ~$27/mes |
| EBS (gp3, 16GiB) | Disco de la EC2 | ~$1.3/mes |
| S3 | Frontend estático | ~$0.01/mes |
| VPC | Red + SG + EIP | $0 |
| **TOTAL** | | **≈ $29/mes** |

## Imágenes Docker Hub

- `anthonygala/avsa-backend:1.0` — Backend Java (Spring Boot)
- `anthonygala/avsa-analytics:1.0` — Backend Python (FastAPI)
- `anthonygala/avsa-frontend:1.0` — Frontend React (Vite + Nginx)

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `taller-cloud-barato.yaml` | Template CloudFormation (crea todo) |
| `scripts/instalar-todo.sh` | Script que instala Docker y despliega |
| `datos/init_mongodb_completo.js` | Seed MongoDB (customers, products, agrochemicals) |
| `datos/init_sqlserver_completo.sql` | Seed SQL Server (pedidos, aplicaciones, inventario) |
| `MANUAL_TALLER_BARATO.md` | Manual paso a paso |
| `COSTOS_CALCULADORA.md` | Estimación de costos con la calculadora AWS |

## Uso rápido

1. Subir esta carpeta a un **repo público** de GitHub
2. En AWS Learner Lab → CloudFormation → Upload `taller-cloud-barato.yaml`
3. Cambiar el parámetro `ScriptUrl` a la URL raw del script en tu repo
4. Submit → esperar ~10 min → ¡listo!

Ver `MANUAL_TALLER_BARATO.md` para instrucciones detalladas.
