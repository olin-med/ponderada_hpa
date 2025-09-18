#!/bin/bash
# Script de setup completo do ambiente HPA

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${CYAN}[INFO] $1${NC}"
}

# Banner
echo -e "${BLUE}"
echo "🚀 ============================================="
echo "   SETUP CLUSTER KUBERNETES COM HPA"
echo "   Atividade Ponderada - Kubernetes + HPA"
echo "=============================================${NC}"
echo ""

# Verificar pré-requisitos
log "Verificando pré-requisitos..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        error "$1 não está instalado"
        echo -e "${YELLOW}Para instalar $1:${NC}"
        case $1 in
            docker)
                echo "  sudo apt update && sudo apt install docker.io"
                echo "  sudo usermod -aG docker \$USER"
                ;;
            kind)
                echo "  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
                echo "  chmod +x ./kind && sudo mv ./kind /usr/local/bin/"
                ;;
            kubectl)
                echo "  curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
                echo "  chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
                ;;
        esac
        exit 1
    fi
}

check_command docker
check_command kind
check_command kubectl

success "Todos os pré-requisitos estão instalados"

# Verificar se Docker está rodando
if ! docker info >/dev/null 2>&1; then
    error "Docker não está rodando. Execute: sudo systemctl start docker"
    exit 1
fi

# Limpeza de ambiente anterior (opcional)
if kind get clusters 2>/dev/null | grep -q "hpa-cluster"; then
    warning "Cluster 'hpa-cluster' já existe"
    read -p "Deseja remover o cluster existente? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removendo cluster existente..."
        kind delete cluster --name hpa-cluster
        success "Cluster anterior removido"
    else
        info "Usando cluster existente"
        CLUSTER_EXISTS=true
    fi
fi

# Criar cluster Kind
if [ "$CLUSTER_EXISTS" != "true" ]; then
    log "Criando cluster Kind..."
    kind create cluster --config=cluster-config.yaml
    success "Cluster Kind criado com sucesso"
    
    # Aguardar cluster estar pronto
    log "Aguardando cluster estar pronto..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    success "Cluster está pronto"
fi

# Verificar contexto do kubectl
log "Configurando contexto do kubectl..."
kubectl cluster-info --context kind-hpa-cluster
success "Contexto configurado"

# Construir imagem Docker da aplicação
log "Construindo imagem Docker da aplicação..."
docker build -t php-hpa-app:latest php-app/
success "Imagem Docker construída"

# Carregar imagem no cluster Kind
log "Carregando imagem no cluster Kind..."
kind load docker-image php-hpa-app:latest --name hpa-cluster
success "Imagem carregada no cluster"

# Instalar Metrics Server
log "Instalando Metrics Server..."
kubectl apply -f metrics-server.yaml
success "Metrics Server instalado"

# Aguardar Metrics Server estar pronto
log "Aguardando Metrics Server estar pronto..."
kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s
success "Metrics Server está pronto"

# Deploy da aplicação
log "Fazendo deploy da aplicação..."
kubectl apply -f k8s/php-app-deployment.yaml
kubectl apply -f k8s/php-app-service.yaml
success "Aplicação deployada"

# Aguardar pods estarem prontos
log "Aguardando pods da aplicação estarem prontos..."
kubectl wait --for=condition=Ready pod -l app=php-app --timeout=120s
success "Pods da aplicação estão prontos"

# Configurar HPA
log "Configurando HPA..."
kubectl apply -f k8s/hpa.yaml
success "HPA configurado"

# Aguardar HPA estar funcional
log "Aguardando HPA estar funcional..."
for i in {1..30}; do
    if kubectl get hpa php-app-hpa --no-headers 2>/dev/null | grep -v "<unknown>" >/dev/null 2>&1; then
        break
    fi
    if [ $i -eq 30 ]; then
        warning "HPA pode levar alguns minutos para coletar métricas iniciais"
    fi
    sleep 10
done

# Verificar status final
log "Verificando status do deployment..."
echo ""
info "Status dos Pods:"
kubectl get pods -l app=php-app

echo ""
info "Status dos Services:"
kubectl get svc -l app=php-app

echo ""
info "Status do HPA:"
kubectl get hpa php-app-hpa

echo ""
info "Métricas dos Pods (pode demorar alguns minutos para aparecer):"
kubectl top pods -l app=php-app 2>/dev/null || warning "Métricas ainda não disponíveis - aguarde alguns minutos"

# Teste de conectividade
log "Testando conectividade da aplicação..."
SERVICE_IP=$(kubectl get svc php-app-service -o jsonpath='{.spec.clusterIP}')
if kubectl run connectivity-test --image=curlimages/curl --rm -it --restart=Never -- curl -s "http://$SERVICE_IP/" >/dev/null 2>&1; then
    success "Aplicação está respondendo corretamente"
else
    warning "Aplicação pode estar ainda inicializando"
fi

# Informações finais
echo ""
echo -e "${GREEN}🎉 SETUP CONCLUÍDO COM SUCESSO! 🎉${NC}"
echo ""
echo -e "${CYAN}📋 Informações do Cluster:${NC}"
echo "   • Cluster Name: hpa-cluster"
echo "   • Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "   • Pods: $(kubectl get pods -l app=php-app --no-headers | wc -l)"
echo "   • Service IP: $SERVICE_IP"
echo ""
echo -e "${CYAN}🧪 Próximos Passos:${NC}"
echo ""
echo -e "${YELLOW}1. Executar testes de carga:${NC}"
echo "   ./scripts/run-load-test.sh"
echo ""
echo -e "${YELLOW}2. Monitorar HPA em tempo real:${NC}"
echo "   ./scripts/monitor-hpa.sh"
echo ""
echo -e "${YELLOW}3. Gerador de carga avançado:${NC}"
echo "   python3 scripts/load-generator.py --url http://$SERVICE_IP --test-type ramp --rps 50"
echo ""
echo -e "${YELLOW}4. Verificar status:${NC}"
echo "   kubectl get hpa,pods -l app=php-app"
echo ""
echo -e "${YELLOW}5. Ver logs da aplicação:${NC}"
echo "   kubectl logs -l app=php-app -f"
echo ""
echo -e "${YELLOW}6. Acessar aplicação (port-forward):${NC}"
echo "   kubectl port-forward svc/php-app-service 8080:80"
echo "   # Então acesse: http://localhost:8080"
echo ""
echo -e "${CYAN}🔧 Comandos Úteis:${NC}"
echo "   • Status geral: kubectl get all"
echo "   • Métricas: kubectl top pods"
echo "   • Eventos: kubectl get events --sort-by=.metadata.creationTimestamp"
echo "   • Cleanup: ./scripts/cleanup.sh"
echo ""
echo -e "${GREEN}Sistema pronto para testes de HPA! 🚀${NC}"
