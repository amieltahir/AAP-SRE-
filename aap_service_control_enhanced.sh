#!/bin/bash
# aap_service_control_enhanced.sh

echo "==============================================="
echo "AAP Service Control - Enhanced Version"
echo "==============================================="

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to control AAP services with validation
control_aap() {
    local action=$1
    local service=$2
    
    # Validate service exists if specified
    if [ -n "$service" ]; then
        if ! sudo supervisorctl status | grep -q "$service"; then
            echo -e "${RED}Error: Service '$service' not found${NC}"
            echo "Available services:"
            get_service_names
            return 1
        fi
    fi
    
    case $action in
        "start")
            if [ -n "$service" ]; then
                echo -e "${YELLOW}Starting $service...${NC}"
                sudo supervisorctl start $service
            else
                echo -e "${YELLOW}Starting all AAP services...${NC}"
                sudo supervisorctl start all
            fi
            ;;
        "stop")
            if [ -n "$service" ]; then
                echo -e "${YELLOW}Stopping $service...${NC}"
                sudo supervisorctl stop $service
            else
                echo -e "${YELLOW}Stopping all AAP services...${NC}"
                sudo supervisorctl stop all
            fi
            ;;
        "restart")
            if [ -n "$service" ]; then
                echo -e "${YELLOW}Restarting $service...${NC}"
                sudo supervisorctl restart $service
            else
                echo -e "${YELLOW}Restarting all AAP services...${NC}"
                sudo supervisorctl restart all
            fi
            ;;
        "status")
            sudo supervisorctl status
            ;;
        *)
            echo -e "${RED}Usage: control_aap <start|stop|restart|status> [service_name]${NC}"
            return 1
            ;;
    esac
}

# Get the actual service names from supervisord
get_service_names() {
    sudo supervisorctl status | awk '{print $1}'
}

# Wait for service to reach expected state
wait_for_service() {
    local service=$1
    local expected_state=$2
    local max_attempts=10
    
    for i in $(seq 1 $max_attempts); do
        local current_state=$(sudo supervisorctl status $service 2>/dev/null | awk '{print $2}')
        if [ "$current_state" = "$expected_state" ]; then
            echo -e "${GREEN}✓ $service is now $expected_state${NC}"
            return 0
        fi
        echo "Waiting for $service to become $expected_state... ($i/$max_attempts)"
        sleep 3
    done
    echo -e "${RED}✗ $service did not reach $expected_state within timeout${NC}"
    return 1
}

# Interactive service selector
select_service() {
    echo -e "\n${YELLOW}Available services:${NC}"
    local services=($(get_service_names))
    local count=1
    
    for service in "${services[@]}"; do
        echo "  $count) $service"
        ((count++))
    done
    
    echo -e "  $count) All services"
    
    read -p "Select service (1-$count): " choice
    if [ $choice -eq $count ]; then
        echo "all"
    else
        echo "${services[$((choice-1))]}"
    fi
}

# Main execution
echo -e "${GREEN}=== Current Status ===${NC}"
sudo supervisorctl status

# Interactive menu
while true; do
    echo -e "\n${YELLOW}=== AAP Service Control ===${NC}"
    echo "1) Start service"
    echo "2) Stop service" 
    echo "3) Restart service"
    echo "4) Check status"
    echo "5) Test individual components"
    echo "6) Exit"
    
    read -p "Select operation (1-6): " main_choice
    
    case $main_choice in
        1|2|3)
            service=$(select_service)
            if [ $? -ne 0 ]; then
                continue
            fi
            
            case $main_choice in
                1) action="start" ;;
                2) action="stop" ;;
                3) action="restart" ;;
            esac
            
            control_aap "$action" "$service"
            
            # Wait and show result if not "all"
            if [ "$service" != "all" ]; then
                wait_for_service "$service" "RUNNING"
            else
                sleep 10
                echo -e "\n${GREEN}=== Final Status ===${NC}"
                sudo supervisorctl status
            fi
            ;;
        4)
            echo -e "\n${GREEN}=== Current Status ===${NC}"
            sudo supervisorctl status
            ;;
        5)
            echo -e "\n${YELLOW}=== Testing Individual Components ===${NC}"
            
            # Test with correct service names
            TEST_SERVICES=(
                "tower-processes:awx-uwsgi"
                "tower-processes:awx-dispatcher"
                "tower-processes:awx-callback-receiver"
                "tower-processes:awx-daphne"
            )
            
            for service in "${TEST_SERVICES[@]}"; do
                echo -e "\nTesting: $service"
                control_aap "restart" "$service"
                wait_for_service "$service" "RUNNING"
            done
            
            echo -e "\n${GREEN}=== All Component Tests Complete ===${NC}"
            sudo supervisorctl status
            ;;
        6)
            echo "Exiting..."
            break
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
done
