/* ============================================================================
   PORTFÓLIO BI | LOGÍSTICA E ENTREGAS
   ----------------------------------------------------------------------------
   Banco .......: SQL Server 2019 ou mais novo (Express ou Developer servem)
   O que faz ...: 1) cria o banco LogisticaBI
                  2) cria as tabelas de cadastro (cad) e de operação (ops)
                  3) popula tudo com dados FICTÍCIOS gerados por regras de negócio
                     (jan/2025 a out/2026, ~40 mil pedidos)
                  4) cria as views (bi) que o Power BI consome
   Como rodar ..: abrir no SSMS (ou Azure Data Studio) e executar tudo (F5)
   Observação ..: os dados são determinísticos: rodar de novo recria o banco
                  com exatamente os mesmos números.
   ============================================================================ */

/* ============================================================================
   0. BANCO
   Se o banco já existir, derruba e cria de novo (script pode ser rodado várias vezes)
   ============================================================================ */
USE master;
GO

IF DB_ID(N'LogisticaBI') IS NOT NULL
BEGIN
    ALTER DATABASE LogisticaBI SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LogisticaBI;
END;
GO

CREATE DATABASE LogisticaBI;
GO

USE LogisticaBI;
GO

/* ============================================================================
   1. SCHEMAS (organização)
   ============================================================================ */
CREATE SCHEMA cad;   -- cadastros (viram as dimensões no BI)
GO
CREATE SCHEMA ops;   -- operação do dia a dia (viram os fatos no BI)
GO
CREATE SCHEMA bi;    -- views prontas para o Power BI consumir
GO

/* ============================================================================
   2. FUNÇÃO DE APOIO
   Devolve um número "aleatório" entre 0 e 1, mas sempre o mesmo para a mesma
   semente (usa hash). É isso que deixa os dados reproduzíveis.
   ============================================================================ */
CREATE FUNCTION dbo.fnAleatorio (@Semente BIGINT)
RETURNS DECIMAL(9, 8)
WITH SCHEMABINDING
AS
BEGIN
    RETURN ABS(CHECKSUM(HASHBYTES('SHA2_256', CONVERT(VARCHAR(30), @Semente))) % 100000000) / 100000000.0;
END;
GO

/* ============================================================================
   3. TABELAS
   ============================================================================ */

-- Cidades atendidas (com coordenadas para calcular distância até o CD)
CREATE TABLE cad.Cidade (
    CidadeID     INT IDENTITY(1, 1) CONSTRAINT PK_Cidade PRIMARY KEY,
    Cidade       NVARCHAR(60)  NOT NULL,
    UF           CHAR(2)       NOT NULL,
    Regiao       NVARCHAR(20)  NOT NULL,
    Latitude     DECIMAL(9, 6) NOT NULL,
    Longitude    DECIMAL(9, 6) NOT NULL,
    PesoDemanda  INT           NOT NULL   -- peso relativo: cidade maior recebe mais clientes
);

-- Prazo prometido ao cliente (SLA) por região de destino
CREATE TABLE cad.PrazoRegiao (
    Regiao     NVARCHAR(20) NOT NULL CONSTRAINT PK_PrazoRegiao PRIMARY KEY,
    PrazoDias  INT          NOT NULL
);

-- Centros de distribuição (de onde as cargas saem)
CREATE TABLE cad.CentroDistribuicao (
    CDID              INT          NOT NULL CONSTRAINT PK_CentroDistribuicao PRIMARY KEY,
    NomeCD            NVARCHAR(60) NOT NULL,
    CidadeID          INT          NOT NULL CONSTRAINT FK_CD_Cidade REFERENCES cad.Cidade (CidadeID),
    CapacidadeDiaria  INT          NOT NULL   -- pedidos/dia que o CD consegue expedir
);

-- Transportadoras (frota própria + terceirizadas)
CREATE TABLE cad.Transportadora (
    TransportadoraID    INT           NOT NULL CONSTRAINT PK_Transportadora PRIMARY KEY,
    NomeTransportadora  NVARCHAR(60)  NOT NULL,
    TipoFrota           NVARCHAR(20)  NOT NULL,   -- Própria / Terceirizada
    CustoFixo           DECIMAL(8, 2) NOT NULL,   -- R$ por entrega
    CustoKm             DECIMAL(6, 4) NOT NULL    -- R$ por km
);

-- Categorias de carga (faixas de peso e valor usadas na geração dos pedidos)
CREATE TABLE cad.Categoria (
    CategoriaID  INT            NOT NULL CONSTRAINT PK_Categoria PRIMARY KEY,
    Categoria    NVARCHAR(40)   NOT NULL,
    Fragil       BIT            NOT NULL,
    PesoMinKg    DECIMAL(8, 2)  NOT NULL,
    PesoMaxKg    DECIMAL(8, 2)  NOT NULL,
    ValorMin     DECIMAL(10, 2) NOT NULL,
    ValorMax     DECIMAL(10, 2) NOT NULL
);

-- Clientes (empresas que recebem as entregas)
CREATE TABLE cad.Cliente (
    ClienteID     INT          NOT NULL CONSTRAINT PK_Cliente PRIMARY KEY,
    NomeCliente   NVARCHAR(80) NOT NULL,
    Segmento      NVARCHAR(30) NOT NULL,
    CidadeID      INT          NOT NULL CONSTRAINT FK_Cliente_Cidade REFERENCES cad.Cidade (CidadeID),
    DataCadastro  DATE         NOT NULL
);

