# Procédure d'Activation PRA — METALIS

**Infrastructure Cloud Azure | k3s + Velero**
**RTO : 4h | RPO : 24h**

---

## Vue d'ensemble

En cas de sinistre sur le site on-prem (incendie, ransomware, panne totale), cette procédure permet de basculer WordPress et Odoo sur une VM Azure en moins de **2h30**.

```
[Site on-prem HS]                    [Azure — switzerlandnorth]
  k3s cluster  ──── backups Velero ────▶  VM PRA (vm-metalis-pra)
  WordPress                              WordPress restauré
  Odoo                                   Odoo restauré
  MariaDB / PostgreSQL                   MariaDB / PostgreSQL restaurés
```

---

## Prérequis

| Élément            | Valeur                                 |
| ------------------ | -------------------------------------- |
| Subscription Azure | `sub-t-dabbadie-student`               |
| Resource Group PRA | `rg-metalis-pra`                       |
| VM PRA             | `vm-metalis-pra` (Standard_B2s)        |
| IP publique        | `20.203.187.132`                       |
| Storage backups    | `stobkpmetalis974 / contmetalisbkp974` |
| Clé SSH            | `~/.ssh/id_rsa` (clé `gyme@wsl`)       |

---

## ÉTAPE 1 — Démarrer la VM PRA

> La VM est normalement **arrêtée** (deallocated) pour économiser ~33€/mois.
> Elle garde son IP statique même éteinte.

```bash
# Authentification Azure
az login --tenant ***REDACTED_TENANT_ID***
az account set --subscription ***REDACTED_SUB_ID***

# Démarrer la VM
az vm start --resource-group rg-metalis-pra --name vm-metalis-pra

# Attendre que la VM soit prête (≈ 2 min)
az vm wait --resource-group rg-metalis-pra --name vm-metalis-pra --custom "instanceView.statuses[?code=='PowerState/running']"

echo "VM démarrée — IP : 20.203.187.132"
```

**🖥️ Screenshot attendu :** VM en état `Running` dans le portail Azure ou en ligne de commande.

---

## ÉTAPE 2 — Vérifier k3s et Velero

```bash
# Connexion SSH
ssh azureuser@20.203.187.132

# Vérifier k3s
kubectl get nodes
# Résultat attendu : vm-metalis-pra   Ready   control-plane

# Vérifier Velero et la connexion au stockage
velero backup-location get
# Résultat attendu : default   azure   contmetalisbkp974   Available

# Lister les backups disponibles
velero backup get
# Résultat attendu : liste des backups backup-quotidienne-YYYYMMDD
```

**🖥️ Screenshot attendu :** Node `Ready`, storage location `Available`, liste des backups.

---

## ÉTAPE 3 — Choisir le backup et lancer la restauration

```bash
# Identifier le backup le plus récent (première ligne)
BACKUP=$(velero backup get --output json | python3 -c "
import sys, json
backups = json.load(sys.stdin)['items']
completed = [b for b in backups if b['status']['phase'] == 'Completed']
completed.sort(key=lambda b: b['status']['completionTimestamp'], reverse=True)
print(completed[0]['metadata']['name'])
")
echo "Backup sélectionné : $BACKUP"

# Lancer la restauration (namespaces applicatifs uniquement)
velero restore create pra-restore-$(date +%Y%m%d%H%M) \
  --from-backup $BACKUP \
  --include-namespaces wordpress,odoo \
  --wait
```

> ⏱️ Durée estimée : **5 à 10 minutes** selon la taille des données.

**🖥️ Screenshot attendu :** `Restore completed` ou `PartiallyFailed` (normal si des pods étaient Failed au moment du backup).

---

## ÉTAPE 4 — Corriger le StorageClass (une seule fois)

> k3s utilise `local-path` comme StorageClass par défaut.
> Les backups référencent `longhorn` (StorageClass on-prem).
> Cette étape crée un alias `longhorn → local-path` **à ne faire qu'une fois**.

```bash
# Vérifier si longhorn existe déjà
kubectl get storageclass longhorn 2>/dev/null && echo "Déjà présent, skip" || \
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
```

---

## ÉTAPE 5 — Vérifier que les pods démarrent

```bash
# Attendre que tous les pods soient Running (2-5 min)
watch kubectl get pods -A | grep -E 'wordpress|odoo'

# Résultat attendu :
# odoo        odoo-584b744...   1/1   Running
# odoo        odoo-db-0         1/1   Running
# wordpress   wordpress-696...  1/1   Running
# wordpress   wordpress-mariadb-0  1/1  Running
```

Si des pods restent bloqués en `Init` plus de 5 minutes :

```bash
# Forcer le redémarrage
kubectl delete pod -n wordpress -l app.kubernetes.io/name=wordpress --force
kubectl delete pod -n odoo -l app=odoo --force
kubectl delete pod -n odoo -l app=odoo-db --force
```

---

## ÉTAPE 6 — Installer nginx Ingress et mettre à jour les URLs

```bash
# Installer nginx ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=ClusterIP \
  --set controller.kind=DaemonSet \
  --wait --timeout=120s

# Supprimer le webhook de validation (peut bloquer le patch)
kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true

# Mettre à jour les Ingress avec l'IP publique Azure
PUBLIC_IP=20.203.187.132
for ns in wordpress odoo; do
  NAME=$(kubectl get ingress -n $ns -o name | head -1 | cut -d/ -f2)
  OLD_HOST=$(kubectl get ingress -n $ns $NAME -o jsonpath='{.spec.rules[0].host}')
  NEW_HOST=$(echo $OLD_HOST | sed "s/10\.1\.248\.100/$PUBLIC_IP/g")
  kubectl patch ingress $NAME -n $ns --type='json' \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/rules/0/host\",\"value\":\"$NEW_HOST\"}]"
  echo "$ns : http://$NEW_HOST"
done
```

