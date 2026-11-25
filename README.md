# 📊 Portfólio de BI | Leonardo Gomes

Analista de BI Jr · **Power BI · Power Query (M) · DAX · SQL · Power Automate** · estudante de ADS

Este repositório reúne dashboards que montei para praticar e mostrar o ciclo completo de um projeto de BI: **coleta e tratamento dos dados, modelagem, medidas DAX e visualização**. Todos estão no formato **PBIP** (projeto do Power BI em texto), então dá pra ler o Power Query, o modelo e as medidas direto aqui no GitHub, sem abrir o Power BI.

## Projetos

| Projeto | O que responde | Destaques técnicos |
|---|---|---|
| ⛽ [**Combustíveis ANP**](./Combustiveis%20ANP) | Quanto custa abastecer em cada UF, qual bandeira é mais barata e quando o etanol compensa | Dados abertos da ANP (~1,5 milhão de coletas), Power Query que lê os links direto do site, modelo estrela, ~40 medidas DAX, painel de filtros retrátil com indicadores |
| 💰 [**DRE**](./DRE) | Resultado da empresa linha a linha: real x previsão x ano anterior | Demonstrativo inteiro em **HTML/CSS/JS gerado por DAX**, base em Excel parametrizada, inteligência de tempo |
| 📚 [**Nardo's Reading**](./BI%20Manhwa) | Painel pessoal de leitura de manhwa, mangá e manhua | A mesma análise em duas versões: **página nativa do Power BI** e **página inteira em HTML** montada por blocos de medidas |

## Como abrir

1. Instale o **Power BI Desktop** (versão recente, com suporte a PBIP).
2. Baixe o repositório: **Code → Download ZIP**.
3. Abra o arquivo `.pbip` da pasta do projeto.
4. Se o projeto usa base em Excel, ajuste o caminho em **Transformar dados → Gerenciar parâmetros** (cada README explica).

## O que pratiquei

- **Power Query:** consultas com nomes de etapas padrão, funções personalizadas, parâmetros, combinação de vários arquivos e leitura de páginas da web.
- **Modelagem:** esquema estrela, tabela calendário e relacionamentos 1:N.
- **DAX:** inteligência de tempo (mês anterior, ano anterior, média móvel), RANKX/Top N, medidas de cor para formatação condicional e medidas que geram HTML.
- **Visual:** templates de fundo, temas JSON, indicadores e botões, painel de filtros, e o visual **HTML Content** para layouts livres.

## Contato

[LinkedIn](https://www.linkedin.com/in/leonardo-gomes-dados)
