-- Para consumir a fila
CREATE TABLE linhas_onibus (

    c STRING,
    cl INT,
    sl INT,
    lt0 STRING,
    lt1 STRING,
    qv INT,
    p INT,
    a BOOLEAN,

    ta BIGINT,
    ta_tempo STRING,

    py DOUBLE,
    px DOUBLE,

    ta_ts AS TO_TIMESTAMP(ta_tempo),
    kafka_time TIMESTAMP(3) METADATA FROM 'timestamp',

    WATERMARK FOR kafka_time AS
        kafka_time - INTERVAL '2' SECOND

)
WITH (
    'connector' = 'kafka',
    'topic' = 'posicoes_sptrans',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'flink-bus-monitor',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'avro-confluent',
    'avro-confluent.url' = 'http://schema-registry:8081'
);

-- Tabela Sink no Flink conectada ao TimescaleDB (PostgreSQL via JDBC)
CREATE TABLE sink_onibus_ativos_por_linha (
    linha STRING,
    total_onibus_ativos BIGINT,
    ultima_atualizacao TIMESTAMP(3),
    PRIMARY KEY (linha) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://timescaledb:5432/sptrans',
    'table-name' = 'tb_onibus_ativos_por_linha',
    'username' = 'admin',
    'password' = 'admin'
);

-- Job Flink: Inserir e atualizar (Upsert) o total de ônibus ativos por linha
INSERT INTO sink_onibus_ativos_por_linha
SELECT 
    c AS linha,
    COUNT(DISTINCT p) AS total_onibus_ativos,
    MAX(kafka_time) AS ultima_atualizacao
FROM linhas_onibus
GROUP BY c;


-- Tabela Sink para Velocidades por Linha conectada ao TimescaleDB (PostgreSQL via JDBC)
CREATE TABLE sink_velocidade_por_linha (
    linha STRING,
    velocidade_media DOUBLE,
    velocidade_maxima DOUBLE,
    velocidade_minima DOUBLE,
    ultima_atualizacao TIMESTAMP(3),
    PRIMARY KEY (linha) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://timescaledb:5432/sptrans',
    'table-name' = 'tb_velocidade_por_linha',
    'username' = 'admin',
    'password' = 'admin'
);

-- Job Flink: Calcular velocidade média, máxima e mínima por linha usando a fórmula de Haversine
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

-- Tabela Sink para Histórico de Velocidade por Linha conectada ao TimescaleDB (PostgreSQL via JDBC)
CREATE TABLE sink_historico_velocidade_por_linha (
    linha STRING,
    janela_inicio TIMESTAMP(3),
    janela_fim TIMESTAMP(3),
    velocidade_media DOUBLE,
    velocidade_maxima DOUBLE,
    velocidade_minima DOUBLE,
    PRIMARY KEY (linha, janela_fim) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://timescaledb:5432/sptrans',
    'table-name' = 'tb_historico_velocidade_por_linha',
    'username' = 'admin',
    'password' = 'admin'
);

-- Job Flink: Registrar histórico de velocidade por linha em Janela de 1 Minuto (Tumbling Window)
INSERT INTO sink_historico_velocidade_por_linha
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
    TUMBLE_START(curr_time, INTERVAL '1' MINUTE) AS janela_inicio,
    TUMBLE_END(curr_time, INTERVAL '1' MINUTE) AS janela_fim,
    ROUND(AVG(velocidade_kmh), 2) AS velocidade_media,
    ROUND(MAX(velocidade_kmh), 2) AS velocidade_maxima,
    ROUND(MIN(velocidade_kmh), 2) AS velocidade_minima
FROM velocidades_validas
GROUP BY
    linha,
    TUMBLE(curr_time, INTERVAL '1' MINUTE);











