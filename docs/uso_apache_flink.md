# Uso do Apache Flink no Projeto

Este documento detalha o papel, a arquitetura e as consultas do **Apache Flink** no sistema de simulação do Centro de Controle Operacional (CCO) de ônibus da SPTrans.

---

## 🎯 1. Visão Geral e Papel do Apache Flink

O Apache Flink é o motor de **Processamento de Streaming em Tempo Real** do projeto. Ele fica posicionado entre o **Apache Kafka** (camada de mensageria) e o **TimescaleDB/PostgreSQL** (camada de persistência e dashboards).

```
┌─────────────────┐      ┌───────────────┐      ┌───────────────────┐      ┌─────────────────┐
│ API SPTrans /   │ ───> │ Apache Kafka  │ ───> │   Apache Flink    │ ───> │  TimescaleDB /  │
│ Produtor Python │      │ (AVRO Topic)  │      │  (Flink SQL Engine│      │   PostgreSQL    │
└─────────────────┘      └───────────────┘      └───────────────────┘      └─────────────────┘
                                                          │                         │
                                                          ▼                         ▼
                                                  Transformação &            Métricas / Grafana
                                               Cálculos em Tempo Real            Dashboards
```

### Principais Responsabilidades:
1. **Consumo de Streaming de Alta Vazão**: Leitura contínua das posições GPS dos ônibus vindas do Kafka serializadas em **Avro** com suporte ao Schema Registry.
2. **Gerenciamento de Tempo e Eventos (Event Time & Watermarks)**: Trata atrasos e desordem nas mensagens usando atribuição de *Watermark* baseada no timestamp do Kafka.
3. **Cálculos Geospaciais Complexos (Fórmula de Haversine)**: Computação da distância percorrida e velocidade instantânea (km/h) de cada veículo comparando posições GPS consecutivas.
4. **Agregações em Tempo Real & Janelas Temporais**:
   - **Processamento Contínuo (Upsert Stream)**: Mantém o estado atualizado da frota ativa e velocidades atuais por linha.
   - **Processamento por Janelas (Tumbling Windows)**: Gera séries temporais de 1 minuto para gravação de histórico acumulado no TimescaleDB.

---

## ⚙️ 2. Arquitetura de Execução

No ambiente de containers (`docker-compose.yaml`), o Apache Flink opera em modo de cluster distribuído:

- **Flink JobManager** (`jobmanager`): Coordenador do cluster, responsável por receber as submissões de SQL, montar os grafos de execução (*Execution Graph*) e gerenciar o ciclo de vida dos jobs.
- **Flink TaskManager** (`taskmanager`): Nó de execução onde as tarefas paralelas rodam (configurado com **4 slots de execução** e **paralelismo 3**).
- **Flink SQL Client**: Utilitário (`bin/sql-client.sh`) utilizado para submeter scripts SQL em lote (*batch/streaming scripts*) para o cluster.

---

## 📊 3. Detalhamento das Consultas Flink SQL

O script principal de consultas está localizado em `bkc_consultas_flink/consultas_flink.sql`.

### 3.1. Tabela Fonte (`linhas_onibus`)
Mapeia o tópico Kafka `posicoes_sptrans` deserializado com Avro Confluent:

```sql
CREATE TABLE linhas_onibus (
    c STRING,           -- Letreiro completo da linha (ex: "5015-10")
    cl INT,             -- Código identificador da linha
    sl INT,             -- Sentido (1: TP->TS, 2: TS->TP)
    lt0 STRING,         -- Letreiro de destino
    lt1 STRING,         -- Letreiro de origem
    qv INT,             -- Quantidade de veículos
    p INT,              -- Prefixo (ID único do veículo)
    a BOOLEAN,          -- Acessibilidade PwD
    ta BIGINT,          -- Epoch timestamp
    ta_tempo STRING,    -- Timestamp formatado (ISO string)
    py DOUBLE,          -- Latitude GPS
    px DOUBLE,          -- Longitude GPS
    ta_ts AS TO_TIMESTAMP(ta_tempo),
    kafka_time TIMESTAMP(3) METADATA FROM 'timestamp',
    WATERMARK FOR kafka_time AS kafka_time - INTERVAL '2' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'posicoes_sptrans',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'flink-bus-monitor',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'http://schema-registry:8081'
);
```

---

### 3.2. Job 1: Total de Ônibus Ativos por Linha (Estado Atual)

- **Sink**: `tb_onibus_ativos_por_linha` (PostgreSQL via JDBC).
- **Tipo de Stream**: **Upsert Stream** (`PRIMARY KEY (linha) NOT ENFORCED`).
- **Lógica**: Agrega continuamente por linha (`GROUP BY c`) contando a quantidade de veículos distintos ativos (`COUNT(DISTINCT p)`).

```sql
INSERT INTO sink_onibus_ativos_por_linha
SELECT 
    c AS linha,
    COUNT(DISTINCT p) AS total_onibus_ativos,
    MAX(kafka_time) AS ultima_atualizacao
FROM linhas_onibus
GROUP BY c;
```

---

### 3.3. Job 2: Velocidade Atual por Linha via Haversine (Estado Atual)

