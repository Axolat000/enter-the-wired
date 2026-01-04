#!/bin/bash

SLSDIR="$HOME/.local/share/SLSsteam"
SLSPATH="$SLSDIR/path"
SLSLIB="$SLSDIR/SLSsteam.so"
BACKUP_DIR="$HOME/Desktop/backup"

check_steamos_deps() {
    if [ ! -f /etc/os-release ] || ! grep -q "SteamOS" /etc/os-release; then
        echo "⚠️  Avertissement : ce script est adapté pour SteamOS"
    fi

    # Vérifie si Steam est installé
    if ! command -v steam > /dev/null 2>&1 && [ ! -f "/usr/bin/steam" ] && [ ! -f "$HOME/.steam/steam.sh" ]; then
        echo "❌ Steam introuvable sur le système !"
        return 1
    fi

    echo "✅ Steam détecté sur le système"
    return 0
}

backup_steam_jupiter() {
    echo "📦 Création d’un backup de steam-jupiter..."

    mkdir -p "$BACKUP_DIR"

    if [ -f "/usr/bin/steam-jupiter" ]; then
        sudo cp -v "/usr/bin/steam-jupiter" "$BACKUP_DIR/steam-jupiter"
        sudo chmod 644 "$BACKUP_DIR/steam-jupiter"

        if [ -f "$BACKUP_DIR/steam-jupiter" ]; then
            echo "✅ Backup créé dans : $BACKUP_DIR/steam-jupiter"
            return 0
        else
            echo "❌ Échec de la création du backup"
            return 1
        fi
    else
        echo "❌ steam-jupiter introuvable dans /usr/bin/"
        return 1
    fi
}

modify_steam_jupiter() {
    echo "🔧 Modification de steam-jupiter pour le mode Game..."

    if [ ! -f "/usr/bin/steam-jupiter" ]; then
        echo "❌ steam-jupiter introuvable !"
        return 1
    fi

    if grep -q "LD_AUDIT=\"$SLSLIB\"" "/usr/bin/steam-jupiter"; then
        echo "✅ steam-jupiter est déjà modifié"
        return 0
    fi

    if [ ! -f "$SLSDIR/steam-jupiter.bak" ]; then
        sudo cp -v "/usr/bin/steam-jupiter" "$SLSDIR/steam-jupiter.bak"
    fi

    sudo sed -i '$ s|exec /usr/lib/steam/steam -steamdeck "$@"|exec env LD_AUDIT="'"$SLSLIB"'" /usr/lib/steam/steam -steamdeck "$@"|' "/usr/bin/steam-jupiter"

    if grep -q "LD_AUDIT=\"$SLSLIB\"" "/usr/bin/steam-jupiter"; then
        echo "✅ steam-jupiter modifié avec succès !"
        echo "   Injection SLSsteam ajoutée pour le mode Game"
        return 0
    else
        echo "❌ Échec de la modification de steam-jupiter"
        return 1
    fi
}

restore_steam_jupiter() {
    echo "🔄 Restauration de steam-jupiter original..."

    if [ -f "$SLSDIR/steam-jupiter.bak" ]; then
        sudo cp -v "$SLSDIR/steam-jupiter.bak" "/usr/bin/steam-jupiter"
        sudo chmod +x "/usr/bin/steam-jupiter"
        echo "✅ Restauré depuis le backup interne"
        return 0
    fi

    if [ -f "$BACKUP_DIR/steam-jupiter" ]; then
        sudo cp -v "$BACKUP_DIR/steam-jupiter" "/usr/bin/steam-jupiter"
        sudo chmod +x "/usr/bin/steam-jupiter"
        echo "✅ Restauré depuis le backup du Bureau"
        return 0
    fi

    echo "⚠️  Aucun backup trouvé pour la restauration"
    return 1
}

find_steam_paths() {
    echo "🔍 Recherche des installations Steam..."

    STEAM_PATHS=()

    if [ -f "/usr/bin/steam" ]; then
        STEAM_PATHS+=("/usr/bin/steam")
        echo "✅ Steam système : /usr/bin/steam"
    fi

    if [ -f "/usr/bin/steam-jupiter" ]; then
        STEAM_PATHS+=("/usr/bin/steam-jupiter")
        echo "✅ Steam Jupiter : /usr/bin/steam-jupiter"
    fi

    if [ -f "$HOME/.steam/steam.sh" ]; then
        STEAM_PATHS+=("$HOME/.steam/steam.sh")
        echo "✅ Steam utilisateur : $HOME/.steam/steam.sh"
    fi

    if [ -f "$HOME/.local/share/Steam/steam.sh" ]; then
        STEAM_PATHS+=("$HOME/.local/share/Steam/steam.sh")
        echo "✅ Steam local : $HOME/.local/share/Steam/steam.sh"
    fi

    if [ ${#STEAM_PATHS[@]} -eq 0 ]; then
        echo "❌ Aucune installation Steam trouvée !"
        return 1
    fi

    return 0
}

restart_steam() {
    echo "🔄 Redémarrage de Steam..."

    if pgrep -x "steam" > /dev/null; then
        echo "🛑 Arrêt de Steam..."
        pkill -x steam
        sleep 3
    fi

    echo "🚀 Lancement de Steam..."
    nohup steam > /dev/null 2>&1 &
}

setup_shell_path() {
    echo "⚙️ Configuration automatique du PATH..."

    CURRENT_SHELL=$(basename "$SHELL")
    echo "Shell détecté : $CURRENT_SHELL"

    case "$CURRENT_SHELL" in
        bash)
            SHELLRC="$HOME/.bashrc"
            PATH_CMD="export PATH=\"$SLSPATH:\$PATH\""
            ;;
        zsh)
            SHELLRC="$HOME/.zshrc"
            PATH_CMD="export PATH=\"$SLSPATH:\$PATH\""
            ;;
        fish)
            SHELLRC="$HOME/.config/fish/config.fish"
            PATH_CMD="set -gx PATH \"$SLSPATH\" \$PATH"
            ;;
        *)
            echo "⚠️  Shell non supporté"
            return 1
            ;;
    esac

    mkdir -p "$(dirname "$SHELLRC")"
    touch "$SHELLRC"

    if ! grep -q "$SLSPATH" "$SHELLRC"; then
        echo "$PATH_CMD" >> "$SHELLRC"
        echo "✅ PATH ajouté à $SHELLRC"
    else
        echo "✅ PATH déjà configuré"
    fi

    export PATH="$SLSPATH:$PATH"
}

install_slssteam() {
    LIB="./bin/SLSsteam.so"

    if [ ! -f "$LIB" ]; then
        echo "❌ Erreur : bin/SLSsteam.so introuvable !"
        exit 1
    fi

    mkdir -p "$SLSDIR" "$SLSPATH"
    cp -v "$LIB" "$SLSLIB"

    echo "✅ SLSsteam installé dans $SLSLIB"
}

install_all() {
    echo "🚀 Installation de SLSsteam sur SteamOS"
    echo "======================================"

    check_steamos_deps || exit 1
    find_steam_paths || exit 1

    install_slssteam
    setup_shell_path
    backup_steam_jupiter
    modify_steam_jupiter

    echo ""
    read -p "🔄 Voulez-vous redémarrer Steam maintenant ? (o/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        restart_steam
    else
        echo "⚠️  Pensez à redémarrer Steam manuellement."
    fi

    echo ""
    echo "🎉 Installation terminée avec succès !"
}

if [ $# -lt 1 ]; then
    echo "Usage : $0 install | uninstall"
    exit 0
fi

case "$1" in
    install)
        install_all
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo "Commande inconnue"
        ;;
esac
