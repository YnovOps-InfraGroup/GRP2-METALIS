# REQUIREMENTS.md - METALIS Project

**Version:** 1.0 (Draft)
**Last Updated:** 29 Mai 2026

---

## 📋 Exigences Métier

### 1. Continuité d'Activité

| Exigence                           | Valeur                     | Justification                      |
| ---------------------------------- | -------------------------- | ---------------------------------- |
| **RTO** (Recovery Time Objective)  | 4h                         | Bascule manuelle automatisée Azure |
| **RPO** (Recovery Point Objective) | 24h                        | Sauvegarde Velero quotidienne 2h00 |
| **Disponibilité cible**            | 99.5%                      | Production continue, budget PME    |
| **PRA**                            | Documenté + testé mensuels | Direction inquiète "vendredi 18h?" |
| **Fenêtres maintenance**           | Sam/Dim nuit               | Pas d'arrêt production semaine     |
| **Incident response**              | <15min escalade            | Décision rapidement                |

### 2. Sécurité & Données

| Exigence                | Description                                  |
| ----------------------- | -------------------------------------------- |
| **Backup Immuable**     | Snapshots + Cloud (pas écrasable ransomware) |
| **Segmentation Réseau** | Production/Bureaux/E-Com séparés             |
| **Accès Distants**      | Prestataires CNC : IP whitelist + VPN        |
| **Encryption**          | TLS transit, AES-256 au repos                |
| **2FA**                 | Admin + accès remote obligatoires            |
| **Compliance**          | GDPR (client data), pas HDS requis           |
| **Audit Trail**         | Logs accès données sensibles                 |

### 3. Performance & Utilisateurs

| Exigence                    | Valeur    | Usage                             |
| --------------------------- | --------- | --------------------------------- |
| **Users simultanés**        | 40 max    | Atelier 2×8, bureaux, ventes      |
| **Temps réponse Odoo**      | <2s       | Saisie commandes heures pointe    |
| **Temps accès CAO**         | <5s       | Fichiers SolidWorks 4To NAS       |
| **Bandwidth Wi-Fi atelier** | 150+ Mbps | Production + douchettes tablettes |
| **Latence VPN**             | <100ms    | Prestataire CNC access            |
| **E-Commerce page load**    | <2s       | Peak promo traffic                |
| **E-Commerce uptime**       | 99.99%    | Black Friday/Cyber Monday         |

### 4. Données & Stockage

| Exigence              | Valeur                        | Notes                                |
| --------------------- | ----------------------------- | ------------------------------------ |
| **Volume CAO actuel** | ~4To                          | SolidWorks, croissance ~500GB/an     |
| **Données Odoo**      | ~100GB                        | Commandes, devis, clients historique |
| **Backup frequency**  | 4x/jour min (NAS) 1x/j (Odoo) | RPO 6h acceptable                    |
| **Snapshots**         | 30 jours immuable             | Protection ransomware                |
| **Rétention légale**  | 7 ans (Odoo)                  | Compliance France                    |

---

## 🔧 Exigences Techniques

### A. Réseau Atelier & Wi-Fi

- [ ] **Firewall HA** dual WAN (failover automatique)
- [ ] **4G backup link** si internet tombe
- [ ] **Wi-Fi 6E** atelier (2.4+5GHz, couvrir 1000m²)
- [ ] **VLAN 4 zones** : Production (10), Bureaux (20), E-Com (30), Guests (40)
- [ ] **Switches gérés** L2/L3 redundancy
- [ ] **Access Points mesh** mode failover
- [ ] **PoE suffisant** pour CNC, caméras, douchettes
- [ ] **VPN IPSec** + MFA pour prestataires externes

### B. Stockage CAO (SolidWorks)

- [ ] **NAS RAID6** primaire (2 disques panne tolérée)
- [ ] **Snapshots auto** 6h (immuable 30 jours)
- [ ] **NAS secondaire** réplication iSCSI (failover manuel ou auto)
- [ ] **Deduplication** activée
- [ ] **Quota par user** (discipline données)
- [ ] **Snapshots immuables** vs ransomware
- [ ] **Monthly restore test** documenté

### C. ERP Odoo

- [ ] **Version** : Odoo 15+ avec modules achat/vente/inv
- [ ] **Hosting** : On-prem VM HA **ou** AWS (à valider)
- [ ] **Database** : PostgreSQL 14+ avec replication
- [ ] **Backup quotidien** + immuable cloud
- [ ] **Load balancer** si traffic élevé
- [ ] **Monitoring APM** (perfs)

