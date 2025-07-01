# 🎬 Sistema de Geração Automatizada de Vídeos - FIAP-X

Este conjunto de scripts automatiza a criação de vídeos de apresentação do projeto FIAP-X, incluindo gravação de tela, geração de slides introdutórios e controle interativo.

## 📋 Scripts Disponíveis

### 1. 🎯 Script Principal de Geração
**Arquivo:** `generate-presentation-video.sh`

Automatiza a gravação completa do vídeo de apresentação baseado no roteiro estruturado.

#### Uso:
```bash
./generate-presentation-video.sh <minutos> [opções]
```

#### Parâmetros:
- `<minutos>`: Duração total do vídeo (1-60 minutos)

#### Opções:
- `--simulate`: Executa em modo simulação (sem gravação real)
- `--section <1-7>`: Grava apenas uma seção específica
- `--no-setup`: Pula verificações de conectividade
- `--keep-temp`: Mantém arquivos temporários
- `--help`: Exibe ajuda detalhada

#### Exemplos:
```bash
# Vídeo completo de 10 minutos
./generate-presentation-video.sh 10

# Simulação de 5 minutos (para testes)
./generate-presentation-video.sh 5 --simulate

# Apenas seção 3 (demonstração do usuário)
./generate-presentation-video.sh 10 --section 3

# Gravação sem verificações de setup
./generate-presentation-video.sh 8 --no-setup
```

### 2. 🛠️ Script de Configuração do Ambiente
**Arquivo:** `setup-video-recording.sh`

Instala dependências e configura o ambiente para gravação de vídeos.

#### Uso:
```bash
./setup-video-recording.sh
```

#### O que faz:
- Detecta a distribuição Linux automaticamente
- Instala dependências necessárias (ffmpeg, xdotool, etc.)
- Configura resolução de tela otimizada
- Configura captura de áudio
- Cria variáveis de ambiente
- Testa a configuração do sistema

#### Dependências instaladas:
- **FFmpeg**: Para gravação e processamento de vídeo
- **x11-utils**: Para captura de janelas (xwininfo)
- **xdotool**: Para automação de mouse/teclado
- **scrot/gnome-screenshot**: Para capturas de tela
- **ImageMagick**: Para processamento de imagens
- **PulseAudio**: Para captura de áudio
- **Firefox**: Browser para demonstrações

### 3. 🎮 Controlador Interativo
**Arquivo:** `video-recording-controller.sh`

Interface interativa para controlar gravações com menu visual.

#### Uso:
```bash
./video-recording-controller.sh
```

#### Funcionalidades:
- **Menu visual** com status em tempo real
- **Gravação por seções** (1-7) ou completa
- **Controles de gravação** (iniciar/parar/pausar)
- **Visualização de roteiros** por seção
- **Verificação de conectividade** automática
- **Configuração de port-forwards** para Grafana/Prometheus
- **Logs de gravação** em tempo real
- **Modo teste** com simulação

#### Interface:
```
╔════════════════════════════════════════════════════════════════╗
║           🎬 CONTROLADOR DE GRAVAÇÃO FIAP-X 🎬                ║
╚════════════════════════════════════════════════════════════════╝

📊 STATUS ATUAL:
  🔴 GRAVANDO - Seção 3
  ⏱️  Tempo: 2m30s / 60s
  📁 PID: 12345

🎯 OPÇÕES DISPONÍVEIS:
  📋 SEÇÕES:
    1) Documentação e Arquitetura (2 min)
    2) Ambiente e Infraestrutura (1.5 min)
    3) Demonstração Usuário (1 min)
    ...
```

### 4. 🎨 Gerador de Slides Introdutórios
**Arquivo:** `generate-intro-slides.sh`

Cria slides introdutórios profissionais para o vídeo.

#### Uso:
```bash
./generate-intro-slides.sh [opções]
```

#### Opções:
- `--slides-only`: Cria apenas os slides
- `--combine <video>`: Combina slides com vídeo existente
- `--help`: Exibe ajuda

#### Slides criados:
1. **Título Principal**: FIAP-X - Sistema de Processamento de Vídeos
2. **Equipe**: Apresentação do desenvolvedor e especializações
3. **Objetivos**: Metas e propósitos do projeto
4. **Arquitetura**: Diagrama visual dos microsserviços
5. **Stack Tecnológico**: Tecnologias utilizadas
6. **Métricas de Qualidade**: Cobertura de testes e certificações
7. **Agenda**: Estrutura da apresentação
8. **Transição**: "Vamos começar!"

#### Exemplos:
```bash
# Criar apenas slides introdutórios
./generate-intro-slides.sh --slides-only

# Combinar slides com vídeo principal
./generate-intro-slides.sh --combine /path/to/main-video.mp4
```

