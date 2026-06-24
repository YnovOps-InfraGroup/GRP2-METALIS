# Velero Backup — Quick Start METALIS

**Cluster :** k3s (`metalis-k3s` — 10.1.248.6)
**Version Velero :** v1.14.0
**Plugin Azure :** velero-plugin-for-microsoft-azure:v1.10.0
**Dernière mise à jour :** 22 juin 2026

---

## 📊 Architecture Backup

```
k3s (10.1.248.6)
│
├── Velero + Node Agent (restic/kopia)
│   │
│   ├── backup-quotidienne (2h AM) ──► Azure Blob Storage
│   │   └── TTL: 30 jours              (BSL default)
│   │
│   └── backup-hebdo-samedi (sam 8h) ─► MinIO Windows Server
│       └── TTL: 30 jours               (BSL local-minio)
│
└── Données sauvegardées :
    ├── Toutes les ressources k8s (namespaces, deployments, services, secrets...)
    └── Contenu des PVC (WordPress, Odoo/PostgreSQL, Grafana, Prometheus)
```

**Règle 3-2-1 ✅** : 3 copies (prod + MinIO + Azure) · 2 médias (disque + cloud) · 1 off-site (Azure)

---

## 🔧 Ressources Azure Déployées

| Ressource | Valeur |
|-----------|--------|
| Subscription | `sub-t-dabbadie-student` |
| Region | Switzerland North |
| Resource Group | `rg-metalis` |
| Storage Account | `stobkpmetalis974` |
| Container Blob | `contmetalisbkp974` |
| Service Principal | `sp-velero-k3s` |
| Permissions SP | Storage Blob Data Contributor |

---

## 🚀 Installation Velero (déjà fait)

### Prérequis

```bash
# Azure CLI authentifié
az login --tenant <TENANT_ID>
az account set --subscription <SUBSCRIPTION_ID>

# Velero CLI installé
velero version --client-only
# Expected: v1.14.0
```

### Déploiement sur le cluster

```bash
# 1. Créer le fichier credentials (voir credentials-velero.example)
cp credentials-velero.example credentials-velero
# Remplir les valeurs (Client ID, Secret, Storage Key)

# 2. Installer Velero
velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.10.0 \
  --bucket contmetalisbkp974 \
  --secret-file ./credentials-velero \
  --backup-location-config resourceGroup=rg-metalis,storageAccount=stobkpmetalis974 \
  --use-node-agent

# 3. Vérifier
kubectl get pods -n velero
# Expected: velero + node-agent = Running
```

---

## ⏰ Schedules Configurés

### Backup quotidien → Azure Blob (PRA)

```bash
velero schedule create backup-quotidienne \
  --schedule="0 2 * * *" \
  --default-volumes-to-fs-backup \
  --ttl 720h
```

> Utilisé par le PRA Azure pour la restauration (voir `PRA/RUNBOOK.md`)

### Backup hebdomadaire → MinIO (local)

```bash
velero schedule create backup-hebdo-samedi \
  --schedule="0 8 * * 6" \
  --storage-location local-minio \
  --default-volumes-to-fs-backup
```

> Backup local sur MinIO Windows Server (redondance on-prem)

### Vérifier les schedules

```bash
velero schedule get
velero backup get
```

---

## 📋 Commandes Utiles

### Backups

```bash
# Lister les backups
velero backup get

# Créer un backup manuel
velero backup create manual-$(date +%Y%m%d-%H%M)

# Détails d'un backup
velero backup describe <nom-backup>

# Logs d'un backup
velero backup logs <nom-backup>
```

### Restauration

```bash
# Lister les backups disponibles
velero backup get

# Restaurer un backup complet
velero restore create --from-backup <nom-backup>

# Restaurer un namespace spécifique
velero restore create --from-backup <nom-backup> --include-namespaces odoo

# Vérifier la restauration
velero restore get
velero restore describe <nom-restore>
```

### Diagnostic

```bash
# État du BSL (Backup Storage Location)
velero backup-location get

# Vérifier la connexion Azure
velero backup-location get default -o yaml

# Logs Velero server
kubectl logs -n velero -l app.kubernetes.io/name=velero

# Logs Node Agent
kubectl logs -n velero -l name=node-agent
```

---

## ⚠️ Limitations & Notes

- **Données SQL** : `--default-volumes-to-fs-backup` copie les fichiers bruts des PVC
  (PostgreSQL data dir, MariaDB data dir). Ce n'est PAS un `pg_dump`. Acceptable
  car le backup tourne à 2h (activité nulle) et PostgreSQL a du crash recovery (WAL).
- **CAO (4To)** : Les fichiers SolidWorks sur NAS ne sont PAS couverts par Velero.
  → Utiliser Synology Hyper Backup vers Azure Blob (Cool tier) séparément.
- **RPO effectif** : 24h (backup à 2h AM). Données du jour = perdues en cas de sinistre.
- **RTO PRA** : ~30 min de restauration Velero + ~30 min de vérification = ~1h.

---

## 🔗 Références

- [Installation détaillée](../../k8s/velero/installation.md)
- [PRA Azure — Runbook](../../PRA/RUNBOOK.md)
- [PRA Azure — README](../../PRA/README.md)
- [MinIO Setup](../../docs/minio.md)
- [credentials-velero.example](./credentials-velero.example)

✓ jq installed (for JSON parsing)
brew install jq # macOS
apt install jq # Linux

═══════════════════════════════════════════════════════════════════

🚀 READY TO DEPLOY?

Step-by-step commands:

# 1. Navigate to velero directory

cd infrastructure/velero

# 2. Make scripts executable

chmod +x deploy.sh create-sp.sh

# 3. RUN DEPLOYMENT (creates Azure resources)

./deploy.sh

# 4. RUN SP CREATOR (fills credentials)

./create-sp.sh

# 5. VERIFY credentials file was created

ls -la credentials-velero
cat credentials-velero

# 6. SHARE WITH THIBAUT (via secure channel)

# Don't share via email/chat! Use 1Password/Bitwarden instead

═══════════════════════════════════════════════════════════════════

⚠️ SECURITY REMINDERS:

❌ NEVER commit credentials-velero to git
❌ NEVER share secrets via email/Slack/chat
❌ NEVER run scripts without understanding them

✅ Store in password manager (1Password, Bitwarden, etc)
✅ Share via secure channel only
✅ Rotate credentials every 90 days

═══════════════════════════════════════════════════════════════════

📚 DOCUMENTATION:

- Full guide: velero/README.md
- Script info: velero/deploy.sh (well-commented)
- Bicep template: velero/main.bicep (detailed comments)
- Infrastructure: infrastructure/README.md

═══════════════════════════════════════════════════════════════════

🆘 TROUBLESHOOTING:

Error: "Not authenticated"
→ az login
→ az account set --subscription <votre-subscription-id>

Error: "Insufficient permissions"
→ Verify you're subscription owner
→ az role assignment list --scope /subscriptions/<sub-id>

Error: "Bicep validation failed"
→ Check main.bicep syntax: az bicep build --file main.bicep

Error: "Storage Account name not unique"
→ Automatic - uses uniqueString() in Bicep

═══════════════════════════════════════════════════════════════════

💬 QUESTIONS?

For Bicep/Azure: gyme
For Velero install: Thibaut
For k3s cluster: gyme

═══════════════════════════════════════════════════════════════════

✨ HAPPY DEPLOYING! ✨

EOF
