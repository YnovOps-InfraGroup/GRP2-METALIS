# RUNBOOK PRA METALIS — Procédure Opérateur

**Version :** 1.0
**Dernière mise à jour :** 22 juin 2026
**RTO :** 4h | **RPO :** 24h

---

## 📋 Table des matières

1. [Quand déclencher le PRA](#1-quand-déclencher-le-pra)
2. [Chaîne de décision](#2-chaîne-de-décision)
3. [Procédure d'activation](#3-procédure-dactivation)
4. [Vérification post-restauration](#4-vérification-post-restauration)
5. [Communication utilisateurs](#5-communication-utilisateurs)
6. [Opération en mode PRA](#6-opération-en-mode-pra)
7. [Retour sur site (failback)](#7-retour-sur-site-failback)
8. [Désactivation PRA](#8-désactivation-pra)
9. [Test de restauration (drill)](#9-test-de-restauration-drill)
10. [Contacts & escalade](#10-contacts--escalade)

---

## 1. Quand déclencher le PRA

### ✅ Déclencher si :

- Incendie ou inondation du datacenter
- Ransomware ayant chiffré le cluster k3s ET le NAS
- Coupure électrique > 4h sans rétablissement prévu
- Panne totale du hyperviseur Nebula sans spare
- Perte complète du réseau site (WAN + 4G backup)

### ❌ Ne PAS déclencher si :

- Panne d'un seul pod (k3s auto-restart)
- Problème réseau temporaire (< 30 min)
- Panne disque NAS avec RAID fonctionnel
- Lenteur Odoo (optimisation, pas PRA)
- Panne internet seule (4G backup disponible)

---

## 2. Chaîne de décision

| Étape     | Qui              | Action                                 | Délai max |
| --------- | ---------------- | -------------------------------------- | --------- |
| 1         | Équipe IT        | Constater la panne, évaluer la gravité | 15 min    |
| 2         | Chef de projet   | Valider le déclenchement PRA           | 15 min    |
| 3         | Direction        | Approuver (si hors horaires)           | 30 min    |
| 4         | Architecte infra | Exécuter l'activation PRA              | 60 min    |
| 5         | Équipe IT        | Vérifier les services                  | 30 min    |
| 6         | Chef de projet   | Communiquer aux utilisateurs           | 15 min    |
| **Total** |                  |                                        | **~2h30** |

> Marge restante : 1h30 sur le RTO de 4h pour troubleshooting.

---

## 3. Procédure d'activation

### Prérequis

- [ ] Accès Azure CLI authentifié
- [ ] Clé SSH pour la VM PRA
- [ ] Credentials SP Velero (Client ID + Secret)
- [ ] Accès internet depuis le poste opérateur

### Option A : Script automatisé (recommandé)

```bash
# 1. Se positionner dans le répertoire PRA
cd PRA/scripts

# 2. Exporter les credentials Velero
export VELERO_SP_CLIENT_ID="***REDACTED_SP_ID***"
export VELERO_SP_CLIENT_SECRET="<secret>"
export PRA_SSH_KEY="$HOME/.ssh/pra_metalis"

# 3. S'authentifier Azure
az login --tenant ***REDACTED_TENANT_ID***
az account set --subscription ***REDACTED_SUB_ID***

# 4. Activer le PRA
chmod +x activate-pra.sh
./activate-pra.sh

# 5. Noter l'IP publique affichée et les URLs
```

### Option B : GitHub Actions

1. Aller sur GitHub → **Actions** → **PRA METALIS — Azure**
2. Cliquer **Run workflow**
3. Sélectionner action : `activate`
4. Cliquer **Run workflow**
5. Suivre l'exécution dans les logs

### Option C : Procédure manuelle

```bash
# 1. Démarrer la VM
az vm start --resource-group rg-metalis-pra --name vm-metalis-pra

# 2. Récupérer l'IP
PUBLIC_IP=$(az vm show -d -g rg-metalis-pra -n vm-metalis-pra --query publicIps -o tsv)
echo "IP: $PUBLIC_IP"

# 3. Se connecter en SSH
ssh -i ~/.ssh/pra_metalis azureuser@$PUBLIC_IP

# 4. Sur la VM : vérifier k3s
sudo kubectl get nodes

# 5. Créer le fichier credentials Velero
cat > /tmp/credentials-velero << 'EOF'
AZURE_SUBSCRIPTION_ID=***REDACTED_SUB_ID***
AZURE_TENANT_ID=***REDACTED_TENANT_ID***
AZURE_CLIENT_ID=***REDACTED_SP_ID***
AZURE_CLIENT_SECRET=<votre-secret>
AZURE_RESOURCE_GROUP=rg-metalis
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

# 6. Installer Velero sur le cluster PRA
sudo velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.10.0 \
  --bucket contmetalisbkp974 \
  --secret-file /tmp/credentials-velero \
  --backup-location-config resourceGroup=rg-metalis,storageAccount=stobkpmetalis974 \
  --use-node-agent \
  --kubeconfig /etc/rancher/k3s/k3s.yaml

# 7. Attendre Velero (1-2 min)
sudo kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero \
  -n velero --timeout=180s --kubeconfig /etc/rancher/k3s/k3s.yaml

# 8. Lister les backups disponibles
sudo velero backup get --kubeconfig /etc/rancher/k3s/k3s.yaml

# 9. Restaurer le dernier backup
sudo velero restore create pra-restore-$(date +%Y%m%d) \
  --from-backup <NOM_DU_BACKUP> \
  --exclude-namespaces velero \
  --kubeconfig /etc/rancher/k3s/k3s.yaml

# 10. Suivre la restauration
sudo velero restore get --kubeconfig /etc/rancher/k3s/k3s.yaml

# 11. Vérifier les pods
sudo kubectl get pods --all-namespaces --kubeconfig /etc/rancher/k3s/k3s.yaml

# 12. Patcher les ingress avec la nouvelle IP
sudo kubectl patch ingress wordpress -n wordpress --type=json \
  -p="[{\"op\": \"replace\", \"path\": \"/spec/rules/0/host\", \"value\": \"wordpress.${PUBLIC_IP}.nip.io\"}]" \
  --kubeconfig /etc/rancher/k3s/k3s.yaml

sudo kubectl patch ingress odoo -n odoo --type=json \
  -p="[{\"op\": \"replace\", \"path\": \"/spec/rules/0/host\", \"value\": \"odoo.${PUBLIC_IP}.nip.io\"}]" \
  --kubeconfig /etc/rancher/k3s/k3s.yaml

# 13. Nettoyer les credentials
rm -f /tmp/credentials-velero
```

---

## 4. Vérification post-restauration

### Checklist obligatoire

| #   | Vérification         | Commande                                      | Attendu           |
| --- | -------------------- | --------------------------------------------- | ----------------- |
| 1   | k3s node ready       | `sudo kubectl get nodes`                      | `Ready`           |
| 2   | Pods WordPress       | `sudo kubectl get pods -n wordpress`          | `Running`         |
| 3   | Pods Odoo            | `sudo kubectl get pods -n odoo`               | `Running`         |
| 4   | Pods Monitoring      | `sudo kubectl get pods -n monitoring`         | `Running`         |
| 5   | Ingress configurés   | `sudo kubectl get ingress -A`                 | Hosts avec IP PRA |
| 6   | WordPress accessible | `curl -sI http://wordpress.<IP>.nip.io`       | HTTP 200/301      |
| 7   | Odoo accessible      | `curl -sI http://odoo.<IP>.nip.io`            | HTTP 200/303      |
| 8   | Grafana accessible   | `curl -sI http://grafana.<IP>.nip.io`         | HTTP 200/302      |
| 9   | Données Odoo         | Vérifier dernières commandes dans l'interface | Données < 24h     |
| 10  | Données WordPress    | Vérifier derniers articles                    | Données < 24h     |

### En cas de problème

```bash
# Logs d'un pod
sudo kubectl logs <pod-name> -n <namespace> --kubeconfig /etc/rancher/k3s/k3s.yaml

# Logs Velero restore
sudo velero restore logs <restore-name> --kubeconfig /etc/rancher/k3s/k3s.yaml

# Describe d'un pod en erreur
sudo kubectl describe pod <pod-name> -n <namespace> --kubeconfig /etc/rancher/k3s/k3s.yaml

# Vérifier les PVC
sudo kubectl get pvc --all-namespaces --kubeconfig /etc/rancher/k3s/k3s.yaml

# Events du cluster
sudo kubectl get events --all-namespaces --sort-by='.lastTimestamp' --kubeconfig /etc/rancher/k3s/k3s.yaml
```

---

## 5. Communication utilisateurs

### Message type à envoyer

```
OBJET : [METALIS] Activation Plan de Reprise — Nouveaux accès

Bonjour,

Suite à un incident sur notre site principal, les services METALIS
sont temporairement hébergés sur notre infrastructure de secours Azure.

Nouveaux accès :
- ERP Odoo    : http://odoo.<IP>.nip.io
- Site web    : http://wordpress.<IP>.nip.io
- Monitoring  : http://grafana.<IP>.nip.io

Les identifiants restent inchangés.
Les données sont à jour au <DATE DU DERNIER BACKUP>.

L'équipe IT reste à votre disposition.
```

---

## 6. Opération en mode PRA

### Points d'attention

- **Performance réduite** : VM B2s (4GB RAM) vs cluster on-prem (16GB)
- **Pas de monitoring CAO** : les fichiers SolidWorks ne sont pas sur la VM PRA
- **Velero schedule désactivé** : pas de backup automatique sur la VM PRA
- **Coûts Azure** : ~37€/mois pendant l'activation (à surveiller)

### Sauvegardes en mode PRA

```bash
# Backup manuel des données PRA (recommandé quotidiennement)
sudo velero backup create pra-daily-$(date +%Y%m%d) \
  --kubeconfig /etc/rancher/k3s/k3s.yaml
```

---

## 7. Retour sur site (failback)

Quand le site on-prem est restauré :

```bash
# 1. Sur la VM PRA : créer un backup final
sudo velero backup create failback-$(date +%Y%m%d) \
  --kubeconfig /etc/rancher/k3s/k3s.yaml

# 2. Sur le cluster on-prem restauré : restaurer ce backup
velero restore create failback-restore \
  --from-backup failback-$(date +%Y%m%d)

# 3. Vérifier les services on-prem

# 4. Basculer les utilisateurs sur les URLs on-prem

# 5. Désactiver le PRA Azure (voir section 8)
```

---

## 8. Désactivation PRA

```bash
# Option A : Script
cd PRA/scripts
./deactivate-pra.sh

# Option B : Manuel
az vm deallocate --resource-group rg-metalis-pra --name vm-metalis-pra

# Option C : GitHub Actions
# → Actions → PRA METALIS → Run workflow → action: deactivate
```

---

## 9. Test de restauration (drill)

### Fréquence recommandée : 1x/mois (1er samedi)

### Procédure de test

```bash
# 1. Activer le PRA
./activate-pra.sh

# 2. Vérifier checklist section 4 (toutes les cases cochées)

# 3. Tester l'accès aux données
#    - Se connecter à Odoo, vérifier les dernières commandes
#    - Se connecter à WordPress, vérifier les derniers articles

# 4. Documenter le résultat dans un rapport
#    Date: YYYY-MM-DD
#    Backup utilisé: <nom>
#    Durée activation: XX minutes
#    Services OK: [WordPress] [Odoo] [Monitoring]
#    Problèmes: aucun / <description>
#    Opérateur: <nom>

# 5. Désactiver le PRA
./deactivate-pra.sh
```

### Template de rapport de test

```markdown
## Rapport Test PRA — YYYY-MM-DD

| Critère                  | Résultat                    |
| ------------------------ | --------------------------- |
| Date                     | YYYY-MM-DD                  |
| Opérateur                | Nom Prénom                  |
| Backup utilisé           | daily-backup-YYYYMMDD020000 |
| Durée activation         | XX minutes                  |
| WordPress                | ✅ OK / ❌ KO               |
| Odoo                     | ✅ OK / ❌ KO               |
| Monitoring               | ✅ OK / ❌ KO               |
| Données récentes (< 24h) | ✅ / ❌                     |
| RTO respecté (< 4h)      | ✅ / ❌                     |
| Problèmes rencontrés     | Aucun / Description         |
| Actions correctives      | Aucune / Description        |
```

---

## 10. Contacts & escalade

| Rôle             | Nom        | Contact                                                 |
| ---------------- | ---------- | ------------------------------------------------------- |
| Chef de projet   | Gregory M. | À compléter                                             |
| RSSI             | Lylian C.  | À compléter                                             |
| Architecte Infra | Thibaut D. | À compléter                                             |
| Support Azure    | Microsoft  | https://portal.azure.com/#blade/Microsoft_Azure_Support |

### Escalade

1. **Niveau 1** (0-15 min) : Architecte Infra → évalue et déclenche
2. **Niveau 2** (15-30 min) : Chef de projet → valide et coordonne
3. **Niveau 3** (30+ min) : Direction → décision stratégique
