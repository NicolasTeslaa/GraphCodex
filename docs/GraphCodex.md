# GraphCodex

## Visão do produto

GraphCodex é um app nativo para macOS que transforma as tarefas abertas no Codex em um pequeno mundo 2D. O usuário acompanha de relance quantas sessões estão trabalhando, quais aguardam uma resposta ou aprovação e quais terminaram ou parecem sem atividade. Clicar em uma sessão abre aquela conversa na janela do Codex já instalada no Mac.

O app é um painel de observação. Ele não envia mensagens, aprova ações nem controla o trabalho do Codex.

## Plano funcional

### Público e problema

Para quem mantém várias tarefas do Codex em andamento e precisa saber rapidamente se alguma depende de sua atenção, sem alternar entre todas as conversas.

### Tela principal: mundo 2D

- Uma cena pixel art representa uma oficina/base com áreas ocupadas pelas sessões. A composição deve caber em uma janela compacta e continuar legível em tamanhos maiores.
- Cada sessão aparece como uma unidade visual clicável: um personagem, estação ou sala com título curto e nome do projeto.
- A animação acompanha o estado: personagem trabalhando para sessão ativa, balão ou sinal luminoso para pergunta/aprovação, pose de descanso para tarefa concluída e animação discreta de espera quando não há atividade recente.
- A barra superior mostra total de sessões, quantas estão trabalhando e quantas precisam de atenção. A fila de atenção vem primeiro na navegação e recebe cor, ícone e texto; cor sozinha nunca comunica estado.
- Ao selecionar uma sessão, o painel lateral mostra título, projeto, horário da última atividade, estado e motivo da atenção, quando conhecido.
- Um clique ou tecla Enter abre a conversa correspondente no Codex. A seleção visual também pode abrir o painel de detalhes sem sair do GraphCodex.
- A tela abre no filtro de sessões ativas (trabalhando, atenção, paradas ou estado desconhecido); conversas com mais de 24 horas não aparecem no painel principal. Um filtro separado permite consultar o histórico recente e sessões concluídas. Busca por título ou projeto. Sessões arquivadas ficam fora por padrão.
- Menu da barra de menus mostra o resumo e as sessões que pedem atenção. Notificações do macOS são opcionais e configuráveis.

### Estados que o usuário vê

| Estado | Regra de apresentação | Ação sugerida |
| --- | --- | --- |
| Trabalhando | Há um turno em execução ou atividade atual confirmada pela integração | Acompanhar |
| Precisa de você | Codex reportou solicitação pendente de aprovação ou resposta | Abrir a sessão |
| Concluída | O turno terminou sem solicitação pendente | Revisar ou iniciar outro turno |
| Sem atividade recente | Nenhum evento novo por um intervalo configurável, sem prova de que a sessão travou | Verificar a sessão |
| Desconhecida | A fonte não confirmou estado atual ou os dados estão desatualizados | Abrir no Codex |

“Sem atividade recente” é um aviso baseado no tempo desde o último evento, não um diagnóstico de travamento. A interface deve mostrar a hora do último evento e evitar afirmar que o Codex parou quando não há evidência suficiente.

### Atualização e preferências

- Atualização contínua enquanto o app estiver aberto, com um indicador visível de conexão e horário da última sincronização.
- Preferência para intervalo de detecção de inatividade, duração de notificações, densidade da cena e redução de movimento.
- Na primeira execução, explicar que GraphCodex lê metadados locais de sessões e abre links `codex://`; não coleta histórico de mensagens.
- Se o Codex não estiver instalado ou o link não puder ser aberto, mostrar uma mensagem de recuperação em vez de descartar o clique.

### Fora do escopo da primeira versão

- Enviar mensagens, iniciar ou interromper turnos e responder a perguntas dentro do GraphCodex.
- Ler ou resumir o conteúdo completo das conversas.
- Sincronizar sessões entre Macs ou enviar telemetria para um serviço externo.
- Criar integração com outros assistentes de código.

## Plano de implementação

### Plataforma e estrutura

- App universal nativo em Swift e SwiftUI, com suporte inicial ao macOS 15 ou posterior.
- Cena 2D feita com SwiftUI Canvas ou SpriteKit; começar com Canvas para interface leve e avaliar SpriteKit se animações e colisões ficarem difíceis de manter.
- Separar modelo de sessão, integração com Codex, classificação de estado, persistência de preferências e apresentação. A tela recebe snapshots do modelo e não lê arquivos diretamente.
- Distribuição inicial para desenvolvimento local; assinatura/notarização entram quando houver um pacote compartilhável.

### Integração com Codex

