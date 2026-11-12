# Quickshell

Shell do desktop (Hyprland + Quickshell).

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `shell.qml` | Ponto de entrada: só compõe os módulos e expõe o IPC. |
| `config/Preferences.qml` | Preferências do usuário, por categoria, salvas em `userdata/preferences.json`; também descreve o que a janela de configurações mostra. |
| `config/Config.qml` | Opções fixas (workspaces de bloqueio, tempos de animação…) e atalhos para as preferências. |
| `config/Theme.qml` | Paleta de cores e fontes. |
| `controllers/` | Singletons com estado e serviços (sem interface): `Session` (bloqueio), `Notifications`, `Network`, `Audio`, `Weather`, `System`, `Hypr`, `Screens`, `Launcher`, `Dialogs`, `Settings`. |
| `components/common/` | Widgets reutilizáveis. |
| `modules/screen/` | Camada por monitor: moldura e, no principal, a barra e o que sai dela. |
| `modules/bar/` | Barra, workspaces, bandeja e recursos do sistema. |
| `modules/notifications/` | Popups, painel e seus cartões (calendário, clima, mídia). |
| `modules/systemmenu/` | Menu de rede, som e energia. |
| `modules/lock/`, `modules/launcher/`, `modules/dialogs/` | Tela de bloqueio, lançador e diálogos. |
| `modules/settings/` | Janela de configurações (engrenagem no menu do sistema). |

## Preferências

A janela de configurações (engrenagem no canto do menu de rede/som/energia)
edita `userdata/preferences.json`. O arquivo também pode ser editado à mão: o
shell recarrega sozinho. Para expor uma nova opção, declare a propriedade no
objeto da categoria em `Preferences.qml` e uma entrada em `categories`.

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
quickshell ipc call settings open bar         # user | bar | behavior | lock | notifications
```

## Clima

Variáveis de ambiente: `_SHELL_WEATHER_API_KEY`, `_SHELL_WEATHER_LOCATION` e
`_SHELL_WEATHER_LANG` (OpenWeatherMap).
