#🌲 InterventionFor_Shiny – Interventions forestières Saguenay (1960–2022)

Application Shiny pour visualiser les interventions forestières au Québec de 1960 à 2022.
![Deploy to shinyapps.io](https://github.com/hgesdrn/InterventionFor_Shiny/actions/workflows/deploy.yml/badge.svg)


**InterventionFor_shiny** est une application Shiny interactive permettant de visualiser les interventions forestières (ex. coupes, plantations, éclaircies) dans 4 unités d’aménagement du Saguenay, regroupées par périodes de 10 ans entre 1960 et 2029.

---

## 🔗 Lien vers l'application

👉 [Application en ligne sur shinyapps.io](https://hgesdrn.shinyapps.io/InterventionFor_Shiny/)

---

## 🎯 Objectif

Cette application vise à explorer l’évolution spatiale et temporelle des interventions forestières réalisées dans 4 unités d’aménagement du Saguenay :

- 02371
- 02471
- 02571
- 02751

L’utilisateur peut :
- Sélectionner une période de 10 ans
- Choisir un type d’intervention (ex. CP, PL, EPC…)
- Visualiser les polygones sur une carte interactive
- Suivre l’évolution par territoire à l’aide d’un graphique

---

## 📂 Structure des données

Les données sont hébergées directement dans ce dépôt GitHub :
https://github.com/hgesdrn/InterventionFor_Shiny  


Chaque fichier `.qs` contient les polygones pour une période donnée.


---

## 🚀 Déploiement automatique

Le déploiement de cette application est automatisé avec **GitHub Actions** à chaque mise à jour du dépôt `main`.

Fichier de configuration : `.github/workflows/deploy.yml`


---

## 📅 Historique des interventions forestières

L’application couvre les types d’interventions suivants :

| Code     | Description                                 |
|----------|---------------------------------------------|
| CP       | Coupe partielle                             |
| CR       | Coupe de récupération                       |
| EPC      | Éclaircie précommerciale                    |
| PL       | Plantation                                  |
| CT-CPR   | Coupe protection régénératon & Coupe totale |

---

## 👤 Auteur

Développée par **Hugues Dorion** – 2025  
Université du Québec à Chicoutimi  
🌐 [GitHub](https://github.com/hgesdrn)

  