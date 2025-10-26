#!/bin/bash
# aap_service_control_fixed.sh

echo "==============================================="
echo "AAP Service Control - Supervisord Environment"
echo "==============================================="

# Function to control AAP services
control_aap() {
    local action=$1
    local service=$2
    
    case $action in
        "start")
            if [ -n "$service" ]; then
                echo "Starting $service..."
                sudo supervisorctl start $service
            else
                echo "Starting all AAP services..."
                sudo supervisorctl start all
            fi
            ;;
        "stop")
            if [ -n "$service" ]; then
                echo "Stopping $service..."
                sudo supervisorctl stop $service
            else
                echo "Stopping all AAP services..."
                sudo supervisorctl stop all
            fi
            ;;
        "restart")
            if [ -n "$service" ]; then
                echo "Restarting $service..."
                sudo supervisorctl restart $service
            else
                echo "Restarting all AAP services..."
                sudo supervisorctl restart all
            fi
            ;;
        "status")
            sudo supervisorctl status
            ;;
        *)
            echo "Usage: control_aap <start|stop|restart|status> [service_name]"
            return 1
            ;;
    esac
}

# Get the actual service names from supervisord
get_service_names() {
    sudo supervisorctl status | awk '{print $1}'
}

# Current status
echo "=== Current Status ==="
sudo supervisorctl status

# Test individual component control with CORRECT service names
echo -e "\n=== Testing Component Control ==="

# Get the actual service names
SERVICES=($(get_service_names))

# Test with a few key services (using their full names)
TEST_SERVICES=(
    "tower-processes:awx-uwsgi"
    "tower-processes:awx-dispatcher" 
    "tower-processes:awx-callback-receiver"
)

for service in "${TEST_SERVICES[@]}"; do
    echo "Testing restart of: $service"
    control_aap "restart" "$service"
    sleep 3
    echo "Status: $(sudo supervisorctl status | grep "$service")"
    echo "---"
done

# Test full restart
echo -e "\n=== Testing Full Restart ==="
control_aap "restart"
sleep 10

# Verify everything came back up
echo -e "\n=== Post-Restart Verification ==="
sudo supervisorctl status

# Check API health
echo -e "\n=== API Health Check ==="
for i in {1..6}; do
    if curl -k -s https://localhost/api/v2/ping/ > /dev/null; then
        echo "✓ API responsive after restart"
        break
    fi
    echo "Waiting for API... ($i/6)"
    sleep 10
done

# Show all available service names for future reference
echo -e "\n=== All Available Service Names ==="
get_service_names
