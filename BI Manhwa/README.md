# 📚 Nardo's Reading | Painel de leitura

Projeto pessoal: um painel com tudo que eu leio de **manhwa, mangá e manhua**, a partir da planilha onde controlo capítulo, gênero, status e nota de cada obra.

A ideia foi fazer **a mesma análise de dois jeitos**:

| Página | Como foi feita |
|---|---|
| **Página 1 · nativa** | Visuais do próprio Power BI, com template de fundo e tema escuro (JSON) feitos sob medida |
| **Página 2 · HTML** | Página inteira em **HTML/CSS gerada por DAX** no visual HTML Content, montada por blocos |

## O que mostra

- **KPIs:** capítulos lidos, horas de leitura (estimadas por capítulo), obras na coleção, fila de pendentes e nota média.
- **Gêneros mais lidos:** gênero principal + secundário, com a nota média de cada um.
- **Como eu avalio:** distribuição das notas de 1 a 10.
- **Saúde da lista:** há quanto tempo cada obra em "Acompanhando" está parada (bom pra decidir o que dropar ou retomar).
- **Maiores maratonas, obras que valem retomar e a fila de pendentes.**

## Como foi feito

- **Power Query:** a consulta `Fonte` lê o Excel (caminho no parâmetro `CaminhoBase`), limpa os textos, troca vazio por nulo e tipa as colunas. `Fato_Leitura`, `Dim_Genero` (gênero 1 + gênero 2) e `Dim_Status` partem dela. `dCalendario` é gerada em M.
- **Medidas:** pastas 01 Base · 02 Análise · 03 HTML. Na versão HTML, `Visual HTML` só monta a página. Cada bloco (`HTML CSS`, `HTML KPIs`, `HTML Gêneros`, `HTML Notas`, `HTML Saúde`...) é uma medida separada e comentada, fácil de manter.
- **Tempo de leitura:** 5 min por capítulo de manhwa/manhua e 7 min por capítulo de mangá.

## Como abrir

1. Salve a base `Mangas_manhwas.xlsx` numa pasta do seu PC.
2. Abra `BI manhwa.pbip` no Power BI Desktop.
3. Em **Transformar dados → Gerenciar parâmetros → CaminhoBase**, cole o caminho completo do Excel e clique em **Atualizar**.
4. A página HTML usa o visual **HTML Content** (AppSource).
