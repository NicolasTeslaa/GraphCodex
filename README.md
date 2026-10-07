# GraphCodex

GraphCodex é um app nativo para macOS que transforma as sessões locais do Codex em uma oficina 3D interativa. Cada sessão ocupa uma estação com um agente, um estado visual e um quadro de atividade. A ideia é dar uma visão rápida do que está acontecendo em várias conversas e facilitar a ida até a conversa que precisa de atenção.

Apesar da aparência de jogo, GraphCodex não tem fases, pontuação ou objetivos para vencer. A oficina é uma forma visual e navegável de explorar e acompanhar o trabalho dos agentes.

## O que ele faz

- Consulta sessões locais do Codex e as organiza por estado.
- Mostra agentes trabalhando, sessões que precisam de você, sessões concluídas, sessões sem atividade recente e estados desconhecidos.
- Exibe contadores, nome da sessão, projeto, motivo de atenção e uma prévia do último prompt disponível.
- Permite buscar por projeto ou nome da sessão e filtrar sessões ativas, trabalhando, em atenção, recentes ou concluídas.
- Abre a conversa selecionada no app Codex instalado no Mac.
- Atualiza os dados automaticamente e permite ajustar o intervalo de atualização e o limite para sinalizar inatividade.

GraphCodex funciona como um painel de observação. Ele não envia mensagens, responde perguntas, aprova ações nem inicia ou interrompe turnos.

## Como usar a oficina

- Clique em um agente ou estação para abrir a conversa correspondente no Codex.
- Use `W`, `A`, `S`, `D` ou as setas para andar pela sala. `Shift` acelera o movimento.
- Aproxime-se de uma estação para selecionar e abrir sua sessão.
- Arraste o mouse para girar a câmera; use a roda do mouse para aproximar ou afastar.
- Pressione `V` para alternar entre a câmera isométrica e a primeira pessoa. Na primeira pessoa, o mouse controla a direção do olhar.
- Use a busca e os filtros acima da cena para encontrar sessões específicas.
- Abra Preferências pelo botão de controles para mudar a frequência de atualização (5–30 segundos) e o limite de inatividade (1–20 minutos).

As cores, animações e ícones são acompanhados por rótulos textuais para indicar o estado. Sessões que exigem atenção são priorizadas na ordem da lista usada para montar a oficina.

## Estados das sessões

| Estado | Interpretação no GraphCodex |
| --- | --- |
| Trabalhando | O turno está ativo ou em andamento e teve atividade dentro do limite configurado. |
| Precisa de você | Há aprovação ou resposta pendente, uma pergunta do Codex, um erro ou atividade insuficiente durante um turno sinalizado como ativo. |
| Concluída | O último turno terminou ou a sessão está ociosa. |
| Sem atividade | Não há atividade recente; isso é um aviso temporal, não um diagnóstico de falha. |
| Estado desconhecido | Os sinais locais não permitem determinar o estado atual com segurança. |

As sessões concluídas aparecem no filtro **Concluídas**. A visualização **Ativas** inclui todos os estados exceto concluída, inclusive sem atividade e desconhecido. **Recentes** mostra todas as sessões retornadas pela consulta local.

## Como foi construído

GraphCodex é escrito em Swift 5.9 e usa SwiftUI para a janela, barra de ferramentas, busca, filtros e preferências. A oficina 3D é criada em tempo de execução com SceneKit: geometria, mobiliário, avatares, quadros, iluminação, cores, poses e animações são montados no código. O ícone do app é fornecido pelo catálogo local `Assets.xcassets`.

A integração com o Codex inicia o processo local `codex app-server --stdio` e troca mensagens JSON-RPC por pipes padrão. As consultas implementadas são `thread/list` e `thread/turns/list`; o cliente também faz a inicialização do protocolo. O GraphCodex não oferece chamadas para alterar sessões.

## Arquitetura atual

```text
GraphCodexApp
├── MainView / SettingsView       Interface SwiftUI e preferências
├── CodexMonitor                  Estado observável, atualização e abertura de sessões
├── CodexAppServerClient          Processo local e protocolo JSON-RPC
│   ├── thread/list               Metadados, status e caminho do arquivo da sessão
│   └── thread/turns/list          Resumo do último turno e pergunta/prompt recente
├── Session                       Modelo, estados e filtros
└── Office3DView                  Cena SceneKit, controles, agentes e estações
```

