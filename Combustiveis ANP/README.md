# ⛽ Preços de Combustíveis no Brasil | ANP

Dashboard com os preços de revenda de combustíveis coletados pela **ANP** (Agência Nacional do Petróleo) de **jan/2025 a out/2026**: cerca de **1,5 milhão de coletas** em postos de todo o país.

## Perguntas que o painel responde

- Quanto está o litro de cada combustível hoje e como variou no mês e no ano?
- Quais UFs, regiões e municípios são mais caros, e quanto acima da média nacional?
- Posto de bandeira branca é mais barato que posto bandeirado?
- Quais são os postos mais baratos da cidade?
- **Etanol ou gasolina?** (paridade abaixo de 70% = etanol compensa)

## Páginas

| Página | Conteúdo |
|---|---|
| **Visão Geral** | KPIs, evolução do preço com média móvel de 3 meses, etanol x gasolina, preço por UF x média Brasil, bandeira branca x bandeirado |
| **Regional** | Diferença de cada UF para a média nacional, ranking por UF com tendência (sparkline), preço por região, municípios mais caros |
| **Postos & Bandeiras** | Preço por bandeira (top 15), 10 postos mais baratos, mínimo, médio e máximo por mês |
| **Etanol x Gasolina** | Paridade ao longo do tempo, paridade por UF e mapa de calor UF x mês |

Todas as páginas têm filtros sincronizados (produto, período, UF e região) e um **painel "Mais filtros" retrátil** (município, bandeira, tipo de bandeira e faixa de preço), feito com indicadores e botões. O botão mostra quantos filtros estão ativos.

## Como os dados chegam

A ANP publica um CSV por mês, mas os nomes dos arquivos mudam de um mês pro outro (inclusive com erros de digitação). Por isso o Power Query **lê os links direto da página da ANP** em vez de montar o nome do arquivo:

```
Links ANP        → lê a página da Série Histórica e lista os CSVs mensais a partir do parâmetro DataInicial
fxBaixarArquivo  → função que baixa e abre um CSV
Base ANP         → chama a função para cada link, empilha tudo e trata tipos e textos
fPrecos / dLocal → fato de preços e dimensão de locais, as duas a partir da Base ANP
```

Quando a ANP publica um mês novo, ele entra sozinho no próximo **Atualizar**.

## Modelo

Esquema estrela: **fPrecos** (fato) ligada a **dCalendario**, **dLocal** (UF, região, município) e **dProduto**.

As medidas ficam na tabela `_Medidas`, em pastas: 01 Preço · 02 Volume · 03 Tempo · 04 Comparativos · 05 Etanol x Gasolina · 06 Visual · 07 Top N.

> 💡 O **"Preço médio"** é calculado pela **mediana**, que é menos sensível a postos com preço fora da curva. O Coeficiente de Variação continua usando a média, por definição.

## Como abrir

1. Abra `Combustiveis ANP.pbip` no Power BI Desktop.
2. Na primeira atualização, escolha acesso **Anônimo** para `gov.br` e nível de privacidade **Público**.
3. Para pegar mais ou menos histórico, mude o parâmetro **DataInicial**.

**Fonte:** [ANP · Série Histórica de Preços de Combustíveis](https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/serie-historica-de-precos-de-combustiveis)
