#!/bin/bash

SLSDIR="$HOME/.local/share/SLSsteam"
SLSPATH="$SLSDIR/path"
SLSLIB="$SLSDIR/SLSsteam.so"
BACKUP_DIR="$HOME/Desktop/backup"

check_steamos_deps() {
    if [ ! -f /etc/os-release ] || ! grep -q "SteamOS" /etc/os-release; then
        echo "Aviso: Este script foi adaptado para SteamOS"
    fi

    # Verifica se o Steam está instalado de alguma forma
    if ! command -v steam > /dev/null 2>&1 && [ ! -f "/usr/bin/steam" ] && [ ! -f "$HOME/.steam/steam.sh" ]; then
        echo "❌ Steam não encontrado no sistema!"
        return 1
    fi

    echo "✅ Steam detectado no sistema"
    return 0
}

backup_steam_jupiter() {
    echo "📦 Criando backup do steam-jupiter..."

    # Cria diretório de backup se não existir
    mkdir -p "$BACKUP_DIR"

    if [ -f "/usr/bin/steam-jupiter" ]; then
        sudo cp -v "/usr/bin/steam-jupiter" "$BACKUP_DIR/steam-jupiter"
        sudo chmod 644 "$BACKUP_DIR/steam-jupiter"

        if [ -f "$BACKUP_DIR/steam-jupiter" ]; then
            echo "✅ Backup criado em: $BACKUP_DIR/steam-jupiter"
            return 0
        else
            echo "❌ Falha ao criar backup"
            return 1
        fi
    else
        echo "❌ steam-jupiter não encontrado em /usr/bin/"
        return 1
    fi
}

modify_steam_jupiter() {
    echo "🔧 Modificando steam-jupiter para modo Game..."

    # Verifica se o arquivo existe
    if [ ! -f "/usr/bin/steam-jupiter" ]; then
        echo "❌ steam-jupiter não encontrado!"
        return 1
    fi

    # Verifica se já foi modificado
    if grep -q "LD_AUDIT=\"$SLSLIB\"" "/usr/bin/steam-jupiter"; then
        echo "✅ steam-jupiter já está modificado"
        return 0
    fi

    # Cria backup interno primeiro
    if [ ! -f "$SLSDIR/steam-jupiter.bak" ]; then
        sudo cp -v "/usr/bin/steam-jupiter" "$SLSDIR/steam-jupiter.bak"
    fi

    # Substitui a última linha do arquivo
    sudo sed -i '$ s|exec /usr/lib/steam/steam -steamdeck "$@"|exec env LD_AUDIT="'"$SLSLIB"'" /usr/lib/steam/steam -steamdeck "$@"|' "/usr/bin/steam-jupiter"

    # Verifica se a modificação foi aplicada
    if grep -q "LD_AUDIT=\"$SLSLIB\"" "/usr/bin/steam-jupiter"; then
        echo "✅ steam-jupiter modificado com sucesso!"
        echo "   Injeção SLSsteam adicionada para modo Game"
        return 0
    else
        echo "❌ Falha ao modificar steam-jupiter"
        return 1
    fi
}

restore_steam_jupiter() {
    echo "🔄 Restaurando steam-jupiter original..."

    # Primeiro tenta restaurar do backup interno
    if [ -f "$SLSDIR/steam-jupiter.bak" ]; then
        sudo cp -v "$SLSDIR/steam-jupiter.bak" "/usr/bin/steam-jupiter"
        sudo chmod +x "/usr/bin/steam-jupiter"
        echo "✅ Restaurado do backup interno"
        return 0
    fi

    # Tenta restaurar do backup no Desktop
    if [ -f "$BACKUP_DIR/steam-jupiter" ]; then
        sudo cp -v "$BACKUP_DIR/steam-jupiter" "/usr/bin/steam-jupiter"
        sudo chmod +x "/usr/bin/steam-jupiter"
        echo "✅ Restaurado do backup no Desktop"
        return 0
    fi

    echo "⚠️  Nenhum backup encontrado para restauração"
    return 1
}

