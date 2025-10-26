#!/bin/bash
# lab1.3_backup_controller_only.sh

echo "==============================================="
echo "AAP Backup Operations - Controller Only"
echo "==============================================="

BACKUP_DIR="/opt/backups/aap_controller_$(date +%Y%m%d_%H%M%S)"
sudo mkdir -p $BACKUP_DIR

echo "Backup directory: $BACKUP_DIR"
echo "Note: PostgreSQL is hosted on db01 (separate server)"

# 1. Stop services for consistent backup
echo "=== Step 1: Stopping Services ==="
sudo supervisorctl stop all
sleep 5

# 2. Backup configurations
echo "=== Step 2: Configuration Backup ==="
echo "Backing up AAP configurations..."
sudo tar -czf $BACKUP_DIR/aap_config.tar.gz \
    /etc/ansible-automation-platform/ \
    /etc/supervisord.conf \
    /etc/supervisord.d/ \
    /etc/nginx/ \
    /etc/receptor/ \
    2>/dev/null
echo "✓ AAP configurations backed up"

# 3. Backup important data directories
echo "=== Step 3: Data Directory Backup ==="
echo "Backing up /var/lib/awx..."
sudo tar -czf $BACKUP_DIR/awx_data.tar.gz \
    /var/lib/awx/ \
    --exclude="*.sock" \
    --exclude="*.pid" \
    --exclude="*.pyc" \
    2>/dev/null
echo "✓ AWX data directory backed up"

# 4. Backup projects and job artifacts
echo "=== Step 4: Projects and Artifacts Backup ==="
if [ -d /var/lib/awx/projects ]; then
    sudo tar -czf $BACKUP_DIR/projects.tar.gz /var/lib/awx/projects/ 2>/dev/null
    echo "✓ Projects backed up"
fi

if [ -d /var/lib/awx/job_status ]; then
    sudo tar -czf $BACKUP_DIR/job_artifacts.tar.gz /var/lib/awx/job_status/ 2>/dev/null
    echo "✓ Job artifacts backed up"
fi

# 5. Backup log files (optional)
echo "=== Step 5: Log Backup ==="
sudo tar -czf $BACKUP_DIR/logs.tar.gz \
    /var/log/supervisor/ \
    /var/log/awx/ \
    /var/log/nginx/ \
    2>/dev/null
echo "✓ Log files backed up"

# 6. Backup SSL certificates and keys
echo "=== Step 6: SSL Certificates Backup ==="
sudo tar -czf $BACKUP_DIR/ssl_certs.tar.gz \
    /etc/pki/tls/certs/ \
    /etc/pki/tls/private/ \
    2>/dev/null
echo "✓ SSL certificates backed up"

# 7. Create metadata file
echo "=== Step 7: Creating Backup Metadata ==="
cat > $BACKUP_DIR/backup_metadata.txt << EOF
AAP Controller Backup
Date: $(date)
Hostname: $(hostname)
Backup Type: Controller Only (PostgreSQL on db01)
AAP Version: $(curl -k -s https://localhost/api/v2/config/ 2>/dev/null | jq -r '.version // "Unknown"')
Components Backed Up:
- AAP Configurations
- AWX Data Directory
- Projects
- Job Artifacts
- Logs
- SSL Certificates
EOF

# 8. Create restore instructions
cat > $BACKUP_DIR/RESTORE_INSTRUCTIONS.md << 'EOF'
# AAP Controller Restore Procedure

## IMPORTANT: PostgreSQL is on db01
This backup only includes controller components. Database must be backed up separately on db01.

## Pre-restore:
1. Stop services: sudo supervisorctl stop all
2. Backup current state

## Restore Steps:
1. Extract configurations: sudo tar -xzf aap_config.tar.gz -C /
2. Extract data: sudo tar -xzf awx_data.tar.gz -C /
3. Extract projects: sudo tar -xzf projects.tar.gz -C / (if exists)
4. Extract artifacts: sudo tar -xzf job_artifacts.tar.gz -C / (if exists)
5. Fix permissions: sudo chown -R awx:awx /var/lib/awx/
6. Start services: sudo supervisorctl start all
7. Verify: sudo supervisorctl status && curl -k https://localhost/api/v2/ping/

## Database:
- Coordinate with db01 administrator for PostgreSQL backup/restore
- Database contains: users, inventories, job templates, job history
EOF

# 9. Restart services
echo "=== Step 8: Restarting Services ==="
sudo supervisorctl start all

# 10. Verify backup and service recovery
echo "=== Step 9: Backup Verification ==="
echo "Backup contents:"
sudo ls -la $BACKUP_DIR/
echo -e "\nBackup size:"
sudo du -sh $BACKUP_DIR

echo -e "\n=== Step 10: Service Recovery Check ==="
sleep 30
echo "Service status:"
sudo supervisorctl status

echo -e "\nAPI check:"
if curl -k -s https://localhost/api/v2/ping/ > /dev/null; then
    echo "✓ API is responsive"
else
    echo "✗ API not responsive - check service status"
fi

echo -e "\n=== Backup Complete ==="
echo "Backup saved to: $BACKUP_DIR"
echo "Important: PostgreSQL backup must be performed separately on db01"
