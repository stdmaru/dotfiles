# Quickshell

Shell do desktop (Hyprland + Quickshell).

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `shell.qml` | Ponto de entrada: só compõe os módulos e expõe o IPC. |
| `config/Preferences.qml` | Preferências do usuário, por categoria, salvas em `userdata/preferences.json`; também descreve o que a janela de configurações mostra. |
| `config/Config.qml` | Opções fixas (workspaces de bloqueio, tempos de animação…) e atalhos para as preferências. |
| `config/Theme.qml` | Cores do tema ativo (com a transição animada) e fontes. |
| `config/Themes.qml` | Temas de cores disponíveis. |
| `shaders/` | Shaders (fonte `.frag` e compilado `.qsb`). |
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

## Temas

Escolhidos em Configurações → Aparência (ou `quickshell ipc call theme set
light`). A troca é uma transição de cores de todo o shell. Para criar um tema,
acrescente um objeto em `config/Themes.qml` com `id`, `name`, `dark` e as cores;
as que faltarem vêm do primeiro tema. Cores fora de `Theme` não acompanham a
troca, então use sempre `Theme.<cor>` (ou `Theme.alpha(Theme.<cor>, a)`).

Os ícones da bandeja vêm dos aplicativos e são feitos para painel escuro. Em
tema claro, o shader `shaders/trayicon-symbolic.frag` troca o branco/cinza deles pela
cor de texto do tema, sem mexer nos ícones coloridos. Depois de editar o
`.frag`, recompile o `.qsb`:
`/usr/lib/qt6/bin/qsb --qt6 -o shaders/trayicon-symbolic.frag.qsb shaders/trayicon-symbolic.frag`.

A sombra das bordas (Aparência → Sombra) vem de `components/common/ShadowLayer.qml`:
os fundos da moldura, da barra e dos painéis ficam dentro dele e projetam
uma sombra só, a partir da união das formas. Janelas à parte (lançador, menu
do sistema) usam `clipToWorkArea` para a sombra não cair sobre a barra.

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
quickshell ipc call settings open bar         # user | appearance | bar | behavior | lock | notifications
quickshell ipc call theme set petal           # também: cycle, get
```

## Clima

Variáveis de ambiente: `_SHELL_WEATHER_API_KEY`, `_SHELL_WEATHER_LOCATION` e
`_SHELL_WEATHER_LANG` (OpenWeatherMap).
