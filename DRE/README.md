# 💰 DRE | Demonstração do Resultado do Exercício

Relatório de DRE com o demonstrativo inteiro desenhado em **HTML, CSS e JavaScript gerados por medidas DAX**, dentro do visual **HTML Content**.

## O que mostra

- As linhas clássicas da DRE: Receita Bruta → Deduções → **Receita Líquida** → CMV → **Lucro Bruto** → Gastos Variáveis e Fixos → **Resultado Operacional** → Resultado Financeiro → Investimentos → **Resultado antes do IR** → Impostos → **Resultado Líquido**.
- **Real x Previsão x Ano anterior** em cada linha, com variação %.
- Cards de destaque: Receita Líquida, Lucro Bruto, Resultado Operacional e Resultado Líquido.
- Filtro de **ano** e de **mês** dentro do próprio visual (JavaScript).

## Como foi feito

| Parte | Detalhe |
|---|---|
| **Base** | Excel com a tabela `fDRE` (lançamentos por data e conta), lido pelo parâmetro `CaminhoBaseDRE` |
| **Modelo** | `fDRE` + `dCalendario` + tabela desconectada `Parâmetro Ano DRE` (anos gerados a partir da base) |
| **Medidas** | ~70 medidas na `_Medidas`: cada linha da DRE tem a versão real, ano anterior (`SAMEPERIODLASTYEAR`) e real + previsão (com `Fator Previsão`) |
| **HTML** | `HTML CSS Base` (estilo), uma medida `HTML Linha - ...` por linha da DRE, `HTML Card - ...` para os cards, `HTML JS ...` para os filtros e `HTML DRE` montando a página. Todo o código está indentado e comentado |

## Como abrir

1. Coloque o arquivo `Base_DRE.xlsx` numa pasta do seu PC.
2. Abra `DRE.pbip` no Power BI Desktop.
3. Vá em **Transformar dados → Gerenciar parâmetros → CaminhoBaseDRE**, cole o caminho completo do Excel e clique em **Atualizar**.
4. O visual **HTML Content** é um visual da AppSource. Se não aparecer, adicione-o em **Obter mais visuais**.
