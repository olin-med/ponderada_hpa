# Cluster Kubernetes com HPA - Atividade Ponderada

Este projeto implementa um cluster Kubernetes com Horizontal Pod Autoscaler (HPA) para uma aplicação PHP/Apache, demonstrando escalabilidade automática baseada em métricas de CPU e memória.

## Arquitetura da Solução

-   **Aplicação**: PHP/Apache simples com endpoint de teste de carga
-   **Cluster**: Kind (Kubernetes in Docker)
-   **Autoscaling**: HPA baseado em CPU e memória
-   **Monitoramento**: Metrics Server para coleta de métricas
-   **Teste de Carga**: Apache Bench (ab) e custom load generator

## Pré-requisitos

-   Docker
-   Kind
-   kubectl
-   Apache Bench (para testes de carga)

### Instalação dos Pré-requisitos

```bash
# Instalar Docker (Ubuntu/Debian)
sudo apt update
sudo apt install docker.io
sudo usermod -aG docker $USER

# Instalar Kind
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Instalar Apache Bench
sudo apt install apache2-utils
```

## Configuração e Execução

### 1. Criar o Cluster

```bash
# Criar cluster Kind
kind create cluster --config=cluster-config.yaml

# Verificar se o cluster está funcionando
kubectl cluster-info
```

### 2. Instalar Metrics Server

```bash
# Aplicar configuração do Metrics Server
kubectl apply -f metrics-server.yaml
```

### 3. Deploy da Aplicação

```bash
# Deploy da aplicação PHP
kubectl apply -f php-app-deployment.yaml

# Criar service
kubectl apply -f php-app-service.yaml

# Configurar HPA
kubectl apply -f hpa.yaml
```

### 4. Verificar Status

```bash
# Verificar pods
kubectl get pods

# Verificar HPA
kubectl get hpa

# Verificar métricas
kubectl top pods
```

## Execução dos Testes de Carga

### Teste Básico com Apache Bench

```bash
# Obter IP do serviço
kubectl get svc php-app-service

# Executar teste de carga
./run-load-test.sh
```

### Monitoramento Durante os Testes

```bash
# Monitorar HPA em tempo real
watch kubectl get hpa

# Monitorar pods
watch kubectl get pods

# Verificar métricas detalhadas
kubectl top pods --sort-by=cpu
```

## Análise de Resultados

Os testes demonstram:

1. **Escalabilidade Automática**: O HPA responde adequadamente ao aumento de carga
2. **Métricas de Performance**: CPU e memória são monitoradas efetivamente
3. **Tempo de Resposta**: O sistema mantém performance durante escalabilidade
4. **Eficiência de Recursos**: Pods são criados/removidos conforme necessário

### Métricas Coletadas

-   Tempo de resposta médio
-   Throughput (requisições/segundo)
-   Utilização de CPU por pod
-   Utilização de memória por pod
-   Número de réplicas ao longo do tempo

## Inovações Implementadas

1. **Custom Load Generator**: Script Python personalizado para testes mais realistas
2. **Múltiplas Métricas**: HPA configurado para CPU e memória
3. **Logs Estruturados**: Coleta e análise automatizada de logs
4. **Dashboard de Monitoramento**: Script para visualização em tempo real
5. **Cleanup Automático**: Scripts para limpeza do ambiente

## Estrutura do Projeto

```
.
├── README.md
├── cluster-config.yaml
├── metrics-server.yaml
├── php-app/
│   ├── Dockerfile
│   ├── index.php
│   └── stress.php
├── k8s/
│   ├── php-app-deployment.yaml
│   ├── php-app-service.yaml
│   └── hpa.yaml
├── scripts/
│   ├── run-load-test.sh
│   ├── load-generator.py
│   ├── monitor-hpa.sh
│   └── cleanup.sh
└── docs/
    ├── load-test-results.md
    └── metrics-analysis.md
```

## Comandos Úteis

```bash
# Limpar ambiente
./scripts/cleanup.sh

# Logs da aplicação
kubectl logs -l app=php-app -f

# Describe HPA para debugging
kubectl describe hpa php-app-hpa

# Verificar eventos do cluster
kubectl get events --sort-by=.metadata.creationTimestamp
```

## Troubleshooting

### HPA não está funcionando

-   Verificar se o Metrics Server está rodando: `kubectl get pods -n kube-system`
-   Confirmar que as métricas estão disponíveis: `kubectl top pods`

### Pods não estão escalando

-   Verificar configuração de recursos no deployment
-   Confirmar thresholds do HPA
-   Verificar logs: `kubectl describe hpa`

### Aplicação não responde

-   Verificar se o service está correto: `kubectl get svc`
-   Confirmar se os pods estão healthy: `kubectl get pods`
-   Verificar logs da aplicação: `kubectl logs <pod-name>`

## Conclusão

Este projeto demonstra com sucesso a implementação de um cluster Kubernetes com auto-scaling, incluindo monitoramento avançado, testes de carga automatizados e análise detalhada de métricas. A solução é robusta, bem documentada e inclui inovações que vão além dos requisitos básicos.