### D. E-Commerce WooCommerce

- [ ] **Cloud hosting** : AWS ou autre (scalabilité)
- [ ] **Auto-scaling** : +2x instances lors promo
- [ ] **CDN Cloudflare** : Edge cache global
- [ ] **Cache Redis** : Performance pages produits
- [ ] **Load testing** avant promo (Black Friday)
- [ ] **Multi-AZ failover** : 60s RTO max
- [ ] **Backup quotidien** + 30j rétention

### E. Sauvegarde Robuste

- [ ] **Veeam Backup** : Veeam Endpoint ou Veeam Backup & Replication
- [ ] **Fréquence** : Incrémental 4x/jour + complet 1x/nuit
- [ ] **Rétention** : 30j local + 90j cloud AWS Glacier
- [ ] **Cloud storage** : AWS S3 (HDS EU region)
- [ ] **Immuable locks** : 90 jours minimum (ransomware proof)
- [ ] **Monthly restore drill** : Evidence documentée
- [ ] **Off-site** : Au minimum 500km de site principal

### F. Monitoring & Observabilité

- [ ] **Monitoring centralisé** : Zabbix agents NAS/Odoo/Firewall
- [ ] **Metrics production** : Prometheus scrape ERP, stockage
- [ ] **Dashboard métier** : Grafana pour direction
- [ ] **SMS alertes** : Critiques uniquement (raid failure, arrêt production)
- [ ] **Uptime monitoring** : External endpoint check
- [ ] **SLA reporting** : Mensuel (uptime %)

---

## 👥 Rôles & Responsabilités

| Rôle                 | Responsabilités                      | Interne/Externe      |
| -------------------- | ------------------------------------ | -------------------- |
| **Chef Projet**      | Planning, validation, status         | Externe (RMI)        |
| **Architecte Infra** | Design, déploiement, tests           | Externe (RMI)        |
| **Admin IT METALIS** | Support jour, maintenance routine    | À désigner (METALIS) |
| **Prestataire CNC**  | Access VPN à cadrer (security)       | Externe              |
| **Direction**        | Approbation budget, RTO/RPO décision | METALIS              |

---

## 📅 Timeline

- **Semaines 1-2** : Audit infrastructure existante
- **Semaines 3-5** : Deploy NAS HA + Firewall + Wi-Fi
- **Semaines 6-8** : Migrate/Optimize Odoo + Backup setup
- **Semaines 9-10** : Deploy E-Commerce + Load tests
- **Semaine 11+** : Production cutover + Support

---

## 💰 Budget

- **Réseau & Wi-Fi** : 8k€
- **Stockage (NAS)** : 7k€
- **Odoo / Cloud** : 10k€
- **E-Commerce** : 12k€
- **Backup & Services** : 8k€
- **Support 1an** : 2k€
- **TOTAL** : ~50k€

---

## ✅ Critères d'Acceptation

Projet "succès" si :

- [ ] 99.5% uptime atteint (mesurable Zabbix)
- [ ] RTO <60min validé (failover drill)
- [ ] Backup restore test réussi (monthly evidenced)
- [ ] Wi-Fi atelier stable (zéro déconnexions production)
- [ ] E-Commerce <2s page load, 99.99% uptime promo
- [ ] Odoo réponse <2s heures pointe
- [ ] Équipe METALIS formée + documentation
- [ ] Zéro incident sécurité mois 1

---

## 🚫 Points NON Inclus

- Formation extensive utilisateurs (brief only)
- Modernisation app métier (lift & shift)
- Migration complète vers cloud (phase 2 potential)
- Contrat maintenance post 1an (option SLA extend)

---

## 📞 Questions pour Client

1. **Odoo** : Maintenir on-prem ou migrer AWS cloud ?
2. **WooCommerce** : Full AWS cloud ou on-prem + backup?
3. **NAS failover** : Manuel (moins cher) ou automatique ?
4. **Budget** : 50k€ envelope ok ? Flexibilité si premium?
5. **Timeline** : Semaine 11 fixe ou négociable ?
6. **Support post** : RMI continue ou equipe interne ?
7. **SLA** : 24/7 ou 8-18 business hours ?

---

**Next Step:** Signature client → Architecture détaillée → Déploiement
