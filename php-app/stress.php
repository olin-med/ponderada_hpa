<?php
// Endpoint para gerar carga CPU/Memória para testar o HPA
header('Content-Type: application/json');

// Parâmetros de entrada
$cpu_cores = isset($_GET['cpu']) ? (int)$_GET['cpu'] : 1;
$duration = isset($_GET['duration']) ? (int)$_GET['duration'] : 30;
$memory_mb = isset($_GET['memory']) ? (int)$_GET['memory'] : 0;
$action = isset($_GET['action']) ? $_GET['action'] : 'stress';

// Limitar valores para segurança
$cpu_cores = min(max($cpu_cores, 1), 8);
$duration = min(max($duration, 5), 300); // máximo 5 minutos
$memory_mb = min(max($memory_mb, 0), 500); // máximo 500MB

$response = [
    'hostname' => gethostname(),
    'timestamp' => date('c'),
    'action' => $action,
    'parameters' => [
        'cpu_cores' => $cpu_cores,
        'duration' => $duration,
        'memory_mb' => $memory_mb
    ]
];

switch ($action) {
    case 'health':
        $response['status'] = 'healthy';
        $response['uptime'] = uptime();
        break;
        
    case 'info':
        $response['system_info'] = getSystemInfo();
        break;
        
    case 'stress':
    default:
        $response['message'] = "Iniciando teste de carga: {$cpu_cores} CPU cores por {$duration}s";
        if ($memory_mb > 0) {
            $response['message'] .= " + {$memory_mb}MB memory";
        }
        
        $start_time = time();
        
        // Stress de CPU
        if ($cpu_cores > 0) {
            cpuStress($cpu_cores, $duration);
        }
        
        // Stress de memória
        if ($memory_mb > 0) {
            memoryStress($memory_mb);
        }
        
        $end_time = time();
        $response['execution_time'] = $end_time - $start_time;
        $response['status'] = 'completed';
        break;
}

echo json_encode($response, JSON_PRETTY_PRINT);

function cpuStress($cores, $duration) {
    $end_time = time() + $duration;
    
    // Simular carga de CPU
    while (time() < $end_time) {
        // Operações matemáticas intensivas
        for ($i = 0; $i < 1000000; $i++) {
            $result = sqrt($i) * sin($i) * cos($i);
        }
        
        // Pequena pausa para não sobrecarregar completamente
        usleep(1000); // 1ms
    }
}

function memoryStress($mb) {
    $bytes = $mb * 1024 * 1024;
    $data = [];
    
    try {
        // Alocar memória em chunks
        $chunk_size = 1024 * 1024; // 1MB chunks
        $chunks = $bytes / $chunk_size;
        
        for ($i = 0; $i < $chunks; $i++) {
            $data[] = str_repeat('A', $chunk_size);
        }
        
        // Manter na memória por alguns segundos
        sleep(10);
        
        // Limpar memória
        unset($data);
        
    } catch (Exception $e) {
        error_log("Memory stress error: " . $e->getMessage());
    }
}

function getSystemInfo() {
    $info = [];
    
    // Load average
    $load = sys_getloadavg();
    $info['load_average'] = [
        '1min' => $load[0],
        '5min' => $load[1],
        '15min' => $load[2]
    ];
    
    // Memory info
    if (file_exists('/proc/meminfo')) {
        $meminfo = file_get_contents('/proc/meminfo');
        preg_match('/MemTotal:\s+(\d+)/', $meminfo, $matches);
        $info['memory_total_mb'] = isset($matches[1]) ? round($matches[1] / 1024) : null;
        
        preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $matches);
        $info['memory_available_mb'] = isset($matches[1]) ? round($matches[1] / 1024) : null;
    }
    
    // CPU info
    if (file_exists('/proc/cpuinfo')) {
        $cpuinfo = file_get_contents('/proc/cpuinfo');
        $info['cpu_cores'] = substr_count($cpuinfo, 'processor');
    }
    
    $info['php_memory_limit'] = ini_get('memory_limit');
    $info['php_memory_usage_mb'] = round(memory_get_usage(true) / 1024 / 1024, 2);
    
    return $info;
}

function uptime() {
    if (file_exists('/proc/uptime')) {
        $uptime_seconds = (float)file_get_contents('/proc/uptime');
        return round($uptime_seconds, 2);
    }
    return null;
}
?>