find_steam_paths() {
    echo "🔍 Procurando instalações do Steam..."

    STEAM_PATHS=()

    # Paths possíveis do Steam no SteamOS
    if [ -f "/usr/bin/steam" ]; then
        STEAM_PATHS+=("/usr/bin/steam")
        echo "✅ Steam system: /usr/bin/steam"
    fi

    if [ -f "/usr/bin/steam-jupiter" ]; then
        STEAM_PATHS+=("/usr/bin/steam-jupiter")
        echo "✅ Steam Jupiter: /usr/bin/steam-jupiter"
    fi

    if [ -f "$HOME/.steam/steam.sh" ]; then
        STEAM_PATHS+=("$HOME/.steam/steam.sh")
        echo "✅ Steam user: $HOME/.steam/steam.sh"
    fi

    if [ -f "$HOME/.local/share/Steam/steam.sh" ]; then
        STEAM_PATHS+=("$HOME/.local/share/Steam/steam.sh")
        echo "✅ Steam local: $HOME/.local/share/Steam/steam.sh"
    fi

    if [ ${#STEAM_PATHS[@]} -eq 0 ]; then
        echo "❌ Nenhuma instalação do Steam encontrada!"
        return 1
    fi

    return 0
}

get_steam_arguments() {
    # Obtém os argumentos atuais do processo Steam, se estiver rodando
    if pgrep -x "steam" > /dev/null; then
        # Pega os argumentos da linha de comando do processo Steam
        STEAM_ARGS=$(ps -p $(pgrep -x "steam") -o args= | head -1 | sed 's/^[^ ]* //')
        echo "$STEAM_ARGS"
    else
        echo ""
    fi
}

restart_steam() {
    echo "Reiniciando o Steam..."

    # Obtém os argumentos atuais do Steam antes de fechar
    CURRENT_ARGS=$(get_steam_arguments)
    echo "📝 Argumentos atuais do Steam: '$CURRENT_ARGS'"

    # Determina como reiniciar baseado nos argumentos atuais
    if echo "$CURRENT_ARGS" | grep -q "\-gamepadui"; then
        MODE="Gamepad UI (Modo Gaming)"
        NEW_ARGS="-gamepadui"
    elif echo "$CURRENT_ARGS" | grep -q "\-steamdeck"; then
        MODE="Steam Deck (Modo Game)"
        NEW_ARGS="-steamdeck"
    else
        MODE="Desktop"
        NEW_ARGS=""
    fi

    echo "🔄 Reiniciando no modo: $MODE"

    # Mata o processo do Steam se estiver rodando
    if pgrep -x "steam" > /dev/null; then
        echo "🛑 Parando Steam..."
        pkill -x steam
        sleep 3

        # Garante que foi fechado
        if pgrep -x "steam" > /dev/null; then
            echo "⚠️  Forçando fechamento do Steam..."
            pkill -9 -x steam
            sleep 2
        fi
    fi

    # Inicia o Steam com os mesmos argumentos
    echo "🚀 Iniciando Steam..."
    if [ -n "$NEW_ARGS" ]; then
        echo "📦 Comando: steam $NEW_ARGS"
        nohup steam $NEW_ARGS > /dev/null 2>&1 &
    else
        echo "📦 Comando: steam"
        nohup steam > /dev/null 2>&1 &
    fi

    STEAM_PID=$!
    sleep 5

    if ps -p $STEAM_PID > /dev/null 2>&1; then
        echo "✅ Steam reiniciado com sucesso no modo $MODE! (PID: $STEAM_PID)"
    else
        echo "⚠️  Steam pode não ter iniciado corretamente"
    fi
}

setup_shell_path() {
    echo "Configurando PATH automaticamente..."

    # Detecta o shell atual
    CURRENT_SHELL=$(basename "$SHELL")
    echo "Shell detectado: $CURRENT_SHELL"

    case "$CURRENT_SHELL" in
        "bash")
            SHELLRC="$HOME/.bashrc"
            PATH_CMD="export PATH=\"$SLSPATH:\$PATH\""
            ;;
        "zsh")
            SHELLRC="$HOME/.zshrc"
            PATH_CMD="export PATH=\"$SLSPATH:\$PATH\""
            ;;
        "fish")
            SHELLRC="$HOME/.config/fish/config.fish"
            PATH_CMD="set -gx PATH \"$SLSPATH\" \$PATH"
            ;;
        *)
            SHELLRC=""
            ;;
    esac

    if [ -n "$SHELLRC" ]; then
        # Cria o arquivo se não existir
        mkdir -p "$(dirname "$SHELLRC")"
        touch "$SHELLRC"

        if ! grep -q "$SLSPATH" "$SHELLRC"; then
            echo "$PATH_CMD" >> "$SHELLRC"
            echo "✅ PATH configurado automaticamente em $SHELLRC"
        else
            echo "✅ PATH já estava configurado em $SHELLRC"
        fi

        # Ativa o PATH imediatamente para a sessão atual
        echo "🔄 Ativando PATH na sessão atual..."
        if [ "$CURRENT_SHELL" = "fish" ]; then
            fish -c "set -gx PATH \"$SLSPATH\" \$PATH"
        else
            export PATH="$SLSPATH:$PATH"
        fi

    else
        echo "⚠️  Shell não suportado para configuração automática"
        echo "Adicione manualmente ao seu shell:"
        echo "export PATH=\"$SLSPATH:\$PATH\""
        return 1
    fi

    return 0
}

