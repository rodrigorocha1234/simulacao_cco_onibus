-- Total de ônibus ativos por linha (Estado Atual)
CREATE TABLE IF NOT EXISTS tb_onibus_ativos_por_linha (
    linha VARCHAR(50) PRIMARY KEY,
    total_onibus_ativos BIGINT NOT NULL,
    ultima_atualizacao TIMESTAMP NOT NULL
);

-- Velocidade média, máxima e mínima por linha (Estado Atual)
CREATE TABLE IF NOT EXISTS tb_velocidade_por_linha (
    linha VARCHAR(50) PRIMARY KEY,
    velocidade_media DOUBLE PRECISION NOT NULL,
    velocidade_maxima DOUBLE PRECISION NOT NULL,
    velocidade_minima DOUBLE PRECISION NOT NULL,
    ultima_atualizacao TIMESTAMP NOT NULL
);

-- Histórico de velocidade por linha (Série Temporal por Janela)
CREATE TABLE IF NOT EXISTS tb_historico_velocidade_por_linha (
    linha VARCHAR(50) NOT NULL,
    janela_inicio TIMESTAMP NOT NULL,
    janela_fim TIMESTAMP NOT NULL,
    velocidade_media DOUBLE PRECISION NOT NULL,
    velocidade_maxima DOUBLE PRECISION NOT NULL,
    velocidade_minima DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (linha, janela_fim)
);

-- Converter a tabela de histórico de velocidade em Hypertable do TimescaleDB
SELECT create_hypertable('tb_historico_velocidade_por_linha', 'janela_fim', if_not_exists => TRUE);

-- Headway médio, mínimo e máximo por linha em minutos (Estado Atual)
CREATE TABLE IF NOT EXISTS tb_headway_por_linha (
    linha VARCHAR(50) PRIMARY KEY,
    headway_medio DOUBLE PRECISION NOT NULL,
    headway_minimo DOUBLE PRECISION NOT NULL,
    headway_maximo DOUBLE PRECISION NOT NULL,
    ultima_atualizacao TIMESTAMP NOT NULL
);

-- Histórico de Headway por linha em minutos (Série Temporal por Janela)
CREATE TABLE IF NOT EXISTS tb_historico_headway_por_linha (
    linha VARCHAR(50) NOT NULL,
    janela_inicio TIMESTAMP NOT NULL,
    janela_fim TIMESTAMP NOT NULL,
    headway_medio DOUBLE PRECISION NOT NULL,
    headway_minimo DOUBLE PRECISION NOT NULL,
    headway_maximo DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (linha, janela_fim)
);

-- Converter a tabela de histórico de headway em Hypertable do TimescaleDB
SELECT create_hypertable('tb_historico_headway_por_linha', 'janela_fim', if_not_exists => TRUE);

-- Posição atual de cada ônibus para exibição em Mapa (Estado Atual - Upsert sem Histórico)
CREATE TABLE IF NOT EXISTS tb_posicao_atual_onibus (
    prefixo INT PRIMARY KEY,
    linha VARCHAR(50) NOT NULL,
    letreiro_terminal VARCHAR(100),
    letreiro_origem VARCHAR(100),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    acessivel BOOLEAN NOT NULL,
    ultima_atualizacao TIMESTAMP NOT NULL
);

-- Status operacional individual de cada veículo em trânsito (Estado Atual por Prefixo - Upsert)
CREATE TABLE IF NOT EXISTS tb_veiculos_em_operacao (
    prefixo INT PRIMARY KEY,
    linha VARCHAR(50) NOT NULL,
    sentido VARCHAR(10) NOT NULL,            -- 'Ida' ou 'Volta'
    velocidade_kmh DOUBLE PRECISION NOT NULL,  -- Velocidade em km/h (ex: 31.2)
    headway_minutos DOUBLE PRECISION NOT NULL, -- Headway em minutos (ex: 6.30 para 06:18)
    status VARCHAR(20) NOT NULL,               -- 'NORMAL', 'PARADO', 'ATRASADO'
    ultima_atualizacao TIMESTAMP NOT NULL
);

-- Lista de Linhas com Descrição Completa para Variável de Filtro do Grafana (Estado Atual - Upsert sem Histórico)
CREATE TABLE IF NOT EXISTS tb_linhas_onibus_filtro (
    linha VARCHAR(50) PRIMARY KEY,
    letreiro_origem VARCHAR(100),
    letreiro_terminal VARCHAR(100),
    linha_descricao VARCHAR(250) NOT NULL,     -- Ex: '627J-10 | METRÔ SÃO JUDAS - JD. MIRIAM'
    ultima_atualizacao TIMESTAMP NOT NULL
);

-- Consultas de verificação

SELECT * 
FROM tb_onibus_ativos_por_linha 
WHERE linha = '627J-10';

SELECT * 
FROM tb_velocidade_por_linha 
WHERE linha = '627J-10';

SELECT * 
FROM tb_historico_velocidade_por_linha 
WHERE linha = '627J-10' 
ORDER BY janela_fim DESC;

SELECT * 
FROM tb_headway_por_linha 
WHERE linha = '627J-10';

SELECT * 
FROM tb_historico_headway_por_linha 
WHERE linha = '627J-10' 
ORDER BY janela_fim DESC;

