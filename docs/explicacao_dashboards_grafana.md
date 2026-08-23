# Documentação e Explicação Detalhada dos Dashboards do Grafana
## Sistema de Simulação e Monitoramento CCO de Ônibus (SPTrans & TimescaleDB)

---

### 1. 🚍 Dashboard: Monitoramento CCO (SPTrans TimescaleDB)
- **Arquivo Principal**: [`config/dashboards/cco_sptrans_timescaledb.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/cco_sptrans_timescaledb.json)
- **Arquivo de Backup**: [`bkp_dashboard/dashboard_cco.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/bkp_dashboard/dashboard_cco.json)
- **UID do Dashboard**: `cco-sptrans-timescaledb`
- **Fonte de Dados (Datasource)**: `TimescaleDB` (PostgreSQL / TimescaleDB - Plugin Nativo)
- **Fuso Horário Configurado**: `America/Sao_Paulo` (Horário Oficial de Brasília, UTC-3)

#### 🎯 Objetivo do Dashboard
Prover uma visão operacional em tempo real do Centro de Controle Operacional (CCO) da SPTrans. Permite monitorar a frota de ônibus, diagnosticar comboiamentos (*bunching*), acompanhar velocidades, intervalos (*headway*), séries temporais históricas em Hypertables e visualizar o rastreamento geográfico dos veículos sobre o traçado GTFS.

#### 🎛️ Filtro Dinâmico por Linha (`$linha`)
Menu suspenso no topo do dashboard que executa a consulta:
```sql
SELECT linha AS __value, linha_descricao AS __text 
FROM tb_linhas_onibus_filtro 
ORDER BY linha ASC;
```
Permite selecionar a linha desejada (ex: `1012-10`, `627J-10`, `477P-10`) e recalcular imediatamente todos os painéis do dashboard.

---

#### 📊 Estrutura de Painéis e Métricas do CCO

##### 1.1 Painéis KPI Stat Cards (Indicadores em Tempo Real)
- **🚌 Ônibus Ativos na Linha**: Total de ônibus em operação na linha selecionada (`tb_onibus_ativos_por_linha`).
- **⚡ Velocidade Média da Linha**: Velocidade média operacional em km/h (`tb_velocidade_por_linha`).
- **🚀 Velocidade Máxima / Mínima**: Pico de velocidade registrado na linha (`tb_velocidade_por_linha`).
- **⏱️ Headway Médio**: Tempo médio de intervalo entre ônibus em minutos (`tb_headway_por_linha`).
- **📏 Extensão do Trajeto (Ida + Volta)**: Extensão espacial em km derivada do cruzamento das tabelas GTFS (`shapes` e `trips`).

##### 1.2 Painel de Diagnóstico Operacional CCO (Tabela com Alertas Coloridos)
- **🚨 Diagnóstico Operacional CCO por Veículo**:
  Calcula a distância acumulada em metros percorridos ao longo do traçado GTFS `shapes` entre ônibus consecutivos (`onibus` e `onibus_a_frente`). Classifica a operação com alertas destacados:
  - `🚨 COMBOIAMENTO / BUNCHING (Colados)`: Distância $\le 200$m.
  - `🔴 BURACO DE OFERTA (Espaçamento Crítico)`: Distância $\ge 5.0$ km.
  - `🟡 ATENÇÃO (Espaçamento Moderado)`: Distância entre $3.0$ km e $4.99$ km.
  - `🟢 REGULAR (Espaçamento Ideal)`: Operação regular.

##### 1.3 Painel de Status da Frota em Operação
- **📋 Tabela CCO: Veículos em Operação por Linha (`$linha`)**:
  Lista os veículos ativos (`tb_veiculos_em_operacao`) exibindo Prefixo, Sentido (Ida/Volta), Velocidade (km/h), Headway (min:seg), Status (`NORMAL`, `PARADO`, `ATRASADO`) e Horário da última posição.

##### 1.4 Painéis de Séries Temporais (Hypertables do TimescaleDB)
- **📈 Histórico de Velocidades por Janela (`tb_historico_velocidade_por_linha`)**:
  Curvas históricas de velocidade média, máxima e mínima por janela de tempo.
  Usa `extract(epoch from (janela_fim AT TIME ZONE 'America/Sao_Paulo')) AS time` para renderizar perfeitamente no Horário de Brasília.
- **⏱️ Histórico de Headway por Janela (`tb_historico_headway_por_linha`)**:
  Curvas históricas de headway médio, máximo e mínimo por janela no Horário de Brasília.

##### 1.5 Painel de Rastreamento Geográfico (Geomap Interativo)
- **🗺️ Mapa Geográfico CCO: Traçado da Rota (`$linha`) & Posição dos Ônibus**:
  - **Camada 1 (Route)**: Plota o traçado azul contínuo da rota ordenado por `shape_id` e `shape_pt_sequence ASC`.
  - **Camada 2 (Markers)**: Plota os marcadores verdes com as posições GPS em tempo real (`tb_posicao_atual_onibus`).

