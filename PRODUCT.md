# Product

<!-- impeccable:product-schema 1 -->

## Platform

native macOS

## Users

Uma pessoa que acompanha várias conversas e agentes locais do Codex e precisa entender rapidamente o trabalho em andamento, localizar gargalos e iniciar agentes com contexto escolhido.

## Product Purpose

GraphCodex transforma as sessões locais do Codex em um escritório operacional: um mapa 3D para orientação e acompanhamento, acompanhado por modos 2D para executar ações de forma direta. Sucesso significa identificar uma sessão que precisa de atenção, focar seu projeto e iniciar um novo agente com a pasta e o contexto corretos.

## Positioning

Um mapa espacial ao vivo das conversas do Codex que liga departamentos, estações de agentes e ações operacionais sem substituir o app Codex.

## Operating Context

- App local para macOS, usado junto ao Codex Desktop.
- Sessões são consultadas pelo `codex app-server --stdio` local.
- O mapa 3D é a tela inicial e a principal forma de acompanhar o escritório.
- Usuários podem abrir a conversa correspondente no Codex Desktop.

## Capabilities and Constraints

- Departamentos são organizados a partir de projetos locais e pastas canônicas; mover uma sessão entre departamentos é uma associação local e não altera o `cwd` real.
- Projetos, associações manuais, prioridades, favoritos, layout e preferências persistem em JSON versionado local.
- Um agente novo escolhe sua própria pasta de trabalho, independentemente do departamento.
- Criar um agente exige uma revisão explícita e o botão **Iniciar Agent**; cancelar antes não cria thread nem turno.
- As opções de contexto incluem começar do zero, templates, instruções do departamento com arquivos selecionados pelo usuário, e clonagem de agente com histórico completo ou resumo.
- O app-server local fornece fatos de threads e turnos; GraphCodex não inventa tarefas ou aprovações.
- Modelo, sandbox e permissões são configurados pelo Codex. GraphCodex nunca aprova ações automaticamente.
- Uma única aplicação macOS mantém SwiftUI e SceneKit; responsabilidades serão separadas incrementalmente.
- As referências de arquivos selecionados entram no prompt como caminhos que o agente pode ler no turno inicial.

## Brand Commitments

- Nome: GraphCodex.
- Plataforma e marca visual mantêm a identidade escura violeta existente.
- Direção de cor escolhida: Midnight Violet.
- Linguagem da interface em português, direta e operacional.

## Evidence on Hand

- Sessões, nomes, diretórios, status e resumos de prompt vindos do app-server local.
- Código SwiftUI/SceneKit existente em `Sources/GraphCodex`.
- Nenhum serviço remoto próprio nem conteúdo de tarefa estruturado além dos dados retornados pelo app-server.

## Product Principles

1. O mapa 3D orienta; os modos 2D deixam toda ação operacional acessível sem navegação espacial.
2. Status crítico é acompanhado por texto e ícone, não apenas por cor.
3. O diretório real da sessão nunca muda quando sua associação visual é movida.
4. Um agente só começa após revisão e confirmação explícitas.
5. O Codex mantém o controle sobre permissões e aprovações.
