#!/usr/bin/env bash

# Author: (aka 4xL)

# Definición de estilos de texto usando tput
bold=$(tput bold)
dim=$(tput dim)
rev=$(tput rev)
smul=$(tput smul)

# Colores de texto (foreground)
blackColour=$(tput setaf 0)
redColour=$(tput setaf 1)
greenColour=$(tput setaf 2)
yellowColour=$(tput setaf 3)
blueColour=$(tput setaf 4)
magentaColour=$(tput setaf 5)
cianColour=$(tput setaf 6)
whiteColour=$(tput setaf 7)
grisColour=$(tput setaf 8)
lightBlueColour="\e[38;2;173;216;230m"
orangeColour="\e[38;2;255;165;0m"

# Colores de fondo (background)
blackBg=$(tput setab 0)
redBg=$(tput setab 1)
greenBg=$(tput setab 2)
yellowBg=$(tput setab 3)
blueBg=$(tput setab 4)
magentaBg=$(tput setab 5)
cianBg=$(tput setab 6)
whiteBg=$(tput setab 7)
grisBg=$(tput setab 8)
# Resetear formato a valores por defecto
endColour=$(tput sgr0)

# ¡Modo estricto!

#set -euo pipefail

# Obtiene el usuario real que ejecutó sudo (no root)
REAL_USER="${SUDO_USER:-$(logname)}"

# Obtiene el directorio home del usuario real
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
INSTALL_DIR="${USER_HOME}/Install_BSPWM"
OPT_DIR="/opt"

# Variables para evitar prompts interactivos de apt
DEBIAN_FRONTEND="noninteractive"
DEBIAN_PRIORITY="critical"
DEBCONF_NOWARNINGS="yes"
export DEBIAN_FRONTEND DEBIAN_PRIORITY DEBCONF_NOWARNINGS
export UCF_FORCE_CONFFNEW=YES

# Controla si el output de comandos se muestra o no
MUTE_MODE=false
OUTPUT_REDIRECT="/dev/stdout"

# Configuración de needrestart para evitar prompts durante instalación
if [[ -f /etc/needrestart/needrestart.conf ]]; then
    sed -i 's/^#\$nrconf{restart} =.*/$nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf &>/dev/null
    sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf &>/dev/null
fi

[[ -f /etc/needrestart/notify.conf ]] && sed -i "s/#NR_NOTIFYD_DISABLE_NOTIFY_SEND='1'/NR_NOTIFYD_DISABLE_NOTIFY_SEND='1'/" /etc/needrestart/notify.conf &>/dev/null

