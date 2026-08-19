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




