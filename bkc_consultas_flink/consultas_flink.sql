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
    janela_inicio TIMESTAMP(3),
    janela_fim TIMESTAMP(3),
    total_onibus_ativos BIGINT,
    PRIMARY KEY (linha,janela_fim) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://timescaledb:5432/sptrans',
    'table-name' = 'tb_onibus_ativos_por_linha',
    'username' = 'admin',
    'password' = 'admin'
);

-- Job Flink: Inserir o resultado da consulta por Janela (Tumbling Window de 1 min) no TimescaleDB
INSERT INTO sink_onibus_ativos_por_linha
SELECT 
    c AS linha,
    TUMBLE_START(kafka_time, INTERVAL '1' MINUTE) AS janela_inicio,
    TUMBLE_END(kafka_time, INTERVAL '1' MINUTE) AS janela_fim,
    COUNT(DISTINCT p) AS total_onibus_ativos
FROM linhas_onibus
GROUP BY 
    c, 
    TUMBLE(kafka_time, INTERVAL '1' MINUTE);