1. **Validar a fonte de estado antes de fechar o design de dados.** O Codex disponibiliza o `app-server`, um processo local com protocolo JSON-RPC sobre `stdio` por padrão. Fazer um protótipo somente de leitura com `initialize`, `thread/list` e notificações de status/turno. Confirmar em uma matriz quais sinais de sessões abertas no app desktop chegam ao processo auxiliar: turno em andamento, fim do turno, pedido de aprovação/pergunta, nova sessão e sessão arquivada.
2. **Preferir protocolo suportado quando ele observar a sessão desejada.** Iniciar o helper com o executável Codex instalado, usando o `CODEX_HOME` efetivo do usuário. Implementar framing JSON-RPC por linha, handshake, timeout, reconexão, negociação de versão/capacidades e encerramento limpo do processo. O helper não deve chamar métodos de escrita.
3. **Cobrir lacunas sem alterar dados.** O `thread/list` do helper pode mostrar `notLoaded` para tarefas gerenciadas pela janela principal. Por isso, o app compara o horário atualizado do índice com a data de modificação do arquivo de sessão, sem ler seu conteúdo. Atividade recente prevalece sobre o status `interrupted` salvo no resumo, que pode estar desatualizado enquanto outro processo executa o turno. Chats com mais de 24 horas saem da tela principal; estado desconhecido continua explícito.
4. **Unificar sinais em `SessionSnapshot`.** Campos mínimos: `threadID`, título, caminho do projeto se disponível, estado, motivo da atenção, origem do sinal, última atividade e confiança/atualidade. Deduplicar por ID da thread, nunca apenas pelo título.
5. **Classificar sem inventar certeza.** Pedidos explícitos de aprovação ou resposta têm prioridade de atenção; turno ativo vira trabalhando; fim de turno vira concluída; ausência de atividade apenas envelhece o sinal para “sem atividade recente”. Se fontes discordarem ou ficarem antigas, mostrar desconhecida e registrar a origem usada.
6. **Abrir a conversa exata.** Usar `NSWorkspace` para abrir `codex://threads/<thread-id>` com o bundle ID do Codex (`com.openai.codex`). Verificar no protótipo que a URL abre a conversa existente, não apenas a janela inicial. Se esse esquema mudar, concentrar a adaptação em `CodexSessionOpener`.

### Componentes sugeridos

```text
GraphCodexApp
├── SessionStore                 # estado publicado à interface
├── CodexAppServerClient         # JSON-RPC e eventos do app-server
├── CodexLocalStoreReader        # alternativa local somente leitura
├── SessionStateClassifier       # sinais em estados de produto
├── CodexSessionOpener            # abre uma thread no app Codex
├── PreferencesStore             # filtros, acessibilidade e aparência
└── WorldView                    # mundo 2D + seleção + resumo
```

### Privacidade e robustez

- Restringir leituras aos metadados indispensáveis; não ler `auth.json`, tokens, credenciais ou corpos de mensagens.
- Não gravar conteúdo de sessão em logs. Logs de diagnóstico devem usar IDs truncados ou pseudonimizados e estados, sem títulos por padrão.
- Não escrever no banco nem nos arquivos do Codex. Encerrar o helper e observadores ao sair do app.
- Tratar suspensão do Mac, encerramento inesperado do Codex, migração de banco, sessão sem título e mudança de versão como estados esperados.
- Exibir “última sincronização” e desbotar estados antigos. O dado mais antigo não pode continuar parecendo vivo.
- Permitir reduzir ou desligar animações e oferecer navegação completa por teclado, VoiceOver e indicação textual dos estados.

### Etapas de entrega

1. **Prova de integração:** listar sessões e observar mudanças reais no app desktop; validar abertura de uma thread por deep link. Registrar quais estados vêm do protocolo e quais exigem leitura local.
2. **Protótipo visual:** implementar cena com dados simulados, estados, seleção, acessibilidade e tamanhos de janela.
3. **Versão funcional:** conectar fontes locais, classificação, busca/filtros, recuperação de falhas e menu da barra de menus.
4. **Acabamento:** notificações configuráveis, preferências persistentes, documentação de privacidade, ícone e pacote macOS.

### Critérios de aceite

- A contagem diferencia sessões trabalhando, aguardando atenção e concluídas sem contar a mesma thread duas vezes.
- Uma pergunta/aprovação reportada pela integração aparece primeiro e identifica o motivo.
- Silêncio prolongado aparece como “sem atividade recente”, com horário do último evento, e não como falha confirmada.
- Clicar numa sessão conhecida abre a thread correspondente no Codex desktop.
- Com o Codex fechado, helper indisponível ou dados incompatíveis, a tela explica a condição e mostra quando os dados foram atualizados.
- GraphCodex não modifica sessão, configuração, banco ou credenciais do Codex e não envia dados para fora do Mac.

## Referências e hipóteses

- [Codex app-server: protocolo e implementação](https://github.com/openai/codex/tree/main/codex-rs/app-server) — referência primária para o helper local e o protocolo experimental.
- [Parâmetros de `thread/list`](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/ThreadListParams.json) e [resposta de `thread/list`](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/ThreadListResponse.json) — paginação, filtros e metadados disponíveis.
- [Notificação de mudança de estado da thread](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/ThreadStatusChangedNotification.json) e [notificação de turno concluído](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/TurnCompletedNotification.json) — sinais para sincronizar o modelo.
- [Codenotch](https://github.com/vinzdg/codenotch) — referência de produto macOS: provedores separados, polling, último estado válido e degradação explícita para `stale`/`error`. GraphCodex adapta essas escolhas para sessões e usa o mundo 2D como metáfora visual.
- [Discussão sobre deep links `codex://` no macOS](https://github.com/openai/codex/issues/25863) — evidência pública de roteamento do esquema pelo bundle ID `com.openai.codex`; o formato de thread específica deve ser validado no protótipo.

O protocolo do app-server e os formatos internos de persistência podem evoluir. A prova de integração da etapa 1 é a decisão técnica que confirma qual fonte entrega estados confiáveis para todas as sessões do Codex desktop; a interface deve preservar o estado `desconhecido` caso alguma informação não esteja disponível.