verify_installation() {
    echo ""
    echo "🔍 Verificando instalação..."

    local all_ok=true

    # Verifica se o wrapper foi criado
    if [ -f "$SLSPATH/steam" ]; then
        echo "✅ Wrapper do Steam: $SLSPATH/steam"
    else
        echo "❌ Wrapper do Steam não encontrado"
        all_ok=false
    fi

    # Verifica se a biblioteca foi copiada
    if [ -f "$SLSLIB" ]; then
        echo "✅ Biblioteca SLSsteam: $SLSLIB"
    else
        echo "❌ Biblioteca SLSsteam não encontrada"
        all_ok=false
    fi

    # Verifica modificação do steam-jupiter
    if [ -f "/usr/bin/steam-jupiter" ]; then
        if grep -q "LD_AUDIT=\"$SLSLIB\"" "/usr/bin/steam-jupiter"; then
            echo "✅ steam-jupiter modificado para modo Game"
        else
            echo "⚠️  steam-jupiter não modificado para modo Game"
            all_ok=false
        fi
    fi

    # Verifica backup
    if [ -f "$BACKUP_DIR/steam-jupiter" ]; then
        echo "✅ Backup criado em: $BACKUP_DIR/steam-jupiter"
    else
        echo "⚠️  Backup não encontrado"
    fi

    # Verifica se o PATH está configurado
    if echo "$PATH" | grep -q "$SLSPATH"; then
        echo "✅ PATH configurado corretamente"
    else
        echo "⚠️  PATH não configurado na sessão atual"
        all_ok=false
    fi

    # Verifica qual steam está sendo usado
    STEAM_PATH=$(command -v steam 2>/dev/null || echo "not found")
    if [ "$STEAM_PATH" = "$SLSPATH/steam" ]; then
        echo "✅ Usando wrapper do SLSsteam: $STEAM_PATH"
    else
        echo "⚠️  Ainda usando: $STEAM_PATH"
        all_ok=false
    fi

    if [ "$all_ok" = true ]; then
        echo "🎉 Todas as verificações passaram!"
    else
        echo "⚠️  Algumas verificações falharam"
    fi
}

