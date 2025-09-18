#!/usr/bin/env python3
"""
Gerador de carga avançado para testes de HPA
Simula diferentes padrões de carga de trabalho
"""

import asyncio
import aiohttp
import argparse
import time
import json
import statistics
from typing import List, Dict, Any
from dataclasses import dataclass, asdict
from datetime import datetime
import logging

@dataclass
class LoadTestResult:
    timestamp: str
    response_time: float
    status_code: int
    error: str = None

@dataclass
class TestSummary:
    test_name: str
    duration: float
    total_requests: int
    successful_requests: int
    failed_requests: int
    avg_response_time: float
    min_response_time: float
    max_response_time: float
    p95_response_time: float
    requests_per_second: float

class LoadGenerator:
    def __init__(self, base_url: str, timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.results: List[LoadTestResult] = []

    async def make_request(self, session: aiohttp.ClientSession, endpoint: str) -> LoadTestResult:
        start_time = time.time()
        try:
            async with session.get(f"{self.base_url}{endpoint}") as response:
                await response.text()
                response_time = time.time() - start_time
                return LoadTestResult(
                    timestamp=datetime.now().isoformat(),
                    response_time=response_time,
                    status_code=response.status
                )
        except Exception as e:
            response_time = time.time() - start_time
            return LoadTestResult(
                timestamp=datetime.now().isoformat(),
                response_time=response_time,
                status_code=0,
                error=str(e)
            )

    async def burst_load(self, endpoint: str, requests: int, concurrency: int) -> List[LoadTestResult]:
        """Executa uma rajada de requisições"""
        connector = aiohttp.TCPConnector(limit=concurrency * 2)
        async with aiohttp.ClientSession(timeout=self.timeout, connector=connector) as session:
            semaphore = asyncio.Semaphore(concurrency)
            
            async def bounded_request():
                async with semaphore:
                    return await self.make_request(session, endpoint)
            
            tasks = [bounded_request() for _ in range(requests)]
            results = await asyncio.gather(*tasks)
            return results

    async def sustained_load(self, endpoint: str, duration: int, rps: int) -> List[LoadTestResult]:
        """Executa carga sustentada por um período"""
        end_time = time.time() + duration
        interval = 1.0 / rps
        
        connector = aiohttp.TCPConnector(limit=rps * 2)
        async with aiohttp.ClientSession(timeout=self.timeout, connector=connector) as session:
            results = []
            
            while time.time() < end_time:
                request_start = time.time()
                result = await self.make_request(session, endpoint)
                results.append(result)
                
                # Controlar taxa de requisições
                elapsed = time.time() - request_start
                sleep_time = max(0, interval - elapsed)
                if sleep_time > 0:
                    await asyncio.sleep(sleep_time)
            
            return results

    async def ramp_up_load(self, endpoint: str, duration: int, max_rps: int, steps: int = 10) -> List[LoadTestResult]:
        """Executa carga com aumento gradual"""
        step_duration = duration // steps
        step_rps_increase = max_rps / steps
        
        all_results = []
        
        for step in range(1, steps + 1):
            current_rps = int(step * step_rps_increase)
            logging.info(f"Step {step}/{steps}: {current_rps} RPS for {step_duration}s")
            
            results = await self.sustained_load(endpoint, step_duration, current_rps)
            all_results.extend(results)
        
        return all_results

    def analyze_results(self, results: List[LoadTestResult], test_name: str) -> TestSummary:
        """Analisa os resultados dos testes"""
        if not results:
            return TestSummary(
                test_name=test_name,
                duration=0,
                total_requests=0,
                successful_requests=0,
                failed_requests=0,
                avg_response_time=0,
                min_response_time=0,
                max_response_time=0,
                p95_response_time=0,
                requests_per_second=0
            )

        successful = [r for r in results if r.status_code == 200]
        failed = [r for r in results if r.status_code != 200]
        
        response_times = [r.response_time for r in successful]
        
        start_time = min(datetime.fromisoformat(r.timestamp) for r in results)
        end_time = max(datetime.fromisoformat(r.timestamp) for r in results)
        duration = (end_time - start_time).total_seconds()
        
        return TestSummary(
            test_name=test_name,
            duration=duration,
            total_requests=len(results),
            successful_requests=len(successful),
            failed_requests=len(failed),
            avg_response_time=statistics.mean(response_times) if response_times else 0,
            min_response_time=min(response_times) if response_times else 0,
            max_response_time=max(response_times) if response_times else 0,
            p95_response_time=statistics.quantiles(response_times, n=20)[18] if len(response_times) > 20 else 0,
            requests_per_second=len(results) / duration if duration > 0 else 0
        )

async def main():
    parser = argparse.ArgumentParser(description='Gerador de carga avançado para HPA')
    parser.add_argument('--url', required=True, help='URL base da aplicação')
    parser.add_argument('--test-type', choices=['burst', 'sustained', 'ramp'], default='burst',
                       help='Tipo de teste de carga')
    parser.add_argument('--requests', type=int, default=100, help='Número de requisições (burst)')
    parser.add_argument('--concurrency', type=int, default=10, help='Concorrência (burst)')
    parser.add_argument('--duration', type=int, default=60, help='Duração em segundos (sustained/ramp)')
    parser.add_argument('--rps', type=int, default=10, help='Requisições por segundo (sustained/ramp)')
    parser.add_argument('--steps', type=int, default=10, help='Número de passos (ramp)')
    parser.add_argument('--endpoint', default='/stress.php?cpu=2&duration=15', help='Endpoint para teste')
    parser.add_argument('--output', help='Arquivo para salvar resultados JSON')
    parser.add_argument('--verbose', action='store_true', help='Logs verbosos')
    
    args = parser.parse_args()
    
    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    generator = LoadGenerator(args.url)
    
    print(f"🚀 Iniciando teste de carga: {args.test_type}")
    print(f"   URL: {args.url}")
    print(f"   Endpoint: {args.endpoint}")
    
    start_time = time.time()
    
    if args.test_type == 'burst':
        print(f"   Requisições: {args.requests}")
        print(f"   Concorrência: {args.concurrency}")
        results = await generator.burst_load(args.endpoint, args.requests, args.concurrency)
    
    elif args.test_type == 'sustained':
        print(f"   Duração: {args.duration}s")
        print(f"   RPS: {args.rps}")
        results = await generator.sustained_load(args.endpoint, args.duration, args.rps)
    
    elif args.test_type == 'ramp':
        print(f"   Duração: {args.duration}s")
        print(f"   RPS máximo: {args.rps}")
        print(f"   Passos: {args.steps}")
        results = await generator.ramp_up_load(args.endpoint, args.duration, args.rps, args.steps)
    
    elapsed_time = time.time() - start_time
    
    # Análise dos resultados
    summary = generator.analyze_results(results, args.test_type)
    
    print(f"\n📊 Resultados do Teste:")
    print(f"   Tempo total: {elapsed_time:.2f}s")
    print(f"   Requisições totais: {summary.total_requests}")
    print(f"   Requisições bem-sucedidas: {summary.successful_requests}")
    print(f"   Requisições falhadas: {summary.failed_requests}")
    print(f"   Taxa de sucesso: {(summary.successful_requests/summary.total_requests*100):.1f}%")
    print(f"   Tempo médio de resposta: {summary.avg_response_time*1000:.2f}ms")
    print(f"   Tempo mín/máx: {summary.min_response_time*1000:.2f}ms / {summary.max_response_time*1000:.2f}ms")
    print(f"   P95: {summary.p95_response_time*1000:.2f}ms")
    print(f"   RPS efetivo: {summary.requests_per_second:.2f}")
    
    # Salvar resultados se especificado
    if args.output:
        output_data = {
            'summary': asdict(summary),
            'results': [asdict(r) for r in results]
        }
        with open(args.output, 'w') as f:
            json.dump(output_data, f, indent=2)
        print(f"   Resultados salvos em: {args.output}")

if __name__ == '__main__':
    asyncio.run(main())
