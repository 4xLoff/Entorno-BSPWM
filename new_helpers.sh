#!/usr/bin/env bash

# Author: (aka 4xL)

# Estilos de texto
bold=$(tput bold)                      # Negrita
dim=$(tput dim)                        # Atenuado
rev=$(tput rev)                        # Inversión de colores
smul=$(tput smul)                      # Subrayado

# Colores de texto (foreground)
blackColour=$(tput setaf 0)            # Negro
redColour=$(tput setaf 1)              # Rojo brillante
greenColour=$(tput setaf 2)            # Verde brillante
yellowColour=$(tput setaf 3)           # Amarillo
blueColour=$(tput setaf 4)             # Azul
magentaColour=$(tput setaf 5)          # Magenta
cianColour=$(tput setaf 6)             # Cian
whiteColour=$(tput setaf 7)            # Blanco
grisColour=$(tput setaf 8)             # Gris (a veces idéntico al negro, depende del terminal)
lightBlueColour="\e[38;2;173;216;230m"
orangeColour="\e[38;2;255;165;0m"

# Colores de fondo (background)
blackBg=$(tput setab 0)                # Fondo negro
redBg=$(tput setab 1)                  # Fondo rojo
greenBg=$(tput setab 2)                # Fondo verde
yellowBg=$(tput setab 3)               # Fondo amarillo
blueBg=$(tput setab 4)                 # Fondo azul
magentaBg=$(tput setab 5)              # Fondo magenta
cianBg=$(tput setab 6)                 # Fondo cian
whiteBg=$(tput setab 7)                # Fondo blanco
grisBg=$(tput setab 8)                 # Fondo gris (si el terminal lo soporta)

# Resetear formato
endColour=$(tput sgr0)

# Constantes Globales

REAL_USER="${SUDO_USER:-$(logname)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
INSTALL_DIR="${USER_HOME}/Install_BSPWM"
OPT_DIR="/opt"

# Variables Globales

# Evitar notificaciones molestas por pantalla

DEBIAN_FRONTEND="noninteractive"
DEBIAN_PRIORITY="critical"
DEBCONF_NOWARNINGS="yes"
export DEBIAN_FRONTEND DEBIAN_PRIORITY DEBCONF_NOWARNINGS

