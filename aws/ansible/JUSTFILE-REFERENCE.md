# Justfile Quick Reference

## Common Commands
```bash
# Infrastructure
just check           # Test connectivity
just install         # Install Docker
just deploy          # Full deployment
just verify          # Verify deployment

# Selective Deployment
just signaling       # Deploy signaling services
just media           # Deploy media services
just opensips        # Deploy OpenSIPS only
just redis           # Deploy Redis only

# Management
just status          # Show container status
just logs SERVICE    # Show logs (e.g., just logs opensips)
just restart SERVICE # Restart service
just clean           # Remove all containers

# Testing
just test-sip        # Test SIP connectivity
just test-metrics    # Test Prometheus exporters
just dry-run         # Show what would change

# Information
just info            # Show deployment info
just list-tags       # Show available Ansible tags
just docker-stats    # Show container resource usage
```

## Advanced Usage
```bash
# Deploy to specific host
just deploy-host aws-signaling

# Run specific Ansible tag
just run-tag docker

# Skip specific tag
just skip-tag monitoring

# Interactive menu
just interactive

# Production deployment (with checks)
just prod-deploy
```

## Service Names

- `opensips` - SIP proxy
- `freeswitch` - Media server
- `rtpengine` - RTP proxy
- `redis` - Database
- `node-exporter` - Metrics exporter
- `redis-exporter` - Redis metrics

## Examples
```bash
# Deploy everything
just deploy

# Deploy only signaling, skip monitoring
just signaling

# Check OpenSIPS logs
just logs opensips

# Restart FreeSWITCH
just restart freeswitch

# Show resource usage
just docker-stats

# Backup configurations
just backup

# Clean start
just clean && just deploy
```
