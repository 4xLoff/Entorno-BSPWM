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
# Si MUTE_MODE es true, redirige todo a /dev/null
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

# Muestra el panel de ayuda con las opciones disponibles
helpPanel() {
    print_msg "\n${greenColour}${rev}[!] Uso: sudo bash $0 -d {Mode} [-c] [-r] [-l] [-s] [-m]${endColour}\n"
    print_msg "\t${blueColour}${rev}[-d] Mode of installation.${endColour}"
    print_msg "\t\t${magentaColour}${grisBg}${bold}debian${endColour}\t\t\t${yellowColour}${rev}Distribution Debian nesesary =< 60 gb.${endColour}"
    print_msg "\t\t${cianColour}${grisBg}${bold}archlinux${endColour}\t\t${yellowColour}${rev}Distribution Archlinux nesesary =< 60 gb.${endColour}"
    print_msg "\t${blueColour}${rev}Opcionales:${endColour}"
    print_msg "\t\t${magentaColour}${rev}[-c]${endColour}\t\t\t${greenColour}${rev}Core package Hacking (Only for more than 90 gb)${endColour}"
    print_msg "\t\t${cianColour}${rev}[-r]${endColour}\t\t\t${greenColour}${rev}Repositories GitHub (Only for more than 90 gb)${endColour}"
    print_msg "\t\t${magentaColour}${rev}[-l]${endColour}\t\t\t${greenColour}${rev}LaTeX environment (Only for more than 90 gb)${endColour}"
    print_msg "\t\t${cianColour}${rev}[-s]${endColour}\t\t\t${greenColour}${rev}Spotify (Only for more than 16 gb RAM)${endColour}"
    print_msg "\t\t${magentaColour}${rev}[-m]${endColour}\t\t\t${greenColour}${rev}Mode silence (mute)${endColour}"
    print_msg "\t${redColour}${rev}[-h] Show this help panel.${endColour}"
    print_msg "\n${greenColour}${rev}Example:${endColour}"
    print_msg "\t${greenColour}${bold}sudo bash $0 -d debian -c -r -l -s -m${endColour}"
    tput cnorm; exit 1
}