##### 1.6 Painel Tabular de Coordenadas
- **📋 Tabela de Posição Atual dos Ônibus (`tb_posicao_atual_onibus`)**:
  Dados detalhados de latitude, longitude, destino, acessibilidade PCD e horário.

---

### 2. 📦 Dashboard: Métricas Kafka (Grafana Loki)
- **Arquivo**: [`config/dashboards/kafka_loki_observability.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/kafka_loki_observability.json)
- **UID do Dashboard**: `kafka-loki-observability`
- **Fonte de Dados (Datasource)**: `Loki`
- **Fuso Horário Configurado**: `America/Sao_Paulo` (UTC-3)

#### 🎯 Objetivo do Dashboard
Monitorar a saúde, vazão de mensagens, métricas do broker Apache Kafka (v4.1.1 KRaft) e a operabilidade do Confluent Schema Registry via LogQL.

#### 📊 Estrutura de Painéis do Kafka
- **🖥️ Brokers Online**: Total de containers Kafka ativos.
- **👑 Broker Leader Controller**: Identificação do líder KRaft.
- **🛡️ Réplicas ISR (In-Sync)**: Total de réplicas sincronizadas.
- **📁 Total de Tópicos / 🔀 Partições Ativas**: Métricas de capacidade do cluster.
- **💻 Tabela de Brokers Kafka Ativos**: Especificações de rede (Docker IP, Portas Host e Status `ONLINE`).
- **📥 Mensagens Recebidas (In/sec)** & **📤 Publicações (Publish/sec)**: Taxas de transferência em tempo real.
- **🧬 Módulo Schema Registry**: Status health, esquemas AVRO registrados, latência REST e contador de erros de desserialização.
- **📜 Stream de Logs em Tempo Real**: Feed ao vivo de logs do container Kafka e Schema Registry.

---

### 3. ⚡ Dashboard: Métricas Flink (Grafana Loki)
- **Arquivo**: [`config/dashboards/flink_loki_observability.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/flink_loki_observability.json)
- **UID do Dashboard**: `flink-loki-observability`
- **Fonte de Dados (Datasource)**: `Loki`
- **Fuso Horário Configurado**: `America/Sao_Paulo` (UTC-3)

#### 🎯 Objetivo do Dashboard
Monitorar a execução do motor Apache Flink v1.20.0 (JobManager, TaskManager, Flink SQL), vazão de streaming, watermarking, checkpoints e erros em Dead-Letter Queue.

#### 📊 Estrutura de Painéis do Flink
- **⚡ Status Flink Cluster**: Saúde geral do cluster Flink (`ONLINE`).
- **🧠 JobManager Leader & ⚙️ TaskManagers Ativos**: Alocação de nós masters e workers.
- **🎯 Total Task Slots**: Capacidade de paralelismo disponível (10 Task Slots).
- **📥 Registros Processados (In/sec)** & **⚡ Taxa de Emissão (Out/sec)**: Performance de ingestão e gravação.
- **🌊 Status de Watermark & 💾 Checkpoints**: Confiabilidade e alinhamento de tempo do evento.
- **💀 Mensagens na DLQ**: Indicador de falhas e desvio para a Dead-Letter Queue.
- **📜 Consultas Flink SQL & Stream de Logs**: DDL/DML ativas e feed ao vivo dos containers Flink.

---

### 4. 🐘 Dashboard: Métricas TimescaleDB (Grafana Loki)
- **Arquivo**: [`config/dashboards/timescaledb_loki_observability.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/timescaledb_loki_observability.json)
- **UID do Dashboard**: `timescaledb-loki-observability`
- **Fonte de Dados (Datasource)**: `Loki`
- **Fuso Horário Configurado**: `America/Sao_Paulo` (UTC-3)

#### 🎯 Objetivo do Dashboard
Monitorar a saúde do motor PostgreSQL 17 / TimescaleDB, volumetria por tabela no schema `sptrans`, taxa de gravação em disco, compressão ZSTD e logs da engine.

#### 📊 Estrutura de Painéis do TimescaleDB
- **🐘 Status TimescaleDB Engine**: Saúde do banco de dados (`ONLINE`).
- **📋 Tabela Dinâmica de Tamanho por Tabela (`sptrans`)**: Mapeamento completo de tamanho de dados, índices e total de cada tabela (`shapes`, `tb_posicao_atual_onibus`, `tb_veiculos_em_operacao`, etc.).
- **📊 Bar Gauge: Ocupação de Disco**: Comparativo em barra horizontal do espaço consumido em MB por tabela.
- **📈 Taxa de Crescimento de Dados (Bytes/sec)**: Velocidade de gravação em armazenamento.
- **📜 Scripts SQL DDL/DML & Stream de Logs**: Exibição formatada das DDLs e logs do motor PostgreSQL.