1. `GraphCodexApp` cria a janela principal e a janela de preferências e compartilha um `CodexMonitor`.
2. `CodexMonitor` inicia a atualização assim que é criado, evita atualizações simultâneas e publica sessões, estado da conexão, contadores e horário da última atualização para a interface. As preferências ficam em `UserDefaults`.
3. `CodexAppServerClient` localiza o executável `codex`, inicia `app-server --stdio`, negocia a sessão JSON-RPC e lista threads não arquivadas. A lista é paginada até 2.000 registros. Para no máximo 60 threads atualizadas nos últimos 14 dias, busca o resumo do turno mais recente.
4. Para atividade, o cliente prefere a data de modificação do arquivo de rollout indicado pelo servidor e usa a data do índice como alternativa. Threads atualizadas nas últimas 24 horas entram na oficina; threads mais antigas também entram quando o servidor as marca com flags ativas.
5. O cliente classifica cada thread em um dos cinco estados do modelo `SessionState`. A interface passa os modelos e a seleção a `Office3DView`, que atualiza a cena e anima as mudanças de estado.
6. Selecionar ou visitar uma estação chama `NSWorkspace` para abrir `codex://threads/<id>` no app cujo bundle ID é `com.openai.codex`.

O cliente e o classificador estão juntos em `CodexAppServerClient.swift`; não há atualmente módulos separados de persistência local, classificação ou integração. `Office3DView.swift` contém tanto a construção da cena quanto os controles de câmera e movimento.

## Dados e privacidade

As consultas são locais e somente de leitura. GraphCodex não grava alterações nas sessões nem envia dados a um serviço próprio. O processo do app-server pode, por sua configuração local, atualizar o catálogo de plugins do Codex.

Para compor o quadro de cada estação, o cliente lê itens resumidos do último turno e extrai o texto da última mensagem do usuário. Uma versão compacta de até 100 caracteres é exibida na cena quando disponível. GraphCodex não persiste essa prévia; ela permanece em memória enquanto o app está aberto. Portanto, a integração lê uma pequena parte do conteúdo das conversas, além dos metadados de sessão.

O intervalo de atualização e o limite de inatividade são salvos nas preferências locais do macOS (`UserDefaults`). O app não lê credenciais nem o conteúdo integral dos arquivos de sessão diretamente; consulta o app-server e usa a data de modificação do arquivo de rollout como sinal de atividade.

## Requisitos e dependências

### Para executar

- macOS 14 ou posterior.
- App Codex para macOS instalado e configurado, incluindo o executável `codex` com suporte a `app-server`.
- Permissão do macOS para abrir o app Codex e o link `codex://`.

O cliente procura o executável junto ao app Codex, em alguns caminhos convencionais e no `PATH`. Se `CODEX_HOME` não estiver definido, usa `~/.codex`.

### Para compilar a partir do código

- Xcode Command Line Tools (`xcodebuild`).
- XcodeGen (`xcodegen`) para gerar `GraphCodex.xcodeproj` a partir de `project.yml`.
- Swift 5.9, incluído no toolchain do Xcode.

### Bibliotecas e frameworks

Não há dependências de terceiros via Swift Package Manager, CocoaPods ou Carthage. O app usa frameworks incluídos no macOS:

| Framework | Uso |
| --- | --- |
| SwiftUI | Interface e gerenciamento de estado das views. |
| AppKit | Integração com janelas, processos/aplicativos e abertura de URLs. |
| SceneKit | Cena 3D, geometria, câmera, materiais e animações. |
| Foundation | Processos, arquivos, JSON, datas e preferências. |
| Combine | Publicação de estado com `ObservableObject` e `@Published`. |
| CoreGraphics | Captura e associação do mouse na cena. |

`CoreGraphics` e os demais frameworks são fornecidos pelo SDK do macOS e não precisam ser instalados separadamente.

## Compilar e executar

Na raiz do repositório:

```sh
brew install xcodegen
make run
```

Para compilar sem abrir o app:

```sh
make build
```

O `Makefile` gera o projeto Xcode e compila o produto Debug em `.build/Build/Products/Debug/GraphCodex.app`.

## Limites conhecidos

- A disponibilidade e os campos retornados pelo `app-server` dependem da versão instalada do Codex.
- Sessões antigas ainda ativas podem aparecer mesmo fora da janela de 24 horas, se o servidor fornecer flags ativas.
- O limite de 60 se aplica à busca de resumos de turno; a consulta de threads tem limite próprio de até 2.000 registros.
- O status “Sem atividade” indica apenas tempo desde o último sinal. Não confirma que o Codex travou.
- Se o app Codex, o executável ou os dados locais não estiverem disponíveis, o GraphCodex mostra um erro de conexão e permite tentar novamente.
