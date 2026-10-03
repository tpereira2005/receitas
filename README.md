# Receitas

[![Compilação](https://github.com/tpereira2005/receitas/actions/workflows/build.yml/badge.svg)](https://github.com/tpereira2005/receitas/actions/workflows/build.yml)
[![Última versão](https://img.shields.io/github/v/release/tpereira2005/receitas?label=vers%C3%A3o&color=10B062)](https://github.com/tpereira2005/receitas/releases/latest)
![iOS 26](https://img.shields.io/badge/iOS-26%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138)
[![Licença MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue)](LICENSE)

App pessoal para iPhone para guardar e cozinhar receitas fit: biblioteca de alimentos com leitura de embalagens, calorias e macros calculados sozinhos, modo cozinhar com temporizadores e lembrete do congelador para os gelados da Ninja CREAMi. Feita em **SwiftUI + SwiftData**, com o design **Liquid Glass** do iOS 26, compilada no GitHub Actions e instalada com o **SideStore**.

<p>
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/1-inicio.png" width="190" alt="Início">
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/2-receita.png" width="190" alt="Receita">
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/38-modo-cozinhar.png" width="190" alt="Modo cozinhar">
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/4-alimentos.png" width="190" alt="Alimentos">
</p>
<p>
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/39-inicio-congelador.png" width="190" alt="No congelador">
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/8-receitas.png" width="190" alt="Receitas">
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/33-definicoes.png" width="190" alt="Definições">
  <img src="https://github.com/tpereira2005/receitas/releases/download/latest/10-receita-escuro.png" width="190" alt="Receita em modo escuro">
</p>

> As capturas são tiradas automaticamente no simulador em cada versão.

## Funcionalidades

**Receitas**
- Fotografia em destaque, com enquadramento e zoom escolhidos para todos os recortes da app.
- Ingredientes com escala de doses, peso ao lado das medidas ("3 bolachas · 24 g") e peso de cada dose.
- Passos que se marcam; o que marcaste fica guardado 12 horas e o ecrã não se apaga enquanto cozinhas.
- Nutrição por dose ou da receita toda, calculada a partir da biblioteca de alimentos.
- Tempo de preparação, confeção e **espera** (congelador, frigorífico, repouso) e nome das porções (dose, fatia…).
- "Fiz esta receita", com histórico; duplicar; partilhar como imagem quadrada, para Stories ou como texto.

**Cozinhar**
- **Modo cozinhar**: um passo de cada vez, em letra grande, com os ingredientes desse passo.
- **Temporizadores** tirados do texto ("forno durante 30 minutos" → ▶ 30 min), com notificação e sempre à vista.
- **Congelador**: "Congelei agora" avisa quando o gelado está pronto a processar e aparece no Início.

**Alimentos**
- Valores do rótulo por 100 g ou 100 ml, porções com nome ("1 scoop = 30 g"), peso das colheres e imagem.
- **Ler embalagem**: fotografias do rótulo lidas pelo Gemini (ou no iPhone, sem chave), com o Open Food Facts a completar; tudo é revisto antes de guardar.
- Alterar um alimento nunca muda uma receita sem confirmação.

**Organizar e encontrar**
- Início com Recentes, No congelador, Favoritas e Feitas recentemente.
- Categorias, coleções (alta proteína, até 400 kcal, até 20 min, favoritas), etiquetas e "já fizeste?", iguais em Receitas e na Pesquisa.
- Pesquisa de receitas e alimentos por relevância; receitas no Spotlight e atalhos para a Siri.

**Dados**
- Cópias de segurança automáticas (uma por dia, numa pasta à escolha, com as fotografias) e restauro dessas cópias.
- Exportar e importar em JSON; **Apagadas recentemente** durante 30 dias.
- Boas-vindas na primeira abertura e "Como funciona" nas Definições.
- Aviso antes de a assinatura do SideStore expirar e ação "Assinatura renovada" para os Atalhos.

## Instalar com o SideStore

1. No iPhone, abre o **SideStore** → **Sources** → **+** e cola:

   ```
   https://raw.githubusercontent.com/tpereira2005/receitas/sidestore/source.json
   ```

2. Abre a fonte **Receitas** e toca em **Get**. As versões novas aparecem em **My Apps → Updates**, e atualizar mantém as receitas.

Também podes descarregar o `Receitas.ipa` da [última versão](https://github.com/tpereira2005/receitas/releases/latest) e abri-lo no SideStore (**My Apps → +**). Com um Apple ID gratuito, a assinatura dura 7 dias e é preciso renová-la no SideStore.

**Renovar com os Atalhos:** numa automação diária, põe a ação **Refresh All** do SideStore e, logo a seguir, a ação **Assinatura renovada** da app Receitas. O SideStore renova sem reinstalar a app, por isso é esta segunda ação que diz à app a data nova (se a renovação falhar, o atalho para antes e a data não muda).

## Como é compilada

Não é preciso Mac. Cada envio para `main` corre o [workflow](.github/workflows/build.yml) em três etapas:

| Etapa | O que faz |
|---|---|
| **Testes** | Gera o projeto com o XcodeGen e corre os testes do código e os testes de interface no simulador. |
| **IPA e fonte do SideStore** | Compila sem assinatura, cria o `Receitas.ipa`, publica a versão seguinte (`1.6`, `1.6.1`, `1.6.2`…) (ficam as 5 mais recentes e a `latest`) e atualiza a fonte no ramo [`sidestore`](https://github.com/tpereira2005/receitas/tree/sidestore). A mensagem do commit é a nota da versão. |
| **Capturas** | Abre a app no simulador e tira capturas de todos os ecrãs, em claro, escuro e texto grande, publicadas na versão `latest`. |

## Estrutura

```
Receitas/
  App/                Entrada da app, separadores, Spotlight, Siri e validade do SideStore
  Models/             Receita e alimento (SwiftData), esquemas e migrações, nutrição, cópias,
                      conteúdo de origem, filtros, modo cozinhar e leitura de embalagens
  Views/              Home, Browse (Receitas e Pesquisa), Detail, Editor, Foods, Settings, Share, Shared
  Utilities/          Formatação, imagens e Porta-chaves
  Resources/          Ícones, cor de destaque e ConteudoBase.json (alimentos e receitas de origem)
ReceitasTests/        Testes do código (dados, migrações, nutrição, leitura de rótulos, cozinhar…)
ReceitasUITests/      Testes de interface
ReceitasWidgets/      Extensão de widgets: Live Activity dos temporizadores
Shared/               Código partilhado entre a app e a extensão
AppIcon.icon/         Ícone em Liquid Glass (Icon Composer)
design/               Scripts que geram ícones, guias de fotografia e rótulos de teste
ferramentas/          Kit do Codex para as fotografias das receitas e as imagens dos alimentos
scripts/              Gerador da fonte do SideStore
docs/                 Documentação
```

## Documentação

- [Arquitetura](docs/arquitetura.md): dados, migrações, cópias de segurança e como as peças se ligam.
- [Conteúdo de origem](docs/conteudo-de-origem.md): os alimentos e as receitas que vêm com a app e como os atualizar.
- [Imagens com o Codex](docs/imagens-com-o-codex.md): fotografias das receitas e imagens dos alimentos.
- [Histórico das versões](docs/versoes.md): o que mudou em cada versão e as decisões tomadas.

## Licença

[MIT](LICENSE): podes usar, alterar e partilhar o código, desde que mantenhas o aviso de direitos de autor e a licença.
