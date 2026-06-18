# ARCHITECTURE.md - METALIS Infrastructure Cible

**Version:** 1.0 (Draft)
**Last Updated:** 29 Mai 2026
**Status:** À Valider avec Client

---

## 1️⃣ Contexte & Enjeux

### Problèmes Critiques Actuels

- 🔴 **NAS saturé & lent** - Panne l'an dernier, restauration partielle
- 🔴 **Wi-Fi atelier instable** - Coupures fréquentes production
- 🔴 **ERP Odoo lent** - Heures de pointe (pic de charge)
- 🔴 **E-Commerce plante** - Lors des promos (peak load)
- 🟠 **Pas de PRA** - Direction inquiète "Que si arrêt vendredi 18h?"
- 🟠 **Backup informelle** - Scripts ad hoc + USB (pas immuable)

### Exigences RTO/RPO

- **RTO** : 1h acceptable, 5h indispo toléré
- **RPO** : Données CAO : <6h, Odoo : <1h
- **Production 2×8** : Zéro arrêt = revenue direct impact

---

## 2️⃣ Architecture Cible (Proposée)

```
┌─────────────────────────────────────────────────────────────┐
│                    METALIS Infrastructure                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌─────────────────────┐           │
│  │ Firewall HA  │◄────────┤ Internet Fibre Box  │           │
│  │ (Failover)   │         │ + 4G Backup Link    │           │
│  └──────────────┘         └─────────────────────┘           │
│         │                                                    │
│  ┌──────┴──────────────────────────────────────┐           │
│  │   Réseau Cœur (Switchs Managés HA)         │           │
│  └──────┬─────────────────────────────────────┘           │
│         │                                                   │
│  ┌──────┴──────────────────────────────────┐              │
│  │  VLAN Segmentation (4 VLAN)             │              │
│  ├──────────────────────────────────────────┤             │
│  │ VLAN 10 (Production) → CNC, CAO, Atelier│             │
│  │ VLAN 20 (Bureaux) → Odoo, Devis, Admin  │             │
│  │ VLAN 30 (E-Commerce) → WooCommerce      │             │
│  │ VLAN 40 (Guests) → WiFi Visiteurs       │             │
│  └──────┬────────────────────────────────────┘            │
│         │                                                   │
│  ┌──────┴────────────┬──────────────┬──────────┐          │
│  │                   │              │          │          │
│  ▼                   ▼              ▼          ▼          │
│ ┌──────────────┐ ┌──────────────┐ ┌────────┐ ┌────────┐ │
│ │ NAS Primaire │ │ ERP Odoo     │ │Backup  │ │ Wi-Fi  │ │
│ │ Synology     │ │ Managed      │ │Cloud   │ │ 6E    │ │
│ │ RAID6 + HA   │ │ (VM + DB)    │ │ AWS S3 │ │Mesh   │ │
│ │ 8To          │ │ Scaling HA   │ │Immuable│ │Atelier│ │
│ │ Snapshots 6h │ │ Load Balance │ │Monthly │ │+Bureaux│ │
│ └──────────────┘ └──────────────┘ └────────┘ └────────┘ │
│       ▲                   ▲                                │
│       │ iSCSI Repl        │ Failover Auto                │
│   ┌───┴─────────────────┐ │                              │
│   │ NAS Secondaire      │ │                              │
│   │ (Failover Standby)  │ │                              │
│   └─────────────────────┘ │                              │
│                           │                              │
│  ┌────────────────────────┴─────────────────┐            │
│  │ E-Commerce WooCommerce (Cloud) ☁️        │            │
│  │ - CDN Cloudflare (Global)                │            │
│  │ - Auto-scaling AWS                       │            │
│  │ - DDoS Protection                        │            │
│  │ - Load Testing automated                 │            │
│  └────────────────────────────────────────┘            │
│                                                          │
│  ┌────────────────────────────────────────┐            │
│  │ Monitoring & Alertes (Zabbix)         │            │
│  │ - NAS Health (Synology)                │            │
│  │ - Odoo Performance (APM)               │            │
│  │ - Wi-Fi Coverage (RSSI maps)           │            │
│  │ - Backup Success Rate                  │            │
│  │ - Production Line Alerts               │            │
│  └────────────────────────────────────────┘            │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 3️⃣ Composants Détaillés

### A. **Réseau & Wi-Fi**

| Composant       | Solution                | Spec           | Lieu                 |
| --------------- | ----------------------- | -------------- | -------------------- |
| Firewall HA     | Fortinet FortiGate 100F | Dual WAN       | Entrée principale    |
| 4G Backup       | Netgear LB2120          | USB Dongle     | Failover automatique |
| Switch Cœur     | Cisco C9200L            | 48 ports, VLAN | Armoire              |
| Switch Atelier  | Cisco C9300-48UXM       | Industrial PoE | 2 locations          |
| Wi-Fi 6 Atelier | Aruba 6200 AP           | 2x2 MIMO, PoE  | Chaîne production    |
| Wi-Fi Bureaux   | Aruba 6100 AP           | Standard       | 3 AP mesh            |
| Wi-Fi Guest     | Distinct SSID           | VLAN 40 isolé  | Visiteurs/Clients    |

### B. **Stockage CAO & Données**

| Composant      | Solution          | Spec          | Notes                |
| -------------- | ----------------- | ------------- | -------------------- |
| NAS Primaire   | Synology DS1821+  | 8x 12TB RAID6 | 4To CAO SolidWorks   |
| NAS Secondaire | Synology DS920+   | 4x 12TB       | Réplication iSCSI 6h |
| Snapshots      | Synology Snapshot | Toutes 6h     | Immuable 30 jours    |
| Deduplication  | Synology Dedup    | Activé        | Économie storage     |
| Quota          | Par utilisateur   | 100GB CAO max | Discipline data      |

### C. **ERP Odoo & DB**

| Composant     | Solution        | Spec             | Notes                 |
| ------------- | --------------- | ---------------- | --------------------- |
| Odoo Hosting  | On-Prem (VM HA) | 4 vCPU, 16GB RAM | ou Cloud si scaling   |
| Database      | PostgreSQL 14   | Master + Replica | Streaming replication |
| Backup Odoo   | pg_basebackup   | Quotidien        | Immuable + versioning |
| Load Balancer | Nginx           | HAProxy          | Distribuer charge     |

### D. **E-Commerce WooCommerce**

| Composant | Solution             | Spec            | Notes                 |
| --------- | -------------------- | --------------- | --------------------- |
| Hosting   | AWS EC2 Auto-Scaling | t3.xlarge base  | Promo: x2 instances   |
| Database  | AWS RDS MySQL        | Multi-AZ        | Failover auto 60s     |
| CDN       | Cloudflare           | Edge Servers EU | Vite + DDoS           |
| Cache     | Redis ElastiCache    | 6GB             | Performance page load |
| Backup    | AWS Snapshot         | Quotidien       | 30j rétention         |

### E. **Sauvegarde & Disaster Recovery**

| Composant       | Solution                       | Spec            | Notes      |
| --------------- | ------------------------------ | --------------- | ---------- |
| Logiciel Backup | Veeam                          | v12 Endpoint    | NAS + VMs  |
| Fréquence       | Incrém. 4x/j + Complet 1x/nuit | RPO 6h          |            |
| Rétention       | 30j local + 90j cloud          | Tiered storage  | Compliance |
| Cloud Backup    | AWS S3 Glacier                 | Région EU (HDS) | Immuable   |
| Restore Test    | Mensuel                        | 1er sam du mois | Documenté  |

### F. **Monitoring & Alertes**

| Composant  | Solution     | Spec                  | Notes               |
| ---------- | ------------ | --------------------- | ------------------- |
| Monitoring | Zabbix       | Agents NAS/Odoo/Wi-Fi | On-Prem             |
| Metrics    | Prometheus   | Scrape Odoo           | KPIs métier         |
| Dashboard  | Grafana      | Business view         | Pour direction      |
| Alertes    | Email + SMS  | Critiques uniquement  | Éviter fatigue      |
| SLA        | Uptime Robot | Endpoint check        | External validation |

---

## 4️⃣ Plan de Déploiement

### Phase 1 : Audit & Planning (Semaines 1-2)

- [ ] Audit NAS actuel (capacité, santé)
- [ ] Audit Odoo (version, perf bottleneck)
- [ ] Survey Wi-Fi coverage atelier
- [ ] Valider architecture avec client

### Phase 2 : Infrastructure (Semaines 3-5)

- [ ] Installer NAS HA + snapshots
- [ ] Deploy Firewall dual WAN
- [ ] Upgrade Wi-Fi (Atelier priority)
- [ ] Configurer VLAN segmentation

### Phase 3 : Odoo & Backup (Semaines 6-8)

- [ ] Migrate/Optimize Odoo (VM ou Cloud?)
- [ ] Setup Veeam + Cloud backup
- [ ] Configure load balancing
- [ ] Tester restore procedures

### Phase 4 : E-Commerce & Tests (Semaines 9-10)

- [ ] Deploy WooCommerce HA cloud
- [ ] Setup CDN + Cache layer
- [ ] Load testing (Black Friday simulation)
- [ ] Valider failover scenarios

### Phase 5 : Production & Support (Semaine 11+)

- [ ] Cutover production
- [ ] 24/7 support 1 mois
- [ ] Monthly PRA drills
- [ ] Documentation finale

---

## 5️⃣ Coûts Estimés

| Catégorie          | Description                   | Budget       |
| ------------------ | ----------------------------- | ------------ |
| **Réseau & Wi-Fi** | Firewall, Switchs, APs        | 8 000€       |
| **Stockage**       | NAS HA + License Synology     | 7 000€       |
| **ERP Odoo**       | Hosting/Cloud, Scaling        | 10 000€      |
| **E-Commerce**     | AWS, CDN, Scaling, License    | 12 000€      |
| **Backup & DR**    | Veeam, Cloud, Setup           | 5 000€       |
| **Services**       | Intégration, tests, formation | 6 000€       |
| **Support (1an)**  | SLA 4h réaction               | 2 000€       |
| **TOTAL**          |                               | **~50 000€** |

---

## 6️⃣ Risques & Mitigation

| Risque               | Impact      | Probabilité | Mitigation                        |
| -------------------- | ----------- | ----------- | --------------------------------- |
| Perte données CAO    | 🔴 Critique | Basse       | NAS HA + Snapshots + Cloud        |
| Arrêt production     | 🔴 Critique | Moyenne     | Wi-Fi HA + Firewall failover      |
| Promo crashing E-Com | 🟠 Revenue  | Haute       | Auto-scaling AWS + Load test      |
| Odoo performance     | 🟠 Haute    | Moyenne     | Upgrade DB + Cache layer          |
| Cyber ransomware     | 🔴 Critique | Moyenne     | Snapshots immuable + Segmentation |

---

## 7️⃣ Points à Clarifier avec Client

- [ ] NAS secondaire **manuel failover** ou **automatique** ?
- [ ] Odoo : **on-prem maintenu** ou **migration cloud AWS ?**
- [ ] WooCommerce : **on-prem** ou **full cloud** (AWS/Shopify) ?
- [ ] Budget **flexibilité** si solutions premium ?
- [ ] **Timeline fixe** ? (Semaine 11 impérative?)
- [ ] Qui **maintient** post-déploiement ? (interne/prestataire)
- [ ] **Contrat SLA** 24/7 ou 8-18 jours ouvrés ?

---

**Prochaine Étape:** Valider architecture → REQUIREMENTS.md → Déploiement
