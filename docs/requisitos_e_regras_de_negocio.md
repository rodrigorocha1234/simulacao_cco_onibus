# Requisitos Funcionais, Não Funcionais e Regras de Negócio
## Sistema de Simulação e Monitoramento CCO de Ônibus (SPTrans & TimescaleDB)

---

### 1. 📋 Requisitos Funcionais (RF)

| ID | Nome | Descrição Detalhada |
| :--- | :--- | :--- |
| **RF01** | **Ingestão de Dados da API SPTrans** | O sistema deve capturar dados de localização GPS e posição da frota de ônibus em tempo real a partir da API Olho Vivo da SPTrans (v2.1). |
| **RF02** | **Publicação de Eventos no Kafka** | Os eventos de posição devem ser serializados no formato AVRO e publicados continuadamente no tópico Apache Kafka utilizando o Confluent Schema Registry. |
| **RF03** | **Processamento em Fluxo via Flink** | O Apache Flink deve consumir os tópicos do Kafka, calcular janelas temporais de velocidade média/máxima/mínima e headway em tempo real. |
| **RF04** | **Persistência Temporal no TimescaleDB** | O sistema deve gravar os dados consolidados e de séries temporais no banco de dados TimescaleDB (PostgreSQL 17) em tabelas relacionais e Hypertables. |
| **RF05** | **Diagnóstico Automatizado de Comboiamento** | O sistema deve calcular a distância acumulada na rota GTFS entre ônibus consecutivos e gerar diagnósticos automáticos de comboiamento (*bunching*) e buraco de oferta. |
| **RF06** | **Monitoramento do Status da Frota** | O sistema deve indicar o estado operacional de cada veículo (*NORMAL*, *PARADO*, *ATRASADO*) com base na velocidade e no headway de rota. |
| **RF07** | **Visualização Geográfica no Grafana** | O sistema deve exibir no painel Geomap a rota gráfica GTFS (`shapes`/`trips`) e os marcadores GPS dos ônibus em movimento em tempo real. |
| **RF08** | **Filtro Dinâmico por Linha (`$linha`)** | O dashboard CCO deve permitir que o operador selecione qualquer linha de ônibus cadastrada e recalcule instantaneamente todas as métricas e gráficos. |
| **RF09** | **Observabilidade Centralizada de Logs** | O Grafana Loki e Alloy devem coletar e categorizar os logs de todos os containers para auditoria e depuração via LogQL. |
| **RF10** | **Tratamento de Exceções e DLQ** | Eventos com erro de schema ou coordenadas inválidas devem ser redirecionados para uma *Dead-Letter Queue* (`posicoes_sptrans_dlq`) sem interromper o pipeline. |
| **RF11** | **Orquestração por Perfis no Docker Compose** | O Docker Compose deve permitir inicializar módulos específicos via perfis (`profiles: servico_kafka`, `servico_flink`, `dashboard`). |
| **RF12** | **Mapeamento de Portas para o Host** | O Docker Compose deve expor portas locais para acesso administrativo (Kafka `9092`, Schema Registry `8085`, Kafka UI `8084`, Flink `8081`, TimescaleDB `5432`, Grafana `3000`, Loki `3100`). |
| **RF13** | **Persistência de Volumes Mapeados** | O Docker Compose deve mapear pastas do host (`./kafka_data`, `./timescale_data`, `./grafana_data`, `./scripts_flink`) para evitar perda de estado ao reiniciar. |
| **RF14** | **Orquestração de Dependências (`depends_on`)** | O Docker Compose deve respeitar a ordem de boot (ex: `schema-registry` e `python-producer` dependem do `kafka`; `taskmanager` depende do `jobmanager`). |
| **RF15** | **Provisionamento Automático de Dashboards** | O Grafana deve carregar automaticamente datasources e dashboards JSON ao iniciar via arquivos de provimento do Docker Compose. |

---

### 2. ⚡ Requisitos Não Funcionais (RNF)

