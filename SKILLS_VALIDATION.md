# 🏭 Validation des Compétences - METALIS (Atelier & E-Commerce)

> **Contexte** : Projet MSPR Virtualisation 2025-2026 — Atelier métal/bois + ventes en ligne
> **Échelle** : 40 employés (production 2×8, bureaux, télétravail)
> **Enjeu** : Continuité production + performance e-commerce (WooCommerce CDN)
> **Objectif** : RTO 1h acceptable, RPO 5h indisponibilité acceptable, PRA/PCA urgent
> **Date Rendu** : 22 juin 2026 23h | **Soutenance** : 25 juin 2026

---

## 📋 Référence — 8 Objectifs Pédagogiques

Pour METALIS, valider ces 8 compétences :

| #   | Objectif                                                    | État | Deadline | Validation |
| --- | ----------------------------------------------------------- | ---- | -------- | ---------- |
| 1️⃣  | **Hyperviseur** (Proxmox/XCP-ng production-grade)           | ⚠️   | 15 juin  | [ ]        |
| 2️⃣  | **Ressources & Sécurité** (Segmentation atelier/e-com)      | ⚠️   | 15 juin  | [ ]        |
| 3️⃣  | **Hybride On-Prem / Cloud** (WooCommerce CDN Cloudflare)    | ⚠️   | 18 juin  | [ ]        |
| 4️⃣  | **Supervision** (Monitoring production Odoo + WooCommerce)  | ⚠️   | 18 juin  | [ ]        |
| 5️⃣  | **Sauvegardes & PRA** (Snapshot NAS HA + off-site immuable) | ⚠️   | 20 juin  | [ ]        |
| 6️⃣  | **VDI & Profils** (Accès distant CAO / e-commerce admin)    | ⚠️   | 18 juin  | [ ]        |
| 7️⃣  | **Hyper-V & Résilience** (Clustering HA atelier robuste)    | ⚠️   | 20 juin  | [ ]        |
| 8️⃣  | **PRA / PCO** (Plan continuité production + e-commerce)     | ⚠️   | 20 juin  | [ ]        |

---

## ✅ Checklist de Rendu METALIS