uninstall() {
    echo "Iniciando desinstalação no SteamOS..."

    # Remove configuração do PATH dos arquivos de shell
    for shell_file in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
        if [ -f "$shell_file" ]; then
            if grep -q "$SLSPATH" "$shell_file"; then
                sed -i "\|$SLSPATH|d" "$shell_file"
                echo "✅ Removido PATH de $shell_file"
            fi
        fi
    done

    # Restaura steam-jupiter original
    restore_steam_jupiter

    # Remove arquivos de usuário
    rm -vf "$HOME/.config/fish/conf.d/SLSsteam.fish" 2>/dev/null
    rm -vf "$HOME/.local/share/applications/steam.desktop" 2>/dev/null
    rm -vf "$HOME/.local/share/applications/steam-native.desktop" 2>/dev/null

    # Remove diretório principal
    if [ -d "$SLSDIR" ]; then
        rm -rfv "$SLSDIR"
    fi

    # Remove do PATH atual
    export PATH=$(echo "$PATH" | sed "s|$SLSPATH:||")

    echo ""
    echo "✅ Desinstalação concluída!"
    echo "Reinicie o terminal para aplicar as mudanças."
    echo "O backup do steam-jupiter permanece em: $BACKUP_DIR/steam-jupiter"
}

install_wrapper() {
    EXE="$1"
    CUSTOM_PATH="$2"

    # Se um path customizado foi fornecido, usa ele
    if [ -n "$CUSTOM_PATH" ] && [ -f "$CUSTOM_PATH" ]; then
        FPATH="$CUSTOM_PATH"
    else
        # Paths padrão do SteamOS
        case "$EXE" in
            "steam")
                FPATH="/usr/bin/steam"
                ;;
            "steam-jupiter")
                FPATH="/usr/bin/steam-jupiter"
                ;;
            "steam-native")
                # Não existe no SteamOS, vamos pular
                echo "⚠️ steam-native não existe no SteamOS! Pulando"
                return 1
                ;;
            "steam-runtime")
                # Verifica se existe no SteamOS
                FPATH="$(command -v steam-runtime 2>/dev/null)"
                if [ -z "$FPATH" ]; then
                    echo "⚠️ steam-runtime não encontrado! Pulando"
                    return 1
                fi
                ;;
            *)
                FPATH="$(command -v "$EXE" 2>/dev/null)"
                ;;
        esac
    fi

    if [ -z "$FPATH" ] || [ ! -f "$FPATH" ]; then
        echo "❌ $EXE não encontrado em $FPATH! Pulando"
        return 1
    fi

    DIRNAME="$(dirname "$FPATH")"
    if [ "$DIRNAME" = "$SLSPATH" ]; then
        echo "✅ Wrapper $EXE já instalado! Pulando"
        return 0
    fi

    echo -e "#!/bin/sh\nLD_AUDIT=\"$SLSLIB\" \"$FPATH\" \"\$@\"" > "$SLSPATH/$EXE"
    chmod +x "$SLSPATH/$EXE"

    echo "✅ Wrapper criado para $FPATH em $SLSPATH/$EXE"
    return 0
}

install_desktop_file() {
    NAME="$1.desktop"
    USR_APP_DIR="$HOME/.local/share/applications"
    APP_DIR="/usr/share/applications"

    # Verifica se o arquivo existe
    if [ ! -f "$APP_DIR/$NAME" ]; then
        echo "⚠️ $NAME não encontrado em $APP_DIR! Pulando"
        return 1
    fi

    # Cria diretório se não existir
    if [ ! -d "$USR_APP_DIR" ]; then
        mkdir -p "$USR_APP_DIR"
        if [ $? -ne 0 ]; then
            echo "❌ Falha ao criar $USR_APP_DIR! Pulando .desktop"
            return 1
        fi
    fi

    # Copia o arquivo
    cp "$APP_DIR/$NAME" "$USR_APP_DIR/"
    
    # Modifica a linha Exec para usar LD_AUDIT
    sed -i "s|^Exec=.*|Exec=env LD_AUDIT=\"$SLSLIB\" /usr/bin/steam|" "$USR_APP_DIR/$NAME"

    echo "✅ Criado $USR_APP_DIR/$NAME"
    return 0
}