- **Sink**: `tb_velocidade_por_linha` (PostgreSQL via JDBC).
- **Tipo de Stream**: **Upsert Stream** (`PRIMARY KEY (linha) NOT ENFORCED`).
- **Lógica**:
  1. Usa a função analítica `LAG()` particionada pelo prefixo do veículo (`PARTITION BY p ORDER BY kafka_time`) para obter as coordenadas e o timestamp anteriores de cada ônibus.
  2. Aplica a **Fórmula de Haversine** para calcular a distância em quilômetros:
     $$d = 2 \cdot R \cdot \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \text{lat}}{2}\right) + \cos(\text{lat}_1) \cdot \cos(\text{lat}_2) \cdot \sin^2\left(\frac{\Delta \text{lon}}{2}\right)}\right)$$
     Onde $R = 6371.0\text{ km}$.
  3. Converte a diferença de tempo em horas (`TIMESTAMPDIFF`) e obtém a velocidade instantânea em km/h ($v = d / \Delta t$), filtrando ruídos de GPS ($v \le 120\text{ km/h}$).
  4. Agrupa por linha (`GROUP BY linha`) calculando a velocidade média (`AVG`), máxima (`MAX`) e mínima (`MIN`).

```sql
INSERT INTO sink_velocidade_por_linha
WITH posicoes_com_anterior AS (
    SELECT 
        c AS linha,
        p AS prefixo,
        py AS current_py,
        px AS current_px,
        kafka_time AS curr_time,
        LAG(py, 1) OVER (PARTITION BY p ORDER BY kafka_time) AS prev_py,
        LAG(px, 1) OVER (PARTITION BY p ORDER BY kafka_time) AS prev_px,
        LAG(kafka_time, 1) OVER (PARTITION BY p ORDER BY kafka_time) AS prev_time
    FROM linhas_onibus
),
calculo_velocidade AS (
    SELECT 
        linha,
        prefixo,
        curr_time,
        (2 * 6371.0 * ASIN(SQRT(
            POWER(SIN(RADIANS(current_py - prev_py) / 2.0), 2) + 
            COS(RADIANS(prev_py)) * COS(RADIANS(current_py)) * 
            POWER(SIN(RADIANS(current_px - prev_px) / 2.0), 2)
        ))) AS distancia_km,
        (CAST(TIMESTAMPDIFF(SECOND, prev_time, curr_time) AS DOUBLE) / 3600.0) AS tempo_horas
    FROM posicoes_com_anterior
    WHERE prev_py IS NOT NULL 
      AND prev_px IS NOT NULL 
      AND prev_time IS NOT NULL
      AND TIMESTAMPDIFF(SECOND, prev_time, curr_time) > 0
),
velocidades_validas AS (
    SELECT 
        linha,
        curr_time,
        (distancia_km / tempo_horas) AS velocidade_kmh
    FROM calculo_velocidade
    WHERE (distancia_km / tempo_horas) <= 120.0
)
SELECT 
    linha,
    ROUND(AVG(velocidade_kmh), 2) AS velocidade_media,
    ROUND(MAX(velocidade_kmh), 2) AS velocidade_maxima,
    ROUND(MIN(velocidade_kmh), 2) AS velocidade_minima,
    MAX(curr_time) AS ultima_atualizacao
FROM velocidades_validas
GROUP BY linha;
```

---

### 3.4. Job 3: Histórico de Velocidade por Linha (Série Temporal)

- **Sink**: `tb_historico_velocidade_por_linha` (TimescaleDB Hypertable via JDBC).
- **Tipo de Stream**: **Append Stream** em janelas de tempo (`PRIMARY KEY (linha, janela_fim)`).
- **Lógica**: Utiliza uma **Tumbling Window de 1 minuto** (`TUMBLE(curr_time, INTERVAL '1' MINUTE)`) para agregar as métricas de velocidade e emitir registros históricos periódicos para os gráficos de tendência no Grafana.

```sql
INSERT INTO sink_historico_velocidade_por_linha
-- [CTEs posicoes_com_anterior, calculo_velocidade, velocidades_validas]
SELECT 
    linha,
    TUMBLE_START(curr_time, INTERVAL '1' MINUTE) AS janela_inicio,
    TUMBLE_END(curr_time, INTERVAL '1' MINUTE) AS janela_fim,
    ROUND(AVG(velocidade_kmh), 2) AS velocidade_media,
    ROUND(MAX(velocidade_kmh), 2) AS velocidade_maxima,
    ROUND(MIN(velocidade_kmh), 2) AS velocidade_minima
FROM velocidades_validas
GROUP BY 
    linha,
    TUMBLE(curr_time, INTERVAL '1' MINUTE);
```

---

## 🛠️ 4. Vantagens do Uso do Apache Flink no Projeto

1. **Baixa Latência**: Processamento de coordenadas em milissegundos assim que chegam ao Kafka.
2. **Resiliência a Falhas**: Mecanismos de *Checkpointing* e salvamento de estado (*State Backends*) garantem processamento *Exactly-Once*.
3. **Escalabilidade Horizontal**: Capacidade de escalar os TaskManagers para processar milhares de linhas de ônibus simultaneamente.
4. **Desacoplamento**: Isola o banco de dados das rajadas de dados da API da SPTrans, pois o Flink envia apenas estados agregados otimizados para o PostgreSQL/TimescaleDB.
