#!/bin/bash
# Script para executar testes de carga no cluster Kubernetes

set -e

echo "🚀 Iniciando testes de carga do HPA..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Verificar se kubectl está configurado
if ! kubectl cluster-info >/dev/null 2>&1; then
    error "kubectl não está configurado ou cluster não está acessível"
    exit 1
fi

# Obter informações do serviço
SERVICE_IP=$(kubectl get svc php-app-service -o jsonpath='{.spec.clusterIP}')
NODE_PORT=$(kubectl get svc php-app-service -o jsonpath='{.spec.ports[0].nodePort}')

log "Service IP: $SERVICE_IP"
log "Node Port: $NODE_PORT"

# Verificar se o serviço está rodando
log "Verificando se a aplicação está respondendo..."
if ! kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s "http://$SERVICE_IP/stress.php?action=health" >/dev/null 2>&1; then
    error "Aplicação não está respondendo"
    exit 1
fi

success "Aplicação está respondendo"

# Estado inicial
log "Estado inicial do cluster:"
kubectl get pods -l app=php-app
kubectl get hpa php-app-hpa

# Teste 1: Carga leve
log "🔥 Teste 1: Carga leve (CPU ~30%)"
echo "Executando 50 requisições com 5 conexões concorrentes..."

kubectl run load-test-1 --image=curlimages/curl --rm -it --restart=Never -- sh -c "
for i in \$(seq 1 50); do
    curl -s \"http://$SERVICE_IP/stress.php?cpu=1&duration=10\" > /dev/null &
    if [ \$((i % 5)) -eq 0 ]; then
        wait
        echo \"Processed \$i requests\"
    fi
done
wait
echo 'Teste 1 concluído'
"

log "Aguardando 60 segundos para observar métricas..."
sleep 60

log "Estado após teste 1:"
kubectl get hpa php-app-hpa
kubectl get pods -l app=php-app

# Teste 2: Carga média
log "🔥 Teste 2: Carga média (CPU ~60%)"
echo "Executando 100 requisições com 10 conexões concorrentes..."

kubectl run load-test-2 --image=curlimages/curl --rm -it --restart=Never -- sh -c "
for i in \$(seq 1 100); do
    curl -s \"http://$SERVICE_IP/stress.php?cpu=2&duration=15\" > /dev/null &
    if [ \$((i % 10)) -eq 0 ]; then
        wait
        echo \"Processed \$i requests\"
    fi
done
wait
echo 'Teste 2 concluído'
"

log "Aguardando 90 segundos para observar escalabilidade..."
sleep 90

log "Estado após teste 2:"
kubectl get hpa php-app-hpa
kubectl get pods -l app=php-app

# Teste 3: Carga alta
log "🔥 Teste 3: Carga alta (CPU ~80% + Memory)"
echo "Executando 200 requisições com stress de CPU e memória..."

kubectl run load-test-3 --image=curlimages/curl --rm -it --restart=Never -- sh -c "
for i in \$(seq 1 200); do
    if [ \$((i % 2)) -eq 0 ]; then
        curl -s \"http://$SERVICE_IP/stress.php?cpu=3&duration=20&memory=100\" > /dev/null &
    else
        curl -s \"http://$SERVICE_IP/stress.php?cpu=2&duration=15\" > /dev/null &
    fi
    
    if [ \$((i % 15)) -eq 0 ]; then
        wait
        echo \"Processed \$i requests\"
    fi
done
wait
echo 'Teste 3 concluído'
"

log "Aguardando 120 segundos para observar escalabilidade máxima..."
sleep 120

log "Estado após teste 3:"
kubectl get hpa php-app-hpa
kubectl get pods -l app=php-app

# Teste de descalonamento
log "🔽 Aguardando descalonamento automático..."
echo "Parando carga e observando descalonamento por 5 minutos..."

for i in {1..10}; do
    sleep 30
    log "Minuto $((i/2)): $(kubectl get hpa php-app-hpa --no-headers | awk '{print $6}')"
    kubectl get pods -l app=php-app --no-headers | wc -l | xargs echo "Pods ativos:"
done

# Relatório final
log "📊 Relatório Final dos Testes"
echo "=================================="

log "HPA Status Final:"
kubectl describe hpa php-app-hpa

log "Pods Finais:"
kubectl get pods -l app=php-app -o wide

log "Métricas dos Pods:"
kubectl top pods -l app=php-app || warning "Métricas não disponíveis - aguarde alguns minutos"

log "Eventos do HPA:"
kubectl get events --field-selector involvedObject.name=php-app-hpa --sort-by='.lastTimestamp' | tail -20

success "Testes de carga concluídos!"
echo ""
echo "📈 Para monitoramento contínuo, execute:"
echo "   watch kubectl get hpa,pods -l app=php-app"
echo ""
echo "📊 Para ver métricas detalhadas:"
echo "   kubectl top pods -l app=php-app"
echo ""
echo "🔍 Para logs detalhados:"
echo "   kubectl logs -l app=php-app -f"