install_slssteam() {
    LIB="./bin/SLSsteam.so"
    if [ ! -f "$LIB" ]; then
        echo "❌ Erro: bin/SLSsteam.so não encontrado!"
        echo "Execute o script no diretório correto."
        exit 1
    fi

    # Cria diretórios necessários
    mkdir -p "$SLSDIR" "$SLSPATH"
    if [ $? -ne 0 ]; then
        echo "❌ Erro: Não foi possível criar diretórios em $SLSDIR"
        exit 1
    fi

    # Copia a biblioteca
    cp -v "$LIB" "$SLSLIB"
    echo "✅ Biblioteca SLSsteam instalada em $SLSLIB"
}

install_all() {
    echo "🚀 Instalando SLSsteam no SteamOS (nova versão)..."
    echo "=========================================="
    echo "🔧 Esta instalação funcionará em:"
    echo "   - Modo Desktop (steam wrapper)"
    echo "   - Modo Game (steam-jupiter modificado)"
    echo "=========================================="

    check_steamos_deps || exit 1
    find_steam_paths || exit 1

    # Instala componentes básicos
    install_slssteam
    setup_shell_path

    # Cria backup do steam-jupiter
    backup_steam_jupiter

    # Modifica steam-jupiter para modo Game
    modify_steam_jupiter

    # Instala wrappers para Steam (como no setup.sh original)
    echo ""
    echo "🔧 Instalando wrappers..."
    install_wrapper "steam"
    install_wrapper "steam-runtime"
    # steam-native não existe no SteamOS
    
    # Configura arquivos .desktop (como no setup.sh original)
    echo ""
    echo "🖥️  Configurando arquivos .desktop..."
    install_desktop_file "steam"
    install_desktop_file "steam-native"

    # Verifica instalação
    verify_installation

    # Reinicia o Steam automaticamente
    echo ""
    read -p "🔄 Deseja reiniciar o Steam automaticamente? (s/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        restart_steam
    else
        echo ""
        echo "⚠️  Lembre-se de reiniciar o Steam manualmente para aplicar as mudanças!"
        echo "   Você pode reiniciar depois com: killall steam && steam"
    fi

    echo ""
    echo "✅ Instalação concluída com sucesso!"
    echo ""
    echo "📋 Resumo da instalação:"
    echo "   • Biblioteca SLSsteam: $SLSLIB"
    echo "   • Wrapper Steam (Desktop): $SLSPATH/steam"
    echo "   • Wrapper Steam Runtime: $SLSPATH/steam-runtime"
    echo "   • steam-jupiter modificado (Game): /usr/bin/steam-jupiter"
    echo "   • Arquivos .desktop modificados em: $HOME/.local/share/applications/"
    echo "   • Backup steam-jupiter: $BACKUP_DIR/steam-jupiter"
    echo ""
    echo "🎮 Agora o SLSsteam funcionará em ambos os modos!"
}

# Menu principal
if [ $# -lt 1 ]; then
    echo "Uso: $0 install|uninstall"
    echo ""
    echo "Este script foi adaptado para SteamOS com automação completa"
    echo "Inclui suporte para Modo Desktop e Modo Game"
    echo "Baseado na nova versão do SLSsteam (sem configuração manual)"
    exit 0
fi

case "$1" in
    "install")
        install_all
        ;;
    "uninstall")
        uninstall
        ;;
    *)
        echo "Comando desconhecido: $1"
        echo "Uso: $0 install|uninstall"
        exit 1
        ;;
esac