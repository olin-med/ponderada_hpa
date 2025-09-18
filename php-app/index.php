<?php
// Página principal da aplicação PHP para teste de HPA
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HPA Test Application</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background-color: #f5f5f5;
        }
        .container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .info-box {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .load-test {
            background: #fff3e0;
            padding: 15px;
            border-radius: 4px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 HPA Test Application</h1>
        
        <div class="info-box">
            <h3>Informações do Servidor</h3>
            <p><strong>Hostname:</strong> <?php echo gethostname(); ?></p>
            <p><strong>Server IP:</strong> <?php echo $_SERVER['SERVER_ADDR'] ?? 'N/A'; ?></p>
            <p><strong>Client IP:</strong> <?php echo $_SERVER['REMOTE_ADDR'] ?? 'N/A'; ?></p>
            <p><strong>Timestamp:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
            <p><strong>Load Average:</strong> <?php echo sys_getloadavg()[0]; ?></p>
        </div>

        <div class="load-test">
            <h3>🔥 Teste de Carga</h3>
            <p>Use os endpoints abaixo para testar o HPA:</p>
            <ul>
                <li><a href="/stress.php?cpu=1&duration=30" target="_blank">/stress.php?cpu=1&duration=30</a> - CPU stress moderado (30s)</li>
                <li><a href="/stress.php?cpu=2&duration=60" target="_blank">/stress.php?cpu=2&duration=60</a> - CPU stress alto (60s)</li>
                <li><a href="/stress.php?memory=50" target="_blank">/stress.php?memory=50</a> - Memory stress (50MB)</li>
            </ul>
        </div>

        <div class="info-box">
            <h3>📊 Métricas de Sistema</h3>
            <?php
            // Informações de memória
            $meminfo = file_get_contents('/proc/meminfo');
            preg_match('/MemTotal:\s+(\d+)/', $meminfo, $matches);
            $total_memory = isset($matches[1]) ? round($matches[1] / 1024) : 'N/A';
            
            preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $matches);
            $available_memory = isset($matches[1]) ? round($matches[1] / 1024) : 'N/A';
            ?>
            <p><strong>Total Memory:</strong> <?php echo $total_memory; ?> MB</p>
            <p><strong>Available Memory:</strong> <?php echo $available_memory; ?> MB</p>
            <p><strong>PHP Version:</strong> <?php echo phpversion(); ?></p>
            <p><strong>Apache Version:</strong> <?php echo apache_get_version(); ?></p>
        </div>

        <div class="info-box">
            <h3>🎯 Endpoints Disponíveis</h3>
            <ul>
                <li><strong>GET /</strong> - Esta página principal</li>
                <li><strong>GET /stress.php</strong> - Endpoint para teste de carga</li>
                <li><strong>GET /health</strong> - Health check (implementado no stress.php)</li>
            </ul>
        </div>

        <h3>📝 Contadores de Requisições</h3>
        <?php
        // Simular contador de requisições
        $counter_file = '/tmp/request_counter.txt';
        $counter = 1;
        
        if (file_exists($counter_file)) {
            $counter = (int)file_get_contents($counter_file) + 1;
        }
        
        file_put_contents($counter_file, $counter);
        ?>
        <p>Esta é a requisição número: <strong><?php echo $counter; ?></strong> para este pod.</p>
    </div>
</body>
</html>
