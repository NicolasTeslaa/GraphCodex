# GraphCodex

App nativo para macOS que mostra as sessões recentes do Codex em uma oficina pixel art 2D. A lista principal abre no filtro de sessões ativas; conversas com mais de 24 horas não entram no painel, e sessões concluídas podem ser vistas em filtros separados. A lista atualiza em intervalos configuráveis, destaca perguntas, aprovações, erros e turnos sem atividade e abre a conversa selecionada no app Codex.

## Executar

Requisitos: macOS 14 ou posterior, Xcode Command Line Tools, XcodeGen e o app Codex instalado.

```sh
brew install xcodegen
make run
```

Para compilar sem abrir:

```sh
make build
```

O cliente inicia `codex app-server --stdio` e usa as chamadas de leitura `thread/list` e `thread/turns/list`. Nenhum conteúdo das mensagens é exibido ou salvo pelo GraphCodex. O app-server pode tentar atualizar o catálogo de plugins segundo a configuração local do Codex.