[[ -f /etc/needrestart/needrestart.conf ]] && sed -i 's/^#\$nrconf{restart} =.*/$nrconf{restart} = '\''a'\'';/' /etc/needrestart/needrestart.conf &>/dev/null
[[ -f /etc/needrestart/needrestart.conf ]] && sed -i "s/#\$nrconf{kernelhints} = -1;/\$nrconf{kernelhints} = -1;/g" /etc/needrestart/needrestart.conf &>/dev/null
[[ -f /etc/needrestart/needrestart.conf ]] && sed -i "s/#NR_NOTIFYD_DISABLE_NOTIFY_SEND='1'/NR_NOTIFYD_DISABLE_NOTIFY_SEND='1'/" /etc/needrestart/notify.conf &>/dev/null
APT_FLAGS=(-yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")

# Debe estar antes de todo por losmodos seguros
function helpPanel() {
    printf "%b\n" "\n${greenColour}${rev}[!] Uso: sudo bash $0 -d {Mode} [-c] [-r] [-l] [-s] [-b]${endColour}"
    printf "%b\n" "\t${blueColour}${rev}[-d] Mode of installation.${endColour}"
    printf "%b\n" "\t\t${magentaColour}${grisBg}${bold}debian${endColour}\t\t\t${yellowColour}${rev}Distribution Debian nesesary =< 60 gb.${endColour}"
    printf "%b\n" "\t\t${cianColour}${grisBg}${bold}archlinux${endColour}\t\t${yellowColour}${rev}Distribution Archlinux nesesary       =< 60 gb.${endColour}"
    printf "%b\n" "\t${yellowColour}Opcionales:${endColour}"
    printf "%b\n" "\t\t${yellowColour}-s${endColour}\t\t\t${greenColour}${rev}Spotify (Only Recomended for more than 16 gb of RAM, the demon use 1 gb of RAM)(Only theme Forest)${endColour}"
    printf "%b\n" "\t\t${yellowColour}-b${endColour}\t\t\t${greenColour}${rev}Mode debug${endColour}"
    printf "%b\n" "\t${redColour}[-h] Show this help panel.${endColour}"
    printf "%b\n" "\n${greenColour}Example:${endColour}"
    printf "%b\n" "\t${blueColour}sudo bash $0 -d debian${endColour}\t${yellowColour}(Install enviroment with repositories and latex and spotify)${endColour}"
    tput cnorm; exit 1
}

# Chequea que solo el usuario de bajos privileguios con sudo pueda ejecutar este script

check_sudo() {
  # Obtener el usuario REAL que ejecutó sudo (no el root)
  local CURRENT_UID=$(id -u)
  local PARENT_PROCESS=$(ps -o comm= -p $PPID 2>/dev/null)

  # Verificar que:
  # 1. Estamos como root (por el sudo)
  # 2. El proceso padre es sudo
  # 3. El usuario REAL no es root

  if [ "${CURRENT_UID}" -eq 0 ] && \
     [ "${PARENT_PROCESS}" = "sudo" ] && \
     [ "${REAL_USER}" != "root" ]; then
      printf "%b\n" "\n${greenColour}${grisBg}${bold}[*] PERMITIDO: ${endColour}${greenColour}${rev}Ejecución en curso${endColour}"
  else
      printf "%b\n" "\n${redColour}${grisBg}${bold}[x] BLOQUEADO: ${endColour}${redColour}${rev}Ejecución no permitida${endColour}"
      helpPanel
  fi
}


# Función para salir con ctrl_c 2 veces

last=0
ctrl_c() {
  local now
  now=$(date +%s)
  if (( now - last < 1 )); then
    printf "%b\n" "\n${redColour}${rev}[!] Exiting...${endColour}"
    [[ -n "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR:?No se borro la carpeta de instalación temporal}"/*
    find "${USER_HOME}" -type d -name "${INSTALL_DIR}" -exec rm -rf {} \; 2>/dev/null 
    set +e
    tput cnorm
    exit 1
  fi
  printf "%b\n" "\n${redColour}${grisBg}${bold}[x] Presiona CTRL+C dos veces seguidas para salir${endColour}"
  last=$now
  # Prevenir que el script continúe después del primer CTRL+C
  return 0
}

trap ctrl_c SIGINT

# Función chequea la distribucion donde se va a instalar en entorno

function check_os() {
    # Entorno a uasr
    read -rp "$(printf "%b\n" "${orangeColour}¿Instalar entorno BSPWM de s4vitar? ${endColour}${greenColour}${grisBg}${bold}(si|y|yes|yey)${endColour} or ${greenColour}${grisBg}${bold}(n|no|nay)${endColour} ")" entorno
    
    # Creamos directorios de trabajo    
    
    sudo -u "${REAL_USER}" mkdir -p "${INSTALL_DIR}"
    
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

    if (( ${#ENTORNOS[@]} > 0 )); then
        for dir in "${ENTORNOS[@]}"; do
           sudo -u "${REAL_USER}" mv "$dir" "${INSTALL_DIR}/"
           echo "[+] Movido: $dir → ${INSTALL_DIR}/"
           printf "%b\n" "\n${magentaColour}${rev}The directory was moved successfully${endColour}"
        done
    fi
    
    cd "${INSTALL_DIR}" || exit 1
    if [[ ! -f /etc/os-release ]]; then 
       printf "%b\n" "\n${redColour}${rev}The system is not permitive${endColour}"    
       helpPanel
    fi
    source /etc/os-release
    case "${ID,,}" in
      kali|parrot|ubuntu|debian)
        printf "%b\n" "\n${greenColour}${grisBg}${bold}The system is Debian${endColour}"
        printf "%b\n" "\n${greenColour}${rev}Installing only the bspwm environment for Debian${endColour}"
        apt-get remove --purge codium -y
        apt-get remove --purge vim -y
        apt-get remove --purge nvim -y
        apt-get remove --purge neovim -y
        rm /usr/share/applications/nvim.desktop
        rm /usr/share/applications/vim.desktop
        apt update -y 

        # Paquetes BSPWM + POLYBAR + Escritorio => Debian

        packages_bspwm_debian=(
        # Core BSPWM + Polybar
        curl wget git dpkg gnupg gdb cmake net-tools 
        plocate p7zip-full meson ninja-build bspwm
        sxhkd picom polybar
        
        # Dependencias de compilación BSPWM
        build-essential libxcb-util0-dev libxcb-ewmh-dev 
        libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev 
        libxcb-xinerama0-dev libxcb-xtest0-dev libxcb-shape0-dev 
        xcb-proto zsh zsh-syntax-highlighting
        
        # Dependencias de compilación Polybar
        make cmake-data pkg-config
        python3-sphinx python3-xcbgen
        libuv1-dev libcairo2-dev libxcb1-dev
        libxcb-composite0-dev libxcb-cursor-dev
        libxcb-damage0-dev libxcb-glx0-dev
        libxcb-present-dev libxcb-render0-dev
        libxcb-render-util0-dev libxcb-xfixes0-dev
        libxcb-xkb-dev libxcb-xrm-dev python-sphinx
        
        # Características opcionales Polybar
        libasound2-dev libpulse-dev libjsoncpp-dev
        libmpdclient-dev libnl-genl-3-dev
        
        # X.org y librerías gráficas
        libx11-xcb-dev libxext-dev libxi-dev
        libxinerama-dev libxkbcommon-x11-dev libxrandr-dev
        libgl1-mesa-dev libpixman-1-dev
        
        # Terminal
        kitty
        
        # Lanzadores de aplicaciones
        rofi suckless-tools
        
        # Wallpaper y visualización
        feh
        
        # Screenshots
        scrot flameshot
        
        # Notificaciones
        dunst
        
        # Gestores de archivos
        caja ranger
        
        # Apariencia
        lxappearance
        
        # Utilidades de escritorio
        xdo xdotool wmctrl xclip
        
        # Fuentes
        fontconfig
        
        # Otros
        bc bd dc keepassxc html2text seclists locate
        html2text libreoffice xpdf
        
        # Python
        python3 python3-dev python3-pip python3-venv 
        python3-qtpy ipython3 pipx docker docker-compose lxc 
        chromium firefox ntfs-3g)

        for package in "${packages_bspwm_debian[@]}"; do
          if apt-get install "${APT_FLAGS[@]}" "${package}"; then
              printf "%b\n" "${greenColour}${rev}The package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly.${endColour}"
          else
              printf "%b\n" "${yellowColour}${rev}The package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install.${endColour}"
          fi
        done  

        dpkg --configure -a &>/dev/null
        apt --fix-broken --fix-missing install &>/dev/null
        apt install --reinstall parrot-apps-basics
        apt-mark manual parrot-apps-basics neovim vim btop figlet
        apt autoremove -y &>/dev/null
        apt-get clean &>/dev/null
        apt autoclean &>/dev/null

        printf "%b\n" "${greenColour}${rev}Install bspwn and sxhkd.${endColour}"
        cd "${INSTALL_DIR}" || exit 1

        # Clone repos bspwm and sxhkdrc and Compilation
        sudo -u "${REAL_USER}" git clone https://github.com/baskerville/bspwm.git
        sudo -u "${REAL_USER}" git clone https://github.com/baskerville/sxhkd.git
        cd "${INSTALL_DIR}/bspwm/"
        make
        make install
        cd "${INSTALL_DIR}/sxhkd/"
        make
        make install 

        # Configuration polybar
        printf "%b\n" "${greenColour}${rev}Configure polybar fonts.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone https://github.com/VaughnValle/blue-sky.git
        cd "${INSTALL_DIR}/blue-sky/polybar/"
        sudo -u "${REAL_USER}" cp * -r "${USER_HOME}/.config/polybar"

        # Copiar fuentes
        cd "${INSTALL_DIR}/blue-sky/polybar/fonts"
        sudo mkdir -p /usr/share/fonts/truetype
        cp * /usr/share/fonts/truetype/
        pushd /usr/share/fonts/truetype &>/dev/null 
        fc-cache -v
        popd &>/dev/null 

        # Picom Compilation
        printf "%b\n" "${greenColour}${rev}Picom compilation.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone https://github.com/ibhagwan/picom.git
        cd picom/
        git submodule update --init --recursive
        meson --buildtype=release . build
        ninja -C build
        ninja -C build install 

        # Polybar Compilation
        printf "%b\n" "${greenColour}${rev}Polybar compilation.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone --recursive https://github.com/polybar/polybar
        cd polybar/
        mkdir build
        cd build/
        cmake ..
        make -j$(nproc)
        make install
        ;;
      arch)
        printf "%b\n"  "\n${blueColour}${grisBg}${bold}The system is Arch Linux${endColour}"
        printf "%b\n" "\n${greenColour}${rev}Installing only the bspwm environment for Arch Linux${endColour}"
        
        pacman -Rns --noconfirm codium 
        pacman -Rns --noconfirm vi 
        pacman -Rns --noconfirm vim 
        pacman -Rns --noconfirm neovim
        pacman -Rns --noconfirm nvim
                        
        # Paquetes BSPWM + POLYBAR + Escritorio => Arch Linux
        packages_bspwm_arch=(
        
        # Core BSPWM + Polybar
        git base-devel curl wget cmake dpkg net-tools rsync
        plocate gnome meson ninja bspwm sxhkd polybar picom
        make zlib
        
        # Dependencias XCB
        libxcb xcb-proto xcb-util xcb-util-wm xcb-util-keysyms cronie
        
        # Librerías gráficas
        libgl libxcursor libxext libxi libxinerama 
        libxkbcommon-x11 libxrandr mesa python-sphinx
        
        # Terminal
        kitty
        
        # Lanzadores
        rofi dmenu jgmenu
        
        # Wallpaper
        feh
        
        # Screenshots
        scrot flameshot maim
        
        # Notificaciones
        dunst
    
        # Gestor de archivos
        caja ranger yazi
    
        # Apariencia y temas
        polkit-gnome papirus-icon-theme lxappearance zsh zsh-syntax-highlighting
        
        # Utilidades de escritorio
        xdo xdotool xclip brightnessctl playerctl pamixer redshift
        
        # X.org
        xorg xorg-server xorg-xinit xorg-xdpyinfo xorg-xkill xorg-xprop xorg-xrandr xorg-xsetroot xorg-xwininfo
        
        # Drivers (virtuales y físicos)
        xf86-video-intel xf86-video-vmware open-vm-tools
        
        # Extras de entorno
        xsettingsd
        
        # MTP (Android)
        gvfs-mtp simple-mtpfs
        
        # Audio/Video/Multimedia
        mpd mpc ncmpcpp mpv
    
        # Utilidades varias de escritorio
        htop eza p7zip html2text libreoffice 
        xpdf keepassxc docker docker-compose 
        lxc python python-pip python-pipx pipx 
        chromium firefox  bc locate ntfs-3g jq)

        for package in "${packages_bspwm_arch[@]}"; do
          if pacman -S "${package}" --noconfirm --needed ; then
              printf "%b\n" "${greenColour}${rev}The package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly.${endColour}"
          else
              printf "%b\n" "${yellowColour}${rev}The package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install.${endColour}"
          fi
        done     

        # Instalacion de Paru, y dependecias para blackarch

        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/paru-bin.git
        cd "${INSTALL_DIR}/paru-bin"
        sudo -u "${REAL_USER}" makepkg -si --noconfirm
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" curl -O https://blackarch.org/strap.sh
        sudo chmod +x strap.sh
        ./strap.sh
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/snapd.git       
        cd "${INSTALL_DIR}/snapd"
        sudo -u "${REAL_USER}" makepkg -si --noconfirm
        systemctl enable --now snapd.socket
        systemctl restart snapd.service
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone https://aur.archlinux.org/yay.git
        cd "${INSTALL_DIR}/yay"
        sudo -u "${REAL_USER}" makepkg -si --noconfirm
        sudo -u "${REAL_USER}" -- yay -S eww-git xqp tdrop-git rofi-greenclip xwinwrap-0.9-bin simple-mtpfs --noconfirm
        pacman -Syu --overwrite '*' --noconfirm

        printf "%b\n" "${greenColour}${rev}Install bspwn and sxhkd.${endColour}"
        cd "${INSTALL_DIR}" || exit 1

        # Clone repos bspwm and sxhkdrc 
        sudo -u "${REAL_USER}" git clone https://github.com/baskerville/bspwm.git
        sudo -u "${REAL_USER}" git clone https://github.com/baskerville/sxhkd.git
        cd "${INSTALL_DIR}/bspwm/"
        make
        make install
        cd "${INSTALL_DIR}/sxhkd/"
        make
        make install 

        # Configuration polybar
        printf "%b\n" "${greenColour}${rev}Configure polybar fonts.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone https://github.com/VaughnValle/blue-sky.git
        cd "${INSTALL_DIR}/blue-sky/polybar/"
        sudo -u "${REAL_USER}" rm -r "${USER_HOME}/.config/polybar/*"

        # Copiar fuentes
        cd "${INSTALL_DIR}/blue-sky/polybar/fonts"
        mkdir -p /usr/share/fonts/truetype
        cp * /usr/share/fonts/truetype/
        pushd /usr/share/fonts/truetype &>/dev/null 
        fc-cache -v
        popd &>/dev/null 
        
        # Compilation polybar Arch Linux
        printf "%b\n" "${greenColour}${rev}Creating swap and compiling Polybar for Arch Linux .${endColour}"
        sleep 5
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        printf "%b\n" "${redColour}${grisBg}${bold}If the polybar doesn't compile, compile it separately and reload it with Alt + r.${endColour}"
        cd "${INSTALL_DIR}" || exit 1
        sudo -u "${REAL_USER}" git clone --recursive https://github.com/polybar/polybar
        cd polybar/
        rm -rf build
        mkdir build
        cd build/
        sleep 5
        cmake .. -DBUILD_DOC=OFF
        sleep 5
        make -j$(nproc)
        sleep 5
        make install
        swapoff /swapfile
        rm /swapfile
        ;;
      *)
        printf "%b\n" "\n${redColour}${rev}The system is neither Debian, Ubuntu, nor Arch Linux${endColour}"
        helpPanel
        ;;
    esac
 }

function bspwm_enviroment() {
  printf "%b\n" "${greenColour}${rev}Install Foo Wallpaper.${endColour}"
  curl -L https://raw.githubusercontent.com/thomas10-10/foo-Wallpaper-Feh-Gif/master/install.sh | bash &>/dev/null

  # Install powerlevel10k
  printf "%b\n" "${greenColour}${rev}Download powerlevel10k.${endColour}"
  sudo -u "${REAL_USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${USER_HOME}/powerlevel10k"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k

  # Install Fonts Hack nerd-fonts
  printf "%b\n" "${greenColour}${rev}Install Hack Nerd Fonts.${endColour}"
  cd "${INSTALL_DIR}" || exit 
  wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/Hack.zip
  mkdir -p /usr/local/share/fonts/
  unzip Hack.zip > /dev/null 2>&1 && sudo mv *.ttf /usr/local/share/fonts/
  rm -f Hack.zip LICENSE.md README.md 2>/dev/null 
  pushd /usr/local/share/fonts/
  fc-cache -v
  popd

  # Install Wallpaper
  printf "%b\n" "${greenColour}${rev}Configuration wallpaper.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  sudo -u "${REAL_USER}" mkdir -p "${USER_HOME}/Pictures"
  cp "${INSTALL_DIR}"/Entorno-BSPWM/*.png "${USER_HOME}/Pictures" 
  cp "${INSTALL_DIR}"/Entorno-BSPWM/*.gif "${USER_HOME}/Pictures"
  printf "%b\n" "${greenColour}${rev}Install plugin sudo.${endColour}"
  mkdir /usr/share/zsh-sudo
  wget -q https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh
  cp sudo.plugin.zsh /usr/share/zsh-sudo/ 

  # Install Batcat
  printf "%b\n" "${greenColour}${rev}Install batcat.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  wget -q https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-musl_0.24.0_amd64.deb
  dpkg -i bat-musl_0.24.0_amd64.deb

  # Install LSD
  printf "%b\n" "${greenColour}${rev}Install lsd.${endColour}"
  cd "${INSTALL_DIR}" || exit 1 
  wget -q https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd-musl_1.0.0_amd64.deb
  dpkg -i lsd-musl_1.0.0_amd64.deb

  # Install fzf
  printf "%b\n" "${greenColour}${rev}Install fzf.${endColour}"
  sudo -u "${REAL_USER}" git clone --depth 1 https://github.com/junegunn/fzf.git "${USER_HOME}/.fzf" &>/dev/null
  sudo -u "${REAL_USER}" "${USER_HOME}/.fzf/install" --all &>/dev/null
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf &>/dev/null
  ~/.fzf/install --all &>/dev/null

  # Install NvChad 
  printf "%b\n" "${greenColour}${rev}Install nvcahd.${endColour}" 
  cd "${INSTALL_DIR}" || exit 1
  # 1. Descargar el tarball oficial
  wget -q https://github.com/neovim/neovim/releases/download/v0.11.3/nvim-linux-x86_64.tar.gz
  # 2. Extraer el contenido
  tar xzvf nvim-linux-x86_64.tar.gz
  # 3. Mover la carpeta completa a /opt (requiere sudo)
  mv nvim-linux-x86_64 /opt/nvim
  # 4. Crear un enlace simbólico en /usr/bin para usarlo globalmente
  ln -s /opt/nvim/bin/nvim /usr/bin/nvim
  # 5. (Opcional) Limpiar el tarball descargado
  rm nvim-linux-x86_64.tar.gz
  sudo -u "${REAL_USER}" rm -rf "${USER_HOME}/.config/nvim" 
  sudo -u "${REAL_USER}" git clone https://github.com/NvChad/starter "${USER_HOME}/.config/nvim" && nvim --headless '+Lazy! sync' +qa
  line="vim.opt.listchars = { tab = '»·', trail = '.' }"
  sed -i "3i ${line}" "${USER_HOME}/.config/nvim/init.lua"
  rm -rf /root/.config/nvim
  git clone https://github.com/NvChad/starter /root/.config/nvim && nvim --headless '+Lazy! sync' +qa
  line="vim.opt.listchars = { tab = '»·', trail = '.' }"
  sed -i "3i ${line}" "/root/.config/nvim/init.lua"
  
  printf "%b\n" "${greenColour}${rev}Install themes polybar.${endColour}"
  cd "${INSTALL_DIR}" || exit 1
  git clone https://github.com/adi1090x/polybar-themes.git
  cd polybar-themes
  cp "${INSTALL_DIR}/Entorno-BSPWM/setup.sh" "${INSTALL_DIR}/polybar-themes/setup.sh"
  cd "${INSTALL_DIR}/polybar-themes"
  chmod +x setup.sh
  ./setup.sh
  # in bspwnrc
  # Available Themes : --
  #--blocks    --colorblocks    --cuts      --docky
  #--forest    --grayblocks     --hack      --material
  #--panels    --pwidgets       --shades    --shapes

  # Copiar archivos 
  printf "%b\n" "${greenColour}${rev}Move files configuration.${endColour}"
  sudo -u "${REAL_USER}" rm -r "${USER_HOME}/.config/polybar/forest"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/polybar/*" "${USER_HOME}/.config/polybar/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/bspwm/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/sxhkd/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/picom/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/kitty/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/rofi/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.p10k.zsh" "${USER_HOME}/.p10k.zsh"
  chmod +x "${USER_HOME}/.config/sxhkd/sxhkdrc"
  chmod +x "${USER_HOME}/.config/bspwm/bspwmrc"
  chmod +x "${USER_HOME}/.config/bspwm/scripts/bspwm_resize"
  chmod +x "${USER_HOME}/.config/picom/picom.conf"
  chmod +x "${USER_HOME}/.config/kitty/kitty.conf"
  chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.config/polybar/scripts/htb_target.sh"
  chmod +x "${USER_HOME}/.config/polybar/scripts/htb_target.sh"
  ln -s -f "${USER_HOME}/.p10k.zsh" "/root/.p10k.zsh"
  
  case "${entorno,,}" in
    si|y|yes|yey)
      printf "%b\n" "${greenColour}${rev}Install themes s4vitar.${endColour}"
      chmod +x "${USER_HOME}/.config/polybar/launch4.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/powermenu.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/launcher.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/ethernet_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/htb_status.sh"
      sudo -u "${REAL_USER}" sed -i 's|~/.config/polybar/launch\.sh --forest|~/.config/polybar/launch4.sh|g' "${USER_HOME}/.config/bspwm/bspwmrc"
      printf "%b\n"  "${greenColour}${rev}All packages installed successfully.${endColour}"
      sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.zshrc-arch" "${USER_HOME}/.zshrc" 
    ;;
    ""|n|no|nay)
      sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/config.ini.spotyfy" "${USER_HOME}/.config/polybar/config.ini"
      chmod +x "${USER_HOME}/.config/polybar/forest/launch.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/scroll_spotify_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/get_spotify_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/target.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/launcher.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/powermenu.sh"
      printf "%b\n" "${greenColour}${rev}All packages installed successfully.${endColour}"
      sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/.zshrc-debian" "${USER_HOME}/.zshrc"
    ;;
    *)
    printf "%b\n" "${yellowColour}[!] Respuesta no válida.${endColour}"
    helpPanel
    ;;
  esac
  
  tar -xvzf /usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz
  chown "${REAL_USER}:${REAL_USER}" "/tmp/name"
  chown "${REAL_USER}:${REAL_USER}" "/tmp/target"
  chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.zshrc"
  ln -s -f "${USER_HOME}/.zshrc" "/root/.zshrc"
  usermod --shell /usr/bin/zsh "$REAL_USER"
  usermod --shell /usr/bin/zsh root
  chown "${REAL_USER}:${REAL_USER}" "/root"
  chown "${REAL_USER}:${REAL_USER}" "/root/.cache" -R
  chown "${REAL_USER}:${REAL_USER}" "/root/.local" -R
  updatedb
  
  # Install VSC
  printf "%b\n" "${greenColour}${rev}Install VSC.${endColour}"
  curl -s "https://vscode.download.prss.microsoft.com/dbazure/download/stable/d78a74bcdfad14d5d3b1b782f87255d802b57511/code_1.94.0-1727878498_amd64.deb" -o code_1.94.0-1727878498_amd64.deb
  dpkg -i --force-confnew code_1.94.0-1727878498_amd64.deb
}

# Spotify solo funciona para forest porque no lo he usado en otros temas
function spotify_env(){
    cd "${INSTALL_DIR}" || exit 1
    git clone https://github.com/noctuid/zscroll
    cd zscroll
    python3 setup.py install
    
    # Configuración de polybar
    rm -f "${USER_HOME}/.config/polybar/forest/user_modules.ini"
    sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWM/polybar/forest/user_modules-copia.ini" "${USER_HOME}/.config/polybar/forest/user_modules.ini"
    
    printf "%b\n" "${greenColour}${rev}Instalando Spotify.${endColour}"
    
    if [[ -f /etc/arch-release ]]; then
        pacman -S playerctl --noconfirm
        snap install spotify
        systemctl --user enable --now mpd.service
        systemctl is-enabled --quiet mpd.service
    else
        # Para Kali, Parrot, Ubuntu
        apt-get install playerctl -y
        curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
        echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
        apt-get update
        apt-get install spotify-client -y
    fi
}

# Función para limpiar
function clean_bspwm() {
    printf "%b\n" "${greenColour}${rev}Limpiando todo.${endColour}"
    sudo chown root:root /usr/local/share/zsh/site-functions/_bspc 2>/dev/null 
    [[ -n "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && rm -rf "${INSTALL_DIR:?No se borro la carpeta de instalación temporal}"/*
    
    # Usar la variable operative_sistem para determinar las acciones de limpieza
    if [[ -f /etc/arch-release ]]; then
        pacman -Scc --noconfirm
        pacman -Syu --noconfirm
        pacman -Rns $(pacman -Qdtq) --noconfirm 2>/dev/null 
        printf "%b\n" "${greenColour}${rev}Habilitando demonios.${endColour}"
        localectl set-x11-keymap es
        systemctl enable vmtoolsd 2>/dev/null
        systemctl enable gdm.service 2>/dev/null 
        systemctl start gdm.service 2>/dev/null
        systemctl enable --now cronie.service 2>/dev/null
    else
        apt update -y
        dpkg --configure -a 
        apt --fix-broken --fix-missing install 
        apt -y --fix-broken --fix-missing full-upgrade
        apt -y full-upgrade
        apt autoremove -y
        apt-get clean &>/dev/null
        apt autoclean &>/dev/null
    fi
}

function shutdown_session(){
    printf "%b\n" "\n\t${cianColour}${rev} We are closing the session to apply the new configuration, be sure to select the BSPWN.${endColour}" 
    sudo -u "${REAL_USER} "echo "@reboot /bin/sh -c ': > /tmp/target; : > /tmp/name'" | crontab -
    sleep 10
    systemctl reboot
}

declare -i parameter_counter=0
Mode=""
spotify=false
debug_mode=false

OPTERR=0 
while getopts "d:rclsbh" arg; do
    case "$arg" in
        d) Mode="${OPTARG}"; let parameter_counter+=1 ;;
        s) spotify=true ;;
        b) debug_mode=true ;;
        h) printf "%s\n" "${redColour}${rev}Menu de ayuda.${endColour}"; helpPanel ;; 
        *) printf "%s\n" "${redColour}${rev}Opción invalida.${endColour}"; helpPanel ;;
    esac
done

tput civis

shift $((OPTIND - 1))

# Verificar si hay argumentos adicionales no permitidos

if [[ -z "${Mode:-}" ]]; then 
  printf "%s\n" "${redColour}${rev}[x] Faltan opciones obligatorias.${endColour}"
  helpPanel
fi 

# Validar el valor de -d
if [[ "$Mode" != "debian" && "$Mode" != "archlinux" ]]; then
    printf "%b\n" "${redColour}[!] Invalid mode: $Mode${endColour}"
    helpPanel
fi

# Validar si hay al menos un parámetro obligatorio
if [[ $parameter_counter -eq 0 ]]; then
    helpPanel
fi

# Ejecutar según el modo seleccionado
if [[ "$Mode" == "debian" ]]; then
    check_sudo
    check_os
    bspwm_enviroment 
    if [[ "$spotify" == true ]]; then
        spotify_env
    fi
    if [[ "$debug_mode" == true ]]; then
        :
        #bebug no implemtado
    fi
    clean_bspwm
    shutdown_session
elif [[ "$Mode" == "archlinux" ]]; then
    check_sudo
    check_os
    bspwm_enviroment 
    if [[ "$spotify" == true ]]; then
        spotify_env
    fi 
    if [[ "$debug_mode" == true ]]; then
        :
        #bebug no implemtado
    fi
    clean_bspwm 
    shutdown_session
else
    printf "%b\n" "${redColour}[!] Invalid mode.${endColour}"
    helpPanel
    tput cnorm
    exit 1
fi
tput cnorm
exit 0