-- Calendário (uma linha por dia)
CREATE TABLE cad.Calendario (
    Data          DATE         NOT NULL CONSTRAINT PK_Calendario PRIMARY KEY,
    Ano           SMALLINT     NOT NULL,
    Mes           TINYINT      NOT NULL,
    NomeMes       NVARCHAR(10) NOT NULL,
    MesAno        NVARCHAR(8)  NOT NULL,   -- ex.: jan/25
    AnoMes        INT          NOT NULL,   -- ex.: 202501 (usado para ordenar)
    Trimestre     NVARCHAR(2)  NOT NULL,
    DiaSemanaNum  TINYINT      NOT NULL,   -- 1 = segunda ... 7 = domingo
    DiaSemana     NVARCHAR(10) NOT NULL,
    FimDeSemana   BIT          NOT NULL
);

-- Pedidos
CREATE TABLE ops.Pedido (
    PedidoID         INT            NOT NULL CONSTRAINT PK_Pedido PRIMARY KEY,
    ClienteID        INT            NOT NULL CONSTRAINT FK_Pedido_Cliente REFERENCES cad.Cliente (ClienteID),
    CDID             INT            NOT NULL CONSTRAINT FK_Pedido_CD REFERENCES cad.CentroDistribuicao (CDID),
    CategoriaID      INT            NOT NULL CONSTRAINT FK_Pedido_Categoria REFERENCES cad.Categoria (CategoriaID),
    DataPedido       DATE           NOT NULL,
    ValorMercadoria  DECIMAL(12, 2) NOT NULL,
    PesoKg           DECIMAL(10, 2) NOT NULL,
    Volumes          INT            NOT NULL
);

-- Entregas (1 por pedido)
CREATE TABLE ops.Entrega (
    EntregaID         INT            NOT NULL CONSTRAINT PK_Entrega PRIMARY KEY,
    PedidoID          INT            NOT NULL CONSTRAINT UQ_Entrega_Pedido UNIQUE,
    TransportadoraID  INT            NOT NULL CONSTRAINT FK_Entrega_Transportadora REFERENCES cad.Transportadora (TransportadoraID),
    DistanciaKm       DECIMAL(8, 1)  NOT NULL,
    DataColeta        DATE           NOT NULL,
    DataPrevista      DATE           NOT NULL,   -- data do pedido + prazo da região
    DataEntrega       DATE           NULL,       -- vazia se ainda não foi entregue
    StatusEntrega     NVARCHAR(20)   NOT NULL,   -- Entregue / Em trânsito / Devolvido / Extraviado
    CustoFrete        DECIMAL(10, 2) NOT NULL,
    CONSTRAINT FK_Entrega_Pedido FOREIGN KEY (PedidoID) REFERENCES ops.Pedido (PedidoID)
);

-- Ocorrências registradas durante a entrega
CREATE TABLE ops.Ocorrencia (
    OcorrenciaID    INT          IDENTITY(1, 1) CONSTRAINT PK_Ocorrencia PRIMARY KEY,
    EntregaID       INT          NOT NULL CONSTRAINT FK_Ocorrencia_Entrega REFERENCES ops.Entrega (EntregaID),
    DataOcorrencia  DATE         NOT NULL,
    TipoOcorrencia  NVARCHAR(40) NOT NULL
);
GO

/* ============================================================================
   4. CADASTROS FIXOS
   ============================================================================ */