```
GRP2-METALIS/
├── 01-contexte-client/
│   ├── README.md                      ✅ Présentation atelier & e-commerce
│   ├── fiche-entreprise.md           ✅ Cas client atelier & ventes online
│   └── besoins-reformules.md         ✅ Analyse production atelier + WooCommerce
│
├── 02-architecture/
│   ├── ARCHITECTURE.md               ✅ Stratégie NAS HA + WooCommerce CDN
│   ├── schemas/
│   │   ├── architecture-globale.md   ✅ On-prem atelier + cloud e-commerce
│   │   ├── nas-storage.md            ✅ NAS HA dual controller + snapshots
│   │   ├── wifi-mesh.md              ✅ Aruba Wi-Fi 6 mesh atelier robuste
│   │   ├── firewall-dual-wan.md      ✅ Firewall HA dual WAN + 4G backup
│   │   ├── odoo-architecture.md      ✅ Odoo HA + optimisations
│   │   ├── woocommerce-cloud.md      ✅ WooCommerce cloud + Cloudflare CDN
│   │   └── reseau.png / .svg         ✅ Diagramme réseau visuel
│   └── pra-pca-urgency.md            ✅ Justification urgence PRA/PCA
│
├── 03-mise-en-oeuvre/
│   ├── 01-hyperviseur/
│   │   ├── selection-justification.md ✅ Proxmox vs XCP-ng (production atelier)
│   │   ├── clustering-config.md      ✅ HA clustering pour continuité
│   │   └── logs-implementation.txt   ✅ Preuves configuration
│   │
│   ├── 02-vms/
│   │   ├── dimensionnement.md         ✅ Specs : Odoo HA, CAO workstations, admin
│   │   ├── templates/
│   │   │   ├── linux-odoo.sh         ✅ Template VM Odoo
│   │   │   └── windows-cao.sh        ✅ Template VM CAO (SolidWorks 4GB)
│   │   └── inventaire-vms.md         ✅ Liste VMs + specs disque
│   │
│   ├── 03-reseau/
│   │   ├── firewall-dual-wan.md      ✅ WAN principal + 4G failover
│   │   ├── wifi-mesh-aruba.md        ✅ Wi-Fi 6 mesh atelier déploiement
│   │   ├── matrix-flux.md            ✅ Tableau flux (40 users, atelier, e-com)
│   │   ├── vlan-segmentation.md      ✅ VLAN atelier / bureaux / admin / DMZ
│   │   └── vpn-remote-access.md      ✅ VPN télétravail (CAO, Odoo)
│   │
│   ├── 04-stockage-nas/
│   │   ├── nas-ha-config.md          ✅ NAS HA dual controller + snapshots
│   │   ├── cao-storage.md            ✅ Stockage SolidWorks 4GB par poste
│   │   ├── nfs-shares.md             ✅ Partages NFS atelier + bureaux
│   │   └── snapshot-strategy.md      ✅ Rotation snapshots immuables
│   │
│   ├── 05-backup-pra/
│   │   ├── plan-backup-detaille.md   ✅ Snapshot NAS + off-site AWS/Equinix
│   │   ├── pra-procedure.md          ✅ Steps restauration atelier (RTO 1h)
│   │   ├── test-restauration.md      ✅ Rapport test snapshot restore
│   │   ├── rpo-rto-mesure.md         ✅ RPO 5h, RTO 1h validés
│   │   └── failover-wan.md           ✅ Basculement 4G si WAN principal down
│   │
│   ├── 06-supervision/
│   │   ├── prometheus-config.md      ✅ Prometheus agents pour Odoo/NAS/WiFi
│   │   ├── grafana-dashboards.md     ✅ Dashboards production atelier + e-com
│   │   ├── alerts-config.md          ✅ Seuils : CPU, RAM, storage, WAN latency
│   │   ├── odoo-monitoring.md        ✅ Métriques ERP (transactions, users)
│   │   ├── woocommerce-monitoring.md ✅ E-commerce : traffic, conversion, errors
│   │   └── screenshots-live.txt      ✅ Preuves monitoring en prod
│   │
│   ├── 07-odoo-optimization/
│   │   ├── odoo-ha-config.md         ✅ Odoo server HA + load balancing
│   │   ├── database-tuning.md        ✅ PostgreSQL performance, backups
│   │   ├── cache-redis.md            ✅ Redis caching Odoo (perfs)
│   │   └── load-test.md              ✅ Test charge Odoo 40 users concurrents
│   │
│   ├── 08-woocommerce-cloud/
│   │   ├── woocommerce-setup.md      ✅ WooCommerce cloud + API
│   │   ├── cloudflare-cdn.md         ✅ CDN configuration (cache, minify)
│   │   ├── auto-scaling.md           ✅ Scaling policy WooCommerce (pic ventes)
│   │   └── load-test-ecom.md         ✅ Test charge e-commerce (simulé pic)
│   │
│   ├── 09-vdi-remote-access/
│   │   ├── cao-rdp-config.md         ✅ RDP WAN pour CAO (SolidWorks remote)
│   │   ├── odoo-vpn.md               ✅ VPN accès Odoo télétravail
│   │   ├── bandwidth-tuning.md       ✅ Optimisations latence WAN
│   │   └── test-remote-cao.md        ✅ Test RDP CAO depuis domicile
│   │
│   └── 10-scripts/
│       ├── snapshot-automation.sh    ✅ Snapshot NAS scheduling
│       ├── odoo-backup.sh            ✅ Backup PostgreSQL Odoo + data
│       ├── woocommerce-sync.sh       ✅ Sync inventory Odoo ↔ WooCommerce
│       ├── failover-wan.sh           ✅ Détection WAN down + basculement 4G
│       └── monitoring-deploy.sh      ✅ Déploiement Prometheus agents
│
├── 04-objectifs-pedagogiques.md       ✅ **MANDATORY** : Mappage 8 objectifs METALIS
├── 05-pra-pco-production.md           ✅ Plan continuité production + e-commerce
├── 06-entretien-2-evolutions.md       ✅ Feedback 16 juin intégré
├── 07-load-testing-results.md         ✅ Tests de charge Odoo + WooCommerce
└── README.md                          ✅ Sommaire + guide navigation

```

