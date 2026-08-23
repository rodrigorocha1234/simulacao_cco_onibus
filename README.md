# Simulação de uma operação CCO de ônibus usando Apache kafka e Apache fink

## Introdução 

O objetivo desse projeto é simular uma **operação CCO** para acomanhar a frota de ônibus da cidade de São Paulo, usando a API da **sptrans** e **tecnologias open-source**.

## Tecnoligias usadas

🐍 **Python**: Integração com a API da SPTrans, ingestão e produção dos eventos

📨 **Apache Kafka**: Mensageria e streaming dos eventos de posicionamento

⚡ **Apache Flink**: Processamento de eventos em tempo real e aplicação das regras operacionais

⏱️ **TimescaleDB**: Armazenamento de dados de séries temporais

📊 **Grafana**: Dashboards operacionais e visualização das métricas

📜 **Grafana Loki**: Armazenamento e consulta centralizada de logs

🔄 **Grafana Alloy**: Coleta e encaminhamento de logs e métricas

🐳 **Docker**: Containerização dos componentes da plataforma

## Requisitos

### Requisitos Funcionais



| ID | Nome | Descrição Detalhada |
|---|---|---|
| RF01 | **Ingestão de Dados da API SPTrans** | O sistema deve capturar dados de localização GPS e posição da frota de ônibus em tempo real a partir da API Olho Vivo da SPTrans (v2.1). |
| RF02 | **Publicação de Eventos no Kafka** | Os eventos de posição devem ser serializados no formato AVRO e publicados continuamente no tópico Apache Kafka utilizando o Confluent Schema Registry. |
| RF03 | **Processamento em Fluxo via Flink** | O Apache Flink deve consumir os tópicos do Kafka, calcular janelas temporais de velocidade média, máxima e mínima, além do headway em tempo real. |
| RF04 | **Persistência Temporal no TimescaleDB** | O sistema deve gravar os dados consolidados e de séries temporais no TimescaleDB (PostgreSQL 17), utilizando tabelas relacionais e Hypertables. |
| RF05 | **Diagnóstico Automatizado de Comboiamento** | O sistema deve calcular a distância acumulada na rota GTFS entre ônibus consecutivos e gerar diagnósticos automáticos de comboiamento (*bunching*) e buraco de oferta. |
| RF06 | **Monitoramento do Status da Frota** | O sistema deve indicar o estado operacional de cada veículo (`NORMAL`, `PARADO`, `ATRASADO`) com base na velocidade e no headway da rota. |
| RF07 | **Visualização Geográfica no Grafana** | O sistema deve exibir no painel Geomap a rota gráfica GTFS (`shapes`/`trips`) e os marcadores GPS dos ônibus em movimento em tempo real. |
| RF08 | **Filtro Dinâmico por Linha (`$linha`)** | O dashboard CCO deve permitir que o operador selecione qualquer linha de ônibus cadastrada e recalcule instantaneamente todas as métricas e gráficos. |
| RF09 | **Observabilidade Centralizada de Logs** | O Grafana Loki e o Alloy devem coletar e categorizar os logs de todos os containers para auditoria e depuração por meio do LogQL. |
| RF10 | **Tratamento de Exceções e DLQ** | Eventos com erro de schema ou coordenadas inválidas devem ser redirecionados para uma Dead-Letter Queue (`posicoes_sptrans_dlq`) sem interromper o pipeline. |
| RF11 | **Orquestração por Perfis no Docker Compose** | O Docker Compose deve permitir inicializar módulos específicos por meio de profiles (`servico_kafka`, `servico_flink`, `dashboard`). |
| RF12 | **Mapeamento de Portas para o Host** | O Docker Compose deve expor portas locais para acesso administrativo: Kafka `9092`, Schema Registry `8085`, Kafka UI `8084`, Flink `8081`, TimescaleDB `5432`, Grafana `3000` e Loki `3100`. |
| RF13 | **Persistência de Volumes Mapeados** | O Docker Compose deve mapear pastas do host (`./kafka_data`, `./timescale_data`, `./grafana_data`, `./scripts_flink`) para evitar perda de estado ao reiniciar os serviços. |
| RF14 | **Orquestração de Dependências (`depends_on`)** | O Docker Compose deve respeitar a ordem de inicialização dos serviços. Por exemplo, `schema-registry` e `python-producer` devem depender do `kafka`, enquanto o `taskmanager` deve depender do `jobmanager`. |
| RF15 | **Provisionamento Automático de Dashboards** | O Grafana deve carregar automaticamente os datasources e dashboards JSON durante a inicialização, utilizando arquivos de provisionamento configurados no Docker Compose. |


