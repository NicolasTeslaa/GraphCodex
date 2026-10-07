# Visual System

## Direction

Midnight Violet: preservar a identidade escura e violeta atual, agora aplicada a um escritório 3D semi-low-poly com departamentos visualmente reconhecíveis e controles macOS familiares. A interface é Operate: clareza, densidade legível e estados evidentes vêm antes do espetáculo.

## Palette

| Token | HEX | Uso |
| --- | --- | --- |
| Background | `#111420` | Fundo principal |
| Surface | `#1B2030` | Painéis e sidebar |
| Raised | `#252B3E` | Controles e superfície elevada |
| Text | `#F2F4FA` | Texto primário |
| Muted | `#AEB7C8` | Texto secundário |
| Primary | `#B2A3FF` | Ação, seleção e foco |
| Working | `#73E1B5` | Trabalho confirmado |
| Attention | `#FF7A68` | Atenção necessária |
| Quiet | `#F4C86A` | Inatividade |
| Line | `#333B50` | Separadores discretos |

Os contrastes revisados entre os pares principais excedem 4.5:1. A cor de cada departamento é um acento persistido por projeto, mantendo texto e ícone para estado semântico.

## Typography and Components

- Usar SF Pro nativa do macOS, com escala compacta de interface e números tabulares para métricas.
- Usar controles SwiftUI nativos sempre que atenderem à tarefa.
- Sidebar, toolbar, inspetor e lista são superfícies planas com bordas discretas; evitar vidro decorativo e cartões aninhados.
- Ações primárias nomeiam a ação. Confirmação de início mostra pasta e prompt.

## Motion

- Transições curtas e amortecidas para foco e troca de modo.
- Animação comunica atividade, carregamento ou transição; redução de movimento remove movimento contínuo.
- Som é opcional, desligado por padrão e reservado para mudança de atenção.
