import time
import requests
import psycopg2
import re
import psutil

DB_PARAMS = {
    "dbname": "metrics_db",
    "user": "admin",
    "password": "admin123",
    "host": "postgres"
}

CADVISOR_URL = "http://cadvisor:8080/metrics"

previous_metrics = {}

def get_metrics():
    global previous_metrics

    response = requests.get(CADVISOR_URL)
    lines = response.text.split("\n")

    metrics = {}
    pattern = re.compile(r'name="(app\d+)"')  # Matches container names like app01, app02

    current_time = time.time()

    for line in lines:
        parts = line.split(" ")
        try:
            value = float(parts[-2])  # Extract metric value before timestamp
        except:
            continue  # Skip malformed lines
        
        if 'machine_cpu_cores' in line:
            CPU_CORES = value  # Total CPU cores of the host machine
        if 'machine_memory_bytes' in line:
            TOTAL_RAM_BYTES = value  # Total Memory that can be used by the container

        match = pattern.search(line)
        if match:
            container_name = match.group(1)
            
            if 'container_cpu_usage_seconds_total' in line:
                metrics.setdefault(container_name, {})["cpu_usage_total"] = value
            
            if 'container_memory_usage_bytes' in line:
                metrics.setdefault(container_name, {})["ram_usage"] = value
            
            if 'container_fs_usage_bytes' in line:
                metrics.setdefault(container_name, {})["disk_usage"] = value
            if 'container_fs_limit_bytes' in line:
                metrics.setdefault(container_name, {})["disk_limit"] = value

    # Convert to percentages
    for container, data in metrics.items():
        if "ram_usage" in data:
            data["ram_usage"] = (data["ram_usage"] / TOTAL_RAM_BYTES) * 100
        
        if "disk_usage" in data and "disk_limit" in data and data["disk_limit"] > 0:
            data["disk_usage"] = (data["disk_usage"] / data["disk_limit"]) * 100

        # CPU Usage Calculation
        if container in previous_metrics and "cpu_usage_total" in data:
            prev_data = previous_metrics[container]
            if "cpu_usage_total" in prev_data:
                cpu_usage_diff = data["cpu_usage_total"] - prev_data["cpu_usage_total"]
                time_diff = current_time - prev_data["timestamp"]

                if time_diff > 0:
                    data["cpu_usage"] = (cpu_usage_diff / (time_diff * CPU_CORES)) * 100
                else:
                    data["cpu_usage"] = 0  # Avoid division by zero

        # Store previous metrics
        data["timestamp"] = current_time

    previous_metrics = metrics.copy()

    return metrics

def store_metrics():
    conn = psycopg2.connect(**DB_PARAMS)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS metrics (
            id SERIAL PRIMARY KEY,
            container_name TEXT,
            cpu_usage FLOAT,
            ram_usage FLOAT,
            disk_usage FLOAT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()

    while True:
        metrics = get_metrics()
        for container, data in metrics.items():
            cursor.execute(
                "INSERT INTO metrics (container_name, cpu_usage, ram_usage, disk_usage) VALUES (%s, %s, %s, %s)",
                (container, data.get("cpu_usage", 0), data.get("ram_usage", 0), data.get("disk_usage", 0))
            )
        conn.commit()
        time.sleep(3)  # Every 3 seconds

if __name__ == "__main__":
    store_metrics()