### Points Obligatoires pour METALIS

- [ ] **Contexte atelier & e-commerce reformulé** — Continuité production + ventes online essentielles
- [ ] **Architecture NAS HA** — Dual controller, snapshots immuables, off-site backup
- [ ] **Hyperviseur production-grade** — Proxmox vs XCP-ng justifié pour continuité atelier
- [ ] **Réseau robuste** — Firewall dual WAN + 4G failover, Wi-Fi 6 mesh Aruba stable
- [ ] **Odoo HA + optimisation** — Load balancing, PostgreSQL tuning, Redis caching, test charge 40 users
- [ ] **WooCommerce cloud + CDN** — Cloudflare setup, auto-scaling, test charge peak sales
- [ ] **Accès distant CAO** — RDP WAN SolidWorks 4GB, VPN Odoo télétravail, test latency
- [ ] **Supervision Prometheus** — Monitoring Odoo transactions, WAN latency, e-commerce traffic
- [ ] **Backup snapshots NAS** — Off-site immuable AWS/Equinix, rotation strategy, test restore
- [ ] **PRA/PCO complet** — Failover automatique WAN, restore Odoo < 1h, e-commerce continuity
- [ ] **8 objectifs détaillés** — Fichier 04-objectifs-pedagogiques.md complet
- [ ] **Repo public** — Aucune credential Odoo, aucune clé Cloudflare, aucune IP en clair

---

## 📊 Grille Validation par Objectif — METALIS

### Objectif 1️⃣ — Hyperviseur Production Atelier

**METALIS Spécifique :**

- [ ] Justifier hyperviseur pour continuité 2×8 production (HA requis, failover rapide)
- [ ] Comparer Proxmox vs XCP-ng : stabilité, clustering, performance I/O
- [ ] Documenter clustering HA : nœuds, quorum, recovery time < 5min
- [ ] Expliquer choix pour SolidWorks VMs (GPU pass-through ?)
- [ ] Démontrer création VM template Odoo + SolidWorks

**Livrables :**

- [ ] Document justification hyperviseur (production atelier context)
- [ ] Schéma architecture HA clustering
- [ ] Config clustering validée + logs failover test
- [ ] Specs GPU/CPU pour SolidWorks VMs

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 2️⃣ — Ressources & Sécurité (Atelier & E-Commerce)

**METALIS Spécifique :**

- [ ] Dimensionner VMs : Odoo HA (DB + app server), SolidWorks CAO (GPU), e-commerce
- [ ] Atelier VM resources : shared NFS CAO 4GB storage, production shift 2×8
- [ ] Sécurité : isoler Odoo (données commerciales), CAO (IP sensibles), e-commerce (DMZ)
- [ ] VLAN segmentation : atelier / bureaux / admin / DMZ e-commerce
- [ ] Firewall rules : WAN incoming 443/80 (WooCommerce), bloquer inter-VLANs non-autorisés
- [ ] Accès télétravail : VPN 2FA, RDP restrictif, audit trail

**Livrables :**

- [ ] Tableau dimensionnement VMs (40 users, CAO 4GB per poste)
- [ ] Matrice flux réseau (atelier, e-commerce, télétravail, cloud)
- [ ] Schéma VLANs + firewall rules
- [ ] Documentation sécurité CAO (IP export controls)

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 3️⃣ — Hybride On-Prem / Cloud (WooCommerce + Backups)

**METALIS Spécifique :**

- [ ] On-prem : Odoo (données commerciales), NAS atelier (CAO, production docs)
- [ ] Cloud : WooCommerce (SaaS public), Cloudflare CDN (global), backups off-site AWS
- [ ] Connectivité on-prem ↔ cloud : VPN WAN, intégration Odoo ↔ WooCommerce (API)
- [ ] Justifier stratégie : local pour production continuity, cloud pour e-commerce scalability
- [ ] Tester failover WAN → cloud e-commerce reste UP

**Livrables :**

