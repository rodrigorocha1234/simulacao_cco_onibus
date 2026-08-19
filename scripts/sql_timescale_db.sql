-- Total de ônibus ativos por linha (Estado Atual)


CREATE TABLE IF NOT EXISTS tb_onibus_ativos_por_linha (
    linha VARCHAR(50) PRIMARY KEY,
    total_onibus_ativos BIGINT NOT NULL,
    ultima_atualizacao TIMESTAMP NOT NULL
);


SELECT *
FROM tb_onibus_ativos_por_linha toapl 
WHERE toapl.linha = '627J-10';

