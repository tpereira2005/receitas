# Arquitetura

A app é um projeto SwiftUI + SwiftData para iOS 26, em Swift 6 com isolamento no `MainActor` por omissão. O projeto Xcode não está no repositório: é gerado pelo [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir do [`project.yml`](../project.yml).

## Dados

Há dois modelos SwiftData:

| Modelo | O que guarda |
|---|---|
| `Recipe` | Título, categoria, etiquetas, doses e nome da porção, tempos (preparação, confeção, espera), nutrição por dose, fotografia e miniatura, enquadramento (foco e zoom), ingredientes e passos (em JSON), "Fiz esta receita", início da espera e data em que foi apagada. |
| `Food` | Nome, marca, categoria, valores por 100 g/ml, peso de uma unidade, porções com nome, peso das colheres, imagem e data em que foi apagado. |

**Cópia dos valores em cada ingrediente.** Cada ingrediente guarda uma cópia (`FoodSnapshot`) dos valores do alimento no momento em que foi escolhido. Assim, editar um alimento nunca muda uma receita sem confirmação: a app mostra as receitas afetadas e o que mudou antes de as atualizar.

**Nutrição.** O `NutritionCalculator` converte cada quantidade (g, ml, unidades, colheres, porções com nome) para gramas e soma os valores. A receita guarda os valores por dose, usados nos cartões, filtros e ordenação.

## Versões dos dados

Há dois tipos de migração, e ambos correm sozinhos ao abrir uma versão nova:

1. **Esquema** (`Schema.swift`): `SchemaV1` → `SchemaV2` → `SchemaV3`, todas automáticas, porque só se acrescentam campos com valor por omissão. Cada versão fica congelada no código.
2. **Dados** (`DataMigration`, versões 2 a 7): acertos ao conteúdo, como ligar ingredientes antigos à biblioteca, marcar exemplos, trazer as receitas de origem ou pôr as esperas dos gelados.

Antes de abrir os dados numa versão nova, o `StoreSafety` guarda uma cópia da base de dados em *Application Support/Proteção* (ficam as 2 mais recentes).

**O identificador da app (`com.tpereira.receitasfit`) nunca muda.** É ele que liga a app aos dados, ao Porta-chaves e às atualizações do SideStore: com outro identificador, o SideStore instalaria uma app nova e vazia.

## Cópias de segurança

| O quê | Onde | Notas |
|---|---|---|
| Exportar / importar | Ficheiro JSON com receitas, alimentos e fotografias | Importar só acrescenta o que falta; o que está em "Apagadas recentemente" volta a aparecer. |
| Cópias automáticas | Pasta escolhida (por exemplo no iCloud Drive) | Uma por dia, só se algo mudou; ficam as 5 mais recentes. Podem ser restauradas na app. |
| Apagadas recentemente | Na própria base de dados | Receitas e alimentos apagados ficam 30 dias; depois saem de vez. |

## Leitura de embalagens

1. As fotografias vão para o **Gemini** (com a chave guardada no Porta-chaves), que devolve os valores por 100 g/ml, a porção do rótulo e a categoria.
2. Sem chave, ou sem ligação, o texto é lido no iPhone (Vision) e interpretado pelo `LabelParser`.
3. Se houver código de barras, o **Open Food Facts** completa os valores em falta e assinala as diferenças.
4. Tudo aparece no editor para rever; nada fica guardado sem tocar em Guardar. As fotografias e o código de barras não são guardados.

## Cozinhar

- `CookingProgress`: ingredientes e passos marcados, guardados 12 horas por receita.
- `StepAnalysis`: tira do texto de cada passo os temporizadores e os ingredientes que usa.
- `CookingTimers`: temporizadores dos passos, guardados (voltam a aparecer se a app for fechada); aparecem nos passos, no fundo da receita e no Início.
- `TimerAlarms`: com autorização, cada temporizador é um alarme do **AlarmKit** (toca mesmo em silêncio, "Mais 1 min" no fim). Sem autorização, ou nos testes e capturas do CI, fica uma notificação.
- A app acompanha o que se faz aos alarmes fora dela (`alarmUpdates`): parar, pausar, continuar e "Mais 1 min" (`CookingTimers.reconcile`, com testes).
- **Live Activity:** a extensão `ReceitasWidgets` desenha a contagem no ecrã bloqueado e na Dynamic Island para os `AlarmAttributes<CookingTimerMetadata>`. Os dados do temporizador, os botões (`LiveActivityIntent`) e as vistas estão em `Shared/`, partilhado com a app. Tocar abre `receitas://receita/<id>`.
- A extensão tem o identificador `com.tpereira.receitasfit.widgets` e ocupa mais um App ID no SideStore gratuito.
- `WaitReminder`: "Congelei agora" (ou frigorífico, repouso) e o aviso quando a receita está pronta.
- `ScreenAwake`: mantém o ecrã aceso no modo cozinhar e enquanto há marcações.

## Capturas e testes

- Os testes do código (`ReceitasTests`) cobrem dados, migrações, nutrição, leitura de rótulos (com imagens geradas por [`design/make_test_labels.py`](../design/make_test_labels.py)), cozinhar e apagadas.
- Os testes de interface (`ReceitasUITests`) tocam no enquadramento, nos filtros, nas Definições, no modo cozinhar e em recuperar uma receita apagada.
- As capturas usam opções de arranque (`ScreenshotMode`, por exemplo `-screenshotOpenFirst YES`) que só existem nas compilações de desenvolvimento; na versão do SideStore não têm efeito.