- [ ] Architecture hybrid on-prem + cloud (justification)
- [ ] API integrations Odoo ↔ WooCommerce (inventory sync)
- [ ] Failover WAN test report (WooCommerce availability > 99.5%)

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 4️⃣ — Supervision Atelier & E-Commerce

**METALIS Spécifique :**

- [ ] Prometheus : agents Odoo server, NAS, WiFi, WAN link, WooCommerce endpoint
- [ ] Dashboards Grafana : Odoo transactions/hour, concurrent users, CAO poste status
- [ ] E-commerce : WooCommerce traffic, conversion rate, Cloudflare cache hit ratio
- [ ] Alertes : Odoo CPU > 80%, NAS storage > 90%, WAN latency > 100ms, e-commerce 5xx errors
- [ ] Audit logs : Odoo access, NFS mount failures, firewall changes

**Livrables :**

- [ ] Prometheus + Grafana install doc
- [ ] Agents config (Odoo, NAS, WiFi, external monitoring)
- [ ] Dashboards screenshots + alert rules
- [ ] Test alert trigger (ex: CPU spike, validation alert sent)

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 5️⃣ — Sauvegardes & PRA (NAS Snapshots + Off-Site)

**METALIS Spécifique :**

- [ ] NAS snapshot strategy : snapshots toutes les 4h (immédiat restore), rétention 1 mois
- [ ] Off-site backup : NAS snapshots vers AWS Glacier nightly (immuable 7 ans archivage)
- [ ] Odoo backup : PostgreSQL full nightly, binlogs hourly → AWS S3
- [ ] RPO/RTO : RPO 5h, RTO 1h atelier down acceptable, e-commerce must restore < 15min
- [ ] Test restauration : snapshot NAS restore < 5min, Odoo restore < 30min

**Livrables :**

- [ ] NAS snapshot policy + retention
- [ ] Backup to AWS Glacier config + scheduling
- [ ] Odoo PostgreSQL backup procedure
- [ ] Restore test report : date, snapshot size, restore time, data integrity check

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 6️⃣ — VDI & Accès Distant (CAO + Odoo)

**METALIS Spécifique :**

- [ ] RDP pour CAO (SolidWorks) : compression, optimization WAN latency
- [ ] VPN Odoo : télétravail accès backend, data encryption, 2FA
- [ ] Bandwidth tuning : SolidWorks RDP needs (4GB storage latency), VPN overhead
- [ ] Testing : RDP SolidWorks from home (latency < 150ms target), VPN Odoo login
- [ ] Failover WAN 4G : remote CAO users remain accessible via 4G backup

**Livrables :**

- [ ] RDP + VPN security architecture
- [ ] SolidWorks remote optimization settings
- [ ] Bandwidth analysis (WAN peak usage)
- [ ] Test results : RDP latency, VPN throughput, failover time

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 7️⃣ — Hyper-V & Résilience (Lien Atelier Windows)

**METALIS Spécifique :**

- [ ] Lien atelier résilience Windows : clustering, failover, live migration applicables METALIS ?
- [ ] Comparer Hyper-V (avec WSFC clustering) vs Proxmox pour VM SolidWorks failover
- [ ] METALIS decision : Proxmox HA OU Hyper-V WSFC (justify choix)
- [ ] Scénarios failover : nœud down → workstations CAO basculent automatiquement
- [ ] Test failover : stop VM SolidWorks nœud 1 → bascule nœud 2 (< 1min)

**Livrables :**

- [ ] Comparatif Hyper-V vs Proxmox pour atelier résilience
- [ ] Architecture failover clustering validée
- [ ] Failover test report (test date, scénario, timing)
- [ ] Lien atelier Windows (WSFC concepts, quorum, heartbeats)

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

### Objectif 8️⃣ — PRA / PCO Complet (Atelier + E-Commerce)

**METALIS Spécifique :**

- [ ] PRA atelier : restauration Odoo, NAS CAO files, production shift continuity < 1h
- [ ] PCO e-commerce : WooCommerce cloud remain UP, Cloudflare CDN failover auto
- [ ] Services critiques : Odoo (commercial data), NAS (production docs), e-commerce (revenue)
- [ ] RTO/RPO : Odoo 30min, NAS 1h, e-commerce 15min (cloud-side)
- [ ] Checklist PRA : contact manager, test backups, notify teams, restore validation
- [ ] Drill PRA : test atelier restore (Odoo + NAS) + e-commerce continuity