### 5. 📖 Roteiro Estruturado
**Arquivo:** `presentation-script.md`

Roteiro detalhado com timing, ações e narração para cada seção.

#### Estrutura:
- **7 seções principais** com timing específico
- **Scripts de narração** palavra por palavra
- **Comandos de suporte** para execução durante gravação
- **Checklist pré-gravação** para validação
- **URLs e dados** para demonstração

## 🎯 Seções do Vídeo

### 1. 📖 Documentação e Arquitetura (2 min)
- **Foco**: Apresentar arquitetura de microsserviços
- **Ações**: Navegar pela documentação técnica
- **Destaque**: Cobertura de testes 84.6%

### 2. 🏗️ Ambiente e Infraestrutura (1.5 min)
- **Foco**: Cluster Kubernetes na AWS
- **Ações**: SSH + comandos kubectl
- **Destaque**: Pods em execução e HPA

### 3. 👤 Demonstração Usuário (1 min)
- **Foco**: Interface web responsiva
- **Ações**: Cadastro e login no sistema
- **Destaque**: UX/UI moderna

### 4. 📤 Upload e Processamento (2 min)
- **Foco**: Processamento paralelo de vídeos
- **Ações**: Upload múltiplo + status em tempo real
- **Destaque**: Fila de jobs e notificações

### 5. 📊 Observabilidade (2 min)
- **Foco**: Monitoramento completo
- **Ações**: Prometheus + Grafana dashboards
- **Destaque**: Métricas business e infraestrutura

### 6. 🔄 CI/CD e Auto-scaling (1.5 min)
- **Foco**: Automação e escalabilidade
- **Ações**: GitHub Actions + simulação de carga
- **Destaque**: HPA em ação

### 7. 💾 Download dos Resultados (45s)
- **Foco**: Entrega final ao usuário
- **Ações**: Download ZIP + validação
- **Destaque**: Qualidade dos resultados

## 🚀 Fluxo de Uso Completo

### 1. Setup Inicial
```bash
# 1. Instalar dependências
./setup-video-recording.sh

# 2. Carregar configurações
source ~/.fiapx-video-config

# 3. Verificar ambiente
./video-recording-controller.sh
# Escolher opção 'c' para verificar conectividade
```

### 2. Preparação da Gravação
```bash
# Configurar port-forwards (via controlador)
./video-recording-controller.sh
# Escolher opção 'm' para configurar monitoramento

# Testar em modo simulação
./generate-presentation-video.sh 5 --simulate
```

### 3. Gravação
```bash
# Opção 1: Gravação completa automática
./generate-presentation-video.sh 10

# Opção 2: Gravação interativa por seções
./video-recording-controller.sh
# Navegar pelas opções 1-7 para gravar cada seção

# Opção 3: Gravação de seção específica
./generate-presentation-video.sh 10 --section 4
```

### 4. Pós-processamento
```bash
# Criar slides introdutórios
./generate-intro-slides.sh --slides-only

# Combinar slides com vídeo principal
./generate-intro-slides.sh --combine /path/to/main-video.mp4
```

## 📁 Estrutura de Arquivos

```
infrastructure/scripts/
├── generate-presentation-video.sh    # Script principal
├── setup-video-recording.sh          # Setup do ambiente
├── video-recording-controller.sh     # Controlador interativo
├── generate-intro-slides.sh          # Gerador de slides
├── presentation-script.md            # Roteiro detalhado
└── README-video-scripts.md           # Esta documentação

outputs/presentation-video/
├── fiapx-presentation-YYYYMMDD_HHMMSS.mp4  # Vídeo final
├── fiapx-intro-slides.mp4                  # Slides introdutórios
├── slides/                                 # Slides individuais
│   ├── slide_1.mp4
│   ├── slide_2.mp4
│   └── ...
└── temp/                                   # Arquivos temporários
    ├── section_1.mp4
    ├── section_2.mp4
    ├── grafana-pf.log
    └── prometheus-pf.log
```

## ⚙️ Configurações Avançadas

### Variáveis de Ambiente
O script `setup-video-recording.sh` cria `~/.fiapx-video-config`:

```bash
export DISPLAY=${DISPLAY:-:0}
export FIAPX_VIDEO_QUALITY=high
export FIAPX_VIDEO_FPS=30
export FIAPX_AUDIO_ENABLED=true
export FIAPX_SCREEN_RESOLUTION=1920x1080
export FIAPX_PROJECT_ROOT="/path/to/projeto-fiapx"
export FIAPX_OUTPUT_DIR="/path/to/outputs/presentation-video"
export FIAPX_AWS_HOST="worker.wecando.click"
export FIAPX_SSH_KEY="$HOME/.ssh/keyPrincipal.pem"
export FIAPX_FRONTEND_URL="https://fiapx.wecando.click"
```

