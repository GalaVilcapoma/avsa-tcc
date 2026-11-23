# Estimación de Costos – Calculadora de AWS

## Servicios utilizados (4)

| # | Servicio AWS | Uso | Configuración |
|---|-------------|-----|---------------|
| 1 | **Amazon EC2** | 1 instancia con 4 contenedores Docker (SQL Server, MongoDB, Backend Java, Backend Python) | `t3a.medium` (2 vCPU, 4 GB RAM) |
| 2 | **Amazon EBS** | Disco de la EC2 | gp3, 16 GiB |
| 3 | **Amazon S3** | Frontend React como sitio web estático | ~10 MB de archivos, hosting estático |
| 4 | **Amazon VPC** | Red privada, grupo de seguridad, IP elástica | 1 VPC, 1 subnet, 1 EIP asociada |

## Costo mensual estimado (us-east-1, N. Virginia)

### Opción A: OnDemand (sin riesgo de interrupción)

| Recurso | Detalle | Costo/mes (USD) |
|---------|---------|----------------:|
| EC2 t3a.medium OnDemand | 730 h × $0.0376/h | **$27.45** |
| EBS gp3 16 GiB | 16 × $0.08/GiB-mes | **$1.28** |
| IP Elástica (asociada) | $0.00 (asociada a instancia running) | **$0.00** |
| S3 almacenamiento | ~0.01 GiB × $0.023/GiB | **$0.01** |
| S3 requests (GET) | ~10,000 × $0.0004/1000 | **$0.004** |
| Data Transfer Out | ~5 GB × $0.09/GB (primeros 10 TB) | **$0.45** |
| **TOTAL OnDemand** | | **≈ $29.19** |

### Opción B: Spot (~70% descuento, puede interrumpirse)

| Recurso | Detalle | Costo/mes (USD) |
|---------|---------|----------------:|
| EC2 t3a.medium Spot | 730 h × ~$0.0113/h (≈70% dto) | **$8.25** |
| EBS gp3 16 GiB | 16 × $0.08/GiB-mes | **$1.28** |
| IP Elástica (asociada) | $0.00 | **$0.00** |
| S3 + Data Transfer | igual | **$0.46** |
| **TOTAL Spot** | | **≈ $9.99** |

> **Nota:** En el Learner Lab, Spot puede no estar disponible. Si falla, usar OnDemand.

## Pasos en la Calculadora de AWS

1. Ir a [calculator.aws](https://calculator.aws)
2. Click **Create estimate**
3. **Add service → Amazon EC2**
   - Region: US East (N. Virginia)
   - Instance type: `t3a.medium`
   - Pricing: On-Demand (o Spot)
   - Quantity: 1
   - Usage: 730 hours/month
   - EBS: gp3, 16 GiB
   - → **Add to my estimate**
4. **Add service → Amazon S3**
   - Storage: S3 Standard, 0.01 GB
   - GET requests: 10,000/month
   - → **Add to my estimate**
5. **Add service → Amazon VPC**
   - Elastic IP: 1 (associated)
   - → **Add to my estimate**
6. **Ver total** → debe dar ≈ **$29/mes** (OnDemand) o ≈ **$10/mes** (Spot)
7. **Share** → copiar el link para mostrarlo en el video

## ¿Por qué es el costo mínimo?

- **1 sola EC2** en lugar de 4+ servicios separados (RDS, DocumentDB, ECS, etc.)
- **SQL Server Express** = licencia gratuita (no paga licencia SQL Server)
- **MongoDB en Docker** = gratis (vs Amazon DocumentDB ≈ $60/mes mínimo)
- **S3 para frontend** = centavos (vs EC2 o Amplify que cuesta más)
- **Spot** reduce la EC2 ~70% (si disponible)
- **gp3** es más barato que gp2 y no requiere IOPS provisionados
