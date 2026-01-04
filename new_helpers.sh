#!/usr/bin/env bash

exec > >(tee -a /home/axel/script_$(date +%Y%m%d_%H%M%S).log) 2>&1

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

# Modos seguro

#set -euo pipefail

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
    printf "%b\n" "\t\t${yellowColour}-c${endColour}\t\t\t${greenColour}${rev}Core Tools 270.${endColour}"
    printf "%b\n" "\t\t${yellowColour}-r${endColour}\t\t\t${greenColour}${rev}Tools Repositories (Tools for OSCP) nesesary =< 160 gb.${endColour}"
    printf "%b\n" "\t\t${yellowColour}-l${endColour}\t\t\t${greenColour}${rev}LaTeX Environment (It tackes 30 min more)${endColour}"
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
    
    ENTORNOS=()

    while IFS= read -r dir; do
        [[ -z "$dir" ]] && continue
        ENTORNOS+=("$dir")
    done < <(
        find "${USER_HOME}" \
            -type d \
            -name "Entorno-BSPWN" \
            -not -path "${INSTALL_DIR}/*"
    )

    if (( ${#ENTORNOS[@]} > 0 )); then
        sudo -u "${REAL_USER}" mkdir -p "${INSTALL_DIR}"
        for dir in "${ENTORNOS[@]}"; do
           sudo -u "${REAL_USER}" mv "$dir" "${INSTALL_DIR}/"
           echo "[+] Movido: $dir → ${INSTALL_DIR}/"
        done
    else
       echo "[i] Entorno-BSPWN no encontrado en ${USER_HOME}"
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
        curl wget git dpkg gnupg gdb cmake net-tools plocate p7zip-full
        
        # Dependencias de compilación BSPWM
        build-essential libxcb-util0-dev libxcb-ewmh-dev 
        libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev 
        libxcb-xinerama0-dev libxcb-xtest0-dev libxcb-shape0-dev 
        xcb-proto zsh zsh-syntax-highlighting
        
        # Dependencias de compilación Polybar
        cmake-data pkg-config
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
        fontconfig)

        for package in "${packages_bspwm_debian[@]}"; do
          if apt-get install "${APT_FLAGS[@]}" "${package}"; then
              printf "%b\n" "${greenColour}${rev}The package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly.${endColour}"
          else
              printf "%b\n" "${yellowColour}${rev}The package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install.${endColour}"
          fi
        done  

        dpkg --configure -a &>/dev/null
        apt --fix-broken --fix-missing install &>/dev/null
        apt-mark manual neovim vim btop figlet
        apt autoremove -y &>/dev/null
        apt-get clean &>/dev/null
        apt autoclean &>/dev/null

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
        git base-devel curl wget cmake dpkg net-tools plocate gnome
        
        # Dependencias XCB
        libxcb xcb-proto xcb-util xcb-util-wm xcb-util-keysyms cronie
        
        # Librerías gráficas
        libgl libxcursor libxext libxi libxinerama libxkbcommon-x11 libxrandr mesa python-sphinx
        
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
        htop eza p7zip)

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
        cd "${INSTALL_DIR}" || exit
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
  cp "${INSTALL_DIR}"/Entorno-BSPWN/*.png "${USER_HOME}/Pictures" 
  cp "${INSTALL_DIR}"/Entorno-BSPWN/*.gif "${USER_HOME}/Pictures"
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
  cp "${INSTALL_DIR}/Entorno-BSPWN/setup.sh" "${INSTALL_DIR}/polybar-themes/setup.sh"
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
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWN/polybar/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWN/bspwm/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWN/sxhkd/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWN/picom/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWN/kitty/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp -r "${INSTALL_DIR}/Entorno-BSPWN/rofi/" "${USER_HOME}/.config/"
  sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWN/.p10k.zsh" "${USER_HOME}/.p10k.zsh"
  chmod +x "${USER_HOME}/.config/sxhkd/sxhkdrc"
  chmod +x "${USER_HOME}/.config/bspwm/bspwmrc"
  chmod +x "${USER_HOME}/.config/bspwm/scripts/bspwm_resize"
  chmod +x "${USER_HOME}/.config/picom/picom.conf"
  chmod +x "${USER_HOME}/.config/kitty/kitty.conf"
  ln -s -f "${USER_HOME}/.p10k.zsh" "/root/.p10k.zsh"
  
  case "${entorno,,}" in
    si|y|yes|yey)
      printf "%b\n" "${greenColour}${rev}Install themes s4vitar.${endColour}"
      chmod +x "${USER_HOME}/.config/polybar/launch4.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/ethernet_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/htb_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/scripts/htb_target.sh"
      sudo -u "${REAL_USER}" sed -i 's|~/.config/polybar/launch\.sh --forest|~/.config/polybar/launch4.sh|g' "${USER_HOME}/.config/bspwm/bspwmrc"
      printf "%b\n"  "${greenColour}${rev}All packages installed successfully.${endColour}"
      sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWN/.zshrc-arch" "${USER_HOME}/.zshrc" 
    ;;
    ""|n|no|nay)
      chmod +x "${USER_HOME}/.config/polybar/forest/launch.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/preview.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/scroll_spotify_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/get_spotify_status.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/target.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/checkupdates"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/launcher.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/powermenu.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/style-switch.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/styles.sh"
      chmod +x "${USER_HOME}/.config/polybar/forest/scripts/updates.sh"
      printf "%b\n" "${greenColour}${rev}All packages installed successfully.${endColour}"
      sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWN/.zshrc-debian" "${USER_HOME}/.zshrc"
    ;;
    *)
    printf "%b\n" "${yellowColour}[!] Respuesta no válida.${endColour}"
    helpPanel
    ;;
  esac
  tar -xvzf /usr/share/seclists/Passwords/Leaked-Databases/rockyou.txt.tar.gz
  ln -s -f "${USER_HOME}/.zshrc" "/root/.zshrc"
  chown "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.zshrc"
  usermod --shell /usr/bin/zsh "$REAL_USER"
  usermod --shell /usr/bin/zsh root
  chown "${REAL_USER}:${REAL_USER}" "/root"
  chown "${REAL_USER}:${REAL_USER}" "/root/.cache" -R
  chown "${REAL_USER}:${REAL_USER}" "/root/.local" -R
  updatedb
}

function update_debian() {
    printf "%b\n" "${greenColour}${rev}Installing additional packages for the correct functioning of the environment.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    apt-get remove --purge python3-unicodecsv -y
    apt-get remove --purge burpsuite -y

    # Verificar si es Kali Linux y configurar wine
    if [[ -f /etc/os-release && $(grep -q "kali" /etc/os-release; echo $?) -eq 0 ]]; then
      printf "%b\n" "${blueColour}${rev}Configuring wine for Kali Linux.${endColour}"
      dpkg --add-architecture i386
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
    autoconf awscli bc bd binwalk
    
    # Herramientas de sistema
    alien axel dtrx git git-cola
    
    # Python
    python3 python3-dev python3-pip python3-venv 
    python3-qtpy ipython3 pipx
    
    # Build tools
    build-essential gcc gcc-multilib pkg-config
    dh-autoreconf meson
    
    # Navegadores/visualizadores texto
    pandoc lynx dc
    
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
    html2text
    
    # Criptografía
    encfs gpp-decrypt keepassxc kpcli
    
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
    padbuster peass powercat seclists shellter
    sprayingtoolkit
    
    # Utilidades varias
    flite gimp hexchat imagemagick locate neo4j 
    qrencode recordmydesktop rlwrap 
    software-properties-common translate-shell 
    wayland-protocols wkhtmltopdf wmis zbar-tools dex)

    for package in "${packages_tools_debian[@]}"; do
      if apt-get install "${APT_FLAGS[@]}" "${package}"; then
          printf "%b\n" "${greenColour}${rev}The package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly.${endColour}"
      else
          printf "%b\n" "${yellowColour}${rev}The package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install.${endColour}"
      fi
    done
    
    # Limpiar y actualizar la base de datos
    printf "%b\n" "${greenColour}${rev}Cleaning up and updating package database.${endColour}"
    apt -y --fix-broken --fix-missing full-upgrade 
    apt -y full-upgrade

}

function update_arch(){
    printf "%b\n" "${greenColour}Additional packages will be installed for the correct functioning of the environment.${endColour}"
    cd "${INSTALL_DIR}" || exit
    
    # Listado único de todos los paquetes agrupados
    packages_tools_arch=(
    # Librerías base
    libconfig libev libevdev libffi libglib2 
    liblcms2 libldap libmemcached libpcap 
    libpng16 libpopt libprotobuf libproxychains
    proxychains libpst librsync libsasl2 
    libwebp uthash zlib
    
    # Herramientas básicas
    acl adb antiword autoconf make cmake 
    meson pkg-config sudo dpkg
    
    # Gestores de paquetes
    pacman pacman-contrib 
    
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
    djvulibre xpdf libreoffice html2text
    
    # Criptografía
    keepassxc krb5 gnupg openssl
    
    # Contenedores y virtualización
    docker docker-compose lxc
    
    # Desarrollo - Lenguajes
    cargo rustup go nodejs npm python 
    python-pip python-pipx pipx ruby maven
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
    
    # Navegadores
    chromium firefox
    
    # Utilidades de sistema
    bc locate ntfs-3g
    
    # LDAP
    slapd ldap-utils
    
    # Utilidades varias
    flite imagemagick gimp hexchat 
    jq pdfid pdf-parser pidgin 
    pngcrush qrencode recordmydesktop 
    rlwrap translate-shell 
    wayland-protocols webp-pixbuf-loader 
    wkhtmltopdf xdg-user-dirs wine)    

    for package in "${packages_tools_arch[@]}"; do
      if pacman -S "${package}" --noconfirm --needed ; then
    printf "%b\n" "${greenColour}${rev}The package ${endColour}${greenColour}${grisBg}${bold} ${package} ${endColour}${greenColour}${rev}has been installed correctly.${endColour}"
      else
          printf "%b\n" "${yellowColour}${rev}The package ${endColour}${yellowColour}${grisBg}${bold} ${package} ${endColour}${yellowColour}${rev} didn't install.${endColour}"
      fi
    done 
    
    printf "%b\n" "${greenColour}${rev}Install Tools paru${endColour}"
    paru -S --skipreview tdrop-git xqp rofi-greenclip xwinwrap-0.9-bin ttf-maple i3lock-color simple-mtpfs eww-git --noconfirm
    sleep 1
    printf "%b\n"  "${greenColour}${rev}Install Tools yay${endColour}"
    yay -S dpkg rustscan
    printf "%b\n"  "${greenColour}${rev}Install Tools snap${endColour}"
    snap install node --classic
}

function core_package(){
	 # Install apps de python
    # No instalar en sistema que esten produccion
    # Eliminar restricción de pip
    printf "%b\n" "${greenColour}${rev}Install Python.${endColour}"
    rm -f /usr/lib/python3*/EXTERNALLY-MANAGED 2>/dev/null

    # Actualizar pip y otras (herramientas aisladas)
    python3 -m pip install --upgrade pip pipx pwntools pyparsing

    # Instalación con pipx
    pipx install posting donpapi
    pipx install git+https://github.com/brightio/penelope
    pipx install git+https://github.com/blacklanternsecurity/MANSPIDER 
    
    # Herramientas de pentesting (NO disponibles en APT o versión muy vieja)
    sudo -H pip3 install -U minikerberos oletools xlrd wesng pwncat-cs git-dumper crawley certipy-ad jsbeautifier
    sudo -H pip3 install -U git+https://github.com/blacklanternsecurity/trevorproxy 
    sudo -H pip3 install -U git+https://github.com/decalage2/ViperMonkey/archive/master.zip
    sudo -H pip3 install -U git+https://github.com/ly4k/ldap3 
    sudo -H pip3 install --upgrade paramiko cryptography pyOpenSSL botocore minikerberos pyparsing cheroot wsgidav \
      ezodf pyreadline3 oathtool pwncat-cs updog pypykatz html2markdown colored oletools droopescan uncompyle6 web3 \
      acefile bs4 pyinstaller flask-unsign pyDes fake_useragent alive_progress githack bopscrk hostapd-mana six \
      crawley certipy-ad chepy minidump aiowinreg msldap winacl pymemcache holehe xlrd wesng jsbeautifier

    #Install gem Packeage
    printf "%b\n" "${greenColour}${rev}Install Ruby.${endColour}"
    gem install evil-winrm http httpx docopt rest-client colored2 wpscan winrm-fs stringio logger fileutils winrm brakeman

    # Install GO y Apps
    printf "%b\n" "${greenColour}${rev}Install go.${endColour}"
    cd "${INSTALL_DIR}" || exit 1

    wget -q https://go.dev/dl/go1.25.5.linux-amd64.tar.gz
	 rm -rf /usr/local/go && tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin

	 go install github.com/hakluke/hakrawler@latest
	 mv ~/go/bin/hakrawler /usr/local/bin/

	 go install github.com/tomnomnom/waybackurls@latest
	 mv ~/go/bin/waybackurls /usr/local/bin/

	 go install github.com/lc/gau/v2/cmd/gau@latest
	 mv ~/go/bin/gau /usr/local/bin/

	 go install github.com/ropnop/kerbrute@latest
	 mv ~/go/bin/kerbrute /usr/local/bin/

	 go install -v github.com/rverton/webanalyze/cmd/webanalyze@latest
	 mv ~/go/bin/webanalyze /usr/local/bin/
	 
    go install github.com/benbusby/namebuster@latest
    mv ~/go/bin/namebuster /usr/local/bin/

    go install github.com/Josue87/gotator@latest
    mv ~/go/bin/gotator /usr/local/bin/ 

    go install github.com/d3mondev/puredns/v2@latest
    mv ~/go/bin/puredns /usr/local/bin/ 

    go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
    mv ~/go/bin/grpcurl /usr/local/bin/

    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest 
    mv ~/go/bin/subfinder /usr/local/bin/ 

    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest 
    mv ~/go/bin/dnsx /usr/local/bin/

    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest CGO_ENABLED=1 
    mv ~/go/bin/httpx /usr/local/bin/ 

    go install github.com/projectdiscovery/katana/cmd/katana@latest
    mv ~/go/bin/katana /usr/local/bin/ 
   
    # Install snap
    printf "%b\n" "${greenColour}${rev}Install snap tools.${endColour}"
    snap install ngrok storage-explorer
    snap install snapcraft kubectl --classic

    # Istall npm
    printf "%b\n" "${greenColour}${rev}Install npm tools.${endColour}"
    npm install -g safe-backup wscat asar memcached-cli node-serialize slendr electron-packager
    cd "${INSTALL_DIR}" || exit 1
    git clone https://github.com/qtc-de/remote-method-guesser
    cd remote-method-guesser
    mvn package
    cd "${INSTALL_DIR}" || exit 1
    git clone https://github.com/CravateRouge/bloodyAD.git
    cd bloodyAD
    pip3 install . 
   
    # Istall Docker Compose
    printf "%b\n" "${greenColour}Install docker Compose.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    usermod -aG docker ${REAL_USER}
    cd "${INSTALL_DIR}" || exit 1
    sleep 1

    # Esto es nesesario para instalar AvaloniaILSpy.
    printf "%b\n" "${greenColour}${rev}Adding Microsoft repository.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb

    # Install AvaloniaILSpy
    printf "%b\n" "${yellowColour}Install AvaloniaILSpy.${endColour}"
    mkdir -p "${OPT_DIR}/AvaloniaILSpy"
    cd "${OPT_DIR}/AvaloniaILSpy"
    wget -q https://github.com/icsharpcode/AvaloniaILSpy/releases/download/v7.2-rc/Linux.x64.Release.zip
    mv /home/$REAL_USER/Downloads/Linux.x64.Release.zip .
    unzip Linux.x64.Release.zip
    rm Linux.x64.Release.zip
    unzip ILSpy-linux-x64-Release.zip
    rm ILSpy-linux-x64-Release.zip 
    # /opt/AvaloniaILSpy/artifacts/linux-x64/ILSpy

    # Install RustScan
    printf "%b\n" "${greenColour}${rev}Install rustscan.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    curl -sL https://github.com/bee-san/RustScan/releases/download/2.3.0/rustscan_2.3.0_amd64.deb -o rustscan_2.3.0_amd64.deb 
    dpkg -i rustscan_2.3.0_amd64.deb

    # Install Feroxbuster
    printf "%b\n" "${greenColour}${rev}Install Feroxbuster.${endColour}"
    cd "${INSTALL_DIR}" || exit 1
    curl -sL https://github.com/epi052/feroxbuster/releases/download/v2.11.0/feroxbuster_amd64.deb.zip -o feroxbuster_amd64.deb.zip
    7z x feroxbuster_amd64.deb.zip
    dpkg -i feroxbuster_2.11.0-1_amd64.deb

    # Install fastTCPscan
    cp "${INSTALL_DIR}/Entorno-BSPWN/fastTCPscan.go" "/opt/fastTCPscan"
    chmod 755 /opt/fastTCPscan
    ln -s -f "/opt/fastTCPscan" "/usr/local/bin/fastTCPscan"

    # Install whichSystem
    mkdir -p /opt/whichSystem
    cp "${INSTALL_DIR}/Entorno-BSPWN/whichSystem.py" "/opt/whichSystem/whichSystem.py"
    ln -s -f "/opt/whichSystem/whichSystem.py" "/usr/local/bin/"

	  # Install VSC
    printf "%b\n" "${greenColour}${rev}Install VSC.${endColour}"
    curl -s "https://vscode.download.prss.microsoft.com/dbazure/download/stable/d78a74bcdfad14d5d3b1b782f87255d802b57511/code_1.94.0-1727878498_amd64.deb" -o code_1.94.0-1727878498_amd64.deb
    dpkg -i --force-confnew code_1.94.0-1727878498_amd64.deb
    
    # Install Curlie
    printf "%b\n" "${greenColour}${rev}Install curlie.${endColour}"
	 curl -sS https://webinstall.dev/curlie | bash
    
    # Install Gef
    printf "%b\n" "${greenColour}${rev}Install Gef.${endColour}"
    bash -c "$(curl -fsSL https://gef.blah.cat/sh)"

}

