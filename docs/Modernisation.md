# Modernisation

Schéma Infra [Actuel](https://mermaid.live/edit#pako:eNqVVutuKjcQfpXRSidK1JATSIAGVZG4HKpIuaCQFOks-eHsOmCdxaa2NyenUZ6iL9B_Lc-B-l797F1YsnDU1lKyvsyMZ775ZsxrEKmYB61gotl8Sne9sSSMDx_o04vlWrKEhlw_i4gb2qN7w7XJJEz6mKl0E5XGOIP8cqEFT3Um4MbVSaMeXolIK6OeLGH106P-eH7FjWETDmG6YiIxD4VGV81mXEeCpS_hxpy4pLvlIlkurGbP0PF22lG0_MuQkMayx4STE4z5s9g0iAuk7V53Qz_hksmIE9bEfXx809DyD4pYrLnO9bmMx3INiDNAQ2E5XXP7VekvJSDGgT8caCEjMQdwV9yyRBgcFO7cqtQCojD_0kfqqBfqty-8H7d8-acSlixOCQEh2CcRkXMcrtqHlTele7t__w5TMSe9XBjOUlh1SYP995e_UxsJmQtRuJpgL1ZfDd1L8WvKH95rutHuhe3IimdOPaF5ZJX-RkjKZA3Z5ugPwwHTFpl2viGQqQB9dgjexEqFn24HfuKBuOTS-nRO4RaoB_1oyvRkl08j_uiAD0dKxwMIG_qBRkrl7MkSPEgYMKQ5MooJoDU012qmyt5sZHw1rtvDEH_0i-AiQToNDHib_Twg6rZvaKgSEcODLwZJc1xCVei4bL7Doi_p3IRDlj7zCdMx_ACtjJLeYlfNBXbuhx2EMIy0mFtDLKapih62nKJKpbIyWByWAtggyWclOXWApoN1_7J9fVCmRn446JqwWqeBMhbOZJvW8QG0Qqje0yLch_98d9vyBHj5u2FqJCp9QVtOjERf7O93FPhuMhl_4UVe4-bg4L18btU7XVs5nW9mqc-29gA08uWsogUILjErgeq6RK0Qw7IkMHANbj51_wGHCS9mcy1mjlnoHQuPkcXcX9tTaTT1S1eNEcN9W9y_cxE5kXA9c0wHM-MUVZazoqOk335ij1pEzO2XHWdgOjMhvvCNGboYZFlKUdYgret5JZVt0KlyVDkvXPqeQAmDUva3u-b6GekqQOCjgn8yUjMhJ2h0ZKecUt9vyLg2lD8fXSRQgv4g-Thoo_gtcOy55k77d1lbROGDPpA4X7XVXHXj3cjVfXt3HWYvs7FLbfVSvNOJBXiHjiGVJLNcRKkW-OxSX0d8IfOI3TGCzA5WDd9VbdF6t89Q2dubRWXuMtYX27tFWWyfIcYdmxmH_i1zN6mdqB1B5VFz64Fx7_73ULlUE-Ruj1wSkcVMoAgwQ_9n_GJYvxiu6-SIr9EpK9xbgd7si8PlORcvA12g8n-0iuL0FVDUQiEYHOIHlIiDltUpPwwA5Yy5ZfDqTIwDkHzGx0EL05g_sTSxru-9QW3O5GelZitNrdLJNGg9scRglc5jZnlPMDTSQgQFxnVXpdIGrWqtfuKNBK3X4CVonVSPTmvVZq1arR2fNBv1RvMw-Ba06sdHx43G8WmjcVI_q9cbb4fBb_7W46OzH0-bjbNmo1pv1E5Om6dv_wAQ_is5)

Plan de modernisation budget 50k € :

* Mise en place de Backup sécurisé \> Veeam SRV
  * Repo NAS et Externe
* Switch redondé
* Changement SRV par cluster \> Prox ou VME
* Baie de Stockage \> Synology ou Qnap avec NFSv3
* Intégration NAS récent (actuelle 15 ans) \> Synology ou Qnap
* Bornes Instable \> Pourquoi ? Surcharge ou manque de puissance
  * Surcharge on prend plus
  * Manque de puissance on en prends des plus récente / adapté
* Mise en Place VPN \> Wireguard
* Mise en Place FW \> OPNsense
* Presta Monitoring
  * Mise en place de supervision
  * Gestion des BKP
* Presta Audit
  * Voir configuration soft
  * Voir configuration matériel
  * Voir si poste atelier besoin changement
* Segmentation RZO
  * Atelier Poste
  * Atelier Caméra
  * Atelier WIFI
  * Atelier CNC
  * Bureaux
  * Admin
  * Serveur
  * BKP

##

## **Logiciels & usages**

| Domaine | Outil |
| ----- | ----- |
| ERP | Odoo |
| E-commerce | WooCommerce (lié à l'ERP) |
| CAO | SolidWorks — fichiers sur NAS |
| Site vitrine | WordPress (devis en ligne) |
| Messagerie | Microsoft 365 |
| Atelier | 2 machines CNC, imprimantes étiquettes, douchettes |
| Surveillance | Caméras IP atelier |
| Mobilité | Tablettes pour bons de fabrication |

##