INSERT INTO cad.Cidade (Cidade, UF, Regiao, Latitude, Longitude, PesoDemanda)
VALUES
    (N'São Paulo', 'SP', N'Sudeste', -23.5505, -46.6333, 100),
    (N'Campinas', 'SP', N'Sudeste', -22.9056, -47.0608, 25),
    (N'Ribeirão Preto', 'SP', N'Sudeste', -21.1775, -47.8103, 15),
    (N'Sorocaba', 'SP', N'Sudeste', -23.5015, -47.4526, 12),
    (N'São José dos Campos', 'SP', N'Sudeste', -23.1791, -45.8872, 12),
    (N'Santos', 'SP', N'Sudeste', -23.9608, -46.3336, 10),
    (N'Cajamar', 'SP', N'Sudeste', -23.3550, -46.8770, 2),
    (N'Rio de Janeiro', 'RJ', N'Sudeste', -22.9068, -43.1729, 60),
    (N'Niterói', 'RJ', N'Sudeste', -22.8832, -43.1034, 10),
    (N'Campos dos Goytacazes', 'RJ', N'Sudeste', -21.7545, -41.3244, 6),
    (N'Belo Horizonte', 'MG', N'Sudeste', -19.9167, -43.9345, 35),
    (N'Contagem', 'MG', N'Sudeste', -19.9320, -44.0539, 4),
    (N'Uberlândia', 'MG', N'Sudeste', -18.9186, -48.2772, 12),
    (N'Juiz de Fora', 'MG', N'Sudeste', -21.7642, -43.3496, 8),
    (N'Montes Claros', 'MG', N'Sudeste', -16.7350, -43.8617, 5),
    (N'Vitória', 'ES', N'Sudeste', -20.3155, -40.3128, 10),
    (N'Curitiba', 'PR', N'Sul', -25.4284, -49.2733, 30),
    (N'São José dos Pinhais', 'PR', N'Sul', -25.5350, -49.2060, 3),
    (N'Londrina', 'PR', N'Sul', -23.3045, -51.1696, 10),
    (N'Maringá', 'PR', N'Sul', -23.4205, -51.9333, 8),
    (N'Cascavel', 'PR', N'Sul', -24.9555, -53.4552, 5),
    (N'Florianópolis', 'SC', N'Sul', -27.5954, -48.5480, 12),
    (N'Joinville', 'SC', N'Sul', -26.3045, -48.8487, 12),
    (N'Blumenau', 'SC', N'Sul', -26.9194, -49.0661, 8),
    (N'Chapecó', 'SC', N'Sul', -27.1004, -52.6152, 5),
    (N'Porto Alegre', 'RS', N'Sul', -30.0346, -51.2177, 28),
    (N'Caxias do Sul', 'RS', N'Sul', -29.1678, -51.1794, 10),
    (N'Pelotas', 'RS', N'Sul', -31.7654, -52.3376, 6),
    (N'Santa Maria', 'RS', N'Sul', -29.6842, -53.8069, 5),
    (N'Brasília', 'DF', N'Centro-Oeste', -15.7939, -47.8828, 30),
    (N'Goiânia', 'GO', N'Centro-Oeste', -16.6869, -49.2648, 18),
    (N'Anápolis', 'GO', N'Centro-Oeste', -16.3281, -48.9534, 5),
    (N'Cuiabá', 'MT', N'Centro-Oeste', -15.6014, -56.0979, 9),
    (N'Campo Grande', 'MS', N'Centro-Oeste', -20.4697, -54.6201, 9),
    (N'Salvador', 'BA', N'Nordeste', -12.9714, -38.5014, 28),
    (N'Feira de Santana', 'BA', N'Nordeste', -12.2664, -38.9663, 8),
    (N'Vitória da Conquista', 'BA', N'Nordeste', -14.8615, -40.8442, 5),
    (N'Recife', 'PE', N'Nordeste', -8.0476, -34.8770, 25),
    (N'Cabo de Santo Agostinho', 'PE', N'Nordeste', -8.2870, -35.0350, 2),
    (N'Caruaru', 'PE', N'Nordeste', -8.2760, -35.9819, 6),
    (N'Fortaleza', 'CE', N'Nordeste', -3.7319, -38.5267, 24),
    (N'Juazeiro do Norte', 'CE', N'Nordeste', -7.2131, -39.3151, 5),
    (N'João Pessoa', 'PB', N'Nordeste', -7.1195, -34.8450, 10),
    (N'Natal', 'RN', N'Nordeste', -5.7945, -35.2110, 10),
    (N'Maceió', 'AL', N'Nordeste', -9.6658, -35.7353, 9),
    (N'Aracaju', 'SE', N'Nordeste', -10.9472, -37.0731, 8),
    (N'Teresina', 'PI', N'Nordeste', -5.0920, -42.8038, 9),
    (N'São Luís', 'MA', N'Nordeste', -2.5307, -44.3068, 10),
    (N'Belém', 'PA', N'Norte', -1.4558, -48.4902, 14),
    (N'Santarém', 'PA', N'Norte', -2.4385, -54.6996, 4),
    (N'Manaus', 'AM', N'Norte', -3.1190, -60.0217, 16),
    (N'Macapá', 'AP', N'Norte', 0.0349, -51.0694, 4),
    (N'Boa Vista', 'RR', N'Norte', 2.8235, -60.6758, 3),
    (N'Porto Velho', 'RO', N'Norte', -8.7612, -63.9004, 5),
    (N'Rio Branco', 'AC', N'Norte', -9.9747, -67.8100, 3),
    (N'Palmas', 'TO', N'Norte', -10.1840, -48.3336, 4);

INSERT INTO cad.PrazoRegiao (Regiao, PrazoDias)
VALUES (N'Sudeste', 3), (N'Sul', 4), (N'Centro-Oeste', 5), (N'Nordeste', 6), (N'Norte', 9);

INSERT INTO cad.CentroDistribuicao (CDID, NomeCD, CidadeID, CapacidadeDiaria)
SELECT v.CDID, v.NomeCD, c.CidadeID, v.Capacidade
FROM (VALUES
        (1, N'CD Cajamar',                 N'Cajamar',                 4000),
        (2, N'CD Contagem',                N'Contagem',                1800),
        (3, N'CD São José dos Pinhais',    N'São José dos Pinhais',    1600),
        (4, N'CD Cabo de Santo Agostinho', N'Cabo de Santo Agostinho', 1500),
        (5, N'CD Anápolis',                N'Anápolis',                1200)
     ) AS v (CDID, NomeCD, Cidade, Capacidade)
JOIN cad.Cidade AS c ON c.Cidade = v.Cidade;

-- Nomes fictícios
INSERT INTO cad.Transportadora (TransportadoraID, NomeTransportadora, TipoFrota, CustoFixo, CustoKm)
VALUES
    (1, N'Rápido Horizonte',     N'Terceirizada', 18.00, 0.0900),
    (2, N'TransVia Cargas',      N'Terceirizada', 14.00, 0.0700),
    (3, N'Expresso Cerrado',     N'Terceirizada', 13.00, 0.0650),
    (4, N'LogNorte Transportes', N'Terceirizada', 16.00, 0.0750),
    (5, N'Frota Própria',        N'Própria',       8.00, 0.0500),
    (6, N'EconoFrete',           N'Terceirizada',  9.00, 0.0450);

