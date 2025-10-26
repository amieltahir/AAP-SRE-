#!/bin/bash
# lab1.1_aap_health_check.sh

echo "==============================================="
echo "AAP Health Check - Supervisord Environment"
echo "==============================================="

# 1. Check supervisord status
echo "=== Supervisord Status ==="
sudo supervisorctl status

# 2. Check process counts
echo -e "\n=== Process Counts ==="
echo "UWSGI workers: $(pgrep -f "uwsgi" | wc -l)"
echo "Callback receivers: $(pgrep -f "run_callback_receiver" | wc -l)"
echo "Dispatchers: $(pgrep -f "run_dispatcher" | wc -l)"
echo "Total AAP processes: $(pgrep -f "awx" | wc -l)"

# 3. Check system resources
echo -e "\n=== System Resources ==="
echo "Memory usage:"
ps aux --sort=-%mem | head -10
echo -e "\nDisk space:"
df -h / /var /tmp

# 4. Check API connectivity
echo -e "\n=== API Health ==="
if curl -k -s https://localhost/api/v2/ping/ > /dev/null; then
    echo "✓ API is responsive"
    # Get version info
    VERSION=$(curl -k -s https://localhost/api/v2/config/ | jq -r '.version  // "unknown"')
    echo "✓ AAP Version: $VERSION"
else
    echo "✗ API is not responsive"
fi

# 5. Check web interface
echo -e "\n=== Web Interface ==="
if curl -k -s https://localhost/ > /dev/null; then
    echo "✓ Web interface is accessible"
else
    echo "✗ Web interface is not accessible"
fi

# 6. Check critical ports
echo -e "\n=== Network Ports ==="
sudo netstat -tulpn | grep -E ":80|:443" | head -10

# 7. Check logs for errors
echo -e "\n=== Recent Errors ==="
sudo tail -20 /var/log/supervisor/supervisord.log | grep -i error || echo "No recent errors found"
