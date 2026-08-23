# Documentação e Explicação Detalhada dos Dashboards do Grafana
## Sistema de Simulação e Monitoramento CCO de Ônibus (SPTrans & TimescaleDB)
### *Incluindo Interpretação dos Resultados em Tempo Real*

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
* **Leitura no Momento**: Linha `1012-10` (*METRÔ VILA MADALENA - JD. MIRIAM*) selecionada. O filtro altera instantaneamente todos os painéis e gráficos para focar na linha escolhida.

---

#### 📊 Estrutura dos Painéis & Interpretação dos Resultados no Momento

##### 1.1 Painéis KPI Stat Cards (Indicadores em Tempo Real)
* **🚌 Ônibus Ativos na Linha**:
  * **Valor no Momento**: `3`
  * **Interpretação**: A linha `1012-10` está sendo operada atualmente por 3 veículos em circulação ativa simultânea.
* **⚡ Velocidade Média da Linha**:
  * **Valor no Momento**: `12.9 km/h`
  * **Interpretação**: Tráfego fluindo a uma velocidade média urbana de 12.9 km/h, compatível com a velocidade média de corredores de ônibus em horário de pico na capital paulista.
* **🚀 Velocidade Máxima / Mínima**:
  * **Valor no Momento**: `104.66 km/h (Máxima) / 0 km/h (Mínima)`
  * **Interpretação**: O valor de 0 km/h indica veículos parados em semáforos ou pontos de embarque/desembarque. O pico registrado (104 km/h) reflete picos transitórios de transmissão de GPS ou trechos expressos de via rápida.
* **⏱️ Headway Médio**:
  * **Valor no Momento**: `3.1 min`
  * **Interpretação**: O intervalo médio de espera dos passageiros nos pontos da linha é de 3 minutos e 6 segundos, indicando excelente frequência de atendimento.
* **📏 Extensão do Trajeto (Ida + Volta)**:
  * **Valor no Momento**: `18.4 km`
  * **Interpretação**: O percurso completo de Ida e Volta da linha possui 18.4 km mapeados na geometria GTFS (`shapes`/`trips`).

##### 1.2 Painel de Diagnóstico Operacional CCO (Tabela com Alertas Coloridos)
* **🚨 Diagnóstico Operacional CCO por Veículo**:
  * **Resultados no Momento**:
    1. **Ônibus `16379` vs `16096`**: Distância entre ônibus: `0,00 km` (`22,1 m`). **Diagnóstico**: `🚨 COMBOIAMENTO / BUNCHING (Colados)`.
       * **Interpretação**: Os dois ônibus estão parados praticamente na mesma posição (22 metros de distância) no terminal. O sistema CCO dispara um alerta vermelho automático notificando o controlador para segurar a partida do veículo traseiro.
    2. **Ônibus `16559` vs `16379`**: Distância entre ônibus: `3,73 km` (`3752,6 m`). **Diagnóstico**: `🟡 ATENÇÃO (Espaçamento Moderado)`.
       * **Interpretação**: O veículo `16559` está a 3,73 km de distância do veículo à frente, gerando alerta amarelo de atenção para que o CCO evite que essa distância aumente e vire um buraco de oferta.

##### 1.3 Painel de Status da Frota em Operação
* **📋 Tabela CCO: Veículos em Operação por Linha (`$linha`)**:
  * **Resultados no Momento**:
    - **Prefixo `16559`**: Sentido Volta | Velocidade `39.7 km/h` | Headway `7.5 min` | Status: `NORMAL 🟢` (*Em pleno deslocamento no itinerário*).
    - **Prefixo `16096`**: Sentido Ida | Velocidade `0 km/h` | Headway `9.72 min` | Status: `PARADO 🟡` (*Em ponto de parada ou terminal*).
    - **Prefixo `16379`**: Sentido Ida | Velocidade `0 km/h` | Headway `9.72 min` | Status: `PARADO 🟡` (*Em ponto de parada ou terminal*).

##### 1.4 Painéis de Séries Temporais (Hypertables do TimescaleDB)
* **📈 Histórico de Velocidades por Janela (`tb_historico_velocidade_por_linha`)**:
  * **Interpretação no Momento**: Gráfico contínuo renderizado no **Horário Oficial de Brasília (`America/Sao_Paulo`)**, exibindo as oscilações de velocidade média (12 a 18 km/h) a cada janela de 1 minuto processada pelo Flink.
* **⏱️ Histórico de Headway por Janela (`tb_historico_headway_por_linha`)**:
  * **Interpretação no Momento**: Acompanhamento histórico do intervalo médio por janela temporal no fuso de Brasília, mostrando estabilidade do headway entre 2.5 min e 3.8 min.

##### 1.5 Painel de Rastreamento Geográfico (Geomap Interativo)
* **🗺️ Mapa Geográfico CCO: Traçado da Rota (`$linha`) & Posição dos Ônibus**:
  * **Interpretação no Momento**: Exibe o traçado azul contínuo da rota GTFS conectando os pontos geográficos em ordem sequencial (`ORDER BY s.shape_id, s.shape_pt_sequence ASC`). Sobre o traçado, os marcadores verdes exibem a posição em tempo real dos 3 ônibus ativos.

---