INSERT INTO cad.Categoria (CategoriaID, Categoria, Fragil, PesoMinKg, PesoMaxKg, ValorMin, ValorMax)
VALUES
    (1, N'Eletrônicos', 1,  2.00,  25.00, 300.00, 6000.00),
    (2, N'Vestuário',   0,  1.00,  10.00,  80.00,  900.00),
    (3, N'Alimentos',   0, 10.00,  60.00, 100.00, 1500.00),
    (4, N'Móveis',      1, 30.00, 120.00, 500.00, 4000.00),
    (5, N'Farmácia',    0,  0.50,   8.00,  50.00,  700.00),
    (6, N'Autopeças',   0,  3.00,  40.00, 100.00, 2500.00);
GO

/* ============================================================================
   5. GERAÇÃO DOS DADOS
   Tudo em um bloco só (as variáveis e tabelas temporárias valem até o fim dele)
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @Inicio       DATE = '2025-01-01';   -- primeiro pedido
DECLARE @Fim          DATE = '2026-10-31';   -- data de corte (hoje, para os dados)
DECLARE @QtdClientes  INT  = 1500;
DECLARE @PedidosDia   INT  = 60;              -- média base de pedidos por dia

---------------------------------------------------------------------------
-- 5.1 Tabela de números 1..100.000 (apoio para "multiplicar" linhas)
---------------------------------------------------------------------------
DROP TABLE IF EXISTS #Numeros;
CREATE TABLE #Numeros (N INT NOT NULL PRIMARY KEY);

WITH D AS (SELECT n FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS v (n))
INSERT INTO #Numeros (N)
SELECT 1 + a.n + 10 * b.n + 100 * c.n + 1000 * d.n + 10000 * e.n
FROM D AS a CROSS JOIN D AS b CROSS JOIN D AS c CROSS JOIN D AS d CROSS JOIN D AS e;

---------------------------------------------------------------------------
-- 5.2 Calendário 2025-2026
-- Dia da semana calculado a partir de 01/01/1900 (uma segunda-feira),
-- assim não depende do idioma/configuração do servidor
---------------------------------------------------------------------------
INSERT INTO cad.Calendario (Data, Ano, Mes, NomeMes, MesAno, AnoMes, Trimestre, DiaSemanaNum, DiaSemana, FimDeSemana)
SELECT
    d.Data,
    YEAR(d.Data),
    MONTH(d.Data),
    CHOOSE(MONTH(d.Data), N'jan', N'fev', N'mar', N'abr', N'mai', N'jun', N'jul', N'ago', N'set', N'out', N'nov', N'dez'),
    CONCAT(CHOOSE(MONTH(d.Data), N'jan', N'fev', N'mar', N'abr', N'mai', N'jun', N'jul', N'ago', N'set', N'out', N'nov', N'dez'),
           N'/', RIGHT(CONVERT(CHAR(4), YEAR(d.Data)), 2)),
    YEAR(d.Data) * 100 + MONTH(d.Data),
    CONCAT(N'T', DATEPART(QUARTER, d.Data)),
    w.DiaSemanaNum,
    CHOOSE(w.DiaSemanaNum, N'seg', N'ter', N'qua', N'qui', N'sex', N'sáb', N'dom'),
    CASE WHEN w.DiaSemanaNum >= 6 THEN 1 ELSE 0 END
FROM #Numeros AS n
CROSS APPLY (SELECT DATEADD(DAY, n.N - 1, CAST('2025-01-01' AS DATE)) AS Data) AS d
CROSS APPLY (SELECT DATEDIFF(DAY, '19000101', d.Data) % 7 + 1 AS DiaSemanaNum) AS w
WHERE n.N <= DATEDIFF(DAY, '2025-01-01', '2026-12-31') + 1;

---------------------------------------------------------------------------
-- 5.3 Clientes
-- A cidade é sorteada respeitando o PesoDemanda (cidade grande = mais clientes)
---------------------------------------------------------------------------
WITH Faixas AS (
    -- cada cidade ganha uma faixa entre 0 e 1 proporcional ao seu peso
    SELECT
        CidadeID,
        CAST(SUM(PesoDemanda) OVER (ORDER BY CidadeID ROWS UNBOUNDED PRECEDING) - PesoDemanda AS DECIMAL(18, 8))
            / SUM(PesoDemanda) OVER () AS FaixaIni,
        CAST(SUM(PesoDemanda) OVER (ORDER BY CidadeID ROWS UNBOUNDED PRECEDING) AS DECIMAL(18, 8))
            / SUM(PesoDemanda) OVER () AS FaixaFim
    FROM cad.Cidade
),
Sorteios AS (
    SELECT
        N AS ClienteID,
        dbo.fnAleatorio(N * 10 + 1) AS rCidade,
        dbo.fnAleatorio(N * 10 + 2) AS rPrefixo,
        dbo.fnAleatorio(N * 10 + 3) AS rNome,
        dbo.fnAleatorio(N * 10 + 4) AS rData
    FROM #Numeros
    WHERE N <= @QtdClientes
)
INSERT INTO cad.Cliente (ClienteID, NomeCliente, Segmento, CidadeID, DataCadastro)
SELECT
    s.ClienteID,
    CONCAT(p.Prefixo, N' ', nm.Nome),
    p.Segmento,
    f.CidadeID,
    DATEADD(DAY, CAST(s.rData * 1400 AS INT), CAST('2021-01-01' AS DATE))
FROM Sorteios AS s
JOIN Faixas AS f
    ON s.rCidade >= f.FaixaIni AND s.rCidade < f.FaixaFim
JOIN (VALUES
        (0, N'Comercial',     N'Atacado'),
        (1, N'Distribuidora', N'Atacado'),
        (2, N'Supermercado',  N'Supermercado'),
        (3, N'Mercado',       N'Supermercado'),
        (4, N'Farmácia',      N'Farmácia'),
        (5, N'Drogaria',      N'Farmácia'),
        (6, N'Loja',          N'Varejo'),
        (7, N'Magazine',      N'Varejo'),
        (8, N'Casa',          N'Varejo'),
        (9, N'Shop',          N'E-commerce')
     ) AS p (Idx, Prefixo, Segmento)
    ON p.Idx = CAST(s.rPrefixo * 10 AS INT)
JOIN (VALUES
        (0, N'Aurora'), (1, N'Bom Preço'), (2, N'Central'), (3, N'Estrela'), (4, N'Horizonte'),
        (5, N'Ipê'), (6, N'Jatobá'), (7, N'Nova Era'), (8, N'Pioneira'), (9, N'Real'),
        (10, N'Sol Nascente'), (11, N'União'), (12, N'Vitória'), (13, N'Primavera'), (14, N'Cristal'),
        (15, N'Bandeirante'), (16, N'Litoral'), (17, N'Serrana'), (18, N'Avenida'), (19, N'Imperial')
     ) AS nm (Idx, Nome)
    ON nm.Idx = CAST(s.rNome * 20 AS INT);

---------------------------------------------------------------------------
-- 5.4 CD de cada cliente = o mais próximo (distância geográfica)
-- Distância de estrada ~ linha reta x 1,25 + 15 km de trecho urbano
---------------------------------------------------------------------------
DROP TABLE IF EXISTS #ClienteCD;

SELECT
    cl.ClienteID,
    cl.Segmento,
    ci.Regiao,
    cd.CDID,
    cd.DistanciaKm
INTO #ClienteCD
FROM cad.Cliente AS cl
JOIN cad.Cidade AS ci ON ci.CidadeID = cl.CidadeID
CROSS APPLY (
    SELECT TOP (1)
        c.CDID,
        CAST(geography::Point(ci.Latitude, ci.Longitude, 4326)
                 .STDistance(geography::Point(cc.Latitude, cc.Longitude, 4326)) / 1000.0 * 1.25 + 15
             AS DECIMAL(8, 1)) AS DistanciaKm
    FROM cad.CentroDistribuicao AS c
    JOIN cad.Cidade AS cc ON cc.CidadeID = c.CidadeID
    ORDER BY geography::Point(ci.Latitude, ci.Longitude, 4326)
                 .STDistance(geography::Point(cc.Latitude, cc.Longitude, 4326))
) AS cd;

---------------------------------------------------------------------------
-- 5.5 Quantidade de pedidos por dia
-- base x sazonalidade do mês (Black Friday/Natal) x dia da semana x crescimento 2026
---------------------------------------------------------------------------
DROP TABLE IF EXISTS #PedidosDia;

SELECT
    c.Data,
    CAST(ROUND(@PedidosDia * m.Fator * w.Fator
               * CASE WHEN c.Ano = 2026 THEN 1.12 ELSE 1.00 END
               * (0.90 + 0.20 * dbo.fnAleatorio(DATEDIFF(DAY, '20000101', c.Data) * 10 + 5)), 0) AS INT) AS QtdPedidos
INTO #PedidosDia
FROM cad.Calendario AS c
JOIN (VALUES (1, 0.85), (2, 0.85), (3, 0.95), (4, 0.95), (5, 1.05), (6, 0.95),
             (7, 1.00), (8, 1.00), (9, 1.00), (10, 1.05), (11, 1.45), (12, 1.30)) AS m (Mes, Fator)
    ON m.Mes = c.Mes
JOIN (VALUES (1, 1.10), (2, 1.10), (3, 1.10), (4, 1.10), (5, 1.10), (6, 0.70), (7, 0.50)) AS w (DiaSemanaNum, Fator)
    ON w.DiaSemanaNum = c.DiaSemanaNum
WHERE c.Data BETWEEN @Inicio AND @Fim;

---------------------------------------------------------------------------
-- 5.6 Pedidos
---------------------------------------------------------------------------
DROP TABLE IF EXISTS #Pedidos;

-- uma linha por pedido
SELECT
    ROW_NUMBER() OVER (ORDER BY d.Data, n.N) AS PedidoID,
    d.Data AS DataPedido
INTO #Pedidos
FROM #PedidosDia AS d
JOIN #Numeros AS n ON n.N <= d.QtdPedidos;

WITH Base AS (
    SELECT
        p.PedidoID,
        p.DataPedido,
        -- clientes com ID menor compram mais (curva de Pareto)
        1 + CAST(POWER(CAST(dbo.fnAleatorio(p.PedidoID * 20 + 1) AS FLOAT), 1.8) * @QtdClientes AS INT) AS ClienteID,
        dbo.fnAleatorio(p.PedidoID * 20 + 2) AS rCategoria,
        dbo.fnAleatorio(p.PedidoID * 20 + 3) AS rPeso,
        dbo.fnAleatorio(p.PedidoID * 20 + 4) AS rValor
    FROM #Pedidos AS p
),
ComCategoria AS (
    -- a categoria da carga depende do segmento do cliente
    SELECT
        b.*,
        cc.CDID,
        CASE cc.Segmento
            WHEN N'Farmácia'     THEN 5
            WHEN N'Supermercado' THEN CASE WHEN b.rCategoria < 0.75 THEN 3 ELSE 1 END
            WHEN N'Varejo'       THEN CASE WHEN b.rCategoria < 0.35 THEN 2
                                           WHEN b.rCategoria < 0.60 THEN 1
                                           WHEN b.rCategoria < 0.85 THEN 4
                                           ELSE 6 END
            WHEN N'E-commerce'   THEN CASE WHEN b.rCategoria < 0.40 THEN 1
                                           WHEN b.rCategoria < 0.75 THEN 2
                                           WHEN b.rCategoria < 0.90 THEN 5
                                           ELSE 4 END
            ELSE                      CASE WHEN b.rCategoria < 0.20 THEN 1   -- Atacado: um pouco de tudo
                                           WHEN b.rCategoria < 0.40 THEN 2
                                           WHEN b.rCategoria < 0.65 THEN 3
                                           WHEN b.rCategoria < 0.75 THEN 4
                                           WHEN b.rCategoria < 0.85 THEN 5
                                           ELSE 6 END
        END AS CategoriaID
    FROM Base AS b
    JOIN #ClienteCD AS cc ON cc.ClienteID = b.ClienteID
)
INSERT INTO ops.Pedido (PedidoID, ClienteID, CDID, CategoriaID, DataPedido, ValorMercadoria, PesoKg, Volumes)
SELECT
    c.PedidoID,
    c.ClienteID,
    c.CDID,
    c.CategoriaID,
    c.DataPedido,
    CAST(cat.ValorMin + (cat.ValorMax - cat.ValorMin) * c.rValor AS DECIMAL(12, 2)),
    pk.PesoKg,
    1 + CAST(pk.PesoKg / 25 AS INT)
FROM ComCategoria AS c
JOIN cad.Categoria AS cat ON cat.CategoriaID = c.CategoriaID
-- peso puxado para cargas leves (r ao quadrado)
CROSS APPLY (SELECT CAST(cat.PesoMinKg + (cat.PesoMaxKg - cat.PesoMinKg) * c.rPeso * c.rPeso AS DECIMAL(10, 2)) AS PesoKg) AS pk;

---------------------------------------------------------------------------
-- 5.7 Entregas
-- Regras de negócio que geram os padrões que o BI vai mostrar:
--   * até 350 km a frota própria faz a maior parte das entregas
--   * no Norte/Nordeste entram transportadoras regionais
--   * cada transportadora tem uma chance diferente de atrasar (EconoFrete é a pior)
--   * Norte e pico de nov/dez atrasam mais
--   * pedido feito no fim de semana só é coletado na segunda
---------------------------------------------------------------------------
DROP TABLE IF EXISTS #Entregas;

WITH Base AS (
    SELECT
        p.PedidoID,
        p.DataPedido,
        p.CategoriaID,
        p.PesoKg,
        cc.Regiao,
        cc.DistanciaKm,
        pr.PrazoDias,
        DATEDIFF(DAY, '19000101', p.DataPedido) % 7 + 1 AS DiaSemanaNum,
        dbo.fnAleatorio(p.PedidoID * 20 + 11) AS rTransp,
        dbo.fnAleatorio(p.PedidoID * 20 + 12) AS rColeta,
        dbo.fnAleatorio(p.PedidoID * 20 + 13) AS rAtraso,
        dbo.fnAleatorio(p.PedidoID * 20 + 14) AS rDiasAtraso,
        dbo.fnAleatorio(p.PedidoID * 20 + 15) AS rStatus
    FROM ops.Pedido AS p
    JOIN #ClienteCD AS cc ON cc.ClienteID = p.ClienteID
    JOIN cad.PrazoRegiao AS pr ON pr.Regiao = cc.Regiao
),
ComTransportadora AS (
    SELECT
        b.*,
        CASE
            WHEN b.DistanciaKm <= 350 THEN
                CASE WHEN b.rTransp < 0.60 THEN 5 WHEN b.rTransp < 0.85 THEN 1 ELSE 2 END
            WHEN b.Regiao = N'Norte' THEN
                CASE WHEN b.rTransp < 0.50 THEN 4 WHEN b.rTransp < 0.75 THEN 3 WHEN b.rTransp < 0.90 THEN 2 ELSE 6 END
            WHEN b.Regiao = N'Nordeste' THEN
                CASE WHEN b.rTransp < 0.35 THEN 4 WHEN b.rTransp < 0.60 THEN 2 WHEN b.rTransp < 0.80 THEN 1 ELSE 6 END
            ELSE
                CASE WHEN b.rTransp < 0.30 THEN 1 WHEN b.rTransp < 0.60 THEN 2 WHEN b.rTransp < 0.80 THEN 3 ELSE 6 END
        END AS TransportadoraID
    FROM Base AS b
),
ComPrazos AS (
    SELECT
        t.*,
        -- dias até a coleta: 70% sai no mesmo dia; sábado/domingo empurram para segunda
        CASE WHEN t.rColeta < 0.70 THEN 0 ELSE 1 END
          + CASE t.DiaSemanaNum WHEN 6 THEN 2 WHEN 7 THEN 1 ELSE 0 END AS DiasColeta,
        -- dias de viagem: 1 dia a cada ~650 km
        CASE WHEN t.DistanciaKm <= 650 THEN 1 ELSE CAST(CEILING(t.DistanciaKm / 650.0) AS INT) END AS DiasTransito,
        -- chance de atraso: transportadora + região + pico de fim de ano
        CASE t.TransportadoraID
            WHEN 1 THEN 0.05 WHEN 2 THEN 0.10 WHEN 3 THEN 0.08
            WHEN 4 THEN 0.12 WHEN 5 THEN 0.04 ELSE 0.20
        END
          + CASE WHEN t.Regiao = N'Norte' THEN 0.06 ELSE 0 END
          + CASE WHEN MONTH(t.DataPedido) IN (11, 12) THEN 0.07 ELSE 0 END AS ChanceAtraso
    FROM ComTransportadora AS t
),
ComDatas AS (
    SELECT
        c.*,
        CASE WHEN c.rAtraso < c.ChanceAtraso
             THEN 1 + CAST(c.rDiasAtraso * 4 AS INT) + CASE WHEN c.Regiao = N'Norte' THEN 2 ELSE 0 END
             ELSE 0 END AS DiasAtrasoOperacional,
        DATEADD(DAY, c.DiasColeta, c.DataPedido) AS DataColeta,
        DATEADD(DAY, c.PrazoDias, c.DataPedido) AS DataPrevista
    FROM ComPrazos AS c
)
SELECT
    d.PedidoID AS EntregaID,
    d.PedidoID,
    d.TransportadoraID,
    d.DistanciaKm,
    d.DataPedido,
    d.DataColeta,
    d.DataPrevista,
    d.DiasTransito,
    d.DiasAtrasoOperacional,
    d.CategoriaID,
    d.rStatus,
    DATEADD(DAY, d.DiasTransito + d.DiasAtrasoOperacional, d.DataColeta) AS DataEntregaCalculada,
    CASE
        WHEN d.rStatus < 0.003 THEN N'Extraviado'
        WHEN d.rStatus < 0.018 THEN N'Devolvido'
        WHEN DATEADD(DAY, d.DiasTransito + d.DiasAtrasoOperacional, d.DataColeta) > @Fim THEN N'Em trânsito'
        ELSE N'Entregue'
    END AS StatusEntrega,
    CAST((t.CustoFixo + t.CustoKm * d.DistanciaKm * (1 + d.PesoKg / 50.0))
         * CASE WHEN MONTH(d.DataPedido) IN (11, 12) THEN 1.08 ELSE 1.00 END AS DECIMAL(10, 2)) AS CustoFrete
INTO #Entregas
FROM ComDatas AS d
JOIN cad.Transportadora AS t ON t.TransportadoraID = d.TransportadoraID;

INSERT INTO ops.Entrega (EntregaID, PedidoID, TransportadoraID, DistanciaKm, DataColeta, DataPrevista, DataEntrega, StatusEntrega, CustoFrete)
SELECT
    EntregaID,
    PedidoID,
    TransportadoraID,
    DistanciaKm,
    DataColeta,
    DataPrevista,
    CASE WHEN StatusEntrega = N'Entregue' THEN DataEntregaCalculada END,
    StatusEntrega,
    CustoFrete
FROM #Entregas;

---------------------------------------------------------------------------
-- 5.8 Ocorrências
---------------------------------------------------------------------------
INSERT INTO ops.Ocorrencia (EntregaID, DataOcorrencia, TipoOcorrencia)
SELECT EntregaID, DataOcorrencia, TipoOcorrencia
FROM (
    -- entregas atrasadas: motivo do atraso
    SELECT
        e.EntregaID,
        DATEADD(DAY, e.DiasTransito, e.DataColeta) AS DataOcorrencia,
        CASE
            WHEN r.rTipo < 0.30 THEN N'Destinatário ausente'
            WHEN r.rTipo < 0.50 THEN N'Endereço incorreto'
            WHEN r.rTipo < 0.75 THEN N'Atraso na transferência'
            WHEN r.rTipo < 0.90 THEN N'Restrição de circulação'
            ELSE N'Condições climáticas'
        END AS TipoOcorrencia
    FROM #Entregas AS e
    CROSS APPLY (SELECT dbo.fnAleatorio(e.PedidoID * 20 + 16) AS rTipo) AS r
    WHERE e.DiasAtrasoOperacional > 0

    UNION ALL

    -- devoluções
    SELECT e.EntregaID, DATEADD(DAY, e.DiasTransito, e.DataColeta), N'Recusa do destinatário'
    FROM #Entregas AS e
    WHERE e.StatusEntrega = N'Devolvido'

    UNION ALL

    -- extravios
    SELECT e.EntregaID, DATEADD(DAY, 1, e.DataColeta), N'Extravio'
    FROM #Entregas AS e
    WHERE e.StatusEntrega = N'Extraviado'

    UNION ALL

    -- avarias: só cargas frágeis entregues (~2%)
    SELECT e.EntregaID, e.DataEntregaCalculada, N'Avaria'
    FROM #Entregas AS e
    JOIN cad.Categoria AS cat ON cat.CategoriaID = e.CategoriaID
    WHERE cat.Fragil = 1
      AND e.StatusEntrega = N'Entregue'
      AND dbo.fnAleatorio(e.PedidoID * 20 + 17) < 0.02
) AS o
WHERE o.DataOcorrencia <= @Fim;

SET NOCOUNT OFF;
GO

/* ============================================================================
   6. VIEWS PARA O POWER BI (schema bi)
   O Power BI lê só daqui: se a tabela mudar, ajusta a view e o BI não quebra
   ============================================================================ */

