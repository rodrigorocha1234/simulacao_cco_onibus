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

-- Consulta para preencher a Variável de Filtro de Linhas no Grafana ($linha)
SELECT 
    linha AS __value,
    linha_descricao AS __text
FROM tb_linhas_onibus_filtro
ORDER BY linha ASC;