---

## ÉTAPE 6b — Post-restore automatique (RECOMMANDÉ)

> Le script `post-restore.sh` automatise **toutes** les corrections post-restauration :
> volumes Kopia, wp-config.php, URLs en DB, ingress, password Odoo.
> Il remplace les étapes manuelles 6 et 7.

```bash
# Copier et exécuter le script sur la VM PRA
scp scripts/post-restore.sh azureuser@20.203.187.132:/tmp/
ssh azureuser@20.203.187.132 'chmod +x /tmp/post-restore.sh && sudo /tmp/post-restore.sh'

# Le script :
#  1. Détecte l'IP publique automatiquement
#  2. Débloquer les pods stuck en Init
#  3. Restaure les volumes depuis Kopia (images WP, filestore Odoo, DBs)
#  4. Met à jour les Ingress (nip.io)
#  5. Corrige wp-config.php (WP_HOME, WP_SITEURL)
#  6. Met à jour WORDPRESS_HOSTNAME
#  7. Remplace toutes les URLs dans la DB WordPress
#  8. Met à jour web.base.url Odoo + reset password admin
#  9. Vérification HTTP finale
```

Options disponibles :

```bash
sudo ./post-restore.sh --ip 20.203.187.132      # Forcer l'IP
sudo ./post-restore.sh --old-ip 10.1.248.100     # Ancienne IP on-prem
sudo ./post-restore.sh --skip-kopia              # Ne pas restaurer les volumes
sudo ./post-restore.sh --dry-run                 # Simulation sans modification
```

---

## ÉTAPE 7 — Vérification finale

```bash
# Test HTTP direct
curl -s -o /dev/null -w "%{http_code}" http://wordpress.20.203.187.132.nip.io/
# Attendu : 200

curl -s -o /dev/null -w "%{http_code}" http://odoo.20.203.187.132.nip.io/
# Attendu : 200 ou 303
```

**URLs de production PRA :**

| Service   | URL                                    |
| --------- | -------------------------------------- |
| WordPress | http://wordpress.20.203.187.132.nip.io |
| Odoo      | http://odoo.20.203.187.132.nip.io      |

**🖥️ Screenshot attendu :** Page WordPress et Odoo accessibles dans le navigateur.

---

## ÉTAPE 8 — Communication utilisateurs

```
Objet : [METALIS] Basculement PRA activé — Services disponibles

L'infrastructure principale est temporairement indisponible.
Le Plan de Reprise d'Activité a été activé.

Les services sont accessibles aux adresses suivantes :
  - WordPress : http://wordpress.20.203.187.132.nip.io
  - Odoo ERP  : http://odoo.20.203.187.132.nip.io

Données restaurées depuis le backup du : [DATE DU BACKUP]
Perte de données maximale (RPO) : 24h

Le retour sur site normal sera communiqué dès que possible.
— Équipe IT Metalis
```

---

## Désactivation / Retour sur site (Failback)

Une fois le site on-prem rétabli :

```bash
# 1. Exporter les données si nécessaire (dump DB)
# WordPress
kubectl exec -n wordpress wordpress-mariadb-0 -- \
  mysqldump -u root -p$(kubectl get secret -n wordpress wordpress-mariadb -o jsonpath='{.data.mariadb-root-password}' | base64 -d) wordpress > wordpress-dump-pra.sql

# Odoo
kubectl exec -n odoo odoo-db-0 -- \
  pg_dump -U odoo odoo > odoo-dump-pra.sql

# 2. Arrêter la VM pour stopper la facturation
az vm deallocate --resource-group rg-metalis-pra --name vm-metalis-pra
```

---

## Résultats du test du 2026-06-24

| Étape                                | Durée       | Résultat                    |
| ------------------------------------ | ----------- | --------------------------- |
| Démarrage VM + k3s ready             | ~3 min      | ✅                          |
| Velero storage location Available    | ~1 min      | ✅                          |
| Restauration Velero (backup 23/06)   | ~6 min      | ✅ PartiallyFailed (normal) |
| Post-restore (re-IP + volumes Kopia) | ~5 min      | ✅ Automatisé               |
| Pods Running (WordPress + Odoo)      | ~5 min      | ✅                          |
| Services accessibles HTTP 200        | < 1 min     | ✅ WordPress **HTTP 200**   |
| **TOTAL**                            | **~20 min** | ✅ **RTO << 4h**            |

> **Note technique :** `PartiallyFailed` est attendu — le backup on-prem contenait des pods en état `Failed/Pending` (cluster dégradé). Les ressources Kubernetes et les bases de données sont correctement restaurées. Le script `post-restore.sh` corrige automatiquement les volumes (Kopia) et les URLs (re-IP).

---

## Guide vidéo (< 4 min)

Structure suggérée pour la démo vidéo :

```
0:00 - 0:30  Introduction : scénario (site HS), architecture PRA
0:30 - 1:00  Portail Azure : démarrage VM, IP publique
1:00 - 1:30  Terminal SSH : kubectl get nodes, velero backup get
1:30 - 2:30  velero restore create --wait → PartiallyFailed normal
2:30 - 3:00  kubectl get pods -A → tous Running
3:00 - 3:45  Navigateur : WordPress et Odoo accessibles
3:45 - 4:00  Conclusion : RTO atteint, données du jour J-1
```

Outil recommandé pour l'enregistrement : **OBS Studio** ou **Loom** (gratuit, partage lien direct).