-- Fato: uma linha por entrega, já com os indicadores calculados
CREATE VIEW bi.vw_fEntregas
AS
SELECT
    e.EntregaID,
    p.PedidoID,
    p.ClienteID,
    p.CDID,
    p.CategoriaID,
    e.TransportadoraID,
    p.DataPedido,
    e.DataColeta,
    e.DataPrevista,
    e.DataEntrega,
    e.StatusEntrega,
    p.ValorMercadoria,
    p.PesoKg,
    p.Volumes,
    e.DistanciaKm,
    e.CustoFrete,
    DATEDIFF(DAY, p.DataPedido, e.DataEntrega) AS LeadTimeDias,     -- vazio se não entregue
    CASE WHEN e.DataEntrega > e.DataPrevista
         THEN DATEDIFF(DAY, e.DataPrevista, e.DataEntrega) ELSE 0 END AS DiasAtraso,
    CASE WHEN e.StatusEntrega <> N'Entregue' THEN NULL
         WHEN e.DataEntrega <= e.DataPrevista THEN 1 ELSE 0 END AS EntregueNoPrazo,
    ISNULL(o.QtdOcorrencias, 0) AS QtdOcorrencias
FROM ops.Entrega AS e
JOIN ops.Pedido AS p ON p.PedidoID = e.PedidoID
LEFT JOIN (
    SELECT EntregaID, COUNT(*) AS QtdOcorrencias
    FROM ops.Ocorrencia
    GROUP BY EntregaID
) AS o ON o.EntregaID = e.EntregaID;
GO

-- Fato: ocorrências
CREATE VIEW bi.vw_fOcorrencias
AS
SELECT
    o.OcorrenciaID,
    o.EntregaID,
    e.TransportadoraID,
    o.DataOcorrencia,
    o.TipoOcorrencia
FROM ops.Ocorrencia AS o
JOIN ops.Entrega AS e ON e.EntregaID = o.EntregaID;
GO

-- Dimensão: clientes com cidade, região e prazo prometido
CREATE VIEW bi.vw_dCliente
AS
SELECT
    cl.ClienteID,
    cl.NomeCliente,
    cl.Segmento,
    cl.DataCadastro,
    ci.Cidade,
    ci.UF,
    ci.Regiao,
    CONCAT(ci.Cidade, N' - ', ci.UF) AS CidadeUF,
    ci.Latitude,
    ci.Longitude,
    pr.PrazoDias
FROM cad.Cliente AS cl
JOIN cad.Cidade AS ci ON ci.CidadeID = cl.CidadeID
JOIN cad.PrazoRegiao AS pr ON pr.Regiao = ci.Regiao;
GO

-- Dimensão: centros de distribuição
CREATE VIEW bi.vw_dCentroDistribuicao
AS
SELECT
    cd.CDID,
    cd.NomeCD,
    ci.Cidade,
    ci.UF,
    ci.Regiao,
    cd.CapacidadeDiaria
FROM cad.CentroDistribuicao AS cd
JOIN cad.Cidade AS ci ON ci.CidadeID = cd.CidadeID;
GO

-- Dimensão: transportadoras
CREATE VIEW bi.vw_dTransportadora
AS
SELECT TransportadoraID, NomeTransportadora, TipoFrota, CustoFixo, CustoKm
FROM cad.Transportadora;
GO

-- Dimensão: categorias de carga
CREATE VIEW bi.vw_dCategoria
AS
SELECT CategoriaID, Categoria, CASE WHEN Fragil = 1 THEN N'Frágil' ELSE N'Comum' END AS TipoCarga
FROM cad.Categoria;
GO

-- Dimensão: calendário
CREATE VIEW bi.vw_dCalendario
AS
SELECT Data, Ano, Mes, NomeMes, MesAno, AnoMes, Trimestre, DiaSemanaNum, DiaSemana, FimDeSemana
FROM cad.Calendario;
GO

/* ============================================================================
   7. CONFERÊNCIA RÁPIDA
   ============================================================================ */
SELECT N'Clientes' AS Tabela, COUNT(*) AS Linhas FROM cad.Cliente
UNION ALL SELECT N'Pedidos',     COUNT(*) FROM ops.Pedido
UNION ALL SELECT N'Entregas',    COUNT(*) FROM ops.Entrega
UNION ALL SELECT N'Ocorrências', COUNT(*) FROM ops.Ocorrencia;

SELECT
    StatusEntrega,
    COUNT(*) AS Entregas,
    CAST(AVG(CAST(EntregueNoPrazo AS DECIMAL(5, 2))) * 100 AS DECIMAL(5, 1)) AS PctNoPrazo
FROM bi.vw_fEntregas
GROUP BY StatusEntrega;
GO
