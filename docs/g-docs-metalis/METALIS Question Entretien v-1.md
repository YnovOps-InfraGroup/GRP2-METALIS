## Thibaut Architecte, Ingénieur Infra et Virtualisation : 

## **1. Réseau & Atelier** 

-   **Question : Quelle est la nature du bâtiment et comment est
    > couverte la zone de production ?**

-   **Question : Les équipements industriels (CNC, caméras, douchettes)
    > sont-ils isolés sur des réseaux dédiés (VLAN) ?**

-   **Question : Le NAS est-il isolé ?**

-   **Question : Comment le prestataire de maintenance des machines CNC
    > se connecte-t-il à distance ?**

-   **Question : Quelles sont les machines présentes dans le SI ?
    > Compatibilité ?**

## **2. CAO & Stockage** 

-   **Question : Quelle est la volumétrie actuelle des données CAO
    > (SolidWorks) et le taux d\'évolution ?**

-   **Question : Utilisez-vous l\'outil PDM (Product Data Management) de
    > SolidWorks ou ouvrez-vous les fichiers directement depuis le
    > réseau ?**

-   **Question : Comment est géré le réseau filaire des postes du bureau
    > d\'études (CAO) ?**

## **3. ERP, E-commerce & Télétravail**

-   **Question : Où sont actuellement hébergés l\'ERP Odoo et le site
    > WooCommerce ?**

-   **Question : Comment les commerciaux en télétravail se
    > connectent-ils au SI actuellement ?**

## **4. Sauvegarde & Plan de Reprise d\'Activité (PRA)**

-   **Question : La production tourne en 2×8. Quel est le délai maximum
    > de coupure acceptable (RTO) avant que l\'usine ne soit à l\'arrêt
    > total ?**

-   **Question : Quel est le budget estimé, ou la perte financière
    > estimée d\'une journée d\'arrêt de production ?**

-   **Question : Les boîtes mails Microsoft 365 sont-elles sauvegardées
    > ?**

-   **Question : Comment sauvegardez-vous vos données ?**

## 

## **5. Financier** 

## 

-   **Question : Quelle est l\'enveloppe budgétaire pour ce projet ?**

    -   **Définir précisément l\'objectif**

    -   **est-il un renouvellement complet de l\'infrastructure, ?**

    -   **une migration vers le cloud (Lift up) ?**

    -   **une simple mise à niveau ?**

    -   **Quelles sont vos 3 principales préoccupations concernant ce
        > projet ?**

    -   **Qu\'est-ce qui serait un succès et, à l\'inverse, un échec
        > après ce projet ?**

-   **Question : A quelle fréquence intervient votre prestataire et dans
    > quelle cadre ?**

## Lylian RSSI : 

-   Si tout s\'arrêtait demain, quel est l\'élément le plus
    > indispensable pour que vous puissiez continuer à travailler ?

-   Quels sont les moments ou les endroits où l\'informatique vous
    > bloque le plus dans votre travail quotidien ?

-   Quand vos fichiers CAO ralentissent, est-ce que cela empêche toute
    > votre équipe de produire ou seulement une personne ?

-   Avez-vous déjà dû refaire du travail parce qu\'un fichier a été
    > perdu ou mal enregistré ?

-   Si vos ordinateurs étaient bloqués par un virus, savez-vous
    > exactement où sont vos copies de secours et combien de temps il
    > faudrait pour tout restaurer ?

-   Comment les techniciens externes accèdent-ils à vos machines-outils
    > aujourd\'hui ?

-   Est-ce qu\'il y a des documents confidentiels auxquels vous
    > souhaitez limiter l\'accès à certains employés ?

-   Vos commerciaux en télétravail se plaignent-ils de lenteurs sur des
    > logiciels précis ou sur l\'accès aux fichiers ?

-   Qui gère aujourd\'hui les mises à jour et la sécurité de votre site
    > internet et de votre boutique en ligne ?

-   Quelle est la chose qui vous inquiète le plus quand vous partez en
    > week-end concernant vos outils informatiques ?

## Gregory : **Chef de projet et auditeur** (Audit Business et PRA/PCA)

**A. Objectifs, Priorités et Périmètre (Focus Projet & Business)**

1.  Quel est l'objectif prioritaire du projet (sécuriser, virtualiser,
    > migrer, moderniser, garantir la reprise d'activité) ?

2.  Qu'est-ce qui vous bloque le plus au quotidien (production, CAO,
    > ERP, télétravail ou sauvegardes) ? sauvegarde des données - disque
    > dur cramé.

3.  Souhaitez-vous une cible *on-premise*, *hybride* ou *cloud*, et pour
    > quelles applications critiques ? free all

4.  Quel est le budget global envisagé pour ce projet et quelle est la
    > date limite souhaitée pour la mise en œuvre ? 50 000€

5.  Qu\'est-ce qui représenterait un succès pour ce projet, et à
    > l\'inverse, un échec ?

**B. Risque, Disponibilité et Continuité d\'Activité (Focus PRA/PCA)**

6.  Quel est le coût ou l'impact estimé d'une journée d'arrêt d'activité
    > ?

7.  Quel niveau de disponibilité attendez-vous pour les outils
    > critiques, et quel est le RTO/RPO acceptable ? 1h, 5h indispo

8.  Quel est le dispositif de Plan de Reprise d\'Activité (PRA) ou de
    > Continuité d\'Activité (PCA) existant, même informel ? rien

9.  Quels incidents récents ont eu le plus fort impact sur la production
    > ou les données ?

10. Quand l\'ERP Odoo ou la CAO ralentissent, combien de personnes ou de
    > processus sont totalement bloqués ? 10 zaine de personnes qui sont
    > dessus, travail directement sur le NAS.

> machine à commande numérique bureau d'étude pour en télétravail.

**C. Sécurité, Sauvegarde et Gouvernance**

11. Quelles sont les données sensibles et/ou critiques à protéger en
    > priorité (CAO, ERP, RH, clients, devis, caméras, accès
    > maintenance) ?

12. Quelle est la politique de sauvegarde actuelle (fréquence,
    > rétention, stockage) ? Les sauvegardes sont-elles testées
    > régulièrement en restauration ?

13. Comment sont gérés les accès distants des commerciaux et des
    > prestataires externes au SI ?

14. Quelles sont les vulnérabilités connues sur le NAS et les serveurs
    > Windows ?

15. Quels outils de supervision utilisez-vous pour suivre les ressources
    > critiques (performance ERP, NAS, Wi-Fi, etc.) ? Synologie

16. Qui, en interne, est le responsable final des decisions et du suivi
    > de l\'IT (gouvernance) ?
