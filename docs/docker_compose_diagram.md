# Diagrama de Infraestrutura e Serviços - Docker Compose
## Sistema de Simulação e Monitoramento CCO de Ônibus (SPTrans & TimescaleDB)

---

### 🐳 Diagrama PlantUML do Docker Compose

```plantuml
@startuml
!theme classic
skinparam backgroundColor #0f172a
skinparam componentStyle uml2
skinparam Shadowing true

title Diagrama de Infraestrutura e Serviços - Docker Compose (Network: flink-net 172.20.0.0/16)

package "Rede Docker Bridge: flink-net (172.20.0.0/16)" #1e293b {

    package "Perfil: servico_kafka" #3b0764 {
        component [kafka\nApache Kafka 4.1.1 (KRaft Mode)\nIP: 172.20.0.21\nPortas: 9092, 9093, 29092] as kafka #dc2626
        component [schema-registry\nConfluent Schema Registry 7.8.0\nIP: 172.20.0.23\nPorta: 8085:8081] as schema #7c3aed
        component [kafka-ui\nProvectus Kafka UI\nIP: 172.20.0.22\nPorta: 8084:8080] as kafka_ui #9333ea
        component [python-producer\nProdutor Ingestor SPTrans API\nIP: 172.20.0.30] as python_prod #0284c7
    }

    package "Perfil: servico_flink" #7c2d12 {
        component [flink-jobmanager\nFlink Master / JobManager\nIP: 172.20.0.10\nPorta: 8081:8081] as flink_jm #ea580c
        component [flink-taskmanager\nFlink Worker (10 Slots)\nIP: 172.20.0.11] as flink_tm #d97706
        component [flink-sql-client\nFlink SQL Client (load_schema.sql)\nIP: 172.20.0.12] as flink_sql #b45309
    }

    package "Perfil: dashboard" #064e3b {
        component [timescaledb\nTimescaleDB / PostgreSQL 17\nIP: 172.20.0.25\nPorta: 5432:5432] as timescaledb #15803d
        component [grafana\nGrafana Dashboards (v11)\nIP: 172.20.0.24\nPorta: 3000:3000] as grafana #059669
        component [loki\nGrafana Loki Log Storage\nIP: 172.20.0.26\nPorta: 3100:3100] as loki #047857
        component [alloy\nGrafana Alloy Log Collector\nIP: 172.20.0.27\nPorta: 12345:12345] as alloy #065f46
    }
}

' Mapeamento de Portas para o Host Local (External Access)
interface "Host Port 9092 / 9093 / 29092" as h_kafka
interface "Host Port 8084" as h_kafkaui
interface "Host Port 8085" as h_schema
interface "Host Port 8081" as h_flink
interface "Host Port 5432" as h_pg
interface "Host Port 3000" as h_grafana
interface "Host Port 3100" as h_loki
interface "Host Port 12345" as h_alloy

h_kafka -- kafka
h_kafkaui -- kafka_ui
h_schema -- schema
h_flink -- flink_jm
h_pg -- timescaledb
h_grafana -- grafana
h_loki -- loki
h_alloy -- alloy

' Dependências de Inicialização (depends_on)
kafka_ui .down.> kafka : depends_on
schema .down.> kafka : depends_on
python_prod .down.> kafka : depends_on
python_prod .down.> schema : depends_on

flink_tm .down.> flink_jm : depends_on
flink_sql .down.> flink_jm : depends_on
flink_sql .down.> flink_tm : depends_on

' Volumes de Persistência em Disco
database "Volume Host:\n./kafka_data" as v_kafka #450a0a
database "Volume Host:\n./timescale_data" as v_ts #052e16
database "Volume Host:\n./grafana_data" as v_graf #064e3b
database "Volume Host:\n./scripts_flink" as v_sql #78350f

kafka -- v_kafka
timescaledb -- v_ts
grafana -- v_graf
flink_sql -- v_sql

@enduml
```

---

### 📋 Mapeamento Completo de Containers, Perfis e Redes

| Container Name | Perfil Docker | Endereço IP (flink-net) | Porta Mapeada (Host) | Dependências (`depends_on`) | Volumes Persistidos / Mapeados |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`kafka`** | `servico_kafka` | `172.20.0.21` | `9092`, `9093`, `29092` | - | `./kafka_data:/var/lib/kafka/data` |
| **`schema-registry`** | `servico_kafka` | `172.20.0.23` | `8085:8081` | `kafka` | - |
| **`kafka-ui`** | `servico_kafka` | `172.20.0.22` | `8084:8080` | `kafka` | - |
| **`python-producer`** | `servico_kafka` | `172.20.0.30` | - | `kafka`, `schema-registry` | - |
| **`flink-jobmanager`** | `servico_flink` | `172.20.0.10` | `8081:8081` | - | - |
| **`flink-taskmanager`** | `servico_flink` | `172.20.0.11` | - | `flink-jobmanager` | - |
| **`flink-sql-client`** | `servico_flink` | `172.20.0.12` | - | `flink-jobmanager`, `flink-taskmanager` | `./scripts_flink:/opt/flink/sql` |
| **`timescaledb`** | `dashboard` | `172.20.0.25` | `5432:5432` | - | `./timescale_data:/var/lib/postgresql/data` |
| **`grafana`** | `dashboard` | `172.20.0.24` | `3000:3000` | - | `./grafana_data:/var/lib/grafana`<br>`./config/dashboards:/etc/grafana/...` |
| **`loki`** | `dashboard` | `172.20.0.26` | `3100:3100` | - | `./config/loki-config.yaml:...` |
| **`alloy`** | `dashboard` | `172.20.0.27` | `12345:12345` | - | `/var/run/docker.sock`<br>`/var/lib/docker/containers` |

---

### 🌐 Rede Docker e Fuso Horário
- **Rede Virtual (IPAM Subnet)**: `flink-net` (`172.20.0.0/16` modo `bridge`).
- **Fuso Horário Global**: `TZ=America/Sao_Paulo` (Horário Oficial de Brasília, UTC-3) configurado em todos os containers.