### Requisitos não-funicionais

# Requisitos Não Funcionais

| ID        | Nome                                            | Descrição Detalhada                                                                                                                                                                                                                                                                                                                                                                     |
| --------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **RNF01** | **Desempenho e Baixa Latência**                 | O tempo total entre a captura da posição GPS na API e a atualização nos gráficos do Grafana deve ser inferior a **2 segundos**.                                                                                                                                                                                                                                                         |
| **RNF02** | **Resiliência e Tolerância a Falhas**           | O Apache Flink deve utilizar *Checkpoints* periódicos em disco e o Kafka operar em modo *KRaft* para garantir a recuperação de estado sem perda de dados.                                                                                                                                                                                                                               |
| **RNF03** | **Eficiência de Armazenamento**                 | As tabelas históricas do TimescaleDB devem utilizar particionamento por tempo (*Hypertables*) e compressão **ZSTD** para reduzir a ocupação de disco.                                                                                                                                                                                                                                   |
| **RNF04** | **Compatibilidade de Esquemas AVRO**            | A evolução dos esquemas de mensagens no Schema Registry deve seguir a regra de compatibilidade **`BACKWARD`**, garantindo compatibilidade com versões anteriores.                                                                                                                                                                                                                       |
| **RNF05** | **Padronização do Fuso Horário**                | Toda a infraestrutura, incluindo containers Docker Compose, PostgreSQL e Grafana, deve operar estritamente no fuso horário de **Brasília (`America/Sao_Paulo` / UTC-3)**.                                                                                                                                                                                                               |
| **RNF06** | **Containerização e Portabilidade**             | O ambiente completo deve ser inicializável via **`docker-compose.yaml`**, com suporte à execução multiplataforma.                                                                                                                                                                                                                                                                       |
| **RNF07** | **Escalabilidade Horizontal**                   | O pipeline de dados deve permitir o aumento transparente de *TaskManagers* no Flink e réplicas no Kafka para suportar frotas maiores.                                                                                                                                                                                                                                                   |
| **RNF08** | **Isolamento em Rede Virtual Bridge**           | Todos os containers devem se comunicar por meio da rede isolada **bridge `flink-net`**, utilizando a sub-rede `172.20.0.0/16` com IPs estáticos atribuídos.                                                                                                                                                                                                                             |
| **RNF09** | **Recuperação Automática (`restart`)**          | Os serviços críticos (`kafka`, `schema-registry`, `python-producer`, `loki` e `alloy`) devem possuir política de reinício automático (`restart: unless-stopped`).                                                                                                                                                                                                                       |
| **RNF10** | **Limites de Recursos de Memória**              | O Docker Compose deve definir alocação explícita de memória para o Flink, utilizando `jobmanager.memory.process.size: 1024m` e `taskmanager.memory.process.size: 4096m`.                                                                                                                                                                                                                |
| **RNF11** | **Políticas de Retenção de Mensagens no Kafka** | O broker Kafka deve gerenciar o ciclo de vida dos arquivos de log com retenção temporal de **6 horas** (`KAFKA_LOG_RETENTION_HOURS: 6`), limite de **1 GB por partição** (`KAFKA_LOG_RETENTION_BYTES: 1073741824`), rotação de segmentos a cada **100 MB** (`KAFKA_LOG_SEGMENT_BYTES: 104857600`) e verificação a cada **5 minutos** (`KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS: 300000`). |