| ID | Nome | Descrição Detalhada |
| :--- | :--- | :--- |
| **RNF01** | **Desempenho e Baixa Latência** | O tempo total entre a captura da posição GPS na API e a atualização nos gráficos do Grafana deve ser inferior a 2 segundos. |
| **RNF02** | **Resiliência e Tolerância a Falhas** | O Apache Flink deve utilizar *Checkpoints* periódicos em disco e o Kafka operar em modo *KRaft* para garantir a recuperação de estado sem perda de dados. |
| **RNF03** | **Eficiência de Armazenamento** | As tabelas históricas do TimescaleDB devem utilizar particionamento por tempo (*Hypertables*) e compressão *ZSTD* para reduzir a ocupação de disco. |
| **RNF04** | **Compatibilidade de Esquemas AVRO** | A evolução dos esquemas de mensagens no Schema Registry deve seguir a regra de compatibilidade `BACKWARD` (compatibilidade com versões anteriores). |
| **RNF05** | **Padronização do Fuso Horário** | Toda a infraestrutura (containers Docker Compose, PostgreSQL e Grafana) deve operar estritamente no fuso horário de **Brasília (`America/Sao_Paulo` / UTC-3)**. |
| **RNF06** | **Containerização e Portabilidade** | O ambiente completo deve ser inicializável via `docker-compose.yaml` com suporte a execução multiplataforma. |
| **RNF07** | **Escalabilidade Horizontal** | O pipeline de dados deve permitir o aumento transparente de *TaskManagers* no Flink e réplicas no Kafka para suportar frotas maiores. |
| **RNF08** | **Isolamento em Rede Virtual Bridge** | Todos os containers devem se comunicar em rede isolada bridge `flink-net` na subrede `172.20.0.0/16` com IPs estáticos atribuídos. |
| **RNF09** | **Recuperação Automática (`restart`)** | Serviços críticos (`kafka`, `schema-registry`, `python-producer`, `loki`, `alloy`) devem ter política de reinício automático (`restart: unless-stopped`). |
| **RNF10** | **Limites de Recursos de Memória** | O Docker Compose deve definir alocação explícita de memória para o Flink (`jobmanager.memory.process.size: 1024m` e `taskmanager.memory.process.size: 4096m`). |
| **RNF11** | **Políticas de Retenção de Mensagens no Kafka** | O broker Kafka deve gerenciar o ciclo de vida dos arquivos de log com limite temporal de 6h (`KAFKA_LOG_RETENTION_HOURS: 6`), limite volumétrico de 1 GB por partição (`KAFKA_LOG_RETENTION_BYTES: 1073741824`), rotação de segmentos a cada 100 MB (`KAFKA_LOG_SEGMENT_BYTES: 104857600`) e verificação a cada 5 min (`KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS: 300000`). |

---

### 3. ⚖️ Regras de Negócio (RN)

| ID | Regra | Critério / Lógica de Aplicação | Alerta / Status Gerado |
| :--- | :--- | :--- | :--- |
| **RN01** | **Comboiamento / Bunching (Ônibus Colados)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente $\le$ 200 metros. | `🚨 COMBOIAMENTO / BUNCHING (Colados)` |
| **RN02** | **Buraco de Oferta (Espaçamento Crítico)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente $\ge$ 5.0 km. | `🔴 BURACO DE OFERTA (Espaçamento Crítico)` |
| **RN03** | **Espaçamento Moderado (Atenção)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente entre 3.0 km e 4.99 km. | `🟡 ATENÇÃO (Espaçamento Moderado)` |
| **RN04** | **Espaçamento Ideal (Operação Regular)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente entre 201 metros e 2.99 km. | `🟢 REGULAR (Espaçamento Ideal)` |
| **RN05** | **Status de Operação do Veículo** | - Velocidade = 0 km/h.<br>- Headway superior ao limite estipulado da linha.<br>- Velocidade > 0 km/h e Headway dentro da meta. | - `🟡 PARADO`<br>- `🔴 ATRASADO`<br>- `• NORMAL` |
| **RN06** | **Sequenciamento do Traçado da Rota GTFS** | As coordenadas da rota GTFS (`shapes`) devem ser conectadas no mapa respeitando rigorosamente a ordem crescente da coluna `shape_pt_sequence ASC`. | Traçado da Rota sem distorções no Mapa |
| **RN07** | **Filtragem de Linhas Operacionais** | Apenas veículos vinculados a linhas cadastradas na tabela de catálogo `tb_linhas_onibus_filtro` devem ser processados nas séries temporais do CCO. | Isolamento por Linha Selecionada |
| **RN08** | **Execução Automática de Schemas no Flink** | O container `flink-sql-client` deve executar automaticamente o script `load_schema.sql` mapeado na inicialização para subir as tabelas streaming. | Início Automatizado das Pipelines Flink SQL |
| **RN09** | **Política Recomendada de Retenção do Kafka** | - **Exclusão por Tempo**: Exclui mensagens com mais de 6 horas (`KAFKA_LOG_CLEANUP_POLICY: delete`).<br>- **Exclusão por Volume**: Purga dados se a partição ultrapassar 1 GB (`KAFKA_LOG_RETENTION_BYTES: 1073741824`).<br>- **Rotação de Segmento**: Fecha o segmento ativo ao atingir 100 MB (`KAFKA_LOG_SEGMENT_BYTES: 104857600`).<br>- **Varredura**: Executa a verificação a cada 5 minutos (`KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS: 300000`). | Rotação e Descarte Automatizado de Logs |
| **RN10** | **Endereçamento IP Estático por Container** | Cada serviço do `docker-compose.yaml` deve receber um IP estático na rede `172.20.0.0/16` (`172.20.0.10` a `172.20.0.30`) para resolver rotas internas. | Conectividade Determinística de Rede |
