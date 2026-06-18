# RDV 2 — 3 SCÉNARIOS D'ARCHITECTURE METALIS

**Date:** 16 juin 2026
**Enveloppe Budget:** 50,000€
**Deadline:** 22 juin 2026
**Soutenance:** 25 juin 2026

---

## 📊 SYNTHÈSE COMPARATIVE

| **Critère**                  | **Scenario 1: CONSERVATIVE** | **Scenario 2: STANDARD** ⭐ | **Scenario 3: PREMIUM** |
| ---------------------------- | ---------------------------- | --------------------------- | ----------------------- |
| **Budget Estimé**            | ~33,000€                     | ~48,000€                    | ~68,000€                |
| **Fiabilité NAS**            | 99.5% (Single)               | 99.9% (HA Primaire)         | 99.95% (HA+SAN)         |
| **E-Com Scalabilité**        | On-prem simple               | Cloud Hybrid                | Full AWS                |
| **Odoo Availability**        | 99%                          | 99.9%                       | 99.95%                  |
| **Wi-Fi Couverture**         | 70% atelier                  | 95% atelier                 | 98% atelier+bureaux     |
| **RTO (Disaster)**           | 4-6 heures                   | 1-2 heures                  | <30 minutes             |
| **PRA Tests**                | Trimestriel                  | Mensuel                     | Hebdomadaire            |
| **Support Post-Déploiement** | Interne                      | Interne+Prestataire         | Prestataire 24/7        |
| **Extensibilité 2027**       | Faible                       | Forte                       | Maximale                |

---

## 🟢 SCENARIO 1: CONSERVATIVE (33,000€)

### _Minimum viable — Local-only, Direct ROI_

### Justification

- Budget ajusté, dépanne les problèmes critiques
- Pas de migration cloud (moins de complexité)
- Maintenance interne possible
- Permet tests 8 objectifs pédagogiques

### Composants

#### Réseau & Connectivité (3,500€)

```
├─ Firewall Fortinet FortiGate 60F (simple failover)    [~1,200€]
├─ Switch Managé 48-ports Cisco C9200L-24           [~1,800€]
├─ Wi-Fi 6 Mesh Budget (TP-Link Deco XE75)          [~500€]
│  └─ Couverture ~70% atelier (zones mortes tolérées)
└─ Câblage RJ45 + Patch Panel                        [~100€]
```

#### Stockage (8,000€)

```
├─ NAS Synology DS1821+ (8 baies RAID6)              [~3,500€]
│  ├─ 4x HDD 4TB WD Red Pro (16TB utile)
│  └─ Snapshots 6h, Local backup uniquement
├─ SSD Cache NVMe 2x1TB (acceleration)               [~300€]
└─ Pas de failover secondaire
   └─ Backup USB + Cloud (manuel)
```

#### Calcul & ERP (12,000€)

```
├─ VM Host (Proxmox) — 2 sockets 16-core CPU        [~4,000€]
├─ Odoo Managed Instance (VM local)                  [~3,000€]
│  ├─ PostgreSQL 14 (local)
│  ├─ No scaling (monolithic)
│  └─ Simple backup nightly
├─ WordPress + WooCommerce (sur NAS via iSCSI)       [~2,000€]
└─ VPN Wireguard (serveur local)                    [~1,000€]
```

#### E-Commerce WooCommerce (3,000€)

```
├─ WordPress Managed (local VM)                      [~2,000€]
├─ WooCommerce Plugin + SureCart                     [~1,000€]
└─ NO cloud CDN
   └─ On-prem scaling limits (~100 concurrent users)
```

#### Monitoring & Supervision (3,000€)

```
├─ Zabbix Server (on local VM)                       [~1,500€]
├─ Prometheus + Grafana (container k3s)              [~800€]
└─ Alertes basiques (email/Slack)                    [~700€]
```

#### Backup & PRA (2,500€)

```
├─ Backup Software Bacula (local)                    [~1,500€]
├─ USB HDD 4TB (manual transport)                    [~300€]
├─ PRA Procedure doc only (no testing)               [~400€]
└─ RTO: 4-6 heures
   └─ RPO: <2h CAO, <30min Odoo
```

