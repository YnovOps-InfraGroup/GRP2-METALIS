# 🏭 METALIS - Modernisation Infrastructure

**Groupe 2 — RMI (Run My Infra)** | Sujet 1 — Atelier & E-Commerce | Virtualisation M1 INFRA 2025-2026

> **Équipe :** Gregory M. _(Chef de projet / Auditeur PRA)_ · Lylian C. _(RSSI)_ · Thibaut D. _(Architecte Infra)_
> **Contexte :** L'ancien prestataire de MEDISOL a fait faillite après un incident grave chez METALIS (48h d'arrêt). L'infrastructure METALIS est donc directement liée à notre périmètre.
> **Entretien 1 :** ⏳ À planifier | **Entretien 2 :** ⏳ 16 juin 2026 après-midi | **Rendu :** 22 juin 23h

## 📋 Contexte du Projet

**METALIS** est une PME de fabrication métal/bois sur mesure + vente e-commerce en croissance. Ce projet adresse des problèmes critiques de stabilité infrastructure, performance et continuité d'activité.

### Enjeux Clés

- 🔧 **Production Continue** - Atelier 2×8, zéro tolérance aux arrêts
- 💾 **Données CAO Volumineuses** - SolidWorks 4Go, besoin de stockage stable
- 🌐 **Wi-Fi Instable** - Coupures fréquentes en atelier
- 📦 **E-Commerce Fiable** - Pic de charge lors promo (plantes souvent)
- 🛡️ **Sauvegarde Robuste** - Perte NAS l'année dernière = impact majeur
- 👥 **Télétravail** - Commerciaux distants besoin d'accès fiable

---

## 🎯 Objectifs du Projet

| Objectif                             | Priorité    | Budget | Statut        |
| ------------------------------------ | ----------- | ------ | ------------- |
| Stabiliser NAS + redondance stockage | 🔴 Critique | ~15k€  | Planification |
| Implémenter PRA/PCA                  | 🔴 Critique | ~10k€  | Planification |
| Wi-Fi atelier robuste                | 🟠 Haute    | ~5k€   | Planification |
| ERP Odoo optimisé                    | 🟠 Haute    | ~8k€   | Planification |
| Infrastructure cloud hybrid          | 🟡 Moyenne  | ~12k€  | À évaluer     |

**Budget Total Enveloppe:** ~50 000€

---

## � Validation des Compétences

**IMPORTANT** : Consulter [SKILLS_VALIDATION.md](./SKILLS_VALIDATION.md) pour :

- ✅ Grille de validation des **8 objectifs pédagogiques** (Hyperviseur, Ressources, Hybride, Supervision, PRA/Backups, VDI, Hyper-V, PRA/PCO)
- 📋 Checklists de rendu (22 juin 23h)
- 📊 Matrices d'auto-évaluation adaptées METALIS (atelier + e-commerce)
- 🎯 Spécificités METALIS : Odoo HA, WooCommerce CDN, NAS snapshots, failover WAN
- ⚠️ Risques identifiés et mitigations
- 📅 Timeline validation semaine par semaine
- 📊 Load testing resultats expected

---

## �📦 Structure du Projet

```
GRP2-METALIS/
├── docs/
│   ├── ARCHITECTURE.md          # Architecture cible (on-prem + cloud)
│   ├── AUDIT_FINDINGS.md        # État infrastructure actuelle
│   ├── REQUIREMENTS.md          # Exigences métier & techniques
│   ├── PRA_PCA_PLAN.md          # Plan continuité activité
│   ├── CAO_STRATEGY.md          # Stratégie stockage CAO
│   └── WIFI_DEPLOYMENT.md       # Plan Wi-Fi atelier
├── infrastructure/
│   ├── network/                 # Configs réseau (VLAN, Wi-Fi)
│   ├── storage/                 # NAS, sauvegarde, redondance
│   ├── compute/                 # Serveurs, VMs production
│   ├── erp/                     # Odoo config/deployment
│   └── ecommerce/               # WooCommerce/WordPress
├── scripts/
│   ├── backup/                  # Stratégie sauvegarde immuable
│   ├── restore/                 # Tests reprise réguliers
│   ├── monitoring/              # Supervision infra
│   └── failover/                # Basculement automatique
├── tests/
│   ├── pra_drills/              # Exercices PRA mensuels
│   ├── load_tests/              # Tests charge E-Commerce
│   └── wifi_tests/              # Validations Wi-Fi coverage
├── README.md
├── CONTRIBUTING.md
└── .gitignore
```

---

## 🚀 Démarrage Rapide

### Prérequis

- Accès administrateur infrastructure METALIS
- Outils audit réseau & stockage
- Accès à Odoo / WooCommerce admin
- Contact prestataire maintenance CNC

### Étapes Initiales

