#!/bin/bash
# Script para limpeza completa do ambiente

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}🧹 Iniciando limpeza do ambiente...${NC}"

# Verificar se kubectl está configurado
if ! kubectl cluster-info >/dev/null 2>&1; then
    warning "kubectl não está configurado - pulando limpeza do Kubernetes"
else
    log "Removendo recursos do Kubernetes..."
    
    # Remover HPA
    if kubectl get hpa php-app-hpa >/dev/null 2>&1; then
        kubectl delete hpa php-app-hpa
        success "HPA removido"
    fi
    
    # Remover services
    if kubectl get svc php-app-service >/dev/null 2>&1; then
        kubectl delete svc php-app-service
        success "Service php-app-service removido"
    fi
    
    if kubectl get svc php-app-service-lb >/dev/null 2>&1; then
        kubectl delete svc php-app-service-lb
        success "Service php-app-service-lb removido"
    fi
    
    # Remover deployment
    if kubectl get deployment php-app >/dev/null 2>&1; then
        kubectl delete deployment php-app
        success "Deployment removido"
    fi
    
    # Aguardar pods terminarem
    log "Aguardando pods terminarem..."
    kubectl wait --for=delete pods -l app=php-app --timeout=60s 2>/dev/null || true
    
    # Remover pods de teste que possam ter ficado
    kubectl delete pods -l run=curl-test --ignore-not-found=true
    kubectl delete pods -l run=load-test-1 --ignore-not-found=true
    kubectl delete pods -l run=load-test-2 --ignore-not-found=true
    kubectl delete pods -l run=load-test-3 --ignore-not-found=true
    
    success "Recursos do Kubernetes removidos"
fi

# Remover imagens Docker locais
log "Removendo imagens Docker..."
if docker images | grep -q "php-hpa-app"; then
    docker rmi php-hpa-app:latest || warning "Não foi possível remover imagem php-hpa-app:latest"
    success "Imagem Docker removida"
fi

# Verificar se o cluster Kind existe
if kind get clusters 2>/dev/null | grep -q "hpa-cluster"; then
    log "Removendo cluster Kind..."
    kind delete cluster --name hpa-cluster
    success "Cluster Kind removido"
else
    warning "Cluster Kind 'hpa-cluster' não encontrado"
fi

# Limpeza de arquivos temporários (opcional)
log "Limpando arquivos temporários..."
rm -f /tmp/load-test-results-*.json 2>/dev/null || true
rm -f /tmp/hpa-metrics-*.log 2>/dev/null || true

# Verificar se existem containers Docker relacionados rodando
if docker ps -a | grep -q "kindest/node"; then
    log "Removendo containers Kind restantes..."
    docker ps -a | grep "kindest/node" | awk '{print $1}' | xargs docker rm -f 2>/dev/null || true
fi

success "🎉 Limpeza concluída!"

echo ""
echo -e "${BLUE}Para recriar o ambiente, execute:${NC}"
echo "1. kind create cluster --config=cluster-config.yaml"
echo "2. docker build -t php-hpa-app:latest php-app/"
echo "3. kind load docker-image php-hpa-app:latest --name hpa-cluster"
echo "4. kubectl apply -f metrics-server.yaml"
echo "5. kubectl apply -f k8s/"
echo ""
echo -e "${GREEN}Ambiente limpo com sucesso! ✨${NC}"