#### Audit & Presta (1,000€)

```
├─ Configuration Audit (initial)                     [~600€]
└─ Network Segmentation setup                        [~400€]
   └─ 4 VLAN only (basic isolation)
```

### Limitations

- ❌ **Pas de NAS Failover** → Panne = 4-6h RTO (critique)
- ❌ **WooCommerce limité** → Pas auto-scaling (promos fragiles)
- ❌ **Wi-Fi gaps** → Dead zones atelier (zones CNC)
- ⚠️ **Backup manual USB** → Erreur humaine risk
- ⚠️ **Support interno uniquement** → Hours limit si problème critique

### Avantages

- ✅ **Budget respecté** (33k€ vs 50k€ budget)
- ✅ **Simple operationalization** → Maintenance interne
- ✅ **Covers 6/8 objectives** (Hyperviseur, Backup basic, Supervision, VDI)
- ✅ **Éléments revendables** → Migration facile vers Scenario 2 later

---

## 🟠 SCENARIO 2: STANDARD (48,000€)

### _RECOMMANDÉ — Hybrid Local+Cloud, Best ROI/Reliability Balance_

### Justification

- Utilise budget complet (48k€ vs 50k€ slack)
- HA sur composants critiques (NAS, Firewall)
- Cloud hybrid (backup AWS S3, e-com scaling)
- Covers 7/8 objectives (all except premium enterprise SAN)
- Support mix (interne + prestataire 2j/semaine)

### Composants

#### Réseau & Connectivité (5,500€)

```
├─ Firewall Fortinet FortiGate 100F HA (dual WAN)    [~2,500€]
├─ Switch Cœur Cisco C9200L-48 (VLAN + MLAG)         [~2,200€]
├─ 4G Failover Link (Netgear LB2120 USB)             [~400€]
├─ Wi-Fi 6E Mesh Enterprise (Ubiquiti WiFi 6E)       [~1,200€]
│  └─ Couverture 95% atelier (enterprise grade)
└─ Câblage + Patch Panel + RJ45 shielded             [~200€]
```

#### Stockage (13,500€)

```
├─ NAS PRIMAIRE Synology DS1821+ (8 baies RAID6)     [~3,500€]
│  ├─ 4x HDD 6TB WD Red Pro (16TB utile)
│  ├─ SSD Cache 2x2TB NVMe
│  └─ Snapshots 6h
│
├─ NAS SECONDAIRE Synology DS720+ (FAILOVER)         [~2,500€]
│  ├─ 2x HDD 8TB (pour réplication iSCSI)
│  └─ Standby hot (sync auto nightly)
│
├─ iSCSI Replication (automatic failover)            [~800€]
│  └─ Data sync <5min, RTO <10min
│
├─ AWS S3 Storage (cloud backup monthly)             [~2,000€]
│  ├─ Immuable backup (ransomware protection)
│  ├─ Cross-region replication
│  └─ 5-year retention
│
└─ Backup Software Veeam Community Edition (1 VM)   [~1,200€]
   └─ Automated daily backups to S3
```

#### Calcul & ERP (14,000€)

```
├─ VM Host Proxmox (single) — 24-core 2-socket      [~5,000€]
│  └─ Later: Scale to cluster (extensible)
│
├─ Odoo Managed HA Ready (VM local)                  [~4,000€]
│  ├─ PostgreSQL 14 + HAProxy (load balancer ready)
│  ├─ Scaling template prepared (not active)
│  └─ Hourly backup to NAS + S3
│
├─ WordPress + WooCommerce cluster (3x containers)  [~3,000€]
│  └─ Load balanced via NGINX ingress
│
└─ VPN Wireguard + Bastion Host                      [~2,000€]
   └─ Remote team access (RDP to terminals)
```

#### E-Commerce WooCommerce (6,000€)

```
├─ WooCommerce Local (pod scaling ready)             [~2,000€]
│  ├─ Max ~500 concurrent users (on-prem)
│  └─ Auto-failover to AWS Lambda (manual trigger)
│
├─ AWS CloudFront CDN (peak traffic only)            [~2,500€]
│  ├─ Activated on-demand for promos
│  ├─ DDoS protection (basic)
│  └─ Global edge caching
│
├─ AWS RDS (read-only replica)                       [~1,500€]
│  └─ Failover target for critical sales
```

