# PCA — Plan de Continuité d'Activité

## Architecture (3 nœuds — Control-Plane séparé)

```
┌──────────────────────────────────────────────────────────────────┐
│                        VIP: 10.1.248.100                         │
│                  (Keepalived VRRP, failover auto)                 │
└────────────────────────────┬─────────────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            ▼                                 ▼
┌───────────────────────┐       ┌───────────────────────┐
│  metalis-worker1      │       │  metalis-worker2      │
│  10.1.248.13          │       │  10.1.248.6           │
│  (MASTER, prio 110)   │       │  (BACKUP, prio 90)    │
│                       │       │                       │
│  k3s agent            │       │  k3s agent            │
│  Workloads + Ingress  │       │  Workloads + Ingress  │
│  Longhorn replica     │       │  Longhorn replica     │
│  /dev/sda1 (20GB)     │       │  disk 19GB            │
└───────────────────────┘       └───────────────────────┘
            │                                 │
            └────────── Flannel VXLAN ────────┘
                       (10.42.0.0/16)
                             │
                    ┌────────┴────────┐
                    ▼                 │
         ┌─────────────────────┐     │
         │  metalis-cp         │     │
         │  10.1.248.15        │     │
         │  k3s server         │     │
         │  control-plane only │     │
         │  (NoExecute taint)  │     │
         │  4 vCPU / 4GB RAM   │     │
         └─────────────────────┘     │
```

## Composants PCA

| Composant         | Rôle                         | Configuration                              |
| ----------------- | ---------------------------- | ------------------------------------------ |
| **k3s server**    | Control-plane dédié          | VM 10.1.248.15, taint `CriticalAddonsOnly` |
| **Longhorn**      | Stockage répliqué (2 copies) | Helm v1.7.2, namespace `longhorn-system`   |
| **Keepalived**    | VIP flottante VRRP           | 10.1.248.100, VRID 51, auth PASS `M3t4l1s` |
| **Ingress-nginx** | DaemonSet sur les 2 workers  | hostNetwork, ports 80/443 directs          |
| **Flannel**       | Réseau pod cross-node        | VXLAN id 1, port 8472/UDP                  |
| **Multipath fix** | Blacklist devices Longhorn   | `/etc/multipath.conf` sur chaque worker    |

## URLs d'accès (via VIP)

| Service   | URL                                  |
| --------- | ------------------------------------ |
| WordPress | http://wordpress.10.1.248.100.nip.io |
| Odoo      | http://odoo.10.1.248.100.nip.io      |

## Fonctionnement du failover

1. **Keepalived** détecte la panne du service `k3s-agent` via check script (toutes les 2s, 3 échecs → prio réduite de 50)
2. La VIP 10.1.248.100 migre vers le worker BACKUP en ~6 secondes
3. **Kubernetes** détecte le nœud défaillant (node NotReady après ~40s)
4. Les pods sont reschedulés sur le worker survivant
5. **Longhorn** fournit les données depuis la réplique locale du nœud survivant
6. Les services reprennent sans perte de données

**Temps de bascule observé** : ~2-3 min (détection VIP ~6s + rescheduling pods + pull images + mount volumes)

**Note importante** : `multipathd` doit être configuré pour blacklister les devices Longhorn (`/etc/multipath.conf`), sinon les volumes ne peuvent pas être montés sur le nœud de failover.

## Test de failover effectué (24/06/2026)

```
Architecture: 3 nœuds (CP dédié + 2 workers)
Avant:  WordPress sur worker1, Odoo sur worker2
Action: cordon worker1 + drain + stop k3s-agent (simule crash VM)
Résultat:
  1. VIP bascule de worker1 (10.1.248.13) → worker2 (10.1.248.6) ✓
  2. Tous pods migrés sur worker2 ✓
  3. Odoo HTTP 200 immédiat ✓
  4. WordPress HTTP 200 après ~3 min (mount volumes + pull images) ✓
  5. Recovery worker1 : uncordon + start k3s-agent → VIP revient ✓
```

## Limitations et points d'attention

- Le control-plane k3s est sur un seul nœud (10.1.248.15) — si cette VM tombe, les pods existants continuent mais aucun nouveau scheduling n'est possible
- Pour une HA complète du control-plane : convertir en k3s multi-server (embedded etcd)
- `multipathd` doit être blacklisté sur tous les workers (sinon Longhorn blockdev inaccessible)
- Le PRA Azure prend le relais si les 2 workers sont perdus (RTO 4h)
- Les images Docker doivent être pré-pullées sur les 2 workers pour accélérer le failover