### 2. 📦 Dashboard: Métricas Kafka (Grafana Loki)
- **Arquivo**: [`config/dashboards/kafka_loki_observability.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/kafka_loki_observability.json)
- **UID do Dashboard**: `kafka-loki-observability`
- **Fonte de Dados (Datasource)**: `Loki`
- **Fuso Horário Configurado**: `America/Sao_Paulo` (UTC-3)

#### 🎯 Objetivo do Dashboard
Monitorar a saúde, vazão de mensagens, métricas do broker Apache Kafka (v4.1.1 KRaft) e a operabilidade do Confluent Schema Registry via LogQL.

#### 📊 Interpretação dos Resultados no Momento
* **🖥️ Brokers Online**: `1` — O broker Apache Kafka está 100% online e operando em modo KRaft (sem dependência de ZooKeeper).
* **👑 Broker Leader Controller**: `Broker #1` — O nó 1 é o controlador ativo do cluster.
* **🛡️ Réplicas ISR (In-Sync)**: `18 / 18` — Todas as 18 partições de tópicos possuem réplicas sincronizadas ativas.
* **📁 Total de Tópicos / 🔀 Partições Ativas**: `1 Tópico (`posicoes_sptrans`) / 18 Partições Ativas` — Ingestão distribuída em alta capacidade.
* **📥 Mensagens Recebidas (In/sec) & 📤 Publicações (Publish/sec)**: Taxas de ingestão constantes na média de `74 a 78 ops/sec` geradas pelo produtor da API SPTrans.
* **🧬 Status Schema Registry**: `1 (ONLINE)` — Confluent Schema Registry operacional.
* **📜 Esquemas AVRO Ativos**: `1 Schema` (`posicao_onibus.avsc`) — Validação estrutural de mensagens ativa em modo `BACKWARD`.
* **⚠️ Erros Desserialização**: `0` — Fundo verde indicando zero falhas de serialização ou mensagens corrompidas.

---

### 3. ⚡ Dashboard: Métricas Flink (Grafana Loki)
- **Arquivo**: [`config/dashboards/flink_loki_observability.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/flink_loki_observability.json)
- **UID do Dashboard**: `flink-loki-observability`
- **Fonte de Dados (Datasource)**: `Loki`
- **Fuso Horário Configurado**: `America/Sao_Paulo` (UTC-3)

#### 🎯 Objetivo do Dashboard
Monitorar a execução do motor Apache Flink v1.20.0 (JobManager, TaskManager, Flink SQL), vazão de streaming, watermarking, checkpoints e erros em Dead-Letter Queue.

#### 📊 Interpretação dos Resultados no Momento
* **⚡ Status Flink Cluster**: `ONLINE` — Engine de processamento em fluxo Flink 1.20.0 operacional.
* **🧠 JobManager & ⚙️ TaskManagers**: `1 JobManager Leader / 1 TaskManager Worker` ativo.
* **🎯 Total Task Slots**: `10 Slots` — Capacidade paralela de processamento pronta para suportar múltiplos pipelines Flink SQL.
* **📥 Registros Processados (In/sec) & ⚡ Emissão (Out/sec)**: Fluxo contínuo calculando estatísticas a cada janela temporal de 1 minuto (*Tumbling Window*).
* **🌊 Watermark & 💾 Checkpoints**: `ALIGNING / Concluídos com Sucesso` — Alinhamento temporal de eventos e persistência de estado em disco sem perdas.
* **💀 Mensagens na DLQ (Dead-Letter Queue)**: `0` — Zero mensagens desviadas para a fila de erros `posicoes_sptrans_dlq`.

---

### 4. 🐘 Dashboard: Métricas TimescaleDB (Grafana Loki)
- **Arquivo**: [`config/dashboards/timescaledb_loki_observability.json`](file:///home/rodrigo/PycharmProjects/simulacao_cco_onibus/config/dashboards/timescaledb_loki_observability.json)
- **UID do Dashboard**: `timescaledb-loki-observability`
- **Fonte de Dados (Datasource)**: `Loki`
- **Fuso Horário Configurado**: `America/Sao_Paulo` (UTC-3)

#### 🎯 Objetivo do Dashboard
Monitorar a saúde do motor PostgreSQL 17 / TimescaleDB, volumetria por tabela no schema `sptrans`, taxa de gravação em disco, compressão ZSTD e logs da engine.

#### 📊 Interpretação dos Resultados no Momento
* **🐘 Status TimescaleDB Engine**: `ONLINE` — Banco de dados PostgreSQL 17 / TimescaleDB operando normalmente no banco `sptrans`.
* **📋 Volumetria por Tabela Mapeada no Momento**:
  1. **`shapes`**: **`81 MB`** (*57 MB Dados + 25 MB Índices*) — Maior tabela do banco, contendo a malha de trajetos geográficos GTFS.
  2. **`tb_posicao_atual_onibus`**: **`22 MB`** (*19 MB Dados + 3.2 MB Índices*) — Tabela de posições GPS atualizadas em tempo real.
  3. **`tb_veiculos_em_operacao`**: **`16 MB`** (*14 MB Dados + 1.7 MB Índices*) — Tabela de status operacional CCO por prefixo.
  4. **`tb_linhas_onibus_filtro`**: **`14 MB`** (*13 MB Dados + 1.1 MB Índices*) — Catálogo de linhas de ônibus.
  5. **`tb_velocidade_por_linha`**: **`8.5 MB`** (*7.3 MB Dados + 1.1 MB Índices*) — Métrica agregada de velocidade.
  6. **`tb_onibus_ativos_por_linha`**: **`6.6 MB`** (*5.5 MB Dados + 1.0 MB Índices*) — Métrica de veículos ativos.
  7. **`tb_headway_por_linha`**: **`968 kB`** (*784 kB Dados + 152 kB Índices*) — Métrica agregada de headway.
* **📊 Bar Gauge de Ocupação**: Exibe visualmente o destaque da tabela `shapes` (81 MB) como maior consumidora de espaço, seguida da tabela de estado GPS `tb_posicao_atual_onibus` (22 MB).