### Regras de negócio


| ID   | Regra | Critério / Lógica de Aplicação | Alerta / Status Gerado |
|------|-------|---------------------------------|-------------------------|
| **RN01** | **Comboiamento / Bunching (Ônibus Colados)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente **≤ 200 metros**. | `🚨 COMBOIAMENTO / BUNCHING (Colados)` |
| **RN02** | **Buraco de Oferta (Espaçamento Crítico)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente **≥ 5,0 km**. | `🔴 BURACO DE OFERTA (Espaçamento Crítico)` |
| **RN03** | **Espaçamento Moderado (Atenção)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente **entre 3,0 km e 4,99 km**. | `🟡 ATENÇÃO (Espaçamento Moderado)` |
| **RN04** | **Espaçamento Ideal (Operação Regular)** | Distância acumulada no traçado GTFS entre o ônibus atual e o ônibus à frente **entre 201 metros e 2,99 km**. | `🟢 REGULAR (Espaçamento Ideal)` |
| **RN05** | **Status de Operação do Veículo** | - Velocidade = **0 km/h**.<br>- Headway superior ao limite estipulado da linha.<br>- Velocidade > 0 km/h e Headway dentro da meta. | - `🟡 PARADO`<br>- `🔴 ATRASADO`<br>- `• NORMAL` |
| **RN06** | **Sequenciamento do Traçado da Rota GTFS** | As coordenadas da rota GTFS (`shapes`) devem ser conectadas no mapa respeitando rigorosamente a ordem crescente da coluna `shape_pt_sequence ASC`. | Traçado da rota sem distorções no mapa. |
| **RN07** | **Filtragem de Linhas Operacionais** | Apenas veículos vinculados a linhas cadastradas na tabela de catálogo `tb_linhas_onibus_filtro` devem ser processados nas séries temporais do CCO. | Isolamento por linha selecionada. |
| **RN08** | **Execução Automática de Schemas no Flink** | O container `flink-sql-client` deve executar automaticamente o script `load_schema.sql` mapeado na inicialização para subir as tabelas de streaming. | Início automatizado das pipelines Flink SQL. |
| **RN09** | **Política Recomendada de Retenção do Kafka** | - **Exclusão por tempo:** mensagens com mais de 6 horas (`KAFKA_LOG_CLEANUP_POLICY=delete`).<br>- **Exclusão por volume:** purga quando a partição ultrapassar 1 GB (`KAFKA_LOG_RETENTION_BYTES=1073741824`).<br>- **Rotação de segmento:** fecha o segmento ativo ao atingir 100 MB (`KAFKA_LOG_SEGMENT_BYTES=104857600`).<br>- **Varredura:** verificação a cada 5 minutos (`KAFKA_LOG_RETENTION_CHECK_INTERVAL_MS=300000`). | Rotação e descarte automatizado de logs. |
| **RN10** | **Endereçamento IP Estático por Container** | Cada serviço do `docker-compose.yaml` deve receber um IP estático na rede `172.20.0.0/16`, utilizando endereços entre `172.20.0.10` e `172.20.0.30`, para resolver rotas internas. | Conectividade determinística de rede. |


## Arquitetura do projeto

### Diagrama de arquitetura integração