# Verifica que el script se ejecute con sudo pero no como root directo
check_sudo() {
    local CURRENT_UID=$(id -u)
    local PARENT_PROCESS=$(ps -o comm= -p $PPID 2>/dev/null)

    # Debe ser root (UID 0), proceso padre debe ser sudo, y usuario real no debe ser root
    if [ "${CURRENT_UID}" -eq 0 ] && \
       [ "${PARENT_PROCESS}" = "sudo" ] && \
       [ "${REAL_USER}" != "root" ]; then
        print_msg "\n${greenColour}${grisBg}${bold}[*] Allowed: ${endColour}${greenColour}${rev}[*] Execution in progress${endColour}"
    else
        print_msg "\n${redColour}${grisBg}${bold}[x] Blocked: ${endColour}${redColour}${rev}[x] Unauthorized execution${endColour}"
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
        print_msg "\n${redColour}${rev}[x] Exiting...${endColour}"

        # Limpia el directorio de instalación antes d.e salir
        [[ -d "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR}"
        set +e
        tput cnorm
        exit 1
    fi
    print_msg "\n${redColour}${grisBg}${bold}[!] Press CTRL+C twice in a row to exit${endColour}"
    last=$now
    return 0
}

# Captura la señal SIGINT (CTRL+C)
trap ctrl_c SIGINT

# Detecta el sistema operativo e instala paquetes según la distribución
function check_os() {

    # Crea el directorio de instalación como el usuario real
    sudo -u "${REAL_USER}" mkdir -p "${INSTALL_DIR}"
    sudo -u "${REAL_USER}" touch /tmp/name 
    sudo -u "${REAL_USER}" touch /tmp/target

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
            print_msg "\n${magentaColour}${rev}[!] The directory was moved successfully.${endColour}"
        done
    fi

    # Instalación para sistemas basados en Debian
    if hash apt 2>/dev/null; then
        print_msg "\n${greenColour}${grisBg}${bold}[*] The system is Debian.${endColour}\n"
        print_msg "\n${yellowColour}${rev}[!] Installing only the bspwm environment for Debian.${endColour}\n"

        # Remueve versiones conflictivas de codium y neovim
        exec_cmd apt-get remove --purge codium -y
        exec_cmd apt-get remove --purge neovim -y
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
        cmake-data pkg-config python-sphinx python3-sphinx 
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
        fontconfig bd bc seclists locate neofetch)

        # Instala cada paquete y muestra si tuvo éxito o falló
        for package in "${packages_bspwm_debian[@]}"; do
            if exec_cmd apt-get install "${APT_FLAGS[@]}" "${package}"; then
                print_msg "${greenColour}${rev}[*] Package => ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}installed. ${endColour}"
            else
                print_msg "${yellowColour}${rev}[!] Package => ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev}failed. ${endColour}"
            fi
        done  

        print_msg "${greenColour}${rev}[*] Install bspwm and sxhkd.${endColour}"
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

        print_msg "${greenColour}${rev}[*] Polybar compilation.${endColour}"
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
        print_msg "\n${blueColour}${grisBg}${bold}[*] The system is Arch Linux.${endColour}\n"
        print_msg "\n${yellowColour}${rev}[!] Installing only the bspwm environment for Arch Linux.${endColour}\n"

        # Array de paquetes necesarios para BSPWM en Arch
        packages_bspwm_arch=(
        base-devel curl wget cmake dpkg net-tools rsync
        plocate gnome meson ninja bspwm sxhkd polybar
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
        xsettingsd gvfs-mtp simple-mtpfs
        mpd mpc ncmpcpp mpv htop eza p7zip bc bd)

        # Instala paquetes con pacman
        for package in "${packages_bspwm_arch[@]}"; do
            if exec_cmd pacman -S "${package}" --noconfirm --needed ; then
                print_msg "${greenColour}${rev}[*] Package => ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}installed. ${endColour}"
            else
                print_msg "${yellowColour}${rev}[!] Package => ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev}failed. ${endColour}"
            fi
        done

        # Clona y compila bspwm y sxhkd desde source
        print_msg "${greenColour}${rev}[*] Install bspwm and sxhkd.${endColour}"
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
        print_msg "${greenColour}${rev}[*] Creating swap and compiling Polybar for Arch Linux.${endColour}"
        sleep 5
        exec_cmd fallocate -l 2G /swapfile           # Crea un archivo de 2GB para usar como memoria virtual
        exec_cmd chmod 600 /swapfile                 # Le da permisos solo al root
        exec_cmd mkswap /swapfile                    # Formatea el archivo como área de swap
        exec_cmd swapon /swapfile                    # Activa el swap (lo usa el sistema)
        
        print_msg "${redColour}${grisBg}${bold}[*] If the polybar doesn't compile, compile it separately and reload it with Alt + r.${endColour}"
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
        print_msg "\n${redColour}${rev}[x] The system is neither Debian, Ubuntu, nor Arch Linux.${endColour}"
        helpPanel
    fi
}

# Configura el entorno BSPWM con temas, fuentes y aplicaciones
function bspwm_enviroment() {

    # Instala foo-Wallpaper para wallpapers animados
    print_msg "${greenColour}${rev}[*] Install Foo Wallpaper.${endColour}"
    exec_cmd curl -L https://raw.githubusercontent.com/thomas10-10/foo-Wallpaper-Feh-Gif/master/install.sh | bash
     
    # Descarga tema blue-sky
    print_msg "${greenColour}${rev}[*] Configure polybar fonts.${endColour}"
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
    print_msg "${greenColour}${rev}[*] Install Hack Nerd Fonts.${endColour}"
    cd "${INSTALL_DIR}" || exit 
    exec_cmd wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip
    mkdir -p /usr/local/share/fonts/
    exec_cmd unzip Hack.zip && sudo mv *.ttf /usr/local/share/fonts/
    rm -f Hack.zip LICENSE.md README.md 2>/dev/null 
    pushd /usr/local/share/fonts/ >/dev/null 2>&1
    exec_cmd fc-cache -v
    popd &>/dev/null

    # Clona y compila picom (compositor)
    print_msg "${greenColour}${rev}[*] Picom compilation.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/ibhagwan/picom.git
    cd picom/
    rm -rf build
    exec_cmd git submodule update --init --recursive
    exec_cmd meson --buildtype=release . build
    exec_cmd ninja -C build
    exec_cmd ninja -C build install 

    # Instala powerlevel10k para el usuario y para root
    print_msg "${greenColour}${rev}[*] Download powerlevel10k.${endColour}"
    exec_cmd sudo -u "${REAL_USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${USER_HOME}/powerlevel10k"
    exec_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k

    # Copia wallpapers al directorio Pictures del usuario
    print_msg "${greenColour}${rev}[*] Configuration wallpaper.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/Pictures"
    cp "${INSTALL_DIR}"/Entorno-BSPWM/*.png "${USER_HOME}/Pictures" 
    cp "${INSTALL_DIR}"/Entorno-BSPWM/*.gif "${USER_HOME}/Pictures"

    # Instala plugin sudo para zsh
    print_msg "${greenColour}${rev}[*] Install plugin sudo.${endColour}"
    mkdir /usr/share/zsh-sudo
    exec_cmd wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh
    cp sudo.plugin.zsh /usr/share/zsh-sudo/ 

    # Instala bat (cat mejorado)
    print_msg "${greenColour}${rev}[*] Install batcat.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd wget -q https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
    exec_cmd dpkg -i bat-musl_0.24.0_amd64.deb

    # Instala lsd (ls mejorado)
    print_msg "${greenColour}${rev}[*] Install lsd.${endColour}"
    cd "${INSTALL_DIR}" || exit 1 
    exec_cmd wget -q https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd-musl_1.0.0_amd64.deb
    exec_cmd dpkg -i lsd-musl_1.0.0_amd64.deb

    # Instala fzf (fuzzy finder) para el usuario y para root
    print_msg "${greenColour}${rev}[*] Install fzf.${endColour}"
    exec_cmd sudo -u "${REAL_USER}" git clone --depth 1 https://github.com/junegunn/fzf.git "${USER_HOME}/.fzf"
    exec_cmd sudo -u "${REAL_USER}" "${USER_HOME}/.fzf/install" --all
    exec_cmd git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    exec_cmd ~/.fzf/install --all

    # Descarga e instala neovim
    print_msg "${greenColour}${rev}[*] Install nvchad.${endColour}" 
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
    print_msg "${greenColour}${rev}[*] Install themes polybar.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd git clone https://github.com/adi1090x/polybar-themes.git
    cd polybar-themes

    # Copia configuraciones del tema polybar
    print_msg "${greenColour}${rev}[*] Move files configuration.${endColour}"
    exec_cmd sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/polybar/" "${USER_HOME}/.config/polybar/"

    # Copia configuraciones de bspwm, sxhkd, picom, kitty, rofi
    exec_cmd sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/bspwm/" "${USER_HOME}/.config/"
    exec_cmd sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/sxhkd/" "${USER_HOME}/.config/"
    exec_cmd sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/picom/" "${USER_HOME}/.config/"
    exec_cmd sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/kitty/" "${USER_HOME}/.config/"
    exec_cmd sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/rofi/" "${USER_HOME}/.config/"
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


    # Bucle para preguntar si se instala el entorno BSPWM de s4vitar
    while true; do
        # Leer respuesta del usuario
        read -rp "$(printf "%b" "${orangeColour}[*] Install s4vitar's BSPWM environment? ${endColour}${greenColour}${grisBg}${bold}(y|yes|yey)${endColour} or ${greenColour}${grisBg}${bold}(n|no|nay)${endColour} ")" entorno 

        case "${entorno,,}" in 

            # Opción sí
            y|yes|yey)
                # Mensaje de instalación
                print_msg "${greenColour}${rev}[*] Installing s4vitar's themes.${endColour}"
                # Cambiar script de lanzamiento de polybar en bspwm
                exec_cmd sudo -u "${REAL_USER}" sed -i 's|~/.config/polybar/launch\.sh --forest|~/.config/polybar/launch4.sh|g' "${USER_HOME}/.config/bspwm/bspwmrc"
                break
                ;;

            # Opción no o enter
            ""|n|no|nay)

                # Copiar configuración de polybar forest
                exec_cmd sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/config.ini.spotyfy" "${USER_HOME}/.config/polybar/config.ini"

                break
                ;;

              # Opción inválida
            *)
                print_msg "\n${redColour}${rev}[x] That option is invalid. Please enter a valid option.${endColour}\n" 
                continue
                ;;
        esac
    done

    # Permisos de ejecución para launcher
    chmod +x "${USER_HOME}/.config/polybar/launch.sh"
    chmod +x "${USER_HOME}/.config/polybar/launch1.sh"
    chmod +x "${USER_HOME}/.config/polybar/launch4.sh"
    chmod +x "${USER_HOME}/.config/polybar/forest/scripts/launcher.sh"
    chmod +x "${USER_HOME}/.config/polybar/forest/scripts/powermenu.sh"
    
    # Permisos para ethernet_status, vpn_status, target_to_hack
    chmod +x "${USER_HOME}/.config/polybar/emili/scripts/ethernet_status"
    chmod +x "${USER_HOME}/.config/polybar/emili/scripts/vpn_status"
    chmod +x "${USER_HOME}/.config/polybar/emili/scripts/target_to_hack"

    # Crear archivos temporales usados por polybar
    chown "${REAL_USER}:${REAL_USER}" "/tmp/name"
    chown "${REAL_USER}:${REAL_USER}" "/tmp/target"

    # Asignar propietario correcto al archivo
    chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.zshrc"

    # Enlace simbólico del .zshrc del usuario a root
    ln -s -f "${USER_HOME}/.zshrc" "/root/.zshrc"

    # Cambiar shell por defecto a zsh
    usermod --shell /usr/bin/zsh "$REAL_USER"
    usermod --shell /usr/bin/zsh root

    # Ajustar propietarios de directorios de root
    chown "${REAL_USER}:${REAL_USER}" "/root"     # Esto no cambia la propiedad de root pero si permite sudo su conserve el entorno
    chown "${REAL_USER}:${REAL_USER}" "/root/.cache" -R
    chown "${REAL_USER}:${REAL_USER}" "/root/.local" -R

    # Instalación de Visual Studio Code
    print_msg "${greenColour}${rev}[*] Install Visual Studio Code.${endColour}"
    exec_cmd curl -s "https://vscode.download.prss.microsoft.com/dbazure/download/stable/d78a74bcdfad14d5d3b1b782f87255d802b57511/code_1.94.0-1727878498_amd64.deb" -o code_1.94.0-1727878498_amd64.deb
    exec_cmd dpkg -i --force-confnew code_1.94.0-1727878498_amd64.deb
}


function update_debian() {
    print_msg "${greenColour}${rev}[*] Installing additional packages for the correct functioning of the environment Hacking.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd apt-get remove --purge python3-unicodecsv -y
    exec_cmd apt-get remove --purge burpsuite -y

    # Verificar si es Kali Linux y configurar wine
    if [[ -f /etc/os-release && $(grep -q "kali" /etc/os-release; echo $?) -eq 0 ]]; then
        print_msg "${blueColour}${rev}[*] Configuring wine for Kali Linux.${endColour}"
        exec_cmd dpkg --add-architecture i386
    fi 

    # PAQUETES DE HACKING, PENTESTING, DESARROLLO Y UTILIDADES
    packages_tools_debian=(
    # Librerías de desarrollo
    libbsd-dev libbz2-dev libconfig-dev libxcursor-dev
    libdb5.3-dev libdbus-1-dev libemail-outlook-message-perl
    libev-dev libevdev-dev libffi-dev libfontconfig1-dev
    libgdbm-dev libglib2.0-dev libharfbuzz-dev
    liblcms2-2 libldap2-dev liblzma-dev libmemcached-tools
    libncurses5-dev libncursesw5-dev libnetfilter-queue-dev
    libpcap-dev libpcre2-dev libpcre3-dev libpng16-16
    libpopt-dev libprotobuf-dev libproxychains4 libpst-dev
    libpython3-dev libqt5sensors5 libqt5webkit5
    libreadline-dev librsync-dev libsasl2-dev libsmbclient
    libsqlite3-dev libssl-dev libxxhash-dev uthash-dev
    protobuf-compiler zlib1g-dev

    # Librerías adicionales
    libnl-3-dev libnl-genl-3-dev libxml2-dev libxslt1-dev 
    libjpeg62-turbo-dev libaio1

    # Utilidades básicas
    acl adb antiword apktool aptitude apt-transport-https
    autoconf awscli binwalk

    # Herramientas de sistema
    alien axel dtrx git-cola

    # Build tools
    build-essential gcc gcc-multilib pkg-config
    dh-autoreconf 

    # Navegadores/visualizadores texto
    pandoc lynx 

    # Hacking - Reconocimiento
    bloodhound nmap amass gospider sublist3r dnsrecon
    snmp snmp-mibs-downloader whatweb masscan

    # Hacking - Explotación
    bruteforce-luks crackmapexec exploitdb
    impacket-scripts python3-impacket netexec
    powershell-empire powersploit veil

    # Hacking - Passwords
    hash-identifier sucrack

    # Hacking - Web
    cadaver cewl cutycapt davtest ffuf gobuster
    hurl skipfish phpggc wfuzz weevely eaphammer
    zaproxy

    # Hacking - Windows/AD
    enum4linux enum4linux-ng gss-ntlmssp
    krb5-user smbmap

    # Hacking - Cloud
    cloud-enum pacu

    # Bases de datos
    crunch default-mysql-client derby-tools
    mdbtools odat pgcli squidclient tnscmd10g

    # Reversing y Forense
    binwalk dex2jar exiftool extundelete hexedit
    jadx jd-gui pdfid pdf-parser pst-utils radare2
    steghide

    # Redes - Análisis
    tshark tcpdump

    # Email
    antiword claws-mail evolution libemail-outlook-message-perl
    mutt sendemail sendmail swaks

    # Documentos y Office
    djvulibre-bin evince libreoffice tesseract-ocr xpdf

    # Criptografía
    encfs gpp-decrypt kpcli

    # Contenedores y virtualización
    docker.io glusterfs-server lxc snap snapd

    # Desarrollo - Lenguajes
    cargo maven mingw-w64-tools mono-devel
    nodejs npm php-curl python3-ldap 
    python3-ldapdomaindump rails ruby ruby-dev

    # Redes y conectividad
    cifs-utils freerdp2-dev freerdp2-x11 fuse
    inetutils-ftp irssi kcat knockd lftp
    ncat pidgin putty-tools rdesktop redis-tools
    samba tigervnc-viewer xtightvncviewer

    # Pentesting tools específicos
    padbuster peass powercat shellter
    sprayingtoolkit

    # Utilidades varias
    flite gimp hexchat imagemagick locate neo4j 
    qrencode recordmydesktop rlwrap 
    software-properties-common translate-shell 
    wayland-protocols wkhtmltopdf wmis zbar-tools dex

    # Python
    python3 python3-dev python3-pip python3-venv
    python3-qtpy ipython3 pipx

    # Contenedores
    docker docker-compose lxc

    # Navegadores
    chromium firefox

    # Filesystems
    ntfs-3g

    # Otros
    bc dc keepassxc html2text seclists
    locate libreoffice xpdf jq)

    for package in "${packages_tools_debian[@]}"; do
        if exec_cmd apt-get install "${APT_FLAGS[@]}" "${package}"; then
            printf "%b\n" "${greenColour}${rev}[*] The package => ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly. ${endColour}"
        else
            printf "%b\n" "${yellowColour}${rev}[*] The package => ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install. ${endColour}"
        fi
    done

}

function update_arch(){
    print_msg "%b\n" "${greenColour}[*] Additional packages will be installed for the correct functioning of the environment Hacking.${endColour}"
    cd "${INSTALL_DIR}" || exit

        # Instala paru (AUR helper)
        print_msg "${greenColour}${rev}[*] Install paru.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/paru-bin.git
        cd "${INSTALL_DIR}/paru-bin"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm
        
        print_msg "${greenColour}${rev}[*] Install Tools paru${endColour}"
        paru -S --skipreview tdrop-git xqp rofi-greenclip xwinwrap-0.9-bin ttf-maple i3lock-color simple-mtpfs eww-git --noconfirm

        # Instala blackarch repositories
        print_msg "${greenColour}${rev}[*] Install blackarch.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" curl -O https://blackarch.org/strap.sh
        chmod +x strap.sh
        exec_cmd ./strap.sh

        # Instala yay (otro AUR helper)
        print_msg "${greenColour}${rev}[*] Install aur.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/yay.git
        cd "${INSTALL_DIR}/yay"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm

        # Instala paquetes adicionales desde AUR con yay
        exec_cmd sudo -u "${REAL_USER}" -- yay -S eww-git xqp tdrop-git rofi-greenclip neofetch xwinwrap-0.9-bin simple-mtpfs --noconfirm
        exec_cmd pacman -Syu --overwrite '*' --noconfirm

         # Instala snap repositories
        print_msg "${greenColour}${rev}[*] Install snap.${endColour}"
        cd "${INSTALL_DIR}" || exit 1 
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/snapd.git       
        cd "${INSTALL_DIR}/snapd"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm
        exec_cmd systemctl enable --now snapd.socket
        exec_cmd systemctl restart snapd.service
        print_msg "%b\n"  "${greenColour}${rev}Install Tools snap${endColour}"
        snap install node --classic

        # Listado único de todos los paquetes agrupados
        packages_tools_arch=(
        # Librerías base
        libconfig libev libevdev libffi libglib2 
        liblcms2 libldap libmemcached libpcap 
        libpng16 libpopt libprotobuf libproxychains
        proxychains libpst librsync libsasl2 
        libwebp uthash 

        # Herramientas básicas
        acl adb antiword autoconf pkg-config

        # Gestores de paquetes
        pacman-contrib 

        # Hacking - Reconocimiento
        bloodhound nmap sublist3r dnsrecon 
        gospider whatweb wafw00f

        # Hacking - Explotación
        bruteforce-luks exploitdb impacket 

        # Hacking - Passwords
        hash-identifier sucrack

        # Hacking - Web
        davtest cutycapt feroxbuster hurl 
        skipfish phpggc

        # Hacking - Windows/AD
        enum4linux smbmap crackmapexec

        # Hacking - Cloud/Redes
        ligolo-ng

        # Bases de datos
        crunch mysql-clients sqlite3 mdbtools
        dbeaver

        # Reversing y Forense
        binwalk dex2jar jadx radare2 steghide gdb

        # Email
        antiword claws-mail evolution mutt swaks

        # Documentos
        djvulibre   

        # Criptografía
        krb5 gnupg openssl

        # Desarrollo - Lenguajes
        cargo rustup go nodejs npm ruby maven
        dotnet-sdk 

        # Desarrollo - Herramientas
        gcc-multilib emacs geany

        # Desarrollo - Python
        python-gobject python-ldap

        # Redes y conectividad
        cifs-utils freerdp inetutils irssi 
        openssh rdesktop remmina samba 
        tcpdump tigervnc lftp

        # Pentesting tools específicos
        padbuster peass shellter seclists 
        sprayingtoolkit veil

        # LDAP
        slapd ldap-utils

        # Utilidades varias
        flite imagemagick gimp hexchat 
        pdfid pdf-parser pidgin 
        pngcrush qrencode recordmydesktop 
        rlwrap translate-shell 
        wayland-protocols webp-pixbuf-loader 
        wkhtmltopdf xdg-user-dirs wine

        # Python
        python python-pip python-virtualenv
        python-qtpy ipython python-pipx

        # Contenedores
        docker docker-compose lxc

        # Navegadores
        chromium firefox

        # Filesystems
        ntfs-3g

        # Otros
        bc dc keepassxc html2text seclists
        mlocate libreoffice-fresh xpdf jq)    

        for package in "${packages_tools_arch[@]}"; do
            if exec_cmd pacman -S "${package}" --noconfirm --needed ; then
                print_msg "${greenColour}${rev}[*] The package => ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly. ${endColour}"
            else
                print_msg "${yellowColour}${rev}[*] The package => ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install. ${endColour}"
            fi
        done 
}

function core_package(){
    # Install apps de python
    # No instalar en sistema que esten produccion
    # Eliminar restricción de pip
    print_msg "${greenColour}${rev}[*] Install Python.${endColour}"
    exec_cmd rm -f /usr/lib/python3*/EXTERNALLY-MANAGED 2>/dev/null

    # Actualizar pip y otras (herramientas aisladas)
    exec_cmd python3 -m pip install --upgrade pip pipx pwntools pyparsing

    # Instalación con pipx
    exec_cmd pipx install posting donpapi
    exec_cmd pipx install git+https://github.com/brightio/penelope
    exec_cmd pipx install git+https://github.com/blacklanternsecurity/MANSPIDER 

    # Herramientas de pentesting (NO disponibles en APT o versión muy vieja)
    exec_cmd sudo -H pip3 install -U minikerberos oletools xlrd wesng pwncat-cs git-dumper crawley certipy-ad jsbeautifier
    exec_cmd sudo -H pip3 install -U git+https://github.com/blacklanternsecurity/trevorproxy 
    exec_cmd sudo -H pip3 install -U git+https://github.com/decalage2/ViperMonkey/archive/master.zip
    exec_cmd sudo -H pip3 install -U git+https://github.com/ly4k/ldap3 
    exec_cmd sudo -H pip3 install --upgrade paramiko cryptography pyOpenSSL botocore minikerberos pyparsing cheroot wsgidav \
      ezodf pyreadline3 oathtool pwncat-cs updog pypykatz html2markdown colored oletools droopescan uncompyle6 web3 \
      acefile bs4 pyinstaller flask-unsign pyDes fake_useragent alive_progress githack bopscrk hostapd-mana six \
      crawley certipy-ad chepy minidump aiowinreg msldap winacl pymemcache holehe xlrd wesng jsbeautifier

    #Install gem Packeage
    print_msg "${greenColour}${rev}[*] Install Ruby.${endColour}"
    exec_cmd gem install evil-winrm http httpx docopt rest-client colored2 wpscan winrm-fs stringio logger fileutils winrm brakeman

    # Install GO y Apps
    print_msg "${greenColour}${rev}[*] Install go.${endColour}"
    cd "${INSTALL_DIR}" || exit 1

    exec_cmd wget -q https://go.dev/dl/go1.25.5.linux-amd64.tar.gz
    exec_cmd rm -rf /usr/local/go && tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin

    exec_cmd go install github.com/hakluke/hakrawler@latest
    mv ~/go/bin/hakrawler /usr/local/bin/

    exec_cmd go install github.com/tomnomnom/waybackurls@latest
    mv ~/go/bin/waybackurls /usr/local/bin/

    exec_cmd go install github.com/lc/gau/v2/cmd/gau@latest
    mv ~/go/bin/gau /usr/local/bin/

    exec_cmdgo install github.com/ropnop/kerbrute@latest
    mv ~/go/bin/kerbrute /usr/local/bin/

    exec_cmd go install -v github.com/rverton/webanalyze/cmd/webanalyze@latest
    mv ~/go/bin/webanalyze /usr/local/bin/

    exec_cmd go install github.com/benbusby/namebuster@latest
    mv ~/go/bin/namebuster /usr/local/bin/

    exec_cmd go install github.com/Josue87/gotator@latest
    mv ~/go/bin/gotator /usr/local/bin/ 

    exec_cmd go install github.com/d3mondev/puredns/v2@latest
    mv ~/go/bin/puredns /usr/local/bin/ 

    exec_cmd go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    mv ~/go/bin/grpcurl /usr/local/bin/

    exec_cmd go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest 
    mv ~/go/bin/subfinder /usr/local/bin/ 

    exec_cmd go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest 
    mv ~/go/bin/dnsx /usr/local/bin/

    exec_cmd go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest CGO_ENABLED=1 
    mv ~/go/bin/httpx /usr/local/bin/ 

    exec_cmd go install github.com/projectdiscovery/katana/cmd/katana@latest
    mv ~/go/bin/katana /usr/local/bin/ 

    # Install snap
    print_msg "${greenColour}${rev}[*] Install snap tools.${endColour}"
    exec_cmd snap install ngrok storage-explorer
    exec_cmd snap install snapcraft kubectl --classic

    # Istall npm
    print_msg "${greenColour}${rev}[*] Install npm tools.${endColour}"
    exec_cmd npm install -g safe-backup wscat asar memcached-cli node-serialize slendr electron-packager
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd git clone https://github.com/qtc-de/remote-method-guesser
    cd remote-method-guesser
    exec_cmd mvn package
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd git clone https://github.com/CravateRouge/bloodyAD.git
    cd bloodyAD
    exec_cmd pip3 install . 

    # Istall Docker Compose
    print_msg "${greenColour}[*] Install docker Compose.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    usermod -aG docker ${REAL_USER}
    cd "${INSTALL_DIR}" || exit 1
    sleep 1

    # Esto es nesesario para instalar AvaloniaILSpy.
    print_msg "${greenColour}${rev}[*] Adding Microsoft repository.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    exec_cmd dpkg -i packages-microsoft-prod.deb
    exec_cmd rm packages-microsoft-prod.deb

    # Install AvaloniaILSpy
    print_msg "${yellowColour}[*] Install AvaloniaILSpy.${endColour}"
    mkdir -p "${OPT_DIR}/AvaloniaILSpy"
    cd "${OPT_DIR}/AvaloniaILSpy"
    exec_cmd wget -q https://github.com/icsharpcode/AvaloniaILSpy/releases/download/v7.2-rc/Linux.x64.Release.zip
    exec_cmd mv /home/$REAL_USER/Downloads/Linux.x64.Release.zip .
    exec_cmd unzip Linux.x64.Release.zip
    exec_cmd rm Linux.x64.Release.zip
    exec_cmd unzip ILSpy-linux-x64-Release.zip
    exec_cmd rm ILSpy-linux-x64-Release.zip 
    # /opt/AvaloniaILSpy/artifacts/linux-x64/ILSpy

    # Install RustScan
    print_msg "${greenColour}${rev}[*] Install rustscan.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd curl -sL https://github.com/bee-san/RustScan/releases/download/2.3.0/rustscan_2.3.0_amd64.deb -o rustscan_2.3.0_amd64.deb 
    exec_cmd dpkg -i rustscan_2.3.0_amd64.deb

    # Install Feroxbuster
    print_msg "${greenColour}${rev}[*] Install Feroxbuster.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd curl -sL https://github.com/epi052/feroxbuster/releases/download/v2.11.0/feroxbuster_amd64.deb.zip -o feroxbuster_amd64.deb.zip
    exec_cmd 7z x feroxbuster_amd64.deb.zip
    exec_cmd dpkg -i feroxbuster_2.11.0-1_amd64.deb

    # Install fastTCPscan
    print_msg "${greenColour}${rev}[*] Install fastTCPscan.${endColour}"
    cp "${INSTALL_DIR}/Entorno-BSPWM/fastTCPscan.go" "/opt/fastTCPscan"
    chmod 755 /opt/fastTCPscan
    ln -s -f "/opt/fastTCPscan" "/usr/local/bin/fastTCPscan"

    # Install whichSystem
    print_msg "${greenColour}${rev}[*] Install whichSystem.${endColour}"
    mkdir -p /opt/whichSystem
    cp "${INSTALL_DIR}/Entorno-BSPWM/whichSystem.py" "/opt/whichSystem/whichSystem.py"
    ln -s -f "/opt/whichSystem/whichSystem.py" "/usr/local/bin/"

    # Install Curlie
    print_msg "${greenColour}${rev}[*] Install curlie.${endColour}"
    exec_cmd curl -sS https://webinstall.dev/curlie | bash

    # Install Gef
    print_msg "${greenColour}${rev}[*] Install Gef.${endColour}"
    exec_cmd bash -c "$(curl -fsSL https://gef.blah.cat/sh)"

}

function repositories(){

    # Install incursore
    print_msg "${yellowColour}Install incursore.${endColour}"
    cd "${OPT_DIR}" || exit 1
    exec_cmd git clone https://github.com/wirzka/incursore.git
    ln -s $(pwd)/incursore/incursore.sh /usr/local/bin/incursore
    #incursore.sh -h

    : '
    # Install WhatWaf
    printf "%b\n" "${greenColour}${rev}Install WhatWaf.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/Ekultek/WhatWaf
    cd WhatWaf
    python3 setup.py install
    #whatwaf -h

    # Install bfac
    printf "%b\n" "${yellowColour}Install bfac.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/mazen160/bfac
    cd bfac
    python3 setup.py install
    #bfac -h

    # Install Postman
    printf "%b\n" "${yellowColour}Install Postman.${endColour}"
    cd "${OPT_DIR}" || exit 1
    wget -q --content-disposition https://dl.pstmn.io/download/latest/linux_64
    tar -xzvf ./postman-linux-x64.tar.gz
    cd Postman
    ln -s /opt/Postman/Postman /usr/bin/
    #Postman &>/dev/null & dsown

    # Install git-hound
    printf "%b\n" "${yellowColour}Install git-hound.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/tillson/git-hound
    cd git-hound
    go build .
    go build -ldflags "-s -w" .
    upx --brute git-hound .

    # Install nmapAutomator
    printf "%b\n" "${yellowColour}Install nmapAutomator.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/21y4d/nmapAutomator.git
    ln -s $(pwd)/nmapAutomator/nmapAutomator.sh /usr/local/bin/
    #nmapAutomator.sh -h

    # Install Reconnoitre
    printf "%b\n" "${yellowColour}Install Reconnoitre.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/codingo/Reconnoitre.git
    cd Reconnoitre
    python3 setup.py install
    #reconnoitre --help

    printf "%b\n" "${greenColour}${rev}Install DockerRegistryGrabber.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone git@github.com:Syzik/DockerRegistryGrabber.git  
    cd DockerRegistryGrabber
    python -m pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install bruteforce-luks.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/glv2/bruteforce-luks
    cd bruteforce-luks
    ./autogen.sh
    ./configure
    make
    make check
    make install

    printf "%b\n" "${greenColour}${rev}Install dnsvalidator.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/vortexau/dnsvalidator  
    cd dnsvalidator
    python3 setup.py install

    printf "%b\n" "${greenColour}${rev}Install firepwd.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/lclevy/firepwd
    cd firepwd
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install Forbidden-Buster.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/Sn1r/Forbidden-Buster
    cd Forbidden-Buster
    pip3 install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install forbiddenpass.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/gotr00t0day/forbiddenpass
    cd forbiddenpass
    pip3 install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install bopscrk.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone --recurse-submodules https://github.com/r3nt0n/bopscrk 
    cd bopscrk
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install jwtcat.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/AresS31/jwtcat  
    cd jwtcat
    git clone https://github.com/ticarpi/jwt_too

    printf "%b\n" "${greenColour}${rev}Install nmap-parse-output.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/LorenzoTullini/InfluxDB-Exploit-CVE-2019-20933.git
    cd InfluxDB-Exploit-CVE-2019-20933
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install nmap-parse-output.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/ernw/nmap-parse-output.git
    cd nmap-parse-output
    ./nmap-parse-output

    printf "%b\n" "${greenColour}${rev}Install nullinux.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/m8sec/nullinux 
    cd nullinux
    sudo bash setup.sh

    printf "%b\n" "${greenColour}${rev}Install NoMoreForbidden.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/akinerkisa/NoMoreForbidden 
    cd NoMoreForbidden
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install ctfr.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/UnaPibaGeek/ctfr
    cd ctfr
    pip3 install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install reconftw.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/six2dez/reconftw
    cd reconftw
    ./install.sh
    ./reconftw.sh -d target.com -r

    printf "%b\n" "${greenColour}${rev}Install hcxtools.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/ZerBea/hcxtools
    cd hcxtools
    make -j $(nproc)
    make install

    printf "%b\n" "${greenColour}${rev}Install hcxdumptool.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/ZerBea/hcxdumptool
    cd hcxdumptool
    make -j $(nproc)
    make install

    printf "%b\n" "${greenColour}${rev}Install Gopherus.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/tarunkant/Gopherus
    cd Gopherus
    chmod +x install.sh
    sudo ./install.sh

    printf "%b\n" "${greenColour}${rev}Install remote-method-guesser.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/qtc-de/remote-method-guesser
    cd remote-method-guesser
    mvn package

    printf "%b\n" "${greenColour}${rev}Install uDork.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/m3n0sd0n4ld/uDork
    cd uDork
    chmod +x uDork.sh

    printf "%b\n" "${greenColour}${rev}Install Veil.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/Veil-Framework/Veil
    cd Veil/
    ./config/setup.sh --force --silent

    printf "%b\n" "${greenColour}${rev}Install trufflesecurity.${endColour}"
    cd "${OPT_DIR}"
    git clone https://github.com/trufflesecurity/trufflehog.git
    cd trufflehog; go install

    printf "%b\n" "${greenColour}${rev}Install targetedKerberoast.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/ShutdownRepo/targetedKerberoast
    cd targetedKerberoast
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install sucrack.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/hemp3l/sucrack
    cd sucrack
    ./configure
    make
    make install

    printf "%b\n" "${greenColour}${rev}Install spose.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/aancw/spose
    cd spose
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install SirepRAT.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/SafeBreach-Labs/SirepRAT.git
    cd SirepRAT
    pip install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install sippts.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/Pepelux/sippts.git
    cd sippts
    pip3 install .

    printf "%b\n" "${greenColour}${rev}Install WPSeku.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/m4ll0k/WPSeku.git wpseku
    cd wpseku
    pip3 install -r requirements.txt
    python3 wpseku.py

    printf "%b\n" "${greenColour}${rev}Install wifi_db.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/r4ulcl/wifi_db
    cd wifi_db
    pip3 install -r requirements.txt 

    printf "%b\n" "${greenColour}${rev}Install wifiphisher.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/wifiphisher/wifiphisher.git # Download the latest revision
    cd wifiphisher 
    python setup.py install # Install any dependencies

    printf "%b\n" "${greenColour}${rev}Install wifite2.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/derv82/wifite2.git
    cd wifite2
    python setup.py install 

    printf "%b\n" "${greenColour}${rev}Install windapsearch.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/ropnop/windapsearch.git
    cd windapsearch
    ./windapsearch.py

    printf "%b\n" "${greenColour}${rev}Install RubeusToCcache.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/SolomonSklash/RubeusToCcache
    cd RubeusToCcache
    pip3 install -r requirements.txt

    printf "%b\n" "${greenColour}${rev}Install WebAssembly.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone --recursive https://github.com/WebAssembly/wabt
    cd wabt
    git submodule update --init  
    mkdir build
    cd build
    cmake ..
    cmake --build .

    printf "%b\n" "${greenColour}${rev}Install + Tools.${endColour}"
    cd "${OPT_DIR}" || exit 1
    # Download Repositories in local
    git clone https://github.com/ropnop/kerbrute /opt/kerbrute
    git clone https://github.com/nicocha30/ligolo-ng.git /opt/ligolo-ng
    git clone https://github.com/epinna/tplmap /opt/tplmap
    git clone https://github.com/HarmJ0y/pylnker /opt/pylnker
    git clone https://github.com/3mrgnc3/BigheadWebSvr /opt/BigheadWebSvr
    git clone https://github.com/IOActive/jdwp-shellifier /opt/jdwp-shellifier
    git clone https://github.com/danielbohannon/Invoke-Obfuscation /opt/Invoke-Obfuscation
    git clone https://github.com/manulqwerty/Evil-WinRAR-Gen /opt/Evil-WinRAR-Gen
    git clone https://github.com/ptoomey3/evilarc /opt/evilarc
    git clone https://github.com/NotSoSecure/docker_fetch /opt/docker_fetch
    git clone https://github.com/cnotin/SplunkWhisperer2 /opt/SplunkWhisperer2
    git clone https://github.com/kozmic/laravel-poc-CVE-2018-15133 /opt/laravel-poc-CVE-2018-15133
    git clone https://github.com/ambionics/phpggc /opt/phpggc
    git clone https://github.com/kozmer/log4j-shell-poc /opt/log4j-shell-poc
    git clone https://github.com/epinna/weevely3 /opt/weevely3
    git clone https://github.com/ohoph/3bowla /opt/3bowla
    git clone https://github.com/v1s1t0r1sh3r3/airgeddon /opt/airgeddon
    git clone https://github.com/anbox/anbox /opt/anbox
    git clone https://github.com/anbox/anbox-modules /opt/anbox-modules
    git clone https://github.com/securecurebt5/BasicAuth-Brute /opt/BasicAuth-Brute
    git clone https://github.com/kimci86/bkcrack /opt/bkcrack
    git clone https://github.com/lobuhi/byp4xx /opt/byp4xx
    git clone https://github.com/theevilbit/ciscot7.git /opt/ciscot7
    git clone https://github.com/pentester-io/commonspeak /opt/commonspeak
    git clone https://github.com/qtc-de/completion-helpers /opt/completion-helpers
    git clone https://github.com/crackpkcs12/crackpkcs12 /opt/crackpkcs12
    git clone https://github.com/jmg/crawley /opt/crawley
    git clone https://github.com/Tib3rius/creddump7 /opt/creddump7
    git clone https://github.com/Mebus/cupp /opt/cupp
    git clone https://github.com/spipm/Depix /opt/Depix
    git clone https://github.com/teambi0s/dfunc-bypasser /opt/dfunc-bypasser
    git clone https://github.com/iagox86/dnscat2 /opt/dnscat2
    git clone https://github.com/lukebaggett/dnscat2-powershell /opt/dnscat2-powershell
    git clone https://github.com/dnSpy/dnSpy /opt/dnSpy
    git clone https://github.com/s0lst1c3/eaphammer /opt/eaphammer
    git clone https://github.com/cddmp/enum4linux-ng /opt/enum4linux-ng
    git clone https://github.com/trickster0/Enyx /opt/Enyx
    git clone https://github.com/shivsahni/FireBaseScanner /opt/FireBaseScanner
    git clone https://github.com/unode/firefox_decrypt /opt/firefox_decrypt
    git clone https://github.com/yonjar/fixgz /opt/fixgz
    git clone https://github.com/carlospolop/fuzzhttpbypass /opt/fuzzhttpbypass
    git clone https://github.com/zackelia/ghidra-dark /opt/ghidra-dark
    git clone https://github.com/git-cola/git-cola /opt/git-cola
    git clone https://github.com/lijiejie/GitHack /opt/GitHack
    git clone https://github.com/micahvandeusen/gMSADumper /opt/gMSADumper
    git clone https://github.com/GitMirar/hMailDatabasePasswordDecrypter /opt/hMailDatabasePasswordDecrypter
    git clone https://github.com/sensepost/hostapd-mana /opt/hostapd-mana
    git clone https://github.com/yasserjanah/HTTPAuthCracker /opt/HTTPAuthCracker
    git clone https://github.com/attackdebris/kerberos_enum_userlists /opt/kerberos_enum_userlists
    git clone https://github.com/chris408/known_hosts-hashcat /opt/known_hosts-hashcat
    git clone https://github.com/dirkjanm/krbrelayx /opt/krbrelayx
    git clone https://github.com/libyal/libesedb /opt/libesedb
    git clone https://github.com/initstring/linkedin2username /opt/linkedin2username
    git clone https://github.com/Plazmaz/LNKUp /opt/LNKUp
    git clone https://github.com/wetw0rk/malicious-wordpress-plugin /opt/malicious-wordpress-plugin
    git clone https://github.com/haseebT/mRemoteNG-Decrypt /opt/mRemoteNG-Decrypt
    git clone https://github.com/NotMedic/NetNTLMtoSilverTicket /opt/NetNTLMtoSilverTicket
    git clone https://github.com/Ridter/noPac.git /opt/noPac
    git clone https://github.com/quentinhardy/odat /opt/odat
    git clone https://github.com/Daniel10Barredo/OSCP_AuxReconTools /opt/OSCP_AuxReconTools
    git clone https://github.com/flozz/p0wny-shell /opt/p0wny-shell
    git clone https://github.com/mpgn/Padding-oracle-attack /opt/Padding-oracle-attack
    git clone https://github.com/AlmondOffSec/PassTheCert /opt/PassTheCert
    git clone https://github.com/topotam/PetitPotam /opt/PetitPotam
    git clone https://github.com/scr34m/php-malware-scanner /opt/php-malware-scanner
    git clone https://github.com/dirkjanm/PKINITtools /opt/PKINITtools
    git clone https://github.com/aniqfakhrul/powerview.py /opt/powerview.py
    git clone https://github.com/byt3bl33d3r/pth-toolkit /opt/pth-toolkit
    git clone https://github.com/utoni/ptunnel-ng /opt/ptunnel-ng
    git clone https://github.com/calebstewart/pwncat /opt/pwncat
    git clone https://github.com/LucifielHack/pyinstxtractor /opt/pyinstxtractor
    git clone https://github.com/3gstudent/pyKerbrute /opt/pyKerbrute
    git clone https://github.com/p0dalirius/pyLAPS /opt/pyLAPS
    git clone https://github.com/JPaulMora/Pyrit /opt/Pyrit
    git clone https://github.com/WithSecureLabs/python-exe-unpacker /opt/python-exe-unpacker
    git clone https://github.com/ShutdownRepo/pywhisker /opt/pywhisker
    git clone https://github.com/cloudflare/quiche /opt/quiche
    git clone https://github.com/n0b0dyCN/RedisModules-ExecuteCommand /opt/RedisModules-ExecuteCommand
    git clone https://github.com/Ridter/redis-rce /opt/redis-rce
    git clone https://github.com/n0b0dyCN/redis-rogue-server /opt/redis-rogue-server
    git clone https://github.com/allyshka/Rogue-MySql-Server /opt/Rogue-MySql-Server
    git clone https://github.com/sensepost/reGeorg /opt/reGeorg
    git clone https://github.com/klsecservices/rpivot /opt/rpivot
    git clone https://github.com/silentsignal/rsa_sign2n /opt/rsa_sign2n
    git clone https://github.com/Flangvik/SharpCollection /opt/SharpCollection
    git clone https://github.com/SECFORCE/SNMP-Brute /opt/SNMP-Brute
    git clone https://github.com/nccgroup/SocksOverRDP /opt/SocksOverRDP
    git clone https://github.com/byt3bl33d3r/SprayingToolkit /opt/SprayingToolkit
    git clone https://github.com/urbanadventurer/username-anarchy.git /opt/username-anarchy
    git clone https://github.com/decalage2/ViperMonkey /opt/ViperMonkey
    git clone https://github.com/mkubecek/vmware-host-modules /opt/vmware-host-modules
    git clone https://github.com/blunderbuss-wctf/wacker /opt/wacker
    git clone https://github.com/Hackndo/WebclientServiceScanner /opt/WebclientServiceScanner
    git clone https://github.com/tennc/webshell /opt/webshell
    git clone https://github.com/bitsadmin/wesng /opt/wesng
    git clone https://github.com/AonCyberLabs/Windows-Exploit-Suggester /opt/Windows-Exploit-Suggester
    git clone https://github.com/mansoorr123/wp-file-manager-CVE-2020-25213 /opt/wp-file-manager-CVE-2020-25213
    git clone https://github.com/artsploit/yaml-payload /opt/yaml-payload
    git clone https://github.com/hoto/jenkins-credentials-decryptor /opt/jenkins-credentials-decryptor
    : '
}


# Instalar Entorno de LaTeX
function latex_env(){
    cd "${INSTALL_DIR}" || exit 1
    exec_cmd wget -q https://github.com/obsidianmd/obsidian-releases/releases/download/v1.10.3/obsidian_1.10.3_amd64.deb
    exec_cmd dpkg -i obsidian_1.10.3_amd64.deb
    print_msg "${greenColour}${rev}[*] The latex environment will be installed, this will take more than 30 minutes approximately.${endColour}"

    if hash pacman 2>/dev/null; then
        exec_cmd pacman -S --needed --noconfirm texlive-most zathura zathura-pdf-poppler
    elif hash apt 2>/dev/null; then
        # Para Kali, Parrot, Ubuntu y otros sistemas basados en Debian
        exec_cmd apt-get install latexmk zathura rubber texlive texlive-latex-extra texlive-fonts-recommended -y --fix-missing # texlive-full
    else
        print_msg "\n${redColour}${rev}[x] The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
    fi
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
    sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/user_modules-copia.ini" "${USER_HOME}/.config/polybar/forest/user_modules.ini"

    # Mensaje de instalación
    print_msg "${greenColour}${rev}[*] Instalando Spotify.${endColour}"

    if hash pacman 2>/dev/null; then

        # Instalar playerctl
        exec_cmd pacman -S playerctl --noconfirm
        exec_cmd snap install spotify
        exec_cmd systemctl --user enable --now mpd.service
        exec_cmd systemctl is-enabled --quiet mpd.service

    elif hash apt 2>/dev/null; then

        # Dar permisos de ejecución a scripts forest
        exec_cmd chmod +x "${USER_HOME}/.config/polybar/forest/scripts/scroll_spotify_status.sh"
        exec_cmd chmod +x "${USER_HOME}/.config/polybar/forest/scripts/get_spotify_status.sh"

        # Instalar playerctl en Debian
        exec_cmd apt-get install playerctl -y
        curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg &>/dev/null

        # Agregar repositorio de Spotify
        echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list &>/dev/null
        exec_cmd apt-get update
        exec_cmd apt-get install spotify-client -y
    else
        print_msg "\n${redColour}${rev}The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
    fi
}

# Función para limpiar y finalizar la instalación de BSPWM
function clean_bspwm() {

    # Mensaje de limpieza
    print_msg "${greenColour}${rev}Limpiando todo, ten paciencia.${endColour}"

    # Corregir permisos de función de bspc para sudo su
    sudo chown root:root /usr/local/share/zsh/site-functions/_bspc 2>/dev/null 

    # Eliminar directorio de instalación si existe
    [[ -d "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR}"

    if hash pacman 2>/dev/null; then

        # Limpiar caché de pacman
        exec_cmd pacman -Scc --noconfirm

        # Actualizar sistema
        exec_cmd pacman -Syu --noconfirm

        # Eliminar dependencias huérfanas
        exec_cmd pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null 

        # Mensaje de habilitación de servicios
        print_msg "${greenColour}${rev}Habilitando demonios.${endColour}"

        # Configurar teclado
        exec_cmd localectl set-x11-keymap es 

        # Habilitar servicios necesarios
        exec_cmd systemctl enable vmtoolsd 2>/dev/null
        exec_cmd systemctl enable gdm.service 2>/dev/null 
        exec_cmd systemctl start gdm.service 2>/dev/null
        exec_cmd systemctl enable --now cronie.service 2>/dev/null 

    elif hash apt 2>/dev/null; then

        # Actualizar repositorios en Debian
        exec_cmd apt update -y 

        # Reconfigurar paquetes rotos
        exec_cmd dpkg --configure -a 

        # Corregir dependencias
        exec_cmd apt-get install "${APT_FLAGS[@]}" --fix-broken --fix-missing 

        # Reinstalar paquetes base de Parrot
        exec_cmd apt-get install --reinstall "${APT_FLAGS[@]}" parrot-apps-basics 

        # Marcar paquetes como manuales
        exec_cmd apt-mark manual parrot-apps-basics neovim bspwm sxhdx picom kitty polybar &>/dev/null # sirve para que `autoremove` no los borre.
        exec_cmd apt-mark unhold bspwm sxhkd picom polybar &>/dev/null   # evitar que se actualicen/cambien de versión.

        # Actualizar sistema completamente
        exec_cmd apt -y --fix-broken --fix-missing full-upgrade
        exec_cmd apt -y full-upgrade

        # Eliminar paquetes innecesarios
        exec_cmd apt autoremove -y

        # Limpiar caché
        exec_cmd apt-get clean
        exec_cmd apt autoclean
    else
        print_msg "\n${redColour}${rev}The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
    fi

    # Actualizar base de datos de locate
    exec_cmd updatedb
}

# Función para cerrar sesión y reiniciar el sistema
function shutdown_session(){
    # Mensaje de aviso
    print_msg "\n\t${cianColour}${rev} We are closing the session to apply the new configuration, be sure to select the BSPWM.${endColour}" 

    sudo -u "${REAL_USER}" echo "@reboot /bin/sh -c ': > /tmp/target; : > /tmp/name'" | crontab -
    # Esperar antes de reiniciar
    sleep 10
    # Reiniciar sistema
    exec_cmd systemctl reboot
}

# Inicializar contador de parámetros
declare -i parameter_counter=0
Mode=""
core_tools=false
repositories=false
latex=false
spotify=false

OPTERR=0
while getopts "d:crlsmh" arg; do
    case "$arg" in
        d) Mode="${OPTARG}"; let parameter_counter+=1 ;;
        c) core_tools=true ;;
        r) repositories=true ;;
        l) latex=true ;;
        s) spotify=true ;;
        m) MUTE_MODE=true ;;
        h) print_msg "${redColour}${rev}Menu de ayuda.${endColour}"; helpPanel ;; 
        *) print_msg "${redColour}${rev}Opción invalida.${endColour}"; helpPanel ;;
    esac