SELECT * 
FROM tb_posicao_atual_onibus 
WHERE linha = '627J-10' 
LIMIT 10;

-- Consulta formatada para o painel CCO: VEÍCULOS EM OPERAÇÃO
SELECT 
    prefixo,
    sentido,
    ROUND(velocidade_kmh::numeric, 1) || ' km/h' AS velocidade,
    TO_CHAR((headway_minutos || ' minutes')::INTERVAL, 'MI:SS') || ' min' AS headway,
    CASE 
        WHEN status = 'PARADO' THEN '🟡 PARADO'
        WHEN status = 'ATRASADO' THEN '🔴 ATRASADO'
        ELSE '• NORMAL'
    END AS status,
    TO_CHAR(ultima_atualizacao, 'HH24:MI:SS') AS ultima_posicao
FROM tb_veiculos_em_operacao
WHERE linha = '627J-10'
ORDER BY sentido ASC, prefixo ASC;

-- Índices de Alta Performance para Geometria e Filtro de Linhas
CREATE INDEX IF NOT EXISTS idx_shapes_lat_lon ON shapes (shape_pt_lat, shape_pt_lon);
CREATE INDEX IF NOT EXISTS idx_tb_posicao_atual_linha ON tb_posicao_atual_onibus (linha);

-- Consulta de Validação de Alta Precisão (Otimizada): Headway de Rota baseado na tabela GTFS shapes
WITH posicoes_com_shape AS (
    SELECT 
        v.prefixo,
        v.linha,
        v.latitude,
        v.longitude,
        v.ultima_atualizacao,
        (
            SELECT s.shape_dist_traveled
            FROM shapes s
            WHERE s.shape_pt_lat BETWEEN v.latitude - 0.01 AND v.latitude + 0.01
              AND s.shape_pt_lon BETWEEN v.longitude - 0.01 AND v.longitude + 0.01
            ORDER BY (POW(s.shape_pt_lat - v.latitude, 2) + POW(s.shape_pt_lon - v.longitude, 2)) ASC
            LIMIT 1
        ) AS dist_percorrida_metros
    FROM tb_posicao_atual_onibus v
),
headway_calculado AS (
    SELECT 
        linha,
        prefixo AS onibus,
        LAG(prefixo, 1) OVER (PARTITION BY linha ORDER BY dist_percorrida_metros ASC) AS onibus_a_frente,
        dist_percorrida_metros,
        ultima_atualizacao,
        ROUND(((dist_percorrida_metros - LAG(dist_percorrida_metros, 1) OVER (PARTITION BY linha ORDER BY dist_percorrida_metros ASC)) / 1000.0)::numeric, 2) AS dist_entre_onibus_km
    FROM posicoes_com_shape
)
SELECT 
    linha,
    onibus,
    onibus_a_frente,
    REPLACE(ROUND(dist_percorrida_metros::numeric, 1)::text, '.', ',') AS km_acumulado_rota,
    REPLACE(dist_entre_onibus_km::text, '.', ',') AS dist_entre_onibus_km,
    CASE 
        WHEN dist_entre_onibus_km <= 0.20 THEN '🚨 COMBOIAMENTO / BUNCHING (Colados)'
        WHEN dist_entre_onibus_km >= 5.0 THEN '🔴 BURACO DE OFERTA (Espaçamento Crítico)'
        WHEN dist_entre_onibus_km >= 3.0 THEN '🟡 ATENÇÃO (Espaçamento Moderado)'
        ELSE '🟢 REGULAR (Espaçamento Ideal)'
    END AS "Diagnóstico Operacional do CCO"
FROM headway_calculado
WHERE dist_entre_onibus_km IS NOT NULL
ORDER BY linha, dist_percorrida_metros ASC;


-- Consulta para preencher a Variável de Filtro de Linhas no Grafana ($linha)
SELECT 
    linha AS __value,
    linha_descricao AS __text
FROM tb_linhas_onibus_filtro
ORDER BY linha ASC;

-- Consulta de Extensão do Trajeto (Ida, Volta e Total Ida + Volta em KM) baseada na tabela GTFS shapes + trips
WITH extensao_por_sentido AS (
    SELECT 
        t.route_id AS linha,
        t.direction_id,
        MAX(s.shape_dist_traveled) / 1000.0 AS dist_km
    FROM shapes s
    JOIN (
        SELECT DISTINCT route_id, shape_id, direction_id 
        FROM trips 
        WHERE route_id IN ('477P-10', '627J-10', '1012-10') -- Substitua pela linha desejada (ex: '1012-10', '477P-10', '627J-10')
    ) t ON s.shape_id = t.shape_id
    GROUP BY t.route_id, t.direction_id
)
SELECT 
    linha,
    REPLACE(ROUND(COALESCE(MAX(CASE WHEN direction_id = 0 THEN dist_km END), 0)::numeric, 2)::text, '.', ',') || ' km' AS extensao_ida,
    REPLACE(ROUND(COALESCE(MAX(CASE WHEN direction_id = 1 THEN dist_km END), 0)::numeric, 2)::text, '.', ',') || ' km' AS extensao_volta,
    REPLACE(ROUND(SUM(dist_km)::numeric, 2)::text, '.', ',') || ' km' AS extensao_total_ida_e_volta
FROM extensao_por_sentido
GROUP BY linha
ORDER BY linha;