# Flags para apt-get que fuerzan respuestas automáticas y evitan prompts
APT_FLAGS=(-yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confnew")

# Función wrapper para ejecutar comandos respetando el modo mute
exec_cmd() {
    if [[ "$MUTE_MODE" == true ]]; then
        "$@" &>/dev/null
    else
        "$@"
    fi
}

# Función para imprimir mensajes importantes (siempre visibles incluso en modo mute)
print_msg() {
    printf "%b\n" "$@"
}

spinner() { 
    local delay=0.1 
    local spinstr='|/-\' 
    while true; do 
        local temp=${spinstr#?} 
        printf "\r${greenColour}[%c]${endColour} " "$spinstr" 
        local spinstr=$temp${spinstr%"$temp"} 
        sleep $delay 
    done 
} 

start_spinner() { 
    tput civis 
    spinner & 
    spinner_pid=$! 
} 

stop_spinner() { 
    if [[ -n "$spinner_pid" ]]; then 
        kill $spinner_pid 2>/dev/null 
        wait $spinner_pid 2>/dev/null 
        tput cnorm 
        unset spinner_pid 
    fi 
}

# Muestra el panel de ayuda con las opciones disponibles
helpPanel() {
    print_msg "\n${greenColour}${rev}[!] Uso: sudo bash $0 -d {Mode} [-l] [-s] [-m]${endColour}\n"
    print_msg "\t${blueColour}${rev}[-d] Mode of installation.${endColour}"
    print_msg "\t\t${magentaColour}${grisBg}${bold}debian${endColour}\t\t\t${yellowColour}${rev}Distribution Debian nesesary =< 60 gb.${endColour}"
    print_msg "\t\t${cianColour}${grisBg}${bold}archlinux${endColour}\t\t${yellowColour}${rev}Distribution Archlinux nesesary =< 60 gb.${endColour}"
    print_msg "\t${blueColour}${rev}Opcionales:${endColour}"
    print_msg "\t\t${cianColour}${rev}[-s]${endColour}\t\t\t${greenColour}${rev}Spotify (Only for more than 16 gb RAM)${endColour}"
    print_msg "\t\t${magentaColour}${rev}[-m]${endColour}\t\t\t${greenColour}${rev}Mode silence (mute)${endColour}"
    print_msg "\t${redColour}${rev}[-h] Show this help panel.${endColour}"
    print_msg "\n${greenColour}${rev}Example:${endColour}"
    print_msg "\t${greenColour}${bold}sudo bash $0 -d debian -l -s -m${endColour}"
    tput cnorm
    exit 1
}

# Verifica que el script se ejecute con sudo pero no como root directo
check_sudo() {
    local CURRENT_UID=$(id -u)
    local PARENT_PROCESS=$(ps -o comm= -p $PPID 2>/dev/null)

    # Debe ser root (UID 0), proceso padre debe ser sudo, y usuario real no debe ser root
    if [ "${CURRENT_UID}" -eq 0 ] && \
        [ "${PARENT_PROCESS}" = "sudo" ] && \
        [ "${REAL_USER}" != "root" ]; then
       
        print_msg "\n${greenColour}${grisBg}${bold} Allowed: ${endColour}${greenColour}${rev}[*] Execution in progress\n${endColour}"
        
    else
        print_msg "\n${redColour}${grisBg}${bold}[x] Blocked: ${endColour}${redColour}${rev}[x] Unauthorized execution\n${endColour}"
        helpPanel
    fi
}

# Función para manejar CTRL+C (requiere presionarlo dos veces en menos de 1 segundo)
last=0
ctrl_c() {
    local now
    now=$(date +%s)

    # Si la diferencia entre ahora y el último CTRL+C es menor a 1 segundo, sale
    if (( now - last < 1 )); then
        print_msg "\n${redColour}${rev}[x] Exiting... ${endColour}"
        
        # Limpia el directorio de instalación antes d.e salir
        [[ -d "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR}" 2>/dev/null
        rm -f /etc/sudoers.d/axel-aur
        tput cnorm
        exit 1
    fi
    print_msg "\n${redColour}${grisBg}${bold}[!] Press CTRL+C twice in a row to exit. ${endColour}"
    last=$now
    return 0
}

# Captura la señal SIGINT (CTRL+C)
trap ctrl_c SIGINT

check_disk_space() { 
    local required_gb=60 
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//') 
    if (( available_gb < required_gb )); then 
        print_msg "${redColour}[x] Not enough disk space. Required: ${required_gb}GB${endColour}" 
        helpPanel
    fi 
}

# Detecta el sistema operativo e instala paquetes según la distribución
function check_os() {

    # Crea el directorio de instalación como el usuario real
    sudo -u "${REAL_USER}" mkdir -p "${INSTALL_DIR}"

    # Busca directorios existentes llamados "Entorno-BSPWM" fuera del INSTALL_DIR
    ENTORNOS=()
    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        ENTORNOS+=("$dir")
    done < <(
        find "${USER_HOME}" \
            -type d \
            -name "Entorno-BSPWM" \
            -not -path "${INSTALL_DIR}/*"
    )

    # Si encuentra directorios Entorno-BSPWM, los mueve a INSTALL_DIR
    if (( ${#ENTORNOS[@]} > 0 )); then
        for dir in "${ENTORNOS[@]}"; do
            sudo -u "${REAL_USER}" mv "$dir" "${INSTALL_DIR}/"
            print_msg "\n${magentaColour}${rev} [!] The directory was moved successfully. ${endColour}\n"
        done
    fi

    # Al principio del script (después de check_sudo)
    while true; do
        read -rp "$(printf "%b" "${orangeColour}[*] Set ${endColour}${redColour}s4vitar's${endColour}${orangeColour} BSPWM environment? ${endColour}${greenColour}${grisBg}${bold}(y|yes|yey)${endColour} or ${greenColour}${grisBg}${bold}(n|no|nay)${endColour} ${orangeColour}for Set ${endColour}${magentaColour}Emili's${endColour} ${orangeColour}BSPWM environment?${endColour} ")" entorno
        
        case "${entorno,,}" in 
            y|yes|yey)
                THEME_CHOICE="s4vitar"
                break
                ;;
            ""|n|no|nay)
                THEME_CHOICE="emili"
                break
                ;;
            *)
                print_msg "\n${redColour}${rev}[x] Invalid option. Please try again.${endColour}\n"
                ;;
        esac
    done

    # Instalación para sistemas basados en Debian
    start_spinner
    if hash apt 2>/dev/null; then
        print_msg "\n${greenColour}${grisBg}${bold} The system is Debian. ${endColour}"
        print_msg "\n${yellowColour}${rev}  Installing only the bspwm environment for Debian. ${endColour}\n"

        # Remueve versiones conflictivas de codium y neovim
        exec_cmd apt-get remove --purge codium -y
        exec_cmd apt-get remove --purge neovim -y
        exec_cmd rm /usr/share/applications/nvim.desktop
        exec_cmd rm /usr/share/applications/vim.desktop
        exec_cmd apt update -y

        # Array de paquetes necesarios para BSPWM en Debian
        packages_bspwm_debian=(
        curl wget dpkg gnupg gdb cmake net-tools 
        p7zip-full meson ninja-build bspwm sxhkd 
        polybar libpcre3-dev libxcb-present-dev
        build-essential libxcb-util0-dev libxcb-ewmh-dev 
        libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev 
        libxcb-xinerama0-dev libxcb-xtest0-dev libxcb-shape0-dev 
        xcb-proto zsh zsh-syntax-highlighting make 
        cmake-data pkg-config python3-sphinx python3-setuptools
        python3-xcbgen libxcb-sync-dev libuv1-dev 
        libcairo2-dev libxcb1-dev libxcb-composite0-dev 
        libxcb-cursor-dev libxcb-damage0-dev libxcb-glx0-dev
        libxcb-render0-dev libxcb-render-util0-dev 
        libxcb-xfixes0-dev libxcb-xkb-dev libxcb-xrm-dev 
        libxcb-image0-dev libstartup-notification0-dev 
        libxkbcommon-dev libpango1.0-dev libglib2.0-dev 
        libjpeg-dev libcurl4-openssl-dev uthash-dev 
        libev-dev libdbus-1-dev libconfig-dev libasound2-dev 
        libpulse-dev libjsoncpp-dev libmpdclient-dev 
        libnl-genl-3-dev libx11-xcb-dev libxext-dev libxi-dev
        libxinerama-dev libxkbcommon-x11-dev libxrandr-dev
        libgl1-mesa-dev libpixman-1-dev kitty rofi 
        suckless-tools feh scrot flameshot dunst caja 
        ranger lxappearance xdo xdotool wmctrl xclip 
        fontconfig bd bc seclists locate snapd)

        for package in "${packages_bspwm_debian[@]}"; do
            if exec_cmd dpkg -l "${package}" 2>/dev/null | grep -q "^ii"; then
                print_msg "${blueColour}${rev} Package => ${endColour}${blueColour}${grisBg}${bold} ${package} ${endColour}${blueColour}${rev}Already installed (skipped). ${endColour}"
                continue
            elif exec_cmd apt-get install "${APT_FLAGS[@]}" "${package}"; then
                print_msg "${greenColour}${rev} Package => ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}installed. ${endColour}"
            else
                print_msg "${yellowColour}${rev} Package => ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev}failed. ${endColour}"
            fi
        done 
        
        print_msg "${greenColour}${rev}[*]  Install bspwm and sxhkd. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1

        # Clona los repositorios de bspwm y sxhkd
        exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/baskerville/bspwm.git
        exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/baskerville/sxhkd.git 

        # Compila e instala bspwm
        cd "${INSTALL_DIR}/bspwm/"
        exec_cmd make
        exec_cmd make install 

        # Compila e instala sxhkd
        cd "${INSTALL_DIR}/sxhkd/"
        exec_cmd make
        exec_cmd make install 

        print_msg "${greenColour}${rev} Polybar compilation please have patience. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        # Clona polybar con submódulos recursivos
        exec_cmd sudo -u "${REAL_USER}" git clone --recursive https://github.com/polybar/polybar
        cd polybar/
        mkdir build
        cd build/

        # Compila e instala polybar
        exec_cmd cmake ..
        exec_cmd make -j$(nproc)
        exec_cmd make install

        # Instalación para Arch Linux
    elif hash pacman 2>/dev/null; then
        print_msg "\n${blueColour}${grisBg}${bold} The system is Arch Linux. ${endColour}"
        
        echo "${REAL_USER} ALL=(ALL) NOPASSWD: /usr/bin/pacman" | tee /etc/sudoers.d/axel-aur > /dev/null 2>&1
        chmod 440 /etc/sudoers.d/axel-aur
        
        # Instala paru (AUR)
        print_msg "${greenColour}${rev} Install Paru. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/paru-bin.git
        cd "${INSTALL_DIR}/paru-bin"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm

        # Instala blackarch repositories (ROOT)
        print_msg "${greenColour}${rev} Install Blackarch. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd curl -O https://blackarch.org/strap.sh
        chmod +x strap.sh
        exec_cmd ./strap.sh

        # Instala yay (otro AUR)
        print_msg "${greenColour}${rev} Install yay. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/yay.git
        cd "${INSTALL_DIR}/yay"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm
        
        print_msg "\n${yellowColour}${rev} Installing only the bspwm environment for Arch Linux. ${endColour}\n"

        # Array de paquetes necesarios para BSPWM en Arch
        packages_bspwm_arch=(
        base-devel curl wget cmake dpkg net-tools rsync
        plocate gnome meson ninja bspwm sxhkd polybar kmod
        make zlib pcre dbus libconfig libev libxpresent 
        pkgconf uthash libxcb xcb-proto xcb-util xcb-util-wm 
        xcb-util-keysyms cronie libgl libxcursor libxext 
        libxi libxinerama libxkbcommon-x11 libxrandr mesa 
        python-sphinx kitty rofi dmenu jgmenu feh scrot 
        flameshot maim dunst caja ranger yazi polkit-gnome 
        papirus-icon-theme lxappearance zsh zsh-syntax-highlighting
        xdo xdotool xclip brightnessctl playerctl pamixer redshift
        xorg xorg-server xorg-xinit xorg-xdpyinfo xorg-xkill 
        xorg-xprop xorg-xrandr xorg-xsetroot xorg-xwininfo
        xf86-video-intel xf86-video-vmware open-vm-tools
        xsettingsd gvfs-mtp simple-mtpfs virtualbox-guest-utils
        mpd mpc ncmpcpp mpv htop eza p7zip bc bd python-setuptools)

        # Instala paquetes con pacman
        for package in "${packages_bspwm_arch[@]}"; do
            if exec_cmd pacman -Qi "${package}" &>/dev/null; then
               print_msg "${blueColour}${rev} Package => ${endColour}${blueColour}${grisBg}${bold} ${package} ${endColour}${blueColour}${rev}Already installed (skipped). ${endColour}"
               continue
            elif exec_cmd pacman -S --noconfirm "${package}"; then
               print_msg "${greenColour}${rev} Package => ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}installed. ${endColour}"
            else
               print_msg "${yellowColour}${rev} Package => ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev}failed. ${endColour}"
            fi
        done

        # Clona y compila bspwm y sxhkd desde source
        print_msg "${greenColour}${rev}[*]  Install bspwm and sxhkd. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/baskerville/bspwm.git
        exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/baskerville/sxhkd.git
        cd "${INSTALL_DIR}/bspwm/"
        exec_cmd make
        exec_cmd make install
        cd "${INSTALL_DIR}/sxhkd/"
        exec_cmd make
        exec_cmd make install 
        
        # Crea un archivo swap temporal de 2GB para la compilación de polybar
        print_msg "${greenColour}${rev} Creating swap and compiling Polybar for Arch Linux please have patience. ${endColour}"
        sleep 5
        exec_cmd fallocate -l 2G /swapfile           # Crea un archivo de 2GB para usar como memoria virtual
        exec_cmd chmod 600 /swapfile                 # Le da permisos solo al root
        exec_cmd mkswap /swapfile                    # Formatea el archivo como área de swap
        exec_cmd swapon /swapfile                    # Activa el swap (lo usa el sistema)
        
        print_msg "${redColour}${rev}If the polybar doesn't compile, compile it separately and reload it with Super + Alt + r. ${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        
        # Clona y compila polybar
        exec_cmd sudo -u "${REAL_USER}" git clone --recursive https://github.com/polybar/polybar
        cd polybar/
        rm -rf build
        mkdir build
        cd build/
        sleep 5
        exec_cmd cmake .. -DBUILD_DOC=OFF
        sleep 5
        exec_cmd make -j$(nproc)
        sleep 5
        exec_cmd make install
        
        # Desactiva y elimina el archivo swap
        exec_cmd swapoff /swapfile
        exec_cmd rm /swapfile
        
    # Si no es Debian ni Arch, sale con error
    else
        print_msg "\n${redColour}${rev}[x] The system is neither Debian, Ubuntu, nor Arch Linux. ${endColour}"
        helpPanel
    fi
}

# Configura el entorno BSPWM con temas, fuentes y aplicaciones
function bspwm_enviroment() {

    # Instala foo-Wallpaper para wallpapers animados
    print_msg "${greenColour}${rev} Install Foo Wallpaper. ${endColour}"
    exec_cmd curl -L https://raw.githubusercontent.com/thomas10-10/foo-Wallpaper-Feh-Gif/master/install.sh | bash
     
    # Descarga tema blue-sky
    print_msg "${greenColour}${rev} Configure polybar fonts. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/VaughnValle/blue-sky.git

    # Copia fuentes de polybar al sistema
    cd "${INSTALL_DIR}/blue-sky/polybar/fonts"
    mkdir -p /usr/share/fonts/truetype
    cp * /usr/share/fonts/truetype/
    pushd /usr/share/fonts/truetype/ >/dev/null 2>&1   # `&>` es **atajo específico de bash** (y zsh); no es POSIX.
    exec_cmd fc-cache -v
    popd &>/dev/null 
    
    # Descarga e instala Hack Nerd Fonts
    print_msg "${greenColour}${rev} Install Hack Nerd Fonts. ${endColour}"
    cd "${INSTALL_DIR}" || exit 
    exec_cmd wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip
    mkdir -p /usr/local/share/fonts/
    exec_cmd unzip Hack.zip && sudo mv *.ttf /usr/local/share/fonts/
    rm -f Hack.zip LICENSE.md README.md 2>/dev/null 
    pushd /usr/local/share/fonts/ >/dev/null 2>&1
    exec_cmd fc-cache -v
    popd &>/dev/null

    # Clona y compila picom (compositor)
    print_msg "${greenColour}${rev} Picom compilation please have patience. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/ibhagwan/picom.git
    cd picom/
    rm -rf build
    exec_cmd git submodule update --init --recursive
    exec_cmd meson --buildtype=release . build
    exec_cmd ninja -C build
    exec_cmd ninja -C build install 

    # Instala powerlevel10k para el usuario y para root
    print_msg "${greenColour}${rev} Download powerlevel10k. ${endColour}"
    exec_cmd sudo -u "${REAL_USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${USER_HOME}/powerlevel10k"
    exec_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k

    # Instala plugin sudo para zsh
    print_msg "${greenColour}${rev} Install plugin sudo. ${endColour}"
    mkdir /usr/share/zsh-sudo
    exec_cmd wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh
    cp sudo.plugin.zsh /usr/share/zsh-sudo/ 

    # Instala bat (cat mejorado)
    print_msg "${greenColour}${rev} Install batcat. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd wget -q https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
    exec_cmd dpkg -i bat-musl_0.24.0_amd64.deb

    # Instala lsd (ls mejorado)
    print_msg "${greenColour}${rev} Install lsd. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1 
    exec_cmd wget -q https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd-musl_1.0.0_amd64.deb
    exec_cmd dpkg -i lsd-musl_1.0.0_amd64.deb

    # Instala fzf (fuzzy finder) para el usuario y para root
    print_msg "${greenColour}${rev} Install fzf. ${endColour}"
    exec_cmd sudo -u "${REAL_USER}" git clone --depth 1 https://github.com/junegunn/fzf.git "${USER_HOME}/.fzf"
    exec_cmd sudo -u "${REAL_USER}" "${USER_HOME}/.fzf/install" --all
    exec_cmd git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    exec_cmd ~/.fzf/install --all

    # Descarga e instala neovim
    print_msg "${greenColour}${rev} Install nvchad. ${endColour}" 
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd wget -q https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.tar.gz
    exec_cmd tar xzvf nvim-linux-x86_64.tar.gz
    exec_cmd mv nvim-linux-x86_64 /opt/nvim
    ln -s /opt/nvim/bin/nvim /usr/bin/nvim
    exec_cmd rm nvim-linux-x86_64.tar.gz

    # Instala NvChad para el usuario
    exec_cmd sudo -u "${REAL_USER}" rm -rf "${USER_HOME}/.config/nvim" 
    exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/NvChad/starter "${USER_HOME}/.config/nvim"
    exec_cmd nvim --headless '+Lazy! sync' +qa
    line="vim.opt.listchars = { tab = '»·', trail = '.' }"
    sed -i "3i ${line}" "${USER_HOME}/.config/nvim/init.lua"

    # Instala NvChad para root
    exec_cmd rm -rf /root/.config/nvim
    exec_cmd git clone https://github.com/NvChad/starter /root/.config/nvim
    exec_cmd nvim --headless '+Lazy! sync' +qa
    line="vim.opt.listchars = { tab = '»·', trail = '.' }"
    sed -i "3i ${line}" "/root/.config/nvim/init.lua"

    # Descarga temas de polybar
    print_msg "${greenColour}${rev} Install themes polybar. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd git clone https://github.com/adi1090x/polybar-themes.git
    cd polybar-themes

    # Copia configuraciones del tema polybar
    print_msg "${greenColour}${rev} Move files configuration. ${endColour}"
    sleep 2
    
   # Copia wallpapers al directorio Pictures del usuario
    print_msg "${greenColour}${rev} Configuration wallpaper. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/bspwm/Pictures"
    exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}"/Entorno-BSPWM/bspwm/Pictures/*.png "${USER_HOME}/.config/bspwm/Pictures" 
    exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}"/Entorno-BSPWM/bspwm/Pictures/*.gif "${USER_HOME}/.config/bspwm/Pictures"
    exec_cmd rm -rf "${USER_HOME}/.config/polybar"
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/polybar"
    exec_cmd sudo -u "${REAL_USER}" cp -af "${INSTALL_DIR}/Entorno-BSPWM/polybar/." "${USER_HOME}/.config/polybar/"

    # Copia configuraciones de bspwm, sxhkd, picom, kitty, rofi
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/bspwm"
    exec_cmd sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/bspwm/." "${USER_HOME}/.config/bspwm/"
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/sxhkd"
    exec_cmd sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/sxhkd/." "${USER_HOME}/.config/sxhkd/"
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/picom"
    exec_cmd sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/picom/." "${USER_HOME}/.config/picom/"
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/kitty"
    exec_cmd sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/kitty/." "${USER_HOME}/.config/kitty/"
    exec_cmd sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/.config/rofi"
    exec_cmd sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/rofi/." "${USER_HOME}/.config/rofi/"
    exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.p10k.zsh" "${USER_HOME}/.p10k.zsh"

    # Da permisos de ejecución a archivos de configuración
    chmod +x "${USER_HOME}/.config/sxhkd/sxhkdrc"
    chmod +x "${USER_HOME}/.config/bspwm/bspwmrc"
    chmod +x "${USER_HOME}/.config/bspwm/scripts/bspwm_resize"
    chmod +x "${USER_HOME}/.config/picom/picom.conf"
    chmod +x "${USER_HOME}/.config/kitty/kitty.conf"

    # Crear enlace simbólico forzado del archivo de configuración de Powerlevel10k para o 
    ln -s -f "${USER_HOME}/.p10k.zsh" "/root/.p10k.zsh"

    # Si el sistema es Arch Linux
    if hash pacman 2>/dev/null; then
        # Sistema con pacman (Arch-based)
        exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.zshrc-arch" "${USER_HOME}/.zshrc"
    elif hash apt 2>/dev/null; then
        # Sistema con apt (Debian-based)
        exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.zshrc-debian" "${USER_HOME}/.zshrc"
    else
        print_msg "\n${redColour}${rev}[x] The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
    fi
    
	 # Aplicar tema según elección
	 if [[ "$THEME_CHOICE" == "s4vitar" ]]; then
	     print_msg "${greenColour}${rev} Set s4vitar's themes.${endColour}"
	     exec_cmd sudo -u "${REAL_USER}" sed -i 's|~/.config/polybar/launch\.sh --forest|~/.config/polybar/launch4.sh|g' "${USER_HOME}/.config/bspwm/bspwmrc"
	 else
	     print_msg "${greenColour}${rev} Set Emili's themes.${endColour}"
	     exec_cmd sudo -u "${REAL_USER}" sed -i 's|~/.config/polybar/launch\.sh --forest|~/.config/polybar/launch1.sh|g' "${USER_HOME}/.config/bspwm/bspwmrc"
	 fi

    # Permisos de ejecución para launcher
    chmod +x "${USER_HOME}/.config/polybar/launch2.sh"
    chmod +x "${USER_HOME}/.config/polybar/launch1.sh"
    chmod +x "${USER_HOME}/.config/polybar/launch4.sh"
    chmod +x "${USER_HOME}/.config/polybar/forest/scripts/launcher.sh"
    chmod +x "${USER_HOME}/.config/polybar/forest/scripts/powermenu.sh"
    
    # Permisos para ethernet_status, vpn_status, target_to_hack
    chmod +x "${USER_HOME}/.config/polybar/emili/scripts/ethernet_status"
    chmod +x "${USER_HOME}/.config/polybar/emili/scripts/vpn_status"
    chmod +x "${USER_HOME}/.config/polybar/emili/scripts/target_to_hack"

    # Crear archivos temporales usados por polybar
    touch /tmp/{name,target}
    chown "${REAL_USER}:${REAL_USER}" /tmp/{name,target}

    # Asignar propietario correcto al archivo
    chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.zshrc"

    # Enlace simbólico del .zshrc del usuario a root
    ln -s -f "${USER_HOME}/.zshrc" "/root/.zshrc"

    # Cambiar shell por defecto a zsh
    usermod --shell /usr/bin/zsh "$REAL_USER" &>/dev/null
    usermod --shell /usr/bin/zsh root  &>/dev/null

    # Ajustar propietarios de directorios de root
    chown "${REAL_USER}:${REAL_USER}" "/root"     # Esto no cambia la propiedad de root pero si permite sudo su conserve el entorno
    chown "${REAL_USER}:${REAL_USER}" "/root/.cache" -R
    chown "${REAL_USER}:${REAL_USER}" "/root/.local" -R

    # Instalación de Visual Studio Code
    print_msg "${greenColour}${rev} Install Visual Studio Code. ${endColour}"
    exec_cmd curl -s "https://vscode.download.prss.microsoft.com/dbazure/download/stable/d78a74bcdfad14d5d3b1b782f87255d802b57511/code_1.94.0-1727878498_amd64.deb" -o code_1.94.0-1727878498_amd64.deb
    exec_cmd dpkg -i --force-confnew code_1.94.0-1727878498_amd64.deb

    # Install GO 
    print_msg "${greenColour}${rev} Install Go. ${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd wget -q https://go.dev/dl/go1.25.5.linux-amd64.tar.gz
    exec_cmd rm -rf /usr/local/go && tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin

    # Install fastTCPscan
    print_msg "${greenColour}${rev} Install fastTCPscan. ${endColour}"
    cp "${INSTALL_DIR}/Entorno-BSPWM/fastTCPscan.go" "/opt/fastTCPscan"
    chmod 755 /opt/fastTCPscan
    ln -s -f "/opt/fastTCPscan" "/usr/local/bin/fastTCPscan"

    # Install whichSystem
    print_msg "${greenColour}${rev}[*]  Install whichSystem. ${endColour}"
    mkdir -p /opt/whichSystem
    cp "${INSTALL_DIR}/Entorno-BSPWM/whichSystem.py" "/opt/whichSystem/whichSystem.py"
    ln -s -f "/opt/whichSystem/whichSystem.py" "/usr/local/bin/"
}

# Función para configurar el entorno de Spotify
function spotify_env(){
    cd "${INSTALL_DIR}" || exit 1

    # Clonar zscroll
    exec_cmd git clone https://github.com/noctuid/zscroll
    cd zscroll
    exec_cmd python3 setup.py install

    # Eliminar configuración previa de módulos de usuario
    exec_cmd rm -f "${USER_HOME}/.config/polybar/forest/user_modules.ini"

    # Copiar configuración personalizada de módulos
    exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/user_modules-copia.ini" "${USER_HOME}/.config/polybar/forest/user_modules.ini"
    exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/config.ini" "${USER_HOME}/.config/polybar/forest/config.ini.old2"
    exec_cmd sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/config.ini.old" "${USER_HOME}/.config/polybar/forest/config.ini"

    # Mensaje de instalación
    print_msg "${greenColour}${rev} Install Spotify. ${endColour}"
    
    # Dar permisos de ejecución a scripts forest
    chmod +x "${USER_HOME}/.config/polybar/forest/scripts/scroll_spotify_status.sh"
    chmod +x "${USER_HOME}/.config/polybar/forest/scripts/get_spotify_status.sh"

    if hash pacman 2>/dev/null; then

        # Instalar playerctl
        exec_cmd pacman -S playerctl --noconfirm
        exec_cmd systemctl --user enable --now mpd.service
        exec_cmd systemctl is-enabled --quiet mpd.service

    elif hash apt 2>/dev/null; then

        # Instalar playerctl en Debian
        exec_cmd apt-get install playerctl -y
        curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg &>/dev/null

        # Agregar repositorio de Spotify
        echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list &>/dev/null
        exec_cmd systemctl enable --now snapd 2>/dev/null

        exec_cmd snap install spotify 2>/dev/null
        sudo systemctl enable --now snapd
        exec_cmd apt-get update
    else
        print_msg "\n${redColour}${rev}The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
    fi
}

# Función para limpiar y finalizar la instalación de BSPWM
function clean_bspwm() {

    # Mensaje de limpieza
    print_msg "${greenColour}${rev} Cleaning everything, have patience. ${endColour}"
    # Corregir permisos de función de bspc para sudo su
    chown root:root /usr/local/share/zsh/site-functions/_bspc 2>/dev/null 

    if hash pacman 2>/dev/null; then

        # Instala paquetes adicionales desde AUR con yay
        exec_cmd sudo -u "${REAL_USER}" yay -S  rofi-greenclip neofetch spotify --noconfirm
        rm -f /etc/sudoers.d/axel-aur

        # Limpiar caché de pacman
        exec_cmd pacman -Scc --noconfirm

        # Eliminar dependencias huérfanas
        orphans=$(pacman -Qdtq 2>/dev/null) 
        [[ -n "$orphans" ]] && exec_cmd pacman -Rns $orphans --noconfirm 

        # Mensaje de habilitación de servicios
        print_msg "${greenColour}${rev} Enabling services. ${endColour}"

        # Configurar teclado
        exec_cmd localectl set-x11-keymap es 

        # Habilitar servicios necesarios
        exec_cmd systemctl enable vmtoolsd 2>/dev/null
        exec_cmd systemctl enable gdm.service 2>/dev/null 
        # exec_cmd systemctl start gdm.service 2>/dev/null # NO INICIAR GDM AQUÍ - se iniciará automáticamente al reiniciar

    elif hash apt 2>/dev/null; then

        # Reconfigurar paquetes rotos
        exec_cmd dpkg --configure -a 

        # Corregir dependencias
        exec_cmd apt-get install "${APT_FLAGS[@]}" --fix-broken --fix-missing 

        # Reinstalar paquetes base de Parrot
        exec_cmd apt-get install --reinstall "${APT_FLAGS[@]}" parrot-apps-basics 

        # Marcar paquetes como manuales
        exec_cmd apt-mark manual parrot-apps-basics neovim bspwm sxhkd picom kitty polybar &>/dev/null # sirve para que `autoremove` no los borre.
        
        # evitar que se actualicen/cambien de versión.
        exec_cmd apt-mark unhold bspwm sxhkd picom polybar &>/dev/null  

        # Limpiar caché
        exec_cmd apt-get clean
        print_msg "\n${yellowColour}${rev}[!] To update your system later!${endColour}"
    else
        print_msg "\n${redColour}${rev}[x] The system is neither Debian, Ubuntu, nor Arch Linux. ${endColour}"
    fi
    
    # Actualizar base de datos de locate
    print_msg "\n\t${cianColour}${rev}[!] Updating the locate database please have patience. ${endColour}" 
}

# Función para cerrar sesión y reiniciar el sistema
function shutdown_session(){
    print_msg "\n\t${cianColour}${rev}[!] We are closing the session to apply the new configuration, be sure to select the BSPWM. ${endColour}" 
    
    if hash pacman 2>/dev/null; then
        exec_cmd systemctl enable --now cronie.service 2>/dev/null 
    fi
    
    # Debian/ArchLinux - usar crontab
    echo "@reboot /bin/sh -c ': > /tmp/target; : > /tmp/name'" | sudo -u "${REAL_USER}" crontab -
    
    # Esperar antes de reiniciar
    sleep 5
    
    stop_spinner
    
    # Eliminar directorio de instalación si existe
    [[ -d "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR}" 2>/dev/null
    # Reiniciar sistema
    exec_cmd systemctl reboot
}

# Inicializar contador de parámetros
declare -i parameter_counter=0
Mode=""
spotify=false

OPTERR=0
while getopts "d:smh" arg; do
    case "$arg" in
        d) Mode="${OPTARG}"; let parameter_counter+=1 ;;
        s) spotify=true ;;
        m) MUTE_MODE=true ;;
        h) print_msg "${redColour}${rev}Menu de ayuda. ${endColour}"; helpPanel ;; 
        *) print_msg "${redColour}${rev}Opción invalida. ${endColour}"; helpPanel ;;
    esac
