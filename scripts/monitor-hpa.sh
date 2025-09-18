#!/bin/bash
# Script para monitorar HPA em tempo real

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para limpar a tela
clear_screen() {
    clear
}

# Função para mostrar header
show_header() {
    echo -e "${BLUE}=================================="
    echo -e "🚀 HPA Monitor - $(date)"
    echo -e "==================================${NC}"
    echo ""
}

# Função para mostrar status do HPA
show_hpa_status() {
    echo -e "${CYAN}📊 Status do HPA:${NC}"
    kubectl get hpa php-app-hpa --no-headers 2>/dev/null | while read line; do
        if [ ! -z "$line" ]; then
            echo -e "${GREEN}   $line${NC}"
        fi
    done
    echo ""
}

# Função para mostrar pods
show_pods() {
    echo -e "${CYAN}🔧 Pods Ativos:${NC}"
    kubectl get pods -l app=php-app --no-headers 2>/dev/null | while read line; do
        if [[ $line == *"Running"* ]]; then
            echo -e "${GREEN}   $line${NC}"
        elif [[ $line == *"Pending"* ]] || [[ $line == *"ContainerCreating"* ]]; then
            echo -e "${YELLOW}   $line${NC}"
        else
            echo -e "${RED}   $line${NC}"
        fi
    done
    echo ""
}

# Função para mostrar métricas
show_metrics() {
    echo -e "${CYAN}📈 Métricas dos Pods:${NC}"
    if kubectl top pods -l app=php-app --no-headers 2>/dev/null | head -10; then
        echo ""
    else
        echo -e "${YELLOW}   Métricas não disponíveis ainda...${NC}"
        echo ""
    fi
}

# Função para mostrar eventos recentes
show_recent_events() {
    echo -e "${CYAN}📋 Eventos Recentes do HPA:${NC}"
    kubectl get events --field-selector involvedObject.name=php-app-hpa --sort-by='.lastTimestamp' --no-headers 2>/dev/null | tail -5 | while read line; do
        if [ ! -z "$line" ]; then
            echo -e "${YELLOW}   $line${NC}"
        fi
    done
    echo ""
}

# Função para mostrar summary
show_summary() {
    local pod_count=$(kubectl get pods -l app=php-app --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local hpa_info=$(kubectl get hpa php-app-hpa --no-headers 2>/dev/null | awk '{print $6, $7, $8}' || echo "N/A N/A N/A")
    
    echo -e "${CYAN}📊 Resumo:${NC}"
    echo -e "${GREEN}   Pods em execução: $pod_count${NC}"
    echo -e "${GREEN}   HPA Info: $hpa_info${NC}"
    echo ""
}

# Loop principal
main_loop() {
    local refresh_rate=${1:-5}
    
    echo -e "${GREEN}Iniciando monitor do HPA... (Ctrl+C para sair)${NC}"
    echo -e "${BLUE}Refresh rate: ${refresh_rate}s${NC}"
    echo ""
    
    while true; do
        clear_screen
        show_header
        show_summary
        show_hpa_status
        show_pods
        show_metrics
        show_recent_events
        
        echo -e "${BLUE}Próxima atualização em ${refresh_rate}s... (Ctrl+C para sair)${NC}"
        sleep $refresh_rate
    done
}

# Verificar argumentos
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Uso: $0 [refresh_rate]"
    echo ""
    echo "  refresh_rate: Intervalo de atualização em segundos (padrão: 5)"
    echo ""
    echo "Exemplos:"
    echo "  $0        # Atualiza a cada 5 segundos"
    echo "  $0 10     # Atualiza a cada 10 segundos"
    echo "  $0 2      # Atualiza a cada 2 segundos"
    exit 0
fi

# Verificar se kubectl está configurado
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}Erro: kubectl não está configurado ou cluster não está acessível${NC}"
    exit 1
fi

# Verificar se o HPA existe
if ! kubectl get hpa php-app-hpa >/dev/null 2>&1; then
    echo -e "${RED}Erro: HPA 'php-app-hpa' não encontrado${NC}"
    echo -e "${YELLOW}Certifique-se de que o HPA foi criado:${NC}"
    echo "  kubectl apply -f k8s/hpa.yaml"
    exit 1
fi

# Iniciar monitoramento
refresh_rate=${1:-5}

# Validar refresh rate
if ! [[ "$refresh_rate" =~ ^[0-9]+$ ]] || [ "$refresh_rate" -lt 1 ]; then
    echo -e "${RED}Erro: Refresh rate deve ser um número inteiro maior que 0${NC}"
    exit 1
fi

main_loop $refresh_rate