<!-- ![Proposta Arquitetura](https://raw.githubusercontent.com/rodrigorocha1234/simulacao_cco_onibus/refs/heads/main/fig/diagrama_arqui_int.png) -->

<div align="center">
  <a href="https://raw.githubusercontent.com/rodrigorocha1234/simulacao_cco_onibus/refs/heads/main/fig/diagrama_arqui_int.png" target="_blank">
    <img 
      src="https://raw.githubusercontent.com/rodrigorocha1234/simulacao_cco_onibus/refs/heads/main/fig/diagrama_arqui_int.png" 
      alt="Proposta Arquitetura" 
      style="max-width: 100%; height: auto;"
    />
  </a>
</div>




### Perfil: Serviço Kafka

####  Produtor Ingestor Sptrans API
* **Papel:** Fornecer a localização GPS em tempo real de toda a frota de ônibus em circulação na cidade de São Paulo via requisições HTTPS REST (`GET /Posicao`).

####  Ingestão & Serialização AVRO (python-producer & schema-registry)
* **python-producer:** Script Python que realiza o polling periódico na API Olho Vivo, extrai a posição GPS dos veículos (prefixo, linha, latitude, longitude, velocidade, sentido) e empacota o payload.
* **schema-registry (Confluent Schema Registry v7.8.0):** Serviço na porta 8085 que armazena e valida o contrato de dados no formato AVRO (`posicao_onibus.avsc`), garantindo a evolução de atributos em modo BACKWARD.

####  Camada de Mensageria (Apache Kafka Broker 4.1. & kafka-ui)
* **kafka:** Broker Apache Kafka v4.1.1 operando na porta 9092 em modo nativo KRaft (sem ZooKeeper).
* **posicoes_sptrans:** Tópico principal particionado que recebe o stream contínuo de dados (vazão de 74 a 193 mensagens/segundo).
* **posicoes_sptrans_dlq:** Dead-Letter Queue para desviar e isolar mensagens corrompidas ou com erro de esquema.
* **kafka-ui:** Interface gráfica web na porta 8084 para inspeção visual do cluster, partições e offsets.

---

###  Processamento em Fluxo (Apache Flink Cluster 1.20.0) (Perfil: Servico_flinl)
* **flink-jobmanager:** Nó master responsável por orquestrar tarefas, alocar slots e gerenciar a recuperação de falhas via Checkpoints.
* **flink-taskmanager:** Nó trabalhador (Worker) com 10 Task Slots para processamento paralelo distribuído.
* **flink-sql-client:** Executa as pipelines Flink SQL orientadas ao tempo do evento (Event-Time Watermarking). Calcula janelas de tempo de 1 minuto (Tumbling Windows) agregando:
  * Velocidade média, máxima e mínima por linha.
  * Headway médio (tempo de intervalo) por linha.
  * Total de ônibus ativos por linha.

---

### Armazenamento Temporal & Relacional (TimescaleDB / PostgreSQL 17)
* **timescaledb:** Banco PostgreSQL 17 com a extensão TimescaleDB na porta 5432 no banco `sptrans`.
* **Tabelas de Estado Operacional:**
  * `tb_posicao_atual_onibus`: Registra a última coordenada GPS conhecida de cada veículo.
  * `tb_veiculos_em_operacao`: Registra o status CCO consolidado por prefixo (NORMAL 🟢, PARADO 🟡, ATRASADO 🔴).
  * `tb_linhas_onibus_filtro`: Catálogo de linhas de ônibus operacionais.
  * `shapes` e `trips`: Malha geométrica GTFS que mapeia a trajetória gráfica dos trajetos.
* **Hypertables (Séries Temporais com Compressão ZSTD):**
  * `tb_historico_velocidade_por_linha`: Armazena o histórico contínuo das janelas de velocidade.
  * `tb_historico_headway_por_linha`: Armazena o histórico contínuo das janelas de intervalo.

---

###  Visualização & Observabilidade (Grafana Stack & Loki)
* **grafana:** Interface web na porta 3000 configurada no fuso oficial de Brasília (`America/Sao_Paulo` / UTC-3).
  * **Datasource TimescaleDB:** Executa consultas SQL diretas para plotar os KPIs CCO em tempo real, a tabela de diagnóstico de comboiamento (bunching) e o mapa interativo Geomap (rota GTFS + marcadores GPS).
* **loki & alloy:** O agente Grafana Alloy varre os logs stdout/stderr de todos os containers e os transmite ao Grafana Loki (porta 3100) para análise de observabilidade da infraestrutura via LogQL.

---

### As 7 Etapas do Fluxo de Dados Ponta a Ponta

1. **1 - Polling GET /Posicao:** O script python-producer faz o polling na API Olho Vivo da SPTrans.
2. **2 - Validação AVRO Schema:** O produtor valida o esquema da mensagem com o Confluent Schema Registry.
3. **3 - Publicação de Eventos AVRO:** O produtor envia os eventos formatados para o tópico Kafka `posicoes_sptrans`.
4. **4 - Ingestão Streaming Event-Time:** O Flink consome os dados do Kafka, aplica Watermarking e calcula as agregações em janelas temporais de 1 min.
5. **5 - Sink Estado & Hypertables:** O Flink salva o estado da frota e insere os registros históricos nas Hypertables do TimescaleDB.
6. **6 - Consultas SQL Nativas CCO:** O Grafana lê o TimescaleDB via SQL nativo e atualiza os painéis do CCO, diagnósticos de comboiamento e o mapa Geomap no fuso de Brasília.
7. **7 - LogQL Analytics:** O Grafana Alloy envia os logs dos containers ao Loki, alimentando os dashboards de observabilidade de infraestrutura.





# Dashboard

## Sistema de Simulação e Monitoramento CCO de Ônibus (SPTrans & TimescaleDB)

Prover uma visão operacional em tempo real do Centro de Controle Operacional (CCO) da SPTrans. Permite monitorar a frota de ônibus, diagnosticar comboiamentos (bunching), acompanhar velocidades, intervalos (headway), séries temporais históricas em Hypertables e visualizar o rastreamento geográfico dos veículos sobre o traçado GTFS.

## Filtro Dinâmico por Linha (`$linha`)

Menu suspenso no topo do dashboard que executa a consulta:

```sql
SELECT linha AS __value, linha_descricao AS __text FROM tb_linhas_onibus_filtro ORDER BY linha ASC;
```

---

## Estrutura dos Painéis & Interpretação dos Resultados no Momento

### Painéis KPI Stat Cards (Indicadores em Tempo Real)

* **Ônibus Ativos na Linha:**
  * **Valor no Momento:** `3`
  * **Interpretação:** A linha `1012-10` está sendo operada atualmente por 3 veículos em circulação ativa simultânea.

* **Velocidade Média da Linha:**
  * **Valor no Momento:** `12.9 km/h`
  * **Interpretação:** Tráfego fluindo a uma velocidade média urbana de 12.9 km/h, compatível com a velocidade média de corredores de ônibus em horário de pico na capital paulista.

* **Velocidade Máxima / Mínima:**
  * **Valor no Momento:** `104.66 km/h (Máxima) / 0 km/h (Mínima)`
  * **Interpretação:** O valor de 0 km/h indica veículos parados em semáforos ou pontos de embarque/desembarque. O pico registrado (104 km/h) reflete picos transitórios de transmissão de GPS ou trechos expressos de via rápida.

* **Headway Médio:**
  * **Valor no Momento:** `3.1 min`
  * **Interpretação:** O intervalo médio de espera dos passageiros nos pontos da linha é de 3 minutos e 6 segundos, indicando excelente frequência de atendimento.

* **Extensão do Trajeto (Ida + Volta):**
  * **Valor no Momento:** `18.4 km`
  * **Interpretação:** O percurso completo de Ida e Volta da linha possui 18.4 km mapeados na geometria GTFS (shapes/trips).

---

### Painel de Diagnóstico Operacional CCO (Tabela com Alertas Coloridos)

* **Diagnóstico Operacional CCO por Veículo:**
  * **Resultados no Momento:**
    * **a. Ônibus 16379 vs 16096:** Distância entre ônibus: `0,00 km` (`22,1 m`). **Diagnóstico:** `COMBOIAMENTO / BUNCHING (Colados)`.
      * **Interpretação:** Os dois ônibus estão parados praticamente na mesma posição (22 metros de distância) no terminal. O sistema CCO dispara um alerta vermelho automático notificando o controlador para segurar a partida do veículo traseiro.
    * **b. Ônibus 16559 vs 16379:** Distância entre ônibus: `3,73 km` (`3752,6 m`). **Diagnóstico:** `ATENÇÃO (Espaçamento Moderado)`.
      * **Interpretação:** O veículo 16559 está a 3,73 km de distância do veículo à frente, gerando alerta amarelo de atenção para que o CCO evite que essa distância aumente e vire um buraco de oferta.

---

### Painel de Status da Frota em Operação

* **Tabela CCO: Veículos em Operação por Linha (`$linha`):**
  * **Resultados no Momento:**
    * **Prefixo 16559:** Sentido Volta \| Velocidade `39.7 km/h` \| Headway `7.5 min` \| **Status:** `NORMAL` (Em pleno deslocamento no itinerário).
    * **Prefixo 16096:** Sentido Ida \| Velocidade `0 km/h` \| Headway `9.72 min` \| **Status:** `PARADO` (Em ponto de parada ou terminal).
    * **Prefixo 16379:** Sentido Ida \| Velocidade `0 km/h` \| Headway `9.72 min` \| **Status:** `PARADO` (Em ponto de parada ou terminal).

---

###  Painéis de Séries Temporais (Hypertables do TimescaleDB)

* **Histórico de Velocidades por Janela (`tb_historico_velocidade_por_linha`):**
  * **Interpretação no Momento:** Gráfico contínuo renderizado no Horário Oficial de Brasília (`America/Sao_Paulo`), exibindo as oscilações de velocidade média (12 a 18 km/h) a cada janela de 1 minuto processada pelo Flink.

* **Histórico de Headway por Janela (`tb_historico_headway_por_linha`):**
  * **Interpretação no Momento:** Acompanhamento histórico do intervalo médio por janela temporal no fuso de Brasília, mostrando estabilidade do headway entre 2.5 min e 3.8 min.

---

### Painel de Rastreamento Geográfico (Geomap Interativo)

* **Mapa Geográfico CCO: Traçado da Rota (`$linha`) & Posição dos Ônibus:**
  * **Interpretação no Momento:** Exibe o traçado azul contínuo da rota GTFS conectando os pontos geográficos em ordem sequencial (`ORDER BY s.shape_id, s.shape_pt_sequence ASC`). Sobre o traçado, os marcadores verdes exibem a posição em tempo real dos 3 ônibus ativos.

---

##  Métricas Kafka (Grafana Loki)

### Objetivo do Dashboard

Monitorar a saúde, vazão de mensagens, métricas do broker Apache Kafka (v4.1.1 KRaft) e a operabilidade do Confluent Schema Registry via LogQL.

### Interpretação Detalhada dos Painéis & Resultados Capturados no Momento

#### Visão Geral do Cluster & Status Operacional do Broker

* **Brokers Online:** 1 (Card Verde)
  * **Interpretação:** O container do broker Apache Kafka (kafka) está ativo, saudável e respondendo sem interrupções.
* **Broker Leader Controller:** Broker #1 (Card Azul)
  * **Interpretação:** O Broker #1 é o controlador ativo responsável pelo gerenciamento de consenso KRaft (No-ZooKeeper).
* **Réplicas ISR (In-Sync Replicas):** 91 (Card Verde)
  * **Interpretação:** Existem 91 réplicas de partições sincronizadas e atualizadas sem atraso (lag), garantindo tolerância a falhas e integridade de escrita.
* **Total de Tópicos:** 1 (Card Amarelo)
  * **Interpretação:** Tópico principal `posicoes_sptrans` ativo para recepção do streaming de dados.
* **Partições Ativas:** 269 (Card Azul)
  * **Interpretação:** 269 partições distribuídas e ativas no cluster, permitindo paralelismo massivo de leitura pelo Apache Flink.
* **Versão do Cluster:** v4.1.1 (KRaft) (Card Roxo)
  * **Interpretação:** Cluster Kafka atualizado rodando em arquitetura nativa KRaft.

#### Tabela de Especificações dos Brokers Kafka Ativos

* **Tabela de Especificações de Rede e Status:**
  * **Conteúdo:** Broker ID: Broker #1 \| Container: kafka \| Versão: v4.1.1 \| Consenso: KRaft Mode (No-ZooKeeper) \| IP Interno: 172.20.0.21:9092 \| Portas Host: 9092 / 9093 / 29092 \| **Status:** ONLINE
  * **Interpretação:** O broker está acessível tanto internamente na rede bridge Docker `flink-net` quanto externamente pelas portas do host local.

#### Vazão de Mensagens & Desempenho do Broker em Tempo Real

* **Mensagens Recebidas por Segundo (In/sec):** Média 60.9 a 81.4 ops/s \| Pico 153 a 193 ops/s \| Atual 150 a 186 ops/s
  * **Interpretação:** Medição da taxa de eventos recebidos no broker. O gráfico mostra picos de até 193 mensagens por segundo nos momentos de carga máxima de polling da API SPTrans, mantendo vazão constante sem gargalos.
* **Conexões de Clientes & Eventos de Broker / sec:** Média 60.7 a 80.3 ops/s \| Pico 154 a 194 ops/s \| Atual 151 a 166 ops/s
  * **Interpretação:** Frequência de requisições de conexão e eventos I/O processados pelo broker.
* **Publicações por Segundo (Publish / sec):** Média 55.3 a 75.6 ops/s \| Pico 150 a 192 ops/s \| Atual 149 a 166 ops/s
  * **Interpretação:** Taxa de mensagens confirmadas e publicadas com sucesso nos segmentos de log do tópico `posicoes_sptrans`.

#### Confluent Schema Registry & Registro de Esquemas AVRO

* **Status Schema Registry:** 1 (Card Verde - ONLINE) — Serviço Schema Registry em perfeito funcionamento na porta 8085.
* **Esquemas AVRO Ativos:** 1 (Card Roxo) — Esquema `posicoes_sptrans-value` cadastrado.
* **Último Schema ID:** 1 (Card Roxo) — Identificador único da primeira versão do schema.
* **Latência Média REST:** 23 ms (Card Roxo) — A API REST responde em apenas 23 milissegundos para validação de esquemas.
* **Modo Compatibilidade:** BACKWARD (Card Azul) — Garante que novas versões do schema sejam compatíveis com consumidores anteriores.
* **Erros Desserialização:** 0 (Card Verde) — Fundo verde indicando zero exceções ou falhas de parse de mensagens.
* **Requisições HTTP REST (Picos 0.383 ops/s) & Distribuição GET/POST:**
  * **Interpretação:** Gráficos demonstrando chamadas transitórias de consulta e registro de schemas executadas pelo produtor.

#### Tabela de Esquemas AVRO & Especificações do Schema Registry

* **Detalhamento do Schema Registrado:**
  * **Subject Name:** `posicoes_sptrans-value`
  * **Formato:** Apache AVRO v1.11
  * **Schema ID:** ID #1 (Versão v1.0, Tamanho 755 Bytes)
  * **Portas Host / Docker:** localhost:8085 / 8081
  * **Status:** REGISTERED & ACTIVE

#### Volumetria de Armazenamento & Stream de Logs do Broker

* **Tamanho Total dos Diretórios de Log (Total Log Dir Size):** 1.87 MiB (Card Verde)
  * **Interpretação:** Armazenamento total utilizado pelos segmentos de log do Kafka no disco, demonstrando atuação da política de retenção recomendada (6 horas / 1 GB).
* **Tamanho por Tópico e Container (Topic Size em Bytes/sec):**
  * `python-producer`: 5.89 KiB/s (Maior gerador de tráfego de logs)
  * `kafka`: 473 B/s
  * `kafka-ui`: 29.9 B/s
* **Stream de Logs em Tempo Real (Loki Feed):**
  * **Interpretação:** Feed ao vivo mostrando o `python-producer` enviando mensagens AVRO formatadas com partição e offset incremental: `INFO container=python-producer ... - Mensagem enviada. tópico=posicoes_sptrans partição=3 offset=3746`

---

## Métricas Flink (Grafana Loki)

### Objetivo do Dashboard

Monitorar a execução do motor Apache Flink v1.20.0 (JobManager, TaskManager, Flink SQL), vazão de streaming, watermarking, checkpoints e erros em Dead-Letter Queue.

### Interpretação dos Resultados no Momento

* **Status Flink Cluster:** `ONLINE` — Engine de processamento em fluxo Flink 1.20.0 operacional.
* **JobManager & TaskManagers:** `1 JobManager Leader / 1 TaskManager Worker` ativo.
* **Total Task Slots:** `10 Slots` — Capacidade paralela de processamento pronta para suportar múltiplos pipelines Flink SQL.
* **Registros Processados (In/sec) & Emissão (Out/sec):** Fluxo contínuo calculando estatísticas a cada janela temporal de 1 minuto (Tumbling Window).
* **Watermark & Checkpoints:** `ALIGNING` / Concluídos com Sucesso — Alinhamento temporal de eventos e persistência de estado em disco sem perdas.
* **Mensagens na DLQ (Dead-Letter Queue):** `0` — Zero mensagens desviadas para a fila de erros `posicoes_sptrans_dlq`.

---

##  Dashboard: Métricas TimescaleDB (Grafana Loki)

### Objetivo do Dashboard

Monitorar a saúde do motor PostgreSQL 17 / TimescaleDB, volumetria por tabela no schema `sptrans`, taxa de gravação em disco, compressão ZSTD e logs da engine.

### Interpretação dos Resultados no Momento

* **Status TimescaleDB Engine:** `ONLINE` — Banco de dados PostgreSQL 17 / TimescaleDB operando normalmente no banco `sptrans`.
* **Volumetria por Tabela Mapeada no Momento:**
  1. `shapes`: 81 MB (57 MB Dados + 25 MB Índices) — Maior tabela do banco, contendo a malha de trajetos geográficos GTFS.
  2. `tb_posicao_atual_onibus`: 22 MB (19 MB Dados + 3.2 MB Índices) — Tabela de posições GPS atualizadas em tempo real.
  3. `tb_veiculos_em_operacao`: 16 MB (14 MB Dados + 1.7 MB Índices) — Tabela de status operacional CCO por prefixo.
  4. `tb_linhas_onibus_filtro`: 14 MB (13 MB Dados + 1.1 MB Índices) — Catálogo de linhas de ônibus.
  5. `tb_velocidade_por_linha`: 8.5 MB (7.3 MB Dados + 1.1 MB Índices) — Métrica agregada de velocidade.
  6. `tb_onibus_ativos_por_linha`: 6.6 MB (5.5 MB Dados + 1.0 MB Índices) — Métrica de veículos ativos.
  7. `tb_headway_por_linha`: 968 kB (784 kB Dados + 152 kB Índices) — Métrica agregada de headway.
* **Bar Gauge de Ocupação:** Exibe visualmente o destaque da tabela `shapes` (81 MB) como maior consumidora de espaço, seguida da tabela de estado GPS `tb_posicao_atual_onibus` (22 MB).

## Demonstração
[![Assistir ao vídeo de demonstração do projeto](https://img.shields.io/badge/🎬%20Assistir%20ao%20vídeo-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://youtu.be/Kx_v8dn240s)

[Link do reposítório](https://github.com/rodrigorocha1/criacao_datalake_youtube)
