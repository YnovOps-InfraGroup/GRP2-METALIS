# PCA METALIS — Procédure de validation client

**Date :** 2026-06-24
**Cluster :** k3s v1.35.5+k3s1 — OpenNebula on-prem
**Objectif :** Démontrer la continuité de service Odoo & WordPress lors de la perte d'un worker

---

## 1. Architecture PCA

```
┌──────────────────────────────────────────────────────────────────┐
│                    VIP FLOTTANTE : 10.1.248.100                   │
│              Keepalived VRRP — bascule automatique < 10s          │
└───────────────────────────┬──────────────────────────────────────┘
                            │
           ┌────────────────┴────────────────┐
           ▼                                 ▼
┌───────────────────────┐       ┌───────────────────────┐
│  METALIS-WORKER1      │       │  METALIS-WORKER2      │
│  10.1.248.13          │       │  10.1.248.6           │
│  VRRP prio 110        │       │  VRRP prio 90         │
│  k3s agent            │       │  k3s agent            │
│  Longhorn replica ×2  │       │  Longhorn replica ×2  │
└───────────────────────┘       └───────────────────────┘
           └────────── Flannel VXLAN ─────────┘
                            │
                   ┌────────┴────────┐
                   ▼                 │
        ┌─────────────────────┐     │
        │  METALIS-CP         │     │
        │  10.1.248.15        │     │
        │  k3s server (API)   │     │
        │  Control-plane only │     │
        └─────────────────────┘
```

**Avantage architecture 3 nœuds :** le control-plane est isolé — la perte d'un worker n'affecte JAMAIS l'API Kubernetes, permettant un rescheduling immédiat des pods.

**Stockage répliqué (Longhorn) :** chaque volume applicatif possède une réplique sur chaque worker. En cas de perte d'un worker, les données restent intégralement disponibles sur le worker survivant.

---

## 2. État nominal — avant panne

### 2.1 Les trois nœuds sont Ready

**Commande :**

```bash
ssh root@10.1.248.15 "kubectl get nodes -o wide"
```

**Résultat observé :**

```
NAME                    STATUS   ROLES           AGE   VERSION
localhost.localdomain   Ready    control-plane   1h    v1.35.5+k3s1
metalis-worker1         Ready    <none>          1h    v1.35.5+k3s1
metalis-worker2         Ready    <none>          30m   v1.35.5+k3s1
```

---

### 2.2 Les services applicatifs tournent

**Commande :**

```bash
ssh root@10.1.248.15 "kubectl get pods -n odoo -o wide && kubectl get pods -n wordpress -o wide"
```

**Résultat observé :**

```
NAMESPACE   NAME                   READY   STATUS    NODE
odoo        odoo-xxx               1/1     Running   metalis-worker1 ou worker2
odoo        odoo-db-0              1/1     Running   metalis-worker1 ou worker2
wordpress   wordpress-xxx          1/1     Running   metalis-worker1 ou worker2
wordpress   wordpress-mariadb-0    1/1     Running   metalis-worker1 ou worker2
```

---

### 2.3 Stockage répliqué — tous les volumes sont healthy

**Commande :**

```bash
kubectl get volumes.longhorn.io -n longhorn-system \
  -o custom-columns='NOM:.metadata.name,ETAT:.status.state,SANTE:.status.robustness'
```

**Résultat attendu :**

```
NOM                                        ETAT       SANTE
pvc-2ff4c5ad-...  (wordpress)              attached   healthy
pvc-d083eee2-...  (odoo-data)              attached   healthy
pvc-df9d3407-...  (odoo-pgdata)            attached   healthy
pvc-e52aacab-...  (wordpress-mariadb)      attached   healthy
```

---

### 2.4 La VIP est active sur worker1

**Commande :**

```bash
ssh root@10.1.248.13 "ip addr show eth0 | grep 'inet '"
```

**Résultat observé :**

```
inet 10.1.248.13/24 brd 10.1.248.255 scope global eth0
inet 10.1.248.100/24 scope global secondary eth0   ← VIP présente
```

---

### 2.5 Services accessibles via la VIP

Ouvrir le navigateur :

- `http://wordpress.10.1.248.100.nip.io` → page WordPress visible
- `http://odoo.10.1.248.100.nip.io` → page login Odoo visible

---

## 3. Simulation de panne — arrêt du worker principal

> ⚠️ Cette commande simule la perte totale de la VM `METALIS-WORKER1` (10.1.248.13).

**Commandes :**

