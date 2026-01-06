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

# Obtiene el usuario real que ejecutó sudo (no root)
REAL_USER="${SUDO_USER:-$(logname)}"

# Obtiene el directorio home del usuario real
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

# Directorio temporal donde se descargará todo
INSTALL_DIR="${USER_HOME}/Install_BSPWM"

# Directorio /opt para instalaciones globales
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
[[ -f /etc/needrestart/needrestart.conf ]] && sed -i 's/^#\$nrconf{restart} =.*/$nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf &>/dev/null
[[ -f /etc/needrestart/needrestart.conf ]] && sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf &>/dev/null
[[ -f /etc/needrestart/needrestart.conf ]] && sed -i "s/#NR_NOTIFYD_DISABLE_NOTIFY_SEND='1'/NR_NOTIFYD_DISABLE_NOTIFY_SEND='1'/" /etc/needrestart/notify.conf &>/dev/null

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
function helpPanel() {
    print_msg "\n${greenColour}${rev}[!] Uso: sudo bash $0 -d {Mode} [-s] [-m]${endColour}"
    print_msg "\t${blueColour}${rev}[-d] Mode of installation.${endColour}"
    print_msg "\t\t${magentaColour}${grisBg}${bold}debian${endColour}\t\t\t${yellowColour}${rev}Distribution Debian nesesary =< 60 gb.${endColour}"
    print_msg "\t\t${cianColour}${grisBg}${bold}archlinux${endColour}\t\t${yellowColour}${rev}Distribution Archlinux nesesary =< 60 gb.${endColour}"
    print_msg "\t${yellowColour}Opcionales:${endColour}"
    print_msg "\t\t${yellowColour}[-s]${endColour}\t\t\t${greenColour}${rev}Spotify (Only for more than 16 gb RAM)${endColour}"
    print_msg "\t\t${yellowColour}[-m]${endColour}\t\t\t${greenColour}${rev}Modo silencioso (mute) - oculta output de instalación${endColour}"
    print_msg "\t${redColour}[-h] Show this help panel.${endColour}"
    print_msg "\n${greenColour}Example:${endColour}"
    print_msg "\t${blueColour}sudo bash $0 -d debian -m${endColour}\t${yellowColour}(Install en modo silencioso)${endColour}"
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
        print_msg "\n${greenColour}${grisBg}${bold}[*] PERMITIDO: ${endColour}${greenColour}${rev}Ejecución en curso${endColour}"
    else
        print_msg "\n${redColour}${grisBg}${bold}[x] BLOQUEADO: ${endColour}${redColour}${rev}Ejecución no permitida${endColour}"
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
        print_msg "\n${redColour}${rev}[!] Exiting...${endColour}"

        # Limpia el directorio de instalación antes de salir
        [[ -d "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR}"
        set +e
        tput cnorm
        exit 1
    fi
    print_msg "\n${redColour}${grisBg}${bold}[x] Presiona CTRL+C dos veces seguidas para salir${endColour}"
    last=$now
    return 0
}

# Captura la señal SIGINT (CTRL+C)
trap ctrl_c SIGINT

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
           print_msg "[+] Movido: $dir → ${INSTALL_DIR}/"
           print_msg "\n${magentaColour}${rev}The directory was moved successfully${endColour}"
        done
    fi
    
    cd "${INSTALL_DIR}" || exit 1
    
    # Verifica que exista /etc/os-release para detectar la distro
    if [[ ! -f /etc/os-release ]]; then 
       print_msg "\n${redColour}${rev}The system is not permitive${endColour}"    
       helpPanel
    fi
    
    # Lee el archivo os-release para obtener el ID de la distro
    source /etc/os-release
    
    case "${ID,,}" in
      # Instalación para sistemas basados en Debian
      kali|parrot|ubuntu|debian)
        print_msg "\n${greenColour}${grisBg}${bold}The system is Debian${endColour}"
        print_msg "\n${greenColour}${rev}Installing only the bspwm environment for Debian${endColour}"
        
        # Remueve versiones conflictivas de codium y neovim
        exec_cmd apt-get remove --purge codium -y
        exec_cmd apt-get remove --purge neovim -y
        exec_cmd apt update -y

        # Array de paquetes necesarios para BSPWM en Debian
        packages_bspwm_debian=(
        curl wget dpkg gnupg gdb cmake net-tools 
        p7zip-full meson ninja-build bspwm
        sxhkd polybar libpcre3-dev 
        build-essential libxcb-util0-dev libxcb-ewmh-dev 
        libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev 
        libxcb-xinerama0-dev libxcb-xtest0-dev libxcb-shape0-dev 
        xcb-proto zsh zsh-syntax-highlighting
        make cmake-data pkg-config
        python3-sphinx python3-xcbgen
        libuv1-dev libcairo2-dev libxcb1-dev
        libxcb-composite0-dev libxcb-cursor0-dev
        libxcb-damage0-dev libxcb-glx0-dev
        libxcb-present0-dev libxcb-render0-dev
        libxcb-render-util0-dev libxcb-xfixes0-dev
        libxcb-xkb-dev libxcb-xrm-dev libxcb-image0-dev 
        libstartup-notification0-dev libxkbcommon-dev 
        libpango1.0-dev libglib2.0-dev libjpeg-dev 
        libcurl4-openssl-dev uthash-dev libev-dev 
        libdbus-1-dev libconfig-dev
        libasound2-dev libpulse-dev libjsoncpp-dev
        libmpdclient-dev libnl-genl-3-dev
        libx11-xcb-dev libxext-dev libxi-dev
        libxinerama-dev libxkbcommon-x11-dev libxrandr-dev
        libgl1-mesa-dev libpixman-1-dev
        kitty rofi suckless-tools feh scrot flameshot
        dunst caja ranger lxappearance
        xdo xdotool wmctrl xclip fontconfig
        bd bc seclists locate)

        # Instala cada paquete y muestra si tuvo éxito o falló
        for package in "${packages_bspwm_debian[@]}"; do
          if exec_cmd apt-get install "${APT_FLAGS[@]}" "${package}"; then
              print_msg "${greenColour}${rev}Package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}installed${endColour}"
          else
              print_msg "${yellowColour}${rev}Package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev}failed${endColour}"
          fi
        done  

        print_msg "${greenColour}${rev}Install bspwm and sxhkd.${endColour}"
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

        print_msg "${greenColour}${rev}Polybar compilation.${endColour}"
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
        ;;
        
      # Instalación para Arch Linux
      arch)
        print_msg "\n${blueColour}${grisBg}${bold}The system is Arch Linux${endColour}"
        print_msg "\n${greenColour}${rev}Installing only the bspwm environment for Arch Linux${endColour}"

        # Array de paquetes necesarios para BSPWM en Arch
        packages_bspwm_arch=(
        base-devel curl wget cmake dpkg net-tools rsync
        plocate gnome meson ninja bspwm sxhkd polybar
        make zlib pcre dbus libconfig libev libxpresent 
        pkgconf uthash
        libxcb xcb-proto xcb-util xcb-util-wm xcb-util-keysyms cronie
        libgl libxcursor libxext libxi libxinerama 
        libxkbcommon-x11 libxrandr mesa python-sphinx
        kitty rofi dmenu jgmenu feh scrot flameshot maim
        dunst caja ranger yazi
        polkit-gnome papirus-icon-theme lxappearance zsh zsh-syntax-highlighting
        xdo xdotool xclip brightnessctl playerctl pamixer redshift
        xorg xorg-server xorg-xinit xorg-xdpyinfo xorg-xkill xorg-xprop xorg-xrandr xorg-xsetroot xorg-xwininfo
        xf86-video-intel xf86-video-vmware open-vm-tools
        xsettingsd gvfs-mtp simple-mtpfs
        mpd mpc ncmpcpp mpv htop eza p7zip bc bd)

        # Instala paquetes con pacman
        for package in "${packages_bspwm_arch[@]}"; do
          if exec_cmd pacman -S "${package}" --noconfirm --needed ; then
              print_msg "${greenColour}${rev}Package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}installed${endColour}"
          else
              print_msg "${yellowColour}${rev}Package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev}failed${endColour}"
          fi
        done     
        
        # Instala paru (AUR helper)
        print_msg "${greenColour}${rev}Install paru.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/paru-bin.git
        cd "${INSTALL_DIR}/paru-bin"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm

        # Instala blackarch repositories
        print_msg "${greenColour}${rev}Install blackarch.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" curl -O https://blackarch.org/strap.sh
        sudo chmod +x strap.sh
        exec_cmd ./strap.sh
        
        # Instala snap repositories
        print_msg "${greenColour}${rev}Install snap.${endColour}"
        cd "${INSTALL_DIR}" || exit 1 
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/snapd.git       
        cd "${INSTALL_DIR}/snapd"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm
        exec_cmd systemctl enable --now snapd.socket
        exec_cmd systemctl restart snapd.service
       
        # Instala yay (otro AUR helper)
        print_msg "${greenColour}${rev}Install aur.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        exec_cmd sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/yay.git
        cd "${INSTALL_DIR}/yay"
        exec_cmd sudo -u "${REAL_USER}" makepkg -si --noconfirm
        
        # Instala paquetes adicionales desde AUR con yay
        exec_cmd sudo -u "${REAL_USER}" -- yay -S eww-git xqp tdrop-git rofi-greenclip xwinwrap-0.9-bin simple-mtpfs --noconfirm
        exec_cmd pacman -Syu --overwrite '*' --noconfirm

        # Clona y compila bspwm y sxhkd desde source
        print_msg "${greenColour}${rev}Install bspwm and sxhkd.${endColour}"
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
        print_msg "${greenColour}${rev}Creating swap and compiling Polybar for Arch Linux.${endColour}"
        sleep 5
        exec_cmd fallocate -l 2G /swapfile
        exec_cmd chmod 600 /swapfile
        exec_cmd mkswap /swapfile
        exec_cmd swapon /swapfile
        
        print_msg "${redColour}${grisBg}${bold}If the polybar doesn't compile, compile it separately and reload it with Alt + r.${endColour}"
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
        ;;
        
      # Si no es Debian ni Arch, sale con error
      *)
        print_msg "\n${redColour}${rev}The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
        helpPanel
        ;;
    esac
}