1. **Audit Infrastructure** → État actuel (docs/AUDIT_FINDINGS.md)
2. **Analyser Problèmes** → Cause root, impact production
3. **Définir Requirements** → Prioriser avec direction (docs/REQUIREMENTS.md)
4. **Architecture Cible** → Proposer solution (docs/ARCHITECTURE.md)
5. **PRA Planning** → RTO/RPO, stratégie reprise (docs/PRA_PCA_PLAN.md)

---

## 💡 Points Critiques à Adresser

### 1️⃣ Stockage CAO (SolidWorks 4Go)

- [ ] NAS Synologie actuel : état, capacité, RAID ?
- [ ] Redondance/Snapshots actuels ?
- [ ] Sauvegarde externalisée immuable ?
- [ ] PDM (Product Data Management) en place ?
- [ ] Bande passante réseau suffisante pour CAO volumineuse ?

### 2️⃣ Wi-Fi Atelier

- [ ] Couverture physique insuffisante ?
- [ ] Interférences (machines CNC, fours) ?
- [ ] Nombre de devices simultanés ?
- [ ] Séparation Wi-Fi prod/bureaux/visiteurs ?

### 3️⃣ ERP Odoo Performance

- [ ] Version Odoo ? On-prem ou cloud ?
- [ ] Base de données overload aux heures pointe ?
- [ ] Ressources serveur suffisantes ?
- [ ] Optimisation requêtes/indexing ?

### 4️⃣ E-Commerce WooCommerce

- [ ] Hébergement actuel ? Capacity ?
- [ ] CDN pour assets (images produits) ?
- [ ] Cache layer (Redis, Varnish) ?
- [ ] Tests de charge avant promo ?

### 5️⃣ PRA/PCA

- [ ] RTO cible : 1h (défini) ?
- [ ] RPO cible : 5h indispo (à confirmer) ?
- [ ] Qui déclenche le failover ?
- [ ] Fréquence tests : mensuels ?

---

## 📊 Métriques de Succès

- ✅ **Zéro panne** de production >2h pendant 3 mois
- ✅ **Wi-Fi atelier** : 99.5% uptime, signal >-70dBm partout
- ✅ **Temps réaction PRA** : <15min de décision à activé
- ✅ **Sauvegarde validée** : restore test 1x/mois ✓
- ✅ **Commerciaux distants** : accès ERP <2s même pic
- ✅ **E-Commerce** : <2s page load, zéro downtime promo

---

## 🔐 Sécurité

**❌ DONNÉES SENSIBLES STRICTEMENT INTERDITES** dans ce repo (public) :

- ⛔ Pas de credentials, API keys, tokens
- ⛔ Pas de plan réseau détaillé, IP réelles
- ⛔ Pas de données client (commandes, devis)
- ⛔ Pas de config production complète

Utiliser `.env.template` pour templates (voir `.gitignore`).

---

## 📞 Points de Contact

| Rôle | Nom | Responsabilité |
|------|-----|----------------|
| Chef de Projet / Auditeur PRA | Gregory M. | PRA/PCA, coordination client |
| RSSI | Lylian C. | Sécurité, réseau, accès |
| Architecte Infra | Thibaut D. | Hyperviseur, NAS, Wi-Fi, ERP |
| Formateur / Client simulé | Florian G. | Entretiens, validation |

> **Organisation :** Groupe 2 : Sujet 1 METALIS

---

## 📅 Calendrier MSPR

| Date | Événement | Statut |
|------|-----------|--------|
| Sem. 1–2 | Entretien 1 METALIS + audit | ⏳ À planifier |
| Sem. 2–3 | Architecture 3 scénarios | ⏳ |
| 16 juin 2026 (après-midi) | ⏳ Entretien 2 METALIS | À venir |
| 16 → 22 juin | Finalisation docs + tests PRA | À venir |
| **22 juin 23h** | **Rendu final** → florian.guillemard@ynov.com | ⏳ |
| 23 juin | Annonce cas soutenance | ⏳ |
| 25 juin | Soutenance (si METALIS annoncé) | ⏳ |

---

## 🛠️ Tech Stack Cible (À Valider)

| Composant      | Solution                     | Notes                    |
| -------------- | ---------------------------- | ------------------------ |
| Stockage       | NAS Synologie + Backup Cloud | Immuable + Off-site      |
| Réseau         | Aruba/Cisco + AP Wi-Fi 6     | Mailles + VLAN segmentés |
| Virtualisation | VMware/Hyper-V (TBD)         | Compute redundancy       |
| ERP            | Odoo Cloud ou On-prem HA     | Scaling auto             |
| E-Commerce     | WooCommerce + Cloudflare     | CDN + DDoS               |
| Backup         | Veeam/Commvault              | RPO <1h                  |
| Monitoring     | Zabbix/Datadog               | Alertes auto             |

---

## 💬 Questions ?

Consulter les **Issues** du projet ou contacter l'équipe RMI (Run My Infra).

---

**Last Updated:** 29 Mai 2026
**Status:** 🟡 Discovery & Planning Phase
**Budget Envelope:** 50,000€