#### Monitoring & Supervision (4,500€)

```
├─ Prometheus + Grafana (k3s cluster)                [~1,200€]
├─ Zabbix Server (alerting backup)                   [~1,500€]
├─ ELK Stack (logs centralization)                   [~1,000€]
├─ Custom dashboards (Odoo perf, WooCommerce, NAS)   [~600€]
└─ Alerts to Slack + PagerDuty                       [~200€]
```

#### Backup & PRA (3,500€)

```
├─ Veeam Backup & Replication (licensed)             [~2,000€]
│  ├─ Instant VM recovery
│  └─ Application-aware backup
│
├─ NAS HA Failover Testing                           [~800€]
│  └─ Monthly PRA drills (documented)
│
└─ DR Runbooks (complete procedures)                 [~700€]
   └─ RTO: 1-2 heures
   └─ RPO: <30min all critical data
```

#### Audit & Presta (1,500€)

```
├─ Network Segmentation (full 4 VLAN config)         [~700€]
├─ Security Audit (Nessus scanning)                  [~500€]
└─ Post-deployment training (team)                   [~300€]
```

#### Professional Services (2,000€)

```
├─ Implementation support (5 days on-site)           [~1,500€]
└─ 2 days/week remote support (first month)          [~500€]
```

### Avantages

- ✅ **Budget exact** (48k€ vs 50k€ — 2k€ slack)
- ✅ **HA Critical Components** → NAS failover <10min RTO
- ✅ **Hybrid Cloud** → Flexibility (scale WooCommerce on demand)
- ✅ **Professional Monitoring** → Proactive alerting
- ✅ **Covers 7/8 objectives** (all pedagogical goals, except enterprise clustering)
- ✅ **Growth Path** → Extend to Scenario 3 in 2027
- ✅ **Support mix** → Balance interne + prestataire

### Limitations

- ⚠️ **Odoo Still Single-Instance** → No active load balancing (prepared but not enabled)
- ⚠️ **WooCommerce <500 users** → Peaks require manual AWS failover
- ⚠️ **Wi-Fi 95% coverage** → Dead zones < 5%
- ⚠️ **PRA testing monthly** (not real-time)

---

## 🔴 SCENARIO 3: PREMIUM (68,000€ — HORS BUDGET)

### _Enterprise-Grade Full HA — For reference only_

### Composants (Highlights Only)

```
RÉSEAU (8k€):
├─ Firewall Fortinet FortiGate 200F cluster (3 nodes)
├─ Wi-Fi 6E Enterprise mesh 802.11ax (Ubiquiti enterprise)
└─ Redundant ISP links + 4G backup

STOCKAGE (22k€):
├─ NAS SAN Qnap TS-932PX (HA + Failover Cluster)
├─ Secondary NAS hot-standby (real-time replication)
├─ AWS S3 + Glacier archive (auto-tiered)
└─ Veeam Enterprise backup

CALCUL (18k€):
├─ Proxmox Cluster (3 nodes for VM HA)
├─ Odoo HA with active-active load balancing
├─ PostgreSQL 14 with streaming replication
└─ Read-only replicas (analytics queries)

E-COMMERCE (12k€):
├─ WooCommerce full AWS deployment
├─ Amazon RDS (managed PostgreSQL)
├─ CloudFront CDN (always active)
├─ Auto-scaling groups (30-1000 concurrent users)

MONITORING (5k€):
├─ Datadog APM (full stack)
├─ Splunk logs (compliance audit trail)
├─ PagerDuty on-call rotation
└─ Custom ML anomaly detection

BACKUP & PRA (2k€):
├─ Veeam+ SRM (Site Recovery Manager)
├─ RTO: <5 minutes (real-time)
├─ Weekly PRA dry-runs (automated)
└─ Compliance reporting

PROFESSIONAL SERVICES (3k€):
├─ 15 days implementation (3 weeks on-site)
├─ 24/7 support (first 3 months)
└─ Knowledge transfer + runbooks
```

