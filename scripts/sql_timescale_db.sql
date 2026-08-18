-- Total de ônibus ativos por linha 


CREATE TABLE IF NOT EXISTS tb_onibus_ativos_por_linha (
    linha VARCHAR(50),

    janela_inicio TIMESTAMP NOT NULL,
    janela_fim TIMESTAMP NOT NULL,
    total_onibus_ativos BIGINT NOT NULL,
    PRIMARY KEY (linha, janela_fim)
);

-- Converter a tabela em Hypertable do TimescaleDB
SELECT create_hypertable('tb_onibus_ativos_por_linha', 'janela_fim', if_not_exists => TRUE);


select *
from tb_onibus_ativos_por_linha toapl 
where toapl.linha  = '627J-10' ;

