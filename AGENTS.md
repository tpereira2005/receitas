# Instruções para agentes (Codex, Claude e outros)

App pessoal para iPhone, **Receitas**: SwiftUI + SwiftData, iOS 26 (Liquid Glass), Swift 6. Compilada no GitHub Actions e instalada com o SideStore. O dono do projeto fala **português de Portugal**: responde, comenta o código e escreve os commits nessa língua.

> A pasta [`ferramentas/fotos-receitas`](ferramentas/fotos-receitas/AGENTS.md) tem as suas próprias instruções (imagens com o Codex); lá dentro, valem essas.

## Regras que não se quebram

1. **O identificador `com.tpereira.receitasfit` nunca muda**, nem o serviço do Porta-chaves em `Utilities/Keychain.swift`. É isso que liga a app aos dados, à chave do Gemini e às atualizações do SideStore: com outro identificador, o SideStore instala uma app nova e vazia.
2. **Nunca se perdem dados.** Mudanças aos modelos seguem as regras de [Dados](#dados); nunca apagar nem substituir o que o utilizador criou ou alterou.
3. **Nada de fotografias pessoais no repositório** (é público). O `ConteudoBase.json` só leva imagens de comida.
4. **Nada de chaves nem segredos no código.** A chave do Gemini fica no Porta-chaves do iPhone.
5. **Mudanças grandes: primeiro um plano**, com as decisões em aberto, e só depois o código, por fases. Cada fase é validada no CI e testada no iPhone pelo dono antes da seguinte.

## Compilar e testar

Não há Mac: **o CI é o único sítio onde o código compila**. Não há `.xcodeproj` no repositório; é gerado pelo XcodeGen a partir do [`project.yml`](project.yml).

- Cada envio para `main` corre o [workflow](.github/workflows/build.yml): testes (código + interface) → IPA e fonte do SideStore → capturas no simulador.
- **Enviar para `main` publica uma versão no SideStore** (`1.6`, `1.6.1`, `1.6.2`…; a base está em `VERSION_BASE`, no workflow). A mensagem do commit é a nota da versão que o dono lê no iPhone: escreve-a para ele (o que muda na app), em português. A linha `Co-Authored-By` é tirada automaticamente.
- Alterações que não mudam a app (documentação, licença): acrescenta `[skip ci]` ao título do commit.
- Depois de enviar, **acompanha o CI** (`gh run watch`) e corrige os erros até ficar verde. Um teste que falha impede a versão de chegar ao SideStore.
- Vê as capturas do CI (artefacto `screenshots`) para confirmar mudanças visuais, em claro, escuro e texto grande.

## Código

- Swift 6 com **isolamento no `MainActor` por omissão** (`SWIFT_DEFAULT_ACTOR_ISOLATION`). Tipos de valor usados fora da interface marcam-se `nonisolated`; métodos em extensões de modelos SwiftData que chamem código da interface levam `@MainActor`.
- Intenções dos Atalhos (`AppIntent` com `@Parameter`) **não** podem ser `nonisolated struct`.
- Nos testes de interface (`ReceitasUITests`), o alvo não tem isolamento por omissão e cada teste leva `@MainActor`.
- Segue o estilo à volta: nomes em inglês no código, comentários e textos da interface em português, comentários só onde explicam o porquê.
- Armadilhas de SwiftUI já encontradas:
  - modificadores de apresentação (`.sheet`, `.alert`, `.fileImporter`…) numa `Section` de um `Form` aplicam-se a cada linha e abrem janelas repetidas: põe-nos na vista inteira;
  - um `Label` dentro de uma linha de `Form` ganha o estilo das linhas: usa `HStack`;
  - `ImageRenderer` não desenha contentores `Lazy`;
  - expressões encadeadas longas fazem o compilador desistir: divide-as em passos.
- Textos que podem não caber: prefere `ViewThatFits`, várias linhas ou `.fixedSize()` a cortar com "…". Confirma com texto de acessibilidade grande.

## Dados

- Modelos: `Recipe` e `Food` (SwiftData). Ver [docs/arquitetura.md](docs/arquitetura.md).
- **Esquema** (`Models/Schema.swift`): para acrescentar campos, congela os modelos atuais num novo `SchemaVn`, cria o seguinte a apontar para os modelos de topo e acrescenta uma etapa `.lightweight` ao plano de migração, com um teste que abre uma base de dados da versão anterior. Só se acrescentam campos com valor por omissão.
- **Migrações de dados** (`DataMigration` em `Models/FoodLibrary.swift`): sobe `currentVersion` e acrescenta `migrateToVn`. Só mexem no que o utilizador ainda não alterou.
- **Conteúdo de origem** (`Resources/ConteudoBase.json`): mesmo formato das cópias de segurança. Ver [docs/conteudo-de-origem.md](docs/conteudo-de-origem.md).
- Apagar receitas ou alimentos usa `moveToTrash()` ("Apagadas recentemente", 30 dias). Os `@Query` e as pesquisas filtram com `Recipe.notDeleted` / `Food.notDeleted`.

## Capturas de ecrã no CI

As capturas usam opções de arranque (`ScreenshotMode`), só ativas em compilações de desenvolvimento. Para mostrar um ecrã novo, acrescenta uma opção e uma linha `shot` no workflow. Algumas das existentes:

| Opção | Efeito |
|---|---|
| `-tab recipes\|foods\|search` | Abre num separador |
| `-screenshotOpenFirst YES` | Abre a primeira receita (com `-screenshotDetailScroll`, `-screenshotDetailWait`, `-screenshotDetailCooked` ou `-screenshotDetailIngredients` para descer até uma secção) |
| `-screenshotCooking YES` | Modo cozinhar (com `-screenshotCookingStep N`) |
| `-screenshotEditFirst YES` | Editor da primeira receita (`-screenshotPhotoFocus YES` para o enquadramento) |
| `-screenshotSettings YES` | Definições (`-screenshotSettingsPage copias\|gemini\|etiquetas\|sidestore\|apagadas\|restaurar\|ajuda\|temporizadores`) |
| `-screenshotWelcome YES` | Boas-vindas |
| `-screenshotLiveActivity YES` | Desenho da Live Activity dos temporizadores (o simulador não fotografa o ecrã bloqueado) |
| `-screenshotWaiting YES` | Gelados no congelador |
| `-screenshotTrash YES` | Uma receita e um alimento em "Apagadas recentemente" (fica em último, porque altera os dados) |

## Estrutura

```
Receitas/            App (App, Models, Views, Utilities, Resources)
ReceitasTests/       Testes do código
ReceitasUITests/     Testes de interface
ReceitasWidgets/     Extensão de widgets (Live Activity dos temporizadores)
Shared/              Código partilhado entre a app e a extensão
AppIcon.icon/        Ícone (Icon Composer)
design/              Scripts de ícones, guias de fotografia e rótulos de teste
ferramentas/         Kit do Codex para imagens (tem o seu AGENTS.md)
scripts/             Gerador da fonte do SideStore
docs/                Arquitetura, conteúdo de origem, imagens e histórico das versões
```

Quando uma versão acrescenta algo visível, atualiza também o [README](README.md), o [histórico das versões](docs/versoes.md) e, se for preciso, o "Como funciona" da app (`Views/Settings/HelpView.swift`), que também tem as boas-vindas.
