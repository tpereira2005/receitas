# Conteúdo de origem

Os alimentos e as receitas que vêm com a app estão em [`Receitas/Resources/ConteudoBase.json`](../Receitas/Resources/ConteudoBase.json). O ficheiro tem **o mesmo formato das cópias de segurança** exportadas na app, com as imagens dos alimentos e as fotografias das receitas.

Hoje tem 34 alimentos e 9 receitas: seis gelados da Ninja CREAMi, o Cookie Dough Cake e as papas e as panquecas de aveia.

## Quando é usado

| Situação | O que acontece |
|---|---|
| Instalação nova | Entram todos os alimentos e todas as receitas. |
| Atualização | Entram só as receitas que ainda não existem (compara pelo título) e só os alimentos de que precisam. Um alimento com o mesmo nome é reaproveitado. Nada do que já existe é alterado. |
| Receita apagada | Não volta a entrar: continua em "Apagadas recentemente" até sair de vez. |

## Como atualizar

1. Na app, **Definições → Cópias de segurança → Exportar cópia**.
2. Substituir o `ConteudoBase.json` por essa cópia, tirando o histórico de "Fiz esta receita" (é pessoal).
3. Se alguma receita mudou de forma que as instalações existentes também devam receber (por exemplo, um tempo de espera novo), acrescentar uma migração de dados em `DataMigration`, que só altere o que o utilizador ainda não mudou.
4. Enviar para `main`; a versão seguinte já traz o conteúdo novo.

> O repositório é público: as fotografias e as imagens deste ficheiro ficam visíveis. Só devem entrar imagens de comida, sem pessoas nem dados pessoais.