### Benefits (Reference Only)

- ✅ Enterprise-grade HA (99.95% uptime SLA)
- ✅ All 8 objectives + Premium clustering
- ✅ Auto-scaling everything
- ✅ Real-time disaster recovery
- ✅ Compliance-ready audit trails

### Reality Check

- ❌ **5k€ over budget** (68k vs 50k budget)
- ❌ **Overkill for 40-person SME** → Non-proportional ROI
- ❌ **Complexity overhead** → Harder to maintain
- ⚠️ **Cloud vendor lock-in** (AWS critical dependency)

---

## 🎯 RECOMMANDATION

### **✅ SCENARIO 2: STANDARD (48,000€) est le choix recommandé**

**Raisons:**

1. **Budget parfait** — Rentre dans 50k€, slack 2k€ pour ajustements
2. **Balance optimal** — HA critique (NAS), scalabilité cloud (WooCommerce)
3. **Objectifs pédagogiques** — Couvre 7/8 (seul Scenario 3 premium clustering exclu)
4. **Support Réaliste** — Interne + prestataire 2j/semaine (24/7 non-nécessaire)
5. **Extensible** — Migration path vers Scenario 3 en 2027 (post-graduation)
6. **RTO/RPO acceptable** — 1-2h RTO, <30min RPO (matches client needs)

### **🔴 SCENARIO 1 à éviter** — Risk trop élevé:

- NAS single point of failure (4-6h RTO = revenue impact)
- Wi-Fi gaps atelier (production impact)
- Backup manual (erreur humaine)

### **🟣 SCENARIO 3 hors budget** — Post-projet:

- Use as 2027 upgrade roadmap
- Reference for "What if we need premium?"

---

## 📋 CHECKLIST QUESTIONS CLIENT (À VALIDER DEMAIN)

### Réseau & Connectivité

- [ ] Dual WAN acceptable? (Fibre + 4G?)
- [ ] Wi-Fi mesh budget (Scenario 1) vs Enterprise 6E (Scenario 2)?
- [ ] Firewall HA needed? (Scenario 2 has dual-instance failover)

### Stockage & Backup

- [ ] NAS Failover critiques? (vs local-only + USB backup)
- [ ] AWS S3 Cloud backup acceptable? (cost: ~150€/month)
- [ ] Backup frequency? (Daily recommended, currently nightly in Scenario 2)

### E-Commerce

- [ ] WooCommerce on-prem (500 users limit) or full AWS cloud?
- [ ] Peak traffic load? (Promos → Scenario 2 with CloudFront)
- [ ] Payment gateway? (SureCart, Stripe, local?)

### Odoo ERP

- [ ] Current Odoo scaling needs? (Scenario 1 single vs Scenario 2 prepared HA)
- [ ] Active directory integration? (LDAP/SAML?)
- [ ] Custom modules? (Budget impact for migration)

### Support & Timeline

- [ ] Support post-déploiement: interne vs prestataire 24/7?
- [ ] PRA testing frequency? (Monthly in Scenario 2, quarterly in Scenario 1)
- [ ] Timeline extensible au-delà 22 juin? (Affects hardware ordering)

### Budget Flexibility

- [ ] 50k€ strict ou slack possible (Scenario 3 demo)?
- [ ] Équipement obsolète à recycler? (NAS actuel 15 ans)
- [ ] Upgrade path 2027? (Budget allocation for Scenario 2→3)

---

## 📞 CONTACTS POUR CLARIFICATIONS

**Infrastructure decisions:**

- Responsable IT Metalis: [À COMPLÉTER]
- Cloud preference (AWS vs Azure vs local)?
- Support preference (internal vs prestataire)?

**Timeline & Hardware Ordering:**

- When can hardware arrive? (Lead time NAS HA: 2-3 weeks)
- Deployment sequence? (Firewall → NAS → Servers → Apps)

**Compliance & Testing:**

- Audit trail requirements?
- Compliance certifications? (GDPR, ISO?)
- Testing frequency expectations?

---

**Document Version:** 1.0
**Last Updated:** 16 juin 2026
**Next Update:** Post-RDV 2 (client feedback integration)
16-06-2026