done

tput civis

shift $((OPTIND - 1))

# Verificar que el modo fue definido
if [[ -z "${Mode:-}" ]]; then 
    print_msg "${redColour}${rev}[x] Faltan opciones obligatorias.${endColour}"
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
    check_os
    bspwm_enviroment 

    # Instalar tools si se solicitó
    if [[ "$core_tools" == true ]]; then
        update_debian
        core_package
    fi

    # Instalar Repos si se solicitó
    if [[ "$repositories" == true ]]; then
        repositories
    fi

    # Instalar Latex si se solicitó
    if [[ "$latex" == true ]]; then
        latex_env
    fi

    # Instalar Spotify si se solicitó
    if [[ "$spotify" == true ]]; then
        spotify_env
    fi

    clean_bspwm
    shutdown_session

# Ejecución para Arch Linux
elif [[ "$Mode" == "archlinux" ]]; then
    check_sudo
    check_os
    bspwm_enviroment 

    # Instalar tools si se solicitó
    if [[ "$core_tools" == true ]]; then
        update_debian
        core_package
    fi

    # Instalar Repos si se solicitó
    if [[ "$repositories" == true ]]; then
        repositories
    fi

    # Instalar Latex si se solicitó
    if [[ "$latex" == true ]]; then
        latex_env
    fi

    # Instalar Spotify si se solicitó
    if [[ "$spotify" == true ]]; then
        spotify_env
    fi
    
    clean_bspwm
    shutdown_session

# Caso inválido
else
    print_msg "${redColour}[x] Invalid mode.${endColour}"
    helpPanel
    tput cnorm
    exit 1
fi

tput cnorm
exit 0 
