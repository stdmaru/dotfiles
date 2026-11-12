#!/usr/bin/env bash
# Instala as dependências e liga as configurações deste repositório.
# Uso: ./install.sh [-y]   (-y responde sim a tudo)

#######################################
############ Parâmetros ###############
#######################################
yes_to_all=0
for param in "$@"; do
    case "$param" in
        -y|--yes) yes_to_all=1 ;;
        -h|--help)
            printf 'Uso: %s [-y]\n  -y, --yes   responde sim a todas as perguntas\n' "$0"
            exit 0
            ;;
    esac
done

#######################################
############ Funções auxiliares #######
#######################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'

install_dir="$HOME/dotfiles"
log_file="/dev/null"

message() {
    case "$1" in
        error)   printf "[${RED}FALHA!${NC}] %s\n" "$2" ;;
        success) printf "[  ${GREEN}OK${NC}  ] %s\n" "$2" ;;
        warning) printf "[ ${YELLOW}WARN${NC} ] %s\n" "$2" ;;
        *)       printf "%s\n" "$2" ;;
    esac
}

prompt() {
    printf "${CYAN}%s${NC}" "$1"
}

# Pergunta sim/não; com -y, assume o padrão "sim".
confirm() {
    [ "$yes_to_all" = 1 ] && return 0
    prompt "$1 [Y/n]: "
    read -r answer
    [ "$answer" != "n" ] && [ "$answer" != "N" ]
}

# Roda um comando mostrando uma animação; a saída vai para o log.
status_message() {
    local text="$1"
    local command="$2"

    printf "$HIDE_CURSOR"
    (
        local frames=("[ ${YELLOW}>${NC}    ]" "[ ${YELLOW}>>${NC}   ]" "[ ${YELLOW}>>>${NC}  ]" "[ ${YELLOW}>>>>${NC} ]")
        local i=0
        while true; do
            printf "\r${frames[i]} %s" "$text"
            i=$(( (i + 1) % 4 ))
            sleep 0.25
        done
    ) &
    local animation_pid=$!

    eval "$command" >> "$log_file" 2>&1
    local status=$?

    kill "$animation_pid" 2>/dev/null
    wait "$animation_pid" 2>/dev/null
    printf "$SHOW_CURSOR"

    if [ $status -eq 0 ]; then
        printf "\r[  ${GREEN}OK${NC}  ] %s\n" "$text"
    else
        printf "\r[${RED}FALHA!${NC}] %s\n" "$text"
        message error "A instalação não pôde ser finalizada. Confira o arquivo [$log_file] para mais detalhes."
        exit 1
    fi
}

trap 'printf "$SHOW_CURSOR"' EXIT

#######################################
############ Verificações #############
#######################################
if [ "$EUID" -eq 0 ]; then
    message error "Não rode este script como root; ele pede o sudo quando precisa."
    exit 1
fi

if ! command -v sudo > /dev/null 2>&1; then
    message error "Um pacote necessário (sudo) não foi encontrado no sistema. Tente novamente após instalá-lo."
    exit 1
fi

printf "
  _____        _    __ _ _
 |  __ \\      | |  / _(_) |
 | |  | | ___ | |_| |_ _| | ___  ___
 | |  | |/ _ \\| __|  _| | |/ _ \\/ __|
 | |__| | (_) | |_| | | | |  __/\\__ \\
 |_____/ \\___/ \\__|_| |_|_|\\___||___/

"

printf 'Acesso root necessário para instalar os pacotes.\n'
sudo -v || exit 1

detect_distro() {
    [ -f /etc/os-release ] || return 1
    # shellcheck disable=SC1091
    . /etc/os-release
    distro_name="${NAME:-desconhecida}"
    case " ${ID:-} ${ID_LIKE:-} " in
        *" arch "*) return 0 ;;
    esac
    return 1
}

check_internet_connection() {
    curl -sfI --max-time 5 https://archlinux.org > /dev/null \
        || ping -c 1 -W 3 archlinux.org > /dev/null
}

#######################################
############ Pacotes ##################
#######################################
# Só o que o Hyprland, o quickshell e as demais configurações usam.
packages=(
    # Sessão
    hyprland
    hyprshutdown                # SUPER+M encerra a sessão
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    xdg-utils                   # xdg-open (clima, links)
    polkit-gnome                # agente de autenticação
    gnome-keyring
    git

    # Quickshell e o que ele usa
    quickshell
    qt6-5compat                 # Qt5Compat.GraphicalEffects
    qt6-svg
    qt6-imageformats
    networkmanager              # nmcli (página de rede)
    pipewire                    # Quickshell.Services.Pipewire
    pipewire-pulse
    wireplumber                 # wpctl (teclas de volume)
    lm_sensors                  # sensors (temperaturas da barra)
    accountsservice             # foto do usuário na tela de bloqueio
    libnotify                   # notify-send
    playerctl                   # teclas de mídia
    pavucontrol                 # botão do mixer

    # Aplicativos e utilitários
    alacritty                   # terminal
    dolphin                     # gerenciador de arquivos
    brightnessctl               # teclas de brilho
    grim                        # captura de tela
    slurp
    wl-clipboard                # wl-copy
    zsh

    # Aparência
    breeze                      # cursor Breeze_Light
    breeze-gtk                  # tema GTK Breeze-Dark
    breeze-icons
    kde-gtk-config              # colorreload-gtk-module
    plasma-integration          # QT_QPA_PLATFORMTHEME=kde
    adwaita-icon-theme-legacy   # ícones do quickshell (AdwaitaLegacy)

    # Fontes
    cantarell-fonts             # fonte do quickshell
    ttf-jetbrains-mono-nerd     # ícones Nerd Font
    woff2-font-awesome          # Font Awesome 7
    noto-fonts                  # fonte do GTK
    noto-fonts-cjk              # japonês (workspaces)
)

