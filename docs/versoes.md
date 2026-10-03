# Histórico das versões

Até à 1.5, cada compilação era `versão.N`, com `N` o número da compilação no GitHub Actions (por exemplo 1.4.62). Desde a 1.6, a primeira versão publicada é `1.6` e as seguintes `1.6.1`, `1.6.2`… As notas de cada compilação estão nas [versões do GitHub](https://github.com/tpereira2005/receitas/releases) e no SideStore.

## 1.5 e 1.6 · 3 de outubro de 2026

- **Temporizadores com alarme (AlarmKit):** tocam mesmo em silêncio ou num modo de foco, com "Parar" e "Mais 1 min". Sem autorização, ficam as notificações.
- **Live Activity:** contagem no ecrã bloqueado e na Dynamic Island, com pausar, continuar e parar; tocar abre a receita.
- Os temporizadores ficam guardados se a app for fechada; **Definições → Temporizadores** mostra o estado.
- **Versões curtas:** desde a 1.6, `1.6`, `1.6.1`, `1.6.2`… (a 1.5 foi só a preparação, com 1.5.72 e 1.5.73).

Decisões: a extensão de widgets ocupa mais um App ID (5 de 10 no SideStore gratuito); o aviso do congelador continua a ser uma notificação normal (uma Live Activity dura no máximo cerca de 8 horas).

## 1.4 · 25–26 de setembro de 2026

Segunda revisão completa da app, em cinco fases.

- **Receitas e tempos:** tempo de **espera** (congelador, frigorífico, repouso), que não conta para "Até 20 min"; nome das porções (doses, fatias…); cápsulas da receita em várias linhas.
- **Enquadramento com zoom:** arrastar e aproximar no topo real da receita, com as pré-visualizações nas proporções certas.
- **Cozinhar:** modo cozinhar, temporizadores tirados do texto (também nos passos da receita e sempre à vista), ecrã aceso, marcações guardadas 12 horas, peso ao lado das medidas e peso de cada dose.
- **Congelador:** "Congelei agora", aviso quando está pronto a processar e secção "No congelador" no Início.
- **Organização:** Início mais curto (Recentes, No congelador, Favoritas, Feitas recentemente), só categorias com receitas, o mesmo painel de filtros em Receitas e na Pesquisa, macros em pontos coloridos, "+" único nos Alimentos e deslizar nas listas.
- **Dados:** Apagadas recentemente (30 dias), restaurar cópias automáticas e categoria sugerida pelo Gemini.
- **Qualidade:** texto muito grande sem cortes, testes de interface e "O que há de novo".
- **SideStore:** ação "Assinatura renovada" para os Atalhos (2 de outubro), porque o SideStore renova sem reinstalar a app e a data dentro da app ficava presa na última instalação.
- **Como funciona** (3 de outubro): boas-vindas na primeira abertura e um guia de cada parte da app nas Definições, no lugar do "O que há de novo" (as notas de cada versão já aparecem no SideStore).
- **Receitas novas** (2 de outubro): papas de aveia e panquecas de aveia, com a farinha de aveia e o Xarope de Ácer Zero da Prozis.
- **Definições** reorganizadas numa página curta, com páginas próprias; etiquetas que se criam, editam e apagam.
- **Conteúdo de origem** vindo de uma cópia de segurança: 32 alimentos com imagens e 7 receitas com fotografia.

Decisões: sem "Sugestão para hoje" no Início; temporizadores na app com notificação (sem Live Activity, que ocuparia mais um lugar no SideStore gratuito); restaurar cópias só acrescenta, nunca substitui.

## 1.3 · 24 de setembro de 2026

- Novo Início, navegação Início · Receitas · Alimentos · Pesquisa, filtros combinados e pesquisa por relevância.
- "Fiz esta receita", com histórico.
- Fotografias da câmara ou dos Ficheiros, enquadramento, duplicar e partilhar como imagem ou para Stories.
- Receitas no Spotlight, atalhos para a Siri, aviso de expiração do SideStore e "O que há de novo".

## 1.2 · 24 de setembro de 2026

- Fundações: esquema de dados com versões, testes e Swift 6.
- Cópias de segurança automáticas numa pasta à escolha.
- Porções com nome e peso das colheres por alimento.
- Leitura de embalagens: primeiro no iPhone (Vision), depois com o Gemini, e o Vision como recurso.

## 1.1 · 23 de setembro de 2026

- Biblioteca de alimentos e cálculo automático das calorias e dos macros.
- Alterar um alimento já não muda as receitas sem confirmação.
- Imagens nos alimentos e ícone da app em Liquid Glass.

## 1.0 · 23 de setembro de 2026

- Primeira versão: receitas com fotografia, ingredientes, passos e nutrição, em SwiftUI + SwiftData com o design Liquid Glass, compilada no GitHub Actions e instalada com o SideStore.

## Ideias para depois

- Widget com uma receita (adiado).
- Proteína por 100 kcal, com ordenação.
