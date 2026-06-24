# Procédures opérationnelles PCA

## Vérification quotidienne

```bash
# SSH sur le control-plane
ssh root@10.1.248.15

# État des nœuds
kubectl get nodes

# VIP active (sur worker1 normalement)
ssh root@10.1.248.13 "ip addr show eth0 | grep 10.1.248.100"

# Volumes Longhorn sains
kubectl get volumes.longhorn.io -n longhorn-system \
  -o custom-columns="NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness"

# Pods applicatifs
kubectl get pods -n odoo -o wide
kubectl get pods -n wordpress -o wide
```

## En cas de panne d'un worker

### Worker1 (10.1.248.13) tombe — VIP MASTER

1. La VIP bascule automatiquement vers worker2 (Keepalived, ~6s)
2. Les pods sur worker1 sont perdus temporairement
3. Kubernetes reschedule les pods sur worker2 (~40s)
4. Vérifier l'accès : `curl -sI http://wordpress.10.1.248.100.nip.io/`

### Worker2 (10.1.248.6) tombe — VIP BACKUP

1. La VIP reste sur worker1 (rien à faire pour le réseau)
2. Les pods sur worker2 sont détectés perdus après ~40s
3. Kubernetes reschedule automatiquement les pods sur worker1
4. Les données Longhorn sont disponibles via la réplique locale de worker1

### Le control-plane (10.1.248.15) tombe

1. Les pods existants continuent de fonctionner sur les workers
2. Aucun nouveau scheduling n'est possible
3. La VIP et les services ne sont PAS affectés
4. Remettre le CP en service dès que possible

## Restauration après panne

### Remettre un worker en service

```bash
# Si worker1 (10.1.248.13) revient
ssh root@10.1.248.13
systemctl start k3s-agent
# Vérifier sur le CP:
ssh root@10.1.248.15 "kubectl get nodes"
# Uncordon si nécessaire:
ssh root@10.1.248.15 "kubectl uncordon metalis-worker1"

# Si worker2 (10.1.248.6) revient
ssh root@10.1.248.6
systemctl start k3s-agent
ssh root@10.1.248.15 "kubectl get nodes"
ssh root@10.1.248.15 "kubectl uncordon metalis-worker2"
```

### Vérifier la resync Longhorn

```bash
# Après retour d'un nœud, les répliques se resynchronisent
kubectl get replicas.longhorn.io -n longhorn-system \
  -o custom-columns="VOLUME:.spec.volumeName,NODE:.spec.nodeID,STATE:.status.currentState"

# Attendre que toutes soient "running" sur les 2 nœuds
# (peut prendre quelques minutes selon la quantité de données)
```

## Configuration Keepalived

### Worker1 — MASTER (/etc/keepalived/keepalived.conf sur 10.1.248.13)

```
vrrp_script chk_k3s {
    script "/usr/bin/systemctl is-active k3s-agent"
    interval 2
    weight -50
    fall 3
    rise 2
}

vrrp_instance METALIS_VIP {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 110
    authentication {
        auth_type PASS
        auth_pass M3t4l1s
    }
    track_script { chk_k3s }
    virtual_ipaddress { 10.1.248.100/24 dev eth0 }
}
```

### Worker2 — BACKUP (/etc/keepalived/keepalived.conf sur 10.1.248.6)

```
vrrp_script chk_k3s {
    script "/usr/bin/systemctl is-active k3s-agent"
    interval 2
    weight -50
    fall 3
    rise 2
}

vrrp_instance METALIS_VIP {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90
    authentication {
        auth_type PASS
        auth_pass M3t4l1s
    }
    track_script { chk_k3s }
    virtual_ipaddress { 10.1.248.100/24 dev eth0 }
}
```

## Configuration Multipath (CRITIQUE)

Sur **chaque worker**, `/etc/multipath.conf` doit blacklister les devices Longhorn :

```
blacklist {
    devnode "^sd[a-z][0-9]*"
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
}
defaults {
    user_friendly_names yes
}
```

Sans cette config, `multipathd` bloque les block devices Longhorn et le failover échoue.

### Worker2 — BACKUP (/etc/keepalived/keepalived.conf sur 10.1.248.6)

```
vrrp_instance METALIS_VIP {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 90
    authentication {
        auth_type PASS
        auth_pass M3t4l1s
    }
    track_script { chk_k3s }
    virtual_ipaddress { 10.1.248.100/24 dev eth0 }
}
```

## Maintenance Longhorn

### Accès UI Longhorn

```bash
kubectl port-forward svc/longhorn-frontend -n longhorn-system 8080:80
# Accessible sur http://localhost:8080
```

### Reconstruire une réplique manuellement

Si un volume reste "degraded" après le retour d'un nœud :

```bash
# Identifier la réplique fautive
kubectl get replicas.longhorn.io -n longhorn-system | grep stopped

# Supprimer pour forcer la reconstruction
kubectl delete replicas.longhorn.io <nom-replica> -n longhorn-system
# Longhorn créera automatiquement une nouvelle réplique
```

## Escalade vers PRA

Si les **2 nœuds** sont perdus simultanément → activer le PRA Azure :

```bash
# Depuis un poste avec accès Azure
cd PRA/
./scripts/activate-pra.sh
# Ou via GitHub Actions : workflow pra-deploy.yml → action "activate"
```

Voir [PRA/RUNBOOK.md](../PRA/RUNBOOK.md) pour la procédure complète.