### Personalização de Timing
Para ajustar a duração das seções, edite a função `calculate_section_timing()` em `generate-presentation-video.sh`:

```bash
calculate_section_timing() {
    local section=$1
    case $section in
        1) echo 120 ;;  # 2 minutos
        2) echo 90 ;;   # 1.5 minutos
        3) echo 60 ;;   # 1 minuto
        # ... customize conforme necessário
    esac
}
```

### Qualidade de Vídeo
Para ajustar qualidade, modifique os parâmetros do FFmpeg:

```bash
# Alta qualidade (arquivo maior)
ffmpeg -f x11grab -s 1920x1080 -r 60 -i :0.0 -c:v libx264 -preset slow -crf 18

# Qualidade equilibrada (recomendado)
ffmpeg -f x11grab -s 1920x1080 -r 30 -i :0.0 -c:v libx264 -preset medium -crf 23

# Qualidade menor (arquivo menor)
ffmpeg -f x11grab -s 1920x1080 -r 24 -i :0.0 -c:v libx264 -preset fast -crf 28
```

## 🔧 Troubleshooting

### Problemas Comuns

#### 1. FFmpeg não encontrado
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install ffmpeg

# CentOS/RHEL/Fedora
sudo dnf install ffmpeg  # ou yum install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg
```

#### 2. Erro de captura de tela
```bash
# Verificar DISPLAY
echo $DISPLAY

# Testar captura manual
scrot test.png
# ou
gnome-screenshot -f test.png
```

#### 3. Port-forwards não funcionam
```bash
# Verificar pods do monitoring
kubectl get pods -n monitoring

# Recriar port-forwards
pkill -f "kubectl port-forward"
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring &
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &
```

#### 4. SSH para AWS falha
```bash
# Verificar chave SSH
ls -la ~/.ssh/keyPrincipal.pem
chmod 600 ~/.ssh/keyPrincipal.pem

# Testar conexão
ssh -i ~/.ssh/keyPrincipal.pem ubuntu@worker.wecando.click "echo 'Conexão OK'"
```

#### 5. Resolução inadequada
```bash
# Verificar resolução atual
xdpyinfo | grep dimensions

# Listar resoluções disponíveis
xrandr

# Configurar resolução (exemplo)
xrandr --output HDMI-1 --mode 1920x1080
```

### Logs e Debug

#### Habilitar logs detalhados
```bash
# Executar com debug
set -x
./generate-presentation-video.sh 10 --simulate
set +x
```

#### Verificar logs de gravação
```bash
# Logs dos port-forwards
tail -f outputs/presentation-video/temp/grafana-pf.log
tail -f outputs/presentation-video/temp/prometheus-pf.log

# Logs do sistema
journalctl -f -u display-manager
```

## 📈 Otimizações de Performance

### Para Gravações Longas
- Use `--keep-temp` para manter arquivos intermediários
- Grave seções separadamente para reduzir uso de memória
- Configure swap adequado no sistema

### Para Arquivos Menores
- Reduza FPS de 30 para 24
- Use preset FFmpeg mais rápido (`-preset fast`)
- Aumente CRF para menor qualidade (`-crf 28`)

### Para Melhor Qualidade
- Use resolução 4K se disponível
- Configure FPS 60 para demonstrações fluidas
- Use preset lento (`-preset slow`) com CRF baixo (`-crf 18`)

## 🎯 Próximas Melhorias

### Funcionalidades Planejadas
- [ ] Gravação de áudio com narração automática
- [ ] Integração com OBS Studio para streaming
- [ ] Templates de slides customizáveis
- [ ] Geração de legendas automáticas
- [ ] Upload automático para YouTube/Vimeo
- [ ] Notificações via Slack/Teams
- [ ] Dashboard web para controle remoto
- [ ] Suporte a múltiplos monitores
- [ ] Integração com Terraform para infra

### Melhorias Técnicas
- [ ] Containerização dos scripts
- [ ] CI/CD para os próprios scripts
- [ ] Testes automatizados
- [ ] Documentação interativa
- [ ] Suporte a Windows/macOS
- [ ] Interface gráfica (GUI)
- [ ] API REST para controle remoto

## 📞 Suporte

Para problemas ou sugestões:

1. **Verifique os logs** em `outputs/presentation-video/temp/`
2. **Execute em modo simulação** primeiro
3. **Consulte o troubleshooting** acima
4. **Abra uma issue** no repositório do projeto

---

**📝 Última atualização:** 30/06/2025  
**✅ Status:** Scripts testados e funcionais  
**🎬 Duração recomendada:** 10 minutos para apresentação completa