# Pacotes do AUR; instalados só se houver um auxiliar (yay ou paru).
aur_packages=(
    waywallen                   # papel de parede
)

install_packages() {
    status_message "Atualizando a base de pacotes..." "sudo pacman -Sy --noconfirm"
    status_message "Instalando ${#packages[@]} pacotes..." \
        "sudo pacman -S --needed --noconfirm ${packages[*]}"

    local helper=""
    command -v paru > /dev/null 2>&1 && helper=paru
    command -v yay > /dev/null 2>&1 && helper=yay
    if [ -n "$helper" ]; then
        status_message "Instalando pacotes do AUR (${aur_packages[*]})..." \
            "$helper -S --needed --noconfirm ${aur_packages[*]}"
    else
        message warning "Nenhum auxiliar do AUR (yay/paru) encontrado. Instale manualmente: ${aur_packages[*]}"
    fi
}

#######################################
############ Configurações ############
#######################################
# Substitui $2 por um link para $1 (pergunta antes, se já existir).
link() {
    local name="$1" source="$2" target="$3"

    if [ ! -e "$source" ]; then
        message error "Configurações de $name não foram encontradas! [$source]"
        exit 1
    fi

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        message success "$name já configurado."
        return
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        confirm "Já existe uma configuração de $name em [$target]. Deseja substituir?" || return
    fi

    status_message "Configurando $name..." \
        "rm -rf '$target' && mkdir -p '$(dirname "$target")' && ln -s '$source' '$target'"
}

install_fonts() {
    local font_dir="$HOME/.local/share/fonts"
    status_message "Instalando fontes do repositório..." \
        "mkdir -p '$font_dir' && cp -r '$install_dir/fonts/.' '$font_dir/' && fc-cache -f"
}

install_configs() {
    install_fonts
    link "GTK 3"      "$install_dir/config/gtk-3.0"         "$HOME/.config/gtk-3.0"
    link "user-dirs"  "$install_dir/config/user-dirs.dirs"  "$HOME/.config/user-dirs.dirs"
    link "Alacritty"  "$install_dir/config/alacritty"       "$HOME/.config/alacritty"
    link "Hyprland"   "$install_dir/config/hypr"            "$HOME/.config/hypr"
    link "Quickshell" "$install_dir/config/quickshell"      "$HOME/.config/quickshell"
    link "zsh"        "$install_dir/config/zsh"             "$HOME/.local/share/zsh"
    link ".zshrc"     "$install_dir/config/.zshrc"          "$HOME/.zshrc"

    # Preferências do quickshell (fora do git); o shell cria o arquivo.
    mkdir -p "$install_dir/config/quickshell/userdata"

    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/bin/zsh" ]; then
        status_message "Configurando zsh como shell padrão..." "sudo usermod -s /bin/zsh '$USER'"
    fi
}

#######################################
############ Etapas ###################
#######################################
choose_install_dir() {
    if [ "$yes_to_all" != 1 ]; then
        prompt "Diretório de instalação [$install_dir]: "
        read -r directory
        [ -n "$directory" ] && install_dir="$directory"
    fi

    if ! mkdir -p "$install_dir" 2> /dev/null || [ ! -w "$install_dir" ]; then
        message error "Você não possui permissões para escrever em [$install_dir]."
        exit 1
    fi
    install_dir=$(readlink -f "$install_dir")
    log_file="$install_dir/install.log"
    : > "$log_file"
    message success "Diretório de instalação definido em [$install_dir]."
}

pre_install() {
    choose_install_dir
    cd "$install_dir" || exit 1

    message warning "As configurações serão ligadas a partir de [$install_dir]. Depois de instalar, não mova este diretório."
    confirm "Deseja continuar?" || exit 0

    if ! detect_distro; then
        message error "Distribuição incompatível com este script: ${distro_name:-desconhecida}. Apenas Arch Linux e derivados."
        exit 1
    fi
    message success "Distribuição compatível: $distro_name"

    status_message "Checando conexão com a internet..." "check_internet_connection"

    install_packages

    if [ ! -d "$install_dir/.git" ]; then
        status_message "Baixando o repositório..." \
            "git init -q && git remote add origin https://github.com/debelzak/dotfiles.git && git fetch -q origin && git reset -q --hard origin/main"
    fi

    # Só os submódulos em uso (plugins e tema do zsh).
    status_message "Baixando plugins do zsh..." "git submodule update --init config/zsh"
}

post_install() {
    if ! systemctl is-active --quiet NetworkManager; then
        message warning "O NetworkManager não está ativo; a página de rede do shell depende dele (sudo systemctl enable --now NetworkManager)."
    fi

    printf "${GREEN}Instalação realizada com sucesso!${NC}\n"
    printf "${GREEN}Inicie a sessão com o comando: Hyprland${NC}\n"
    printf "${GREEN}Clima: defina _SHELL_WEATHER_API_KEY e _SHELL_WEATHER_LOCATION (hl.env) em [~/.config/hypr/hyprland.lua].${NC}\n"
}

pre_install
install_configs
post_install
exit 0
