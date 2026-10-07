# GraphCodex — guia operacional

GraphCodex é um aplicativo macOS local para acompanhar e operar sessões do Codex. O Mapa 3D é a tela inicial; Lista e Foco oferecem as mesmas informações e ações em uma apresentação direta. O aplicativo consulta o app-server local, abre conversas no Codex Desktop e inicia novos agents somente após uma revisão confirmada.

## Mapa, Lista e Foco

- **Mapa** organiza departamentos como ilhas com placas, acentos de projeto, agentes, estações, indicadores e marcas de atenção. Use Overview, Orbit ou 1ª pessoa para navegar. Clique numa estação para selecionar e abrir o inspetor; Enter ou duplo clique abre a conversa no Codex. A miniatura no canto inferior mostra os departamentos e permite focá-los.
- **Lista** oferece busca, filtro, status textual, atividade recente, seleção e abertura da conversa.
- **Foco** resume um departamento, seus agentes e contagens de trabalho, atenção e conclusão.
- A barra lateral reúne departamentos e a fila de atenção. KPIs distinguem agentes, atividade, atenção e conclusão.

Status sempre combina texto, símbolo e cor. “Sem atividade” descreve apenas o intervalo sem sinal novo; não diagnostica travamento. O último prompt aparece resumido conforme os dados disponíveis do app-server.

## Departamentos e agentes

Threads são agrupadas pelo diretório de trabalho canônico (`cwd`). Pastas com o mesmo nome recebem segmentos adicionais do caminho para ficarem distintas. Mover uma sessão no GraphCodex grava uma associação por thread; não muda o `cwd` real. Departamentos podem ser criados sem uma pasta e guardam descrição, instruções, tipo, tags, ícone e acento visual.

**Novo Agent** pede departamento, nome, objetivo, papel, prioridade, tags e pasta de trabalho individual. A etapa de contexto permite começar do zero, aplicar template, incluir instruções do departamento e arquivos selecionados na pasta, ou clonar um agente. Clonagem permite histórico completo ou resumo. A revisão exibe pasta e prompt editável. Somente **Iniciar Agent** cria/faz fork da conversa e envia o primeiro turno; cancelar antes não inicia o turno.

Modelo, sandbox e permissões seguem as configurações do Codex. GraphCodex não aprova ações. Se o app-server enviar um pedido de aprovação por sua própria conexão, GraphCodex recusa tratar essa solicitação como uma decisão e apresenta uma instrução para abrir a thread no Codex.

## Dados e privacidade

O app-server fornece threads, estados, flags, atividade e resumos do último turno. Dados auxiliares do GraphCodex — departamentos, associação thread/departamento, nome e papel dos agents, prioridade, favoritos, layout e preferências — são gravados em JSON versionado em `~/Library/Application Support/GraphCodex/graphcodex.json`, com substituição atômica. Se o arquivo usar uma versão não suportada, o app preserva o arquivo e apresenta erro em vez de sobrescrevê-lo.

O arquivo de rollout do Codex não é alterado. O caminho de trabalho escolhido para um agent é enviado ao app-server para criar/fazer fork de uma thread e não modifica a pasta das conversas já existentes. Arquivos de contexto escolhidos são referenciados no prompt inicial por caminho; GraphCodex não os copia.

## Preferências e recuperação

Ajustes permite escolher o intervalo de atualização, o limite de inatividade, a tela inicial, som discreto opcional e redução de movimento. Som vem desligado por padrão. Erros de conexão e de ações aparecem na janela e oferecem atualização ou abertura da conversa quando aplicável. Aprovações continuam no Codex.

## Compilar

Requisitos: macOS 14+, Xcode Command Line Tools e XcodeGen.

```sh
xcodegen generate
xcodebuild -project GraphCodex.xcodeproj -scheme GraphCodex -destination 'platform=macOS,name=My Mac' build
xcodebuild -project GraphCodex.xcodeproj -scheme GraphCodex -destination 'platform=macOS,name=My Mac' -parallel-testing-enabled NO test
```

A suíte cobre agrupamento e movimentação, persistência, composição de prompt, criação/fork, roteamento JSON-RPC sem aprovação automática, layout e câmera.