done

tput civis

shift $((OPTIND - 1))

# Verificar que el modo fue definido
if [[ -z "${Mode:-}" ]]; then 
    print_msg "${redColour}${rev}[x] Faltan opciones obligatorias. ${endColour}"
    helpPanel
fi 

# Validar modo permitido
if [[ "$Mode" != "debian" && "$Mode" != "archlinux" ]]; then
    print_msg "${redColour}[!] Invalid mode: $Mode${endColour}"
    helpPanel
fi

# Verificar que existan parámetros
if [[ $parameter_counter -eq 0 ]]; then
    helpPanel
fi

# Ejecutar según el modo seleccionado

# Ejecución para Debian
if [[ "$Mode" == "debian" ]]; then
    check_sudo
    check_disk_space
    check_os
    bspwm_enviroment 

    # Instalar Spotify si se solicitó
    if [[ "$spotify" == true ]]; then
        spotify_env
    fi

    clean_bspwm
    shutdown_session

# Ejecución para Arch Linux
elif [[ "$Mode" == "archlinux" ]]; then
    check_sudo
    check_disk_space
    check_os
    bspwm_enviroment 

    # Instalar Spotify si se solicitó
    if [[ "$spotify" == true ]]; then
        spotify_env
    fi
    
    clean_bspwm
    shutdown_session

# Caso inválido
else
    print_msg "${redColour}[x] Invalid mode. ${endColour}"
    helpPanel
fi

tput cnorm
exit 0 