# Configura el entorno BSPWM con temas, fuentes y aplicaciones
function bspwm_enviroment() {

  # Instala foo-Wallpaper para wallpapers animados
  print_msg "${greenColour}${rev}Install Foo Wallpaper.${endColour}"
  exec_cmd curl -L https://raw.githubusercontent.com/thomas10-10/foo-Wallpaper-Feh-Gif/master/install.sh | bash
   
  # Descarga tema blue-sky
  print_msg "${greenColour}${rev}Configure polybar fonts.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/VaughnValle/blue-sky.git
  cd "${INSTALL_DIR}/blue-sky/polybar/"
  sudo -u "${REAL_USER}" rm -r "${USER_HOME}/.config/polybar/*"

  # Copia fuentes de polybar al sistema
  cd "${INSTALL_DIR}/blue-sky/polybar/fonts"
  mkdir -p /usr/share/fonts/truetype
  cp * /usr/share/fonts/truetype/
  pushd /usr/share/fonts/truetype &>/dev/null 
  exec_cmd fc-cache -v
  popd &>/dev/null 
  
  # Descarga e instala Hack Nerd Fonts
  print_msg "${greenColour}${rev}Install Hack Nerd Fonts.${endColour}"
  cd "${INSTALL_DIR}" || exit 
  exec_cmd wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip
  mkdir -p /usr/local/share/fonts/
  exec_cmd unzip Hack.zip && sudo mv *.ttf /usr/local/share/fonts/
  rm -f Hack.zip LICENSE.md README.md 2>/dev/null 
  pushd /usr/local/share/fonts/
  exec_cmd fc-cache -v
  popd &>/dev/null
  
  # Clona y compila picom (compositor)
  print_msg "${greenColour}${rev}Picom compilation.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/ibhagwan/picom.git
  cd picom/
  rm -rf build
  exec_cmd git submodule update --init --recursive
  exec_cmd meson --buildtype=release . build
  exec_cmd ninja -C build
  exec_cmd ninja -C build install 
  
  # Instala powerlevel10k para el usuario y para root
  print_msg "${greenColour}${rev}Download powerlevel10k.${endColour}"
  exec_cmd sudo -u "${REAL_USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${USER_HOME}/powerlevel10k"
  exec_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k

  # Copia wallpapers al directorio Pictures del usuario
  print_msg "${greenColour}${rev}Configuration wallpaper.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/Pictures"
  cp "${INSTALL_DIR}"/Entorno-BSPWM/*.png "${USER_HOME}/Pictures" 
  cp "${INSTALL_DIR}"/Entorno-BSPWM/*.gif "${USER_HOME}/Pictures"
  
  # Instala plugin sudo para zsh
  print_msg "${greenColour}${rev}Install plugin sudo.${endColour}"
  mkdir /usr/share/zsh-sudo
  exec_cmd wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh
  cp sudo.plugin.zsh /usr/share/zsh-sudo/ 

  # Instala bat (cat mejorado)
  print_msg "${greenColour}${rev}Install batcat.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  exec_cmd wget -q https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
  exec_cmd dpkg -i bat-musl_0.24.0_amd64.deb

  # Instala lsd (ls mejorado)
  print_msg "${greenColour}${rev}Install lsd.${endColour}"
  cd "${INSTALL_DIR}" || exit 1 
  exec_cmd wget -q https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd-musl_1.0.0_amd64.deb
  exec_cmd dpkg -i lsd-musl_1.0.0_amd64.deb

  # Instala fzf (fuzzy finder) para el usuario y para root
  print_msg "${greenColour}${rev}Install fzf.${endColour}"
  exec_cmd sudo -u "${REAL_USER}" git clone --depth 1 https://github.com/junegunn/fzf.git "${USER_HOME}/.fzf"
  exec_cmd sudo -u "${REAL_USER}" "${USER_HOME}/.fzf/install" --all
  exec_cmd git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  exec_cmd ~/.fzf/install --all

  # Descarga e instala neovim
  print_msg "${greenColour}${rev}Install nvchad.${endColour}" 
  cd "${INSTALL_DIR}" || exit 1
  exec_cmd wget -q https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.tar.gz
  exec_cmd tar xzvf nvim-linux-x86_64.tar.gz
  mv nvim-linux-x86_64 /opt/nvim
  ln -s /opt/nvim/bin/nvim /usr/bin/nvim
  rm nvim-linux-x86_64.tar.gz
  
  # Instala NvChad para el usuario
  sudo -u "${REAL_USER}" rm -rf "${USER_HOME}/.config/nvim" 
  exec_cmd sudo -u "${REAL_USER}" git clone https://github.com/NvChad/starter "${USER_HOME}/.config/nvim"
  exec_cmd nvim --headless '+Lazy! sync' +qa
  line="vim.opt.listchars = { tab = '»·', trail = '.' }"
  sed -i "3i ${line}" "${USER_HOME}/.config/nvim/init.lua"
  
  # Instala NvChad para root
  rm -rf /root/.config/nvim
  exec_cmd git clone https://github.com/NvChad/starter /root/.config/nvim
  exec_cmd nvim --headless '+Lazy! sync' +qa
  line="vim.opt.listchars = { tab = '»·', trail = '.' }"
  sed -i "3i ${line}" "/root/.config/nvim/init.lua"
  
  # Descarga temas de polybar
  print_msg "${greenColour}${rev}Install themes polybar.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  exec_cmd git clone https://github.com/adi1090x/polybar-themes.git
  cd polybar-themes

  # Copia configuraciones del tema polybar
  print_msg "${greenColour}${rev}Move files configuration.${endColour}"
  sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/polybar-themes/simple/." "${USER_HOME}/.config/polybar/"
  sudo -u "${REAL_USER}" rm -r "${USER_HOME}/.config/polybar/forest"
  sudo -u "${REAL_USER}" cp -a "${INSTALL_DIR}/Entorno-BSPWM/polybar/." "${USER_HOME}/.config/polybar/"
  sudo -u "${REAL_USER}" rm -r "${USER_HOME}/.config/polybar/launch.sh"
  
  # Copia configuraciones de bspwm, sxhkd, picom, kitty, rofi
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/bspwm/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/sxhkd/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/picom/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/kitty/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/rofi/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.p10k.zsh" "${USER_HOME}/.p10k.zsh"
  
  # Da permisos de ejecución a archivos de configuración
  chmod +x "${USER_HOME}/.config/sxhkd/sxhkdrc"
  chmod +x "${USER_HOME}/.config/bspwm/bspwmrc"
  chmod +x "${USER_HOME}/.config/bspwm/scripts/bspwm_resize"
  chmod +x "${USER_HOME}/.config/picom/picom.conf"
  chmod +x "${USER_HOME}/.config/kitty/kitty.conf"
  
  # Crear enlace simbólico forzado del archivo de configuración de Powerlevel10k para o 
  ln -s -f "${USER_HOME}/.p10k.zsh" "/root/.p10k.zsh"

  # Si el sistema es Arch Linux
  if [[ -f /etc/arch-release ]]; then
    # Copiar .zshrc específico de Arch al usuario real
    sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.zshrc-arch" "${USER_HOME}/.zshrc"
  else
    # Copiar .zshrc para Debian
    sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.zshrc-debian" "${USER_HOME}/.zshrc"
  fi

  # Bucle para preguntar si se instala el entorno BSPWM de s4vitar
  while true; do
    # Leer respuesta del usuario
    read -rp "$(printf "%b" "${orangeColour}¿Instalar entorno BSPWM de s4vitar? ${endColour}${greenColour}${grisBg}${bold}(y|yes|yey)${endColour} or ${greenColour}${grisBg}${bold}(n|no|nay)${endColour} ")" entorno 

    case "${entorno,,}" in 

      # Opción sí
      y|yes|yey)

        # Mensaje de instalación
        print_msg "${greenColour}${rev}Install themes s4vitar.${endColour}"

        # Dar permisos de ejecución a scripts de polybar
        chmod +x "${USER_HOME}/.config/polybar/launch4.sh"
        chmod +x "${USER_HOME}/.config/polybar/scripts/ethernet_status.sh"
        chmod +x "${USER_HOME}/.config/polybar/scripts/htb_status.sh"
        chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.config/polybar/scripts/htb_target.sh"
        chmod +x "${USER_HOME}/.config/polybar/scripts/htb_target.sh"

        # Cambiar script de lanzamiento de polybar en bspwm
        sudo -u "${REAL_USER}" sed -i 's|~/.config/polybar/launch\.sh --forest|~/.config/polybar/launch4.sh|g' "${USER_HOME}/.config/bspwm/bspwmrc"
        # Mensaje final
        print_msg "${greenColour}${rev}All packages installed successfully.${endColour}"
        break
      ;;

      # Opción no o enter
      ""|n|no|nay)

        # Copiar configuración de polybar forest
        sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/config.ini.spotyfy" "${USER_HOME}/.config/polybar/config.ini"

        # Dar permisos de ejecución a scripts forest
        chmod +x "${USER_HOME}/.config/polybar/forest/launch.sh"
        chmod +x "${USER_HOME}/.config/polybar/forest/scripts/scroll_spotify_status.sh"
        chmod +x "${USER_HOME}/.config/polybar/forest/scripts/get_spotify_status.sh"
        chmod +x "${USER_HOME}/.config/polybar/forest/scripts/target.sh"
        chmod +x "${USER_HOME}/.config/polybar/forest/scripts/powermenu.sh"

        # Mensaje final
        print_msg "${greenColour}${rev}All packages installed successfully.${endColour}"
        break
      ;;

      # Opción inválida
      *)
        print_msg "\n${redColour}${rev}That option is invalid. Please enter a valid option.${endColour}\n" 
        continue
      ;;
    esac
  done

  # Permisos de ejecución para launcher
  chmod +x "${USER_HOME}/.config/polybar/forest/scripts/launcher.sh"

  # Crear archivos temporales usados por polybar
  sudo -u "${REAL_USER}" touch /tmp/name /tmp/target
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

  # Actualizar base de datos de locate
  exec_cmd updatedb

  # Instalación de Visual Studio Code
  print_msg "${greenColour}${rev}Install VSC.${endColour}"
  exec_cmd curl -s "https://vscode.download.prss.microsoft.com/dbazure/download/stable/d78a74bcdfad14d5d3b1b782f87255d802b57511/code_1.94.0-1727878498_amd64.deb" -o code_1.94.0-1727878498_amd64.deb
  exec_cmd dpkg -i --force-confnew code_1.94.0-1727878498_amd64.deb
}

# Función para configurar el entorno de Spotify
function spotify_env(){
  cd "${INSTALL_DIR}" || exit 1

  # Clonar zscroll
  exec_cmd git clone https://github.com/noctuid/zscroll
  cd zscroll
  exec_cmd python3 setup.py install

  # Eliminar configuración previa de módulos de usuario
  rm -f "${USER_HOME}/.config/polybar/forest/user_modules.ini"

  # Copiar configuración personalizada de módulos
  sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/user_modules-copia.ini" "${USER_HOME}/.config/polybar/forest/user_modules.ini"

  # Mensaje de instalación
  print_msg "${greenColour}${rev}Instalando Spotify.${endColour}"

  if [[ -f /etc/arch-release ]]; then

    # Instalar playerctl
    exec_cmd pacman -S playerctl --noconfirm
    exec_cmd snap install spotify
    exec_cmd systemctl --user enable --now mpd.service
    exec_cmd systemctl is-enabled --quiet mpd.service
  else

    # Instalar playerctl en Debian
    exec_cmd apt-get install playerctl -y
    exec_cmd curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg

    # Agregar repositorio de Spotify
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    exec_cmd apt-get update
    exec_cmd apt-get install spotify-client -y
  fi
}

# Función para limpiar y finalizar la instalación de BSPWM
function clean_bspwm() {

  # Mensaje de limpieza
  print_msg "${greenColour}${rev}Limpiando todo.${endColour}"

  # Corregir permisos de función de bspc para sudo su
  sudo chown root:root /usr/local/share/zsh/site-functions/_bspc 2>/dev/null 

  # Eliminar directorio de instalación si existe
  [[ -d "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR}"

  if [[ -f /etc/arch-release ]]; then

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
  else

    # Actualizar repositorios en Debian
    exec_cmd apt update -y 

    # Reconfigurar paquetes rotos
    exec_cmd dpkg --configure -a 

    # Corregir dependencias
    exec_cmd apt-get install "${APT_FLAGS[@]}" --fix-broken --fix-missing 

    # Reinstalar paquetes base de Parrot
    exec_cmd apt-get install --reinstall "${APT_FLAGS[@]}" parrot-apps-basics 

    # Marcar paquetes como manuales
    apt-mark manual parrot-apps-basics neovim vim btop figlet 

    # Actualizar sistema completamente
    exec_cmd apt -y --fix-broken --fix-missing full-upgrade
    exec_cmd apt -y full-upgrade

    # Eliminar paquetes innecesarios
    exec_cmd apt autoremove -y

    # Limpiar caché
    exec_cmd apt-get clean
    exec_cmd apt autoclean
  fi
}

# Función para cerrar sesión y reiniciar el sistema
function shutdown_session(){
  # Mensaje de aviso
  print_msg "\n\t${cianColour}${rev} We are closing the session to apply the new configuration, be sure to select the BSPWM.${endColour}" 

  # Crear tarea cron para limpiar archivos temporales al reiniciar
  sudo -u "${REAL_USER}" echo "@reboot /bin/sh -c ': > /tmp/target; : > /tmp/name'" | crontab -

  # Esperar antes de reiniciar
  sleep 10
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

# Ejecución para Debian
if [[ "$Mode" == "debian" ]]; then
  check_sudo
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
  print_msg "${redColour}[!] Invalid mode.${endColour}"
  helpPanel
  tput cnorm
  exit 1
fi

tput cnorm
exit 0 
