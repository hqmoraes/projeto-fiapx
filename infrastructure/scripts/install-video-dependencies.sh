#!/bin/bash

# Script para instalar dependências necessárias para geração de vídeos
# Uso: ./install-video-dependencies.sh

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_color $BLUE "🎬 Instalando dependências para geração de vídeos..."

# Detectar sistema operacional
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian
        print_color $YELLOW "📦 Detectado Ubuntu/Debian - usando apt"
        
        sudo apt update
        
        # Dependências principais
        sudo apt install -y \
            ffmpeg \
            xdotool \
            curl \
            bc \
            gnome-terminal \
            google-chrome-stable \
            espeak espeak-data \
            pulseaudio \
            x11-utils
            
        # Instalar kubectl se não estiver presente
        if ! command -v kubectl >/dev/null 2>&1; then
            print_color $YELLOW "📦 Instalando kubectl..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
        fi
        
    elif command -v yum >/dev/null 2>&1; then
        # RHEL/CentOS/Fedora
        print_color $YELLOW "📦 Detectado RHEL/CentOS/Fedora - usando yum"
        
        sudo yum update -y
        sudo yum install -y \
            ffmpeg \
            xdotool \
            curl \
            bc \
            gnome-terminal \
            google-chrome-stable \
            espeak \
            pulseaudio \
            xorg-x11-utils
            
    else
        print_color $YELLOW "⚠️  Sistema Linux não suportado automaticamente"
        print_color $YELLOW "💡 Instale manualmente: ffmpeg, xdotool, curl, bc, gnome-terminal"
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    print_color $YELLOW "📦 Detectado macOS - usando brew"
    
    if ! command -v brew >/dev/null 2>&1; then
        print_color $YELLOW "📦 Instalando Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    brew install ffmpeg
    brew install cliclick  # Alternativa ao xdotool no macOS
    brew install curl
    brew install bc
    brew install --cask google-chrome
    brew install espeak
    
    # Instalar kubectl se não estiver presente
    if ! command -v kubectl >/dev/null 2>&1; then
        brew install kubectl
    fi
    
else
    print_color $YELLOW "⚠️  Sistema operacional não suportado: $OSTYPE"
    exit 1
fi

print_color $GREEN "✅ Dependências instaladas com sucesso!"

# Verificar instalação
print_color $BLUE "🔍 Verificando instalação..."

deps_ok=true

if command -v ffmpeg >/dev/null 2>&1; then
    print_color $GREEN "✅ ffmpeg: $(ffmpeg -version | head -1)"
else
    print_color $RED "❌ ffmpeg não encontrado"
    deps_ok=false
fi

if command -v xdotool >/dev/null 2>&1 || command -v cliclick >/dev/null 2>&1; then
    print_color $GREEN "✅ Automação de mouse/teclado: OK"
else
    print_color $RED "❌ xdotool/cliclick não encontrado"
    deps_ok=false
fi

if command -v curl >/dev/null 2>&1; then
    print_color $GREEN "✅ curl: $(curl --version | head -1)"
else
    print_color $RED "❌ curl não encontrado"
    deps_ok=false
fi

if command -v kubectl >/dev/null 2>&1; then
    print_color $GREEN "✅ kubectl: $(kubectl version --client --short 2>/dev/null || echo 'instalado')"
else
    print_color $YELLOW "⚠️  kubectl não encontrado - configure manualmente"
fi

if command -v bc >/dev/null 2>&1; then
    print_color $GREEN "✅ bc: instalado"
else
    print_color $RED "❌ bc não encontrado"
    deps_ok=false
fi

echo ""

if [ "$deps_ok" = true ]; then
    print_color $GREEN "🎉 Todas as dependências estão prontas!"
    echo ""
    print_color $BLUE "📋 Próximos passos:"
    echo "1. Configure kubectl para seu cluster AWS:"
    echo "   kubectl config set-context --current --namespace=fiapx"
    echo ""
    echo "2. Configure SSH para AWS:"
    echo "   ssh-add ~/.ssh/keyPrincipal.pem"
    echo ""
    echo "3. Teste o script:"
    echo "   ./infrastructure/scripts/generate-demo-video.sh 10 --mode simulate"
    echo ""
    echo "4. Execute gravação completa:"
    echo "   ./infrastructure/scripts/generate-demo-video.sh 10"
else
    print_color $RED "❌ Algumas dependências falharam na instalação"
    echo "Verifique os erros acima e instale manualmente se necessário"
fi