function repositories(){

    # Install incursore
    printf "%b\n" "${yellowColour}Install incursore.${endColour}"
    cd "${OPT_DIR}" || exit 1
    git clone https://github.com/wirzka/incursore.git
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
    wget -q https://github.com/obsidianmd/obsidian-releases/releases/download/v1.10.3/obsidian_1.10.3_amd64.deb
    dpkg -i obsidian_1.10.3_amd64.deb
    printf "%b\n" "${greenColour}${rev}The latex environment will be installed, this will take more than 30 minutes approximately..${endColour}"
    
    if [[ -f /etc/arch-release ]]; then
        pacman -S --needed --noconfirm texlive-most zathura zathura-pdf-poppler
    else
        # Para Kali, Parrot, Ubuntu y otros sistemas basados en Debian
        apt-get install latexmk zathura rubber texlive texlive-latex-extra texlive-fonts-recommended -y --fix-missing # texlive-full
    fi
}

# Spotify solo funciona para forest porque no lo he usado en otros temas
function spotify_env(){
    cd "${INSTALL_DIR}" || exit 1
    git clone https://github.com/noctuid/zscroll
    cd zscroll
    python3 setup.py install
    
    # Configuración de polybar
    rm -f "${USER_HOME}/.config/polybar/forest/user_modules.ini"
    sudo -u "${REAL_USER}" cp "${INSTALL_DIR}/Entorno-BSPWN/polybar/forest/user_modules-copia.ini" "${USER_HOME}/.config/polybar/forest/user_modules.ini"
    
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
    [[ -n "${INSTALL_DIR}" && "${INSTALL_DIR}" != "/" ]] && sudo rm -rf "${INSTALL_DIR:?}"/*
    
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
    echo "@reboot /bin/sh -c ': > /tmp/target; : > /tmp/name'" | crontab -
    sleep 10
    systemctl reboot
}

declare -i parameter_counter=0
Mode=""
core_tools=false
repositories=false
latex=false
spotify=false
debug_mode=false

OPTERR=0 
while getopts "d:rclsbh" arg; do
    case "$arg" in
        d) Mode="${OPTARG}"; let parameter_counter+=1 ;;
        c) core_tools=true ;;
        r) repositories=true ;;
        l) latex=true ;;
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
    if [[ "$core_tools" == true ]]; then
        update_debian
        core_package
    fi
    if [[ "$repositories" == true ]]; then
        repositories
    fi
    if [[ "$latex" == true ]]; then
        latex_env
    fi
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
    if [[ "$core_tools" == true ]]; then
        update_arch
        core_package
    fi
    if [[ "$repositories" == true ]]; then
        repositories
    fi
    if [[ "$latex" == true ]]; then
        latex_env
    fi
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
