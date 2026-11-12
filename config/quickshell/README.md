# Quickshell

Shell do desktop (Hyprland + Quickshell).

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `shell.qml` | Ponto de entrada: só compõe os módulos e expõe o IPC. |
| `config/Config.qml` | Opções: monitor principal, workspaces de bloqueio, tempos de animação… |
| `config/Theme.qml` | Paleta de cores e fontes. |
| `controllers/` | Singletons com estado e serviços (sem interface): `Session` (bloqueio), `Notifications`, `Network`, `Audio`, `Weather`, `System`, `Hypr`, `Screens`, `Launcher`, `Dialogs`. |
| `components/common/` | Widgets reutilizáveis. |
| `modules/screen/` | Camada por monitor: moldura e, no principal, a barra e o que sai dela. |
| `modules/bar/` | Barra, workspaces, bandeja e recursos do sistema. |
| `modules/notifications/` | Popups, painel e seus cartões (calendário, clima, mídia). |
| `modules/systemmenu/` | Menu de rede, som e energia. |
| `modules/lock/`, `modules/launcher/`, `modules/dialogs/` | Tela de bloqueio, lançador e diálogos. |

## Monitores

A barra fica em `Config.primary_screen`; se ele não estiver conectado, o
primeiro monitor assume. As workspaces vazias usadas no bloqueio
(`Config.lock_workspaces`) precisam existir como regras persistentes no
`hyprland.lua`.

## IPC

```sh
quickshell ipc call launcher toggle
quickshell ipc call notifications toggle      # também: clear, toggleDnd
quickshell ipc call systemmenu toggle sound   # network | sound | power
quickshell ipc call session lock              # também: suspend
```

## Clima

Variáveis de ambiente: `_SHELL_WEATHER_API_KEY`, `_SHELL_WEATHER_LOCATION` e
`_SHELL_WEATHER_LANG` (OpenWeatherMap).
