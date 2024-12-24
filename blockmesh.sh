#!/bin/bash

INSTALL_DIR="$HOME/.blockmesh"
SCRIPT_PATH="$INSTALL_DIR/install.sh"

BANNER="
╔══════════════════════════════════════╗
║           BLOCKMESH NODE             ║
║         Installation Script          ║
║         Author: Nofan Rambe          ║
║           Version: 1.0.0             ║
╚══════════════════════════════════════╝
"

check_docker_status() {
    echo "╔═════════ System Status ═════════╗"
    if command -v docker &>/dev/null; then
        docker_version=$(docker --version | cut -d ' ' -f3 | tr -d ',')
        echo "║ Docker: ✅ v$docker_version"
    else
        echo "║ Docker: ❌ Not Installed"
    fi
    
    if command -v docker-compose &>/dev/null; then
        compose_version=$(docker-compose --version | cut -d ' ' -f3 | tr -d ',')
    else
        echo "║ Docker Compose: ❌ Not Installed"
    fi

    if [ "$(docker ps -q -f name=blockmesh-cli-container)" ]; then
        echo "║ BlockMesh Node: 🟢 Running      ║"
    elif [ "$(docker ps -aq -f name=blockmesh-cli-container)" ]; then
        echo "║ BlockMesh Node: 🔴 Stopped      ║"
    else
        echo "║ BlockMesh Node: ⚪ Not Deployed ║"
    fi
    echo "╚═══════════════════════════════════╝"
}

mkdir -p "$INSTALL_DIR"

if [ ! -f "$SCRIPT_PATH" ]; then
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
fi

if [ "$(id -u)" != "0" ]; then
    echo "⚠️  This script needs root privileges."
    echo "➜ Run: sudo -i"
    exit 1
fi

function main_menu() {
    while true; do
        clear
        echo -e "\033[36m$BANNER\033[0m"
        check_docker_status
        echo
        echo "╔═ Menu ═══════════════════╗"
        echo "║ 1. Deploy Node           ║"
        echo "║ 2. View Logs             ║"
        echo "║ 3. Exit                  ║"
        echo "╚══════════════════════════╝"

        read -p "Select option [1-3]: " option

        case $option in
            1) deploy_node ;;
            2) view_logs ;;
            3) 
                echo "👋 Goodbye!"
                exit 0 
                ;;
            *) 
                echo "❌ Invalid option"
                sleep 2
                ;;
        esac
    done
}

function deploy_node() {
    echo "🔄 System update..."
    apt update -y &>/dev/null && apt upgrade -y &>/dev/null

    rm -rf "$INSTALL_DIR/blockmesh-cli.tar.gz" "$INSTALL_DIR/target"

    if [ "$(docker ps -aq -f name=blockmesh-cli-container)" ]; then
        echo "🔄 Cleaning old container..."
        docker stop blockmesh-cli-container &>/dev/null
        docker rm blockmesh-cli-container &>/dev/null
    fi

    if ! command -v docker &>/dev/null; then
        echo "📦 Installing Docker..."
        apt-get install -y ca-certificates curl gnupg lsb-release &>/dev/null
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg &>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update &>/dev/null && apt-get install -y docker-ce docker-ce-cli containerd.io &>/dev/null
        echo "✅ Docker installed successfully"
    else
        echo "✅ Docker already installed"
    fi

    if ! command -v docker-compose &>/dev/null; then
        echo "📦 Installing Docker Compose..."
        curl -sL "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo "✅ Docker Compose installed successfully"
    else
        echo "✅ Docker Compose already installed"
    fi

    mkdir -p "$INSTALL_DIR/target/release"
    echo "📥 Downloading BlockMesh CLI..."
    curl -sL https://github.com/block-mesh/block-mesh-monorepo/releases/download/v0.0.358/blockmesh-cli-x86_64-unknown-linux-gnu.tar.gz -o "$INSTALL_DIR/blockmesh-cli.tar.gz"
    tar -xzf "$INSTALL_DIR/blockmesh-cli.tar.gz" --strip-components=3 -C "$INSTALL_DIR/target/release"

    if [[ ! -f "$INSTALL_DIR/target/release/blockmesh-cli" ]]; then
        echo "❌ Installation failed: CLI not found"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "\n👤 Enter your credentials:"
    read -p "Email: " email
    read -s -p "Password: " password
    echo

    echo "🚀 Launching BlockMesh node..."
    docker run -it --rm \
        --name blockmesh-cli-container \
        -v "$INSTALL_DIR/target/release:/app" \
        -e EMAIL="$email" \
        -e PASSWORD="$password" \
        --workdir /app \
        ubuntu ./blockmesh-cli --email "$email" --password "$password"

    read -p "Press Enter to continue..."
}

function view_logs() {
    echo "📜 Recent logs:"
    if ! docker logs --tail 50 blockmesh-cli-container 2>/dev/null; then
        echo "❌ No active container found"
    fi
    read -p "Press Enter to continue..."
}

main_menu
