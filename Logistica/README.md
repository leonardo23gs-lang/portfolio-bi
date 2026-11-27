# 🚚 Logística & Entregas | SQL Server + Power BI

Projeto de ponta a ponta: **criei o banco de dados do zero em SQL Server**, populei com dados fictícios gerados por regras de negócio e montei o painel no Power BI conectado direto nas views do banco.

## Perguntas que o painel responde

- Estamos entregando no prazo? Onde e por que não?
- Qual transportadora entrega melhor, e qual custa mais caro por kg?
- O prazo prometido ao cliente é realista em cada região?
- Quais clientes e centros de distribuição concentram o volume?

## O banco (`sql/01_criar_banco_logistica.sql`)

Um script só cria tudo, e pode ser rodado de novo sempre que quiser. Os dados são **determinísticos**, então rodar de novo gera exatamente os mesmos números.

| Schema | Conteúdo |
|---|---|
| `cad` | Cadastros: 57 cidades com coordenadas, 5 CDs, 6 transportadoras, categorias de carga, prazo por região, 1.500 clientes e calendário |
| `ops` | Operação: ~40 mil pedidos (jan/2025 a out/2026), entregas e ocorrências |
| `bi` | **Views** que o Power BI consome, já com lead time, dias de atraso e flag de entrega no prazo |

**Regras de negócio que geram os padrões:**
- cada cliente é atendido pelo **CD mais próximo**, com a distância calculada no próprio SQL (`geography::Point` + `STDistance`);
- até 350 km a frota própria faz a maior parte das entregas, e no Norte e Nordeste entram as transportadoras regionais;
- cada transportadora tem uma chance diferente de atraso, e o Norte e o pico de nov/dez pioram o prazo;
- pedido feito no fim de semana só é coletado na segunda.

## O painel

| Página | Conteúdo |
|---|---|
| **Visão Geral** | KPIs (entregas, % no prazo, lead time, atraso médio, custo de frete, frete / mercadoria), volume x pontualidade por mês, status, % no prazo por região e pelo dia do pedido, ocorrências por tipo |
| **Transportadoras** | Tabela de desempenho, custo x pontualidade (dispersão), % no prazo por mês, ocorrências por transportadora |
| **Regiões & Clientes** | Lead time x prazo prometido por região, % no prazo por UF, maiores clientes e desempenho dos CDs |

**Modelo:** esquema estrela com `fEntregas` e `fOcorrencias` ligadas a `dCalendario`, `dCliente`, `dTransportadora`, `dCategoria` e `dCentroDistribuicao`. A data de entrega tem um relacionamento inativo com o calendário, pra usar com `USERELATIONSHIP`. São 22 medidas DAX em pastas (Volume, Prazo, Custo, Ocorrências e Visual), com cor dinâmica pela meta de 95% no prazo.

**Alguns achados nos dados:** 94,7% das entregas no prazo, mas a EconoFrete fica em ~90%, pedidos de sábado caem pra ~80% e nov/dez ficam abaixo da média.

## Como rodar

1. Instale o **SQL Server** (Express ou Developer) e o **SSMS**.
2. Abra `sql/01_criar_banco_logistica.sql` no SSMS e execute (F5). Isso cria o banco `LogisticaBI`.
3. Abra `Logistica BI.pbip` no Power BI Desktop. A fonte é `localhost` / `LogisticaBI`; se o seu servidor tiver outro nome (ex.: `localhost\SQLEXPRESS`), ajuste em **Transformar dados → Configurações da fonte de dados**.
4. Clique em **Atualizar**.

A pasta `Template` tem os fundos das páginas (com versão guia) e o tema JSON.
