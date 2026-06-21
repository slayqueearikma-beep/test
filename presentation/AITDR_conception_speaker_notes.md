# Notes de présentation - Partie Conception AITDR

Ces notes sont prévues pour être collées dans les notes du présentateur.

## Slide 8 - Architecture Azure AITDR

Cette slide présente l'architecture globale de AITDR. On retrouve une zone DMZ exposée avec le honeypot DVWA, une zone Data pour stocker les logs, et une zone SIEM/SOAR pour analyser les événements et automatiser la réponse. L'objectif est de séparer les composants sensibles et de garder une architecture sécurisée et reproductible avec Terraform.

## Slide 9 - Diagramme de classes AITDR

Ce diagramme de classes montre les principaux objets manipulés par la solution et leurs relations. Le HoneypotVM capture plusieurs AttackEvent, puis le LogPipeline collecte ces événements, les parse et les envoie vers l'analyse. Le MLModel analyse les données pour détecter les anomalies, le SIEMAlert crée l'incident, le SOARPlaybook déclenche la réponse automatique, et le NSGRule applique le blocage. Enfin, Power BI visualise les incidents et les anomalies.

## Slide 10 - Diagramme de séquence

Ce diagramme explique le déroulement d'un incident. L'attaquant génère une requête vers le honeypot, Suricata produit des événements, le pipeline collecte et analyse les logs, puis Sentinel déclenche une alerte. Si l'incident est confirmé, Logic Apps bloque automatiquement l'adresse IP via le NSG et les tableaux de bord sont rafraîchis.

## Slide 11 - Diagramme de cas d'utilisation

Ce diagramme présente les principaux utilisateurs du système. L'attaquant génère des événements, l'analyste SOC consulte les incidents et les tableaux de bord, tandis que l'administrateur configure l'infrastructure, les règles KQL et les alertes Sentinel. La plateforme relie donc la capture, la détection, la réponse et le reporting.