**Livrables :**

- [ ] PRA/PCO document (1-2 pages)
- [ ] Services critiques matrix (RTO/RPO cible per service)
- [ ] Activation checklist (responsabilités par role)
- [ ] Drill report (date, scenario, timing, issues found, resolutions)
- [ ] Post-drill lessons learned + improvements

**État :** ❌ / ⚠️ / ✅ | **Notes :**

---

## 📅 Timeline Validation METALIS

| Semaine         | Tâches                                               | Status | Blocage? |
| --------------- | ---------------------------------------------------- | ------ | -------- |
| **Sem 1**       | Repo public ✅; entretien 1 ✅; architecture draft   | ✅     | Non      |
| **Sem 2**       | Hyperviseur sélectionné; Odoo vs SolidWorks VMs plan | ⚠️     |          |
| **Sem 3**       | Hyperviseur install salle campus; NAS config         | ⚠️     |          |
| **16 juin AM**  | **Entretien 2** — Feedback formateur intégré         | ⏳     | —        |
| **Sem 4**       | Odoo HA + PostgreSQL; WooCommerce integration test   | ⚠️     |          |
| **Sem 5**       | WiFi mesh deployment; load test Odoo/e-com           | ⚠️     |          |
| **20 juin**     | **Drill PRA** — Test snapshot restore + failover WAN | ⚠️     |          |
| **21 juin**     | Finalize docs; 8 objectifs complétés                 | ⚠️     |          |
| **22 juin 23h** | **Rendu final** — Email + repo verrouillé            | ⏳     | —        |
| **23 juin**     | Annonce cas soutenance (METALIS ou autre)            | ⏳     | —        |
| **25 juin PM**  | **Soutenance** (si METALIS annoncé)                  | ⏳     | —        |

---

## ⚠️ Risques Identifiés METALIS

| Risque                        | Impact                       | Mitigation                                      | Status |
| ----------------------------- | ---------------------------- | ----------------------------------------------- | ------ |
| Complexity Odoo + WooCommerce | Retard integration           | Commencer setup Odoo sem 2; utiliser addon sync | 🔴     |
| SolidWorks GPU passthrough    | Driver issues, failover bugs | Test setup sem 3; have CPU-only fallback VM     | 🟡     |
| WAN latency SolidWorks        | RDP unusable                 | Optimize bandwidth sem 4; test from home early  | 🟡     |
| NAS HA clustering             | Config time                  | Pre-config NAS vendor recommandations sem 2     | 🟡     |
| Load test coordination        | Peak traffic simulation      | Automate load gen tools sem 3                   | 🟡     |
| Wi-Fi 6 mesh deployment       | Coverage gaps atelier        | Survey floor plan sem 2; stage APs week 4       | 🟡     |

---

## ✏️ Notes Équipe METALIS

_À remplir au fur et à mesure par le groupe._

```
Décisions d'architecture :
- [DATE] Choix Proxmox (vs XCP-ng) : Reasons : GPU support CAO, smaller learning curve.
- [DATE] Odoo + PostgreSQL tuning : Redis cache decision pour perfs.
- [DATE] WooCommerce SaaS + Cloudflare CDN : off-load e-commerce cloud, local Odoo.
- [DATE] NAS HA snapshot strategy : 4h interval, 1 month local retention.

Blocages rencontrés :
- [DATE] SolidWorks licensing : resolved community lab license.
- [DATE] WAN 4G backup pricing : evaluated providers, selected [PROVIDER].

Feedback entretien 2 (16 juin) :
- [À REMPLIR POST-ENTRETIEN]

Tests charge résultats :
- Odoo : [X] concurrent users, [Y] transactions/sec avg, [Z] max latency.
- WooCommerce : [A] page views/sec, [B] conversion rate, [C] 5xx errors.

Load test findings :
- [SUMMARY]
```

---

**Dernier update :** [À remplir]
**Groupe:** [À remplir : 3 noms]
**État global :** ❌ En démarrage | ⚠️ En cours | ✅ Complété