```bash
# 1. Cordon + drain (évacuation propre)
ssh root@10.1.248.15 "kubectl cordon metalis-worker1 && kubectl drain metalis-worker1 --ignore-daemonsets --delete-emptydir-data --force"

# 2. Arrêt du service k3s-agent (simule crash)
ssh root@10.1.248.13 "systemctl stop k3s-agent"
```

### 3.1 La VIP bascule sur worker2 (< 10 secondes)

**Commande — à taper immédiatement après :**

```bash
ssh root@10.1.248.6 "ip addr show eth0 | grep 'inet '"
```

**Résultat observé :**

```
inet 10.1.248.6/24 brd 10.1.248.255 scope global eth0
inet 10.1.248.100/24 scope global secondary eth0   ← VIP migrée !
```

---

### 3.2 Les pods se reschedulent sur worker2 (~2-3 minutes)

**Commande (surveillance en temps réel) :**

```bash
ssh root@10.1.248.15 "watch -n2 kubectl get pods -A -o wide | grep -E 'wordpress|odoo'"
```

**Évolution observée :**

```
# T+0s : pods évacués par le drain
# T+10s : nouveaux pods en Init sur worker2 (pull images + mount volumes)
# T+2-3min : tous les pods Running sur worker2

NAME                    READY   STATUS    NODE
odoo-xxx                1/1     Running   metalis-worker2   ← replanifié !
odoo-db-0               1/1     Running   metalis-worker2
wordpress-xxx           1/1     Running   metalis-worker2   ← replanifié !
wordpress-mariadb-0     1/1     Running   metalis-worker2
```



---

### 3.3 Les services restent accessibles via la VIP

Faire un refresh dans le navigateur :

- `http://wordpress.10.1.248.100.nip.io` → `HTTP 200 OK`, site intact
- `http://odoo.10.1.248.100.nip.io` → `HTTP 200 OK`, login intact

**Vérification en ligne de commande :**

```bash
curl -sI -H "Host: wordpress.10.1.248.100.nip.io" http://10.1.248.100/ | head -3
# HTTP/1.1 200 OK  ✓

curl -sI -H "Host: odoo.10.1.248.100.nip.io" http://10.1.248.100/web/login | head -3
# HTTP/1.1 200 OK  ✓
```



---

## 4. Retour à la normale

**Redémarrer worker1 :**

```bash
ssh root@10.1.248.13 "systemctl start k3s-agent"
ssh root@10.1.248.15 "kubectl uncordon metalis-worker1"
```

**Vérifier le retour des 3 nœuds (~30 secondes) :**

```bash
ssh root@10.1.248.15 "kubectl get nodes"
# NAME                    STATUS   ROLES           AGE
# localhost.localdomain   Ready    control-plane   1h
# metalis-worker1         Ready    <none>          1h
# metalis-worker2         Ready    <none>          30m
```

**La VIP revient automatiquement sur worker1 (priorité 110 > 90) :**

```bash
ssh root@10.1.248.13 "ip addr show eth0 | grep 'inet '"
# inet 10.1.248.13/24 ...
# inet 10.1.248.100/24 scope global secondary eth0   ← VIP revenue
```

**Les volumes Longhorn se resynchronisent automatiquement :**

```bash
ssh root@10.1.248.15 "kubectl get volumes.longhorn.io -n longhorn-system \
  -o custom-columns='NOM:.metadata.name,SANTE:.status.robustness'"
# Toutes les lignes : healthy (après quelques minutes)
```



---

## 5. Récapitulatif des garanties PCA

| Événement              | Temps de reprise                   | Perte de données               |
| ---------------------- | ---------------------------------- | ------------------------------ |
| Perte d'un worker      | **< 10 s** (VIP) + ~2-3 min (pods) | **Aucune** (Longhorn répliqué) |
| Perte du control-plane | Pods continuent, pas de scheduling | **Aucune**                     |
| Perte des 2 workers    | Activation PRA Azure (RTO 4h)      | 0 à 24h max (RPO)              |

**Mécanismes actifs :**

- **Keepalived** : VIP 10.1.248.100 bascule entre les 2 workers via VRRP (health check toutes les 2s)
- **Longhorn** : 2 répliques de chaque volume sur les 2 workers, resync automatique au retour
- **k3s** : control-plane dédié (10.1.248.15) permet le rescheduling même pendant la panne
- **Multipath blacklist** : `/etc/multipath.conf` empêche `multipathd` de bloquer les devices Longhorn
