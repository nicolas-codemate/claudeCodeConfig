---
description: Corrige les breaking changes GraphQL en restaurant et dépréciant les éléments supprimés
argument-hint: [rapport BC (format "[log] ✖ Field/Argument ... was removed ...")]
project: true
gitignored: false
---

# Correction des Breaking Changes GraphQL

Tu es un expert en correction de breaking changes d'API GraphQL. Ta mission est de restaurer les champs, queries, mutations et arguments supprimés tout en les marquant comme dépréciés pour maintenir la rétrocompatibilité.

## Format d'entrée

L'utilisateur fournira un rapport de BC breaks dans ce format :
```
[log] ✖  Field <fieldName> was removed from object type <TypeName>
[log] ✖  Field <queryName> was removed from object type RootQuery
  - Argument <argName>: <ArgType> was removed from field RootMutation.<MutationName>
```

## Ta mission

Parse les BC breaks et applique les corrections appropriées pour chaque type :

### 1. Pour les champs supprimés d'un type GraphQL

**Exemple** : `Field name was removed from object type BlockingFlowDetail`

**Actions** :
1. Lire le fichier YAML du type : `config/graphql/types/<TypeName>.yaml`
2. Ajouter le champ supprimé avec :
   - `deprecationReason: "Use <newFieldName> instead"` (identifier le champ de remplacement)
   - `resolve: "@=value['<newFieldName>']"` (fallback vers le nouveau champ)
3. Garder également le nouveau champ (les deux coexistent)

**Exemple de correction** :
```yaml
name:
    type: "String!"
    deprecationReason: "Use securityOperationName instead"
    resolve: "@=value['securityOperationName']"
securityOperationName:
    type: "String!"
```

### 2. Pour les queries supprimées de RootQuery

**Exemple** : `Field GetAccountTransactionMoneyMovements was removed from object type RootQuery`

**Actions** :
1. Lire `config/graphql/queries/RootQuery.yaml`
2. Consulter l'historique git pour trouver :
   - La définition originale de la query (args, type, resolve)
   - Ce qui l'a remplacée (généralement une version renommée/refactorisée)
3. Rajouter la query avec :
   - `deprecationReason: "Use <NewQueryName> with <specificParams> instead"`
   - Structure d'arguments originale
   - Créer un resolver wrapper si les types de retour sont incompatibles
4. Si la nouvelle query retourne un type différent (ex: Connection vs Array) :
   - Créer une classe resolver dans `src/Infrastructure/Graphql/Resolver/Queries/RootQuery/<QueryName>.php`
   - **IMPORTANT** : Implémenter `QueryInterface` (sinon le service ne sera pas taggé)
   - Appeler la logique de la nouvelle query et convertir la réponse
5. **Tests Behat (IMPORTANT)** :
   - Restaurer le fichier `.feature` original de la query dépréciée depuis git
   - Simplifier les tests (garder 2-3 scénarios basiques)
   - Marquer le feature comme `[DEPRECATED]` dans le titre
   - S'assurer que le fichier `.feature` de la NOUVELLE query existe aussi
   - **Convention : 1 query = 1 fichier .feature du même nom**

### 3. Pour les mutations supprimées de RootMutation

**Exemple** : `Field SetSomething was removed from object type RootMutation`

**Actions** (identiques aux queries) :
1. Restaurer la mutation dans `config/graphql/queries/RootMutation.yaml`
2. Marquer comme dépréciée avec `deprecationReason`
3. Le resolver doit implémenter `MutationInterface`
4. **Tests Behat (IMPORTANT)** :
   - Restaurer le fichier `.feature` original depuis git
   - Simplifier à 2-3 scénarios essentiels
   - Marquer comme `[DEPRECATED]`
   - **Convention : 1 mutation = 1 fichier .feature du même nom**

### 4. Pour les arguments supprimés de mutations

**Exemple** : `Argument documentGeneration: DocumentGenerationInput! was removed from field RootMutation.SetCessionPaymentDate`

**Actions** :
1. Lire `config/graphql/queries/RootMutation.yaml`
2. Rajouter les arguments en **optionnel** (retirer le `!`) :
   ```yaml
   args:
       existingArg:
           type: 'ID!'
       deprecatedArg:
           type: 'DocumentGenerationInput'  # Optionnel, pas de !
           description: "⚠️ DEPRECATED : Cet argument est ignoré. <Raison/Alternative>"
   ```
3. **Important** : Ne PAS ajouter les args dépréciés à l'expression `resolve`
4. Signature PHP du resolver :
   - Garder uniquement les paramètres non-dépréciés
   - La couche GraphQL accepte les args dépréciés mais ne les passe pas au resolver

**Templates de description** :
- Pour génération de documents : `"⚠️ DEPRECATED : Cet argument est ignoré. Les documents sont maintenant générés dans <MutationAlternative>"`
- Pour emails : `"⚠️ DEPRECATED : Cet argument est ignoré. Les emails sont envoyés dans <MutationAlternative>"`
- Pour dates : `"⚠️ DEPRECATED : Cet argument est ignoré. Utiliser <MutationAlternative> à la place"`

### 5. Gestion des tests Behat - TRÈS IMPORTANT

**Convention stricte** : 1 query/mutation = 1 fichier .feature avec le même nom

#### Quand une query/mutation est supprimée :

1. **Identifier le fichier .feature correspondant** :
   ```bash
   find features -name "<QueryName>.feature"
   ```

2. **Vérifier l'historique git** :
   ```bash
   git log --all --full-history -- "**/<QueryName>.feature"
   ```

3. **Deux cas possibles** :

   **Cas A : Le fichier a été supprimé**
   - Restaurer la version ORIGINALE depuis git :
     ```bash
     git show <commit_avant_suppression>:path/to/<QueryName>.feature
     ```
   - Simplifier les tests (garder 2-3 scénarios essentiels)
   - Marquer comme `[DEPRECATED]` dans le titre

   **Cas B : Le fichier a été renommé/modifié pour tester la nouvelle query**
   - Restaurer l'ancienne version pour la query dépréciée
   - S'assurer qu'un fichier séparé existe pour la nouvelle query
   - Organiser correctement les namespaces :
     - Query dépréciée : garde son namespace original
     - Nouvelle query : nouveau namespace approprié

4. **Structure d'un test pour query dépréciée** :
   ```gherkin
   Feature: [DEPRECATED] Description de la query dépréciée
     This query is deprecated. Use <NewQueryName> instead.

     @unauthenticated
     Scenario: Test d'authentification basique
       # Test minimal

     Scenario: Test fonctionnel basique
       # Test avec les paramètres principaux

     Scenario: Test avec filtres optionnels (si applicable)
       # Test des paramètres optionnels
   ```

5. **Validation finale** :
   - Vérifier qu'il y a bien 2 fichiers distincts :
     - `<DeprecatedQueryName>.feature` → Teste la query dépréciée
     - `<NewQueryName>.feature` → Teste la nouvelle query
   - Les deux fichiers doivent passer tous leurs tests
   - Ne JAMAIS avoir un seul fichier qui teste les deux queries

### 6. Étapes d'investigation

Avant de faire des modifications :
1. Utiliser l'historique git pour comprendre ce qui s'est passé :
   ```bash
   git log --all --full-history -p -- path/to/file
   git show <commit>:<path>
   git diff <commit>^..<commit> -- path/to/file
   ```
2. Trouver le commit qui a supprimé l'élément
3. Comprendre le remplacement/l'alternative
4. **Vérifier si des tests ont été modifiés/supprimés dans le même commit**

### 7. Étapes finales

Après avoir appliqué toutes les corrections :

1. Vider et régénérer les assets :
   ```bash
   make dump-webapp-assets
   ```

2. Vider le cache de test :
   ```bash
   rm -rf var/cache/test
   docker compose exec php php bin/console cache:warmup --env=test
   ```

3. Lancer les tests Behat pour les features affectées :
   ```bash
   docker compose exec php ./vendor/bin/behat features/path/to/deprecated.feature
   docker compose exec php ./vendor/bin/behat features/path/to/new.feature
   ```

4. Vérifier qu'il ne reste plus d'erreurs de BC

## Stratégie d'implémentation

1. **Parser l'entrée** : Extraire tous les BC breaks de l'input utilisateur
2. **Catégoriser** : Grouper par type (champ supprimé, query supprimé, argument supprimé)
3. **Prioriser** :
   - D'abord : Champs de types (dépendances pour les queries)
   - Ensuite : Queries/Mutations (structure)
   - Enfin : Arguments (détails)
4. **Appliquer les corrections** : Pour chaque BC break, appliquer la correction appropriée
5. **Restaurer les tests Behat** : Vérifier et restaurer tous les .feature supprimés/modifiés
6. **Valider** : Lancer les tests et vérifier les erreurs
7. **Reporter** : Résumer ce qui a été corrigé

## Principes clés

- ✅ Toujours maintenir la rétrocompatibilité
- ✅ Ne jamais supprimer sans déprécier d'abord
- ✅ Fournir des messages de dépréciation clairs avec alternatives
- ✅ Les arguments dépréciés doivent être optionnels (pas de `!`)
- ✅ Garder anciennes et nouvelles versions coexistantes
- ✅ Tester les APIs dépréciées pour s'assurer qu'elles fonctionnent
- ✅ **1 query/mutation = 1 fichier .feature avec le même nom**
- ✅ **Toujours restaurer les tests Behat des éléments dépréciés**
- ✅ **Les resolvers doivent implémenter QueryInterface ou MutationInterface**
- ❌ Ne jamais passer les args dépréciés aux resolvers (ils sont ignorés)
- ❌ Ne jamais amender ou supprimer du vieux code sans dépréciation d'abord

## Format de sortie

Fournir un résumé avec :
- Nombre de BC breaks trouvés et catégorisés
- Nombre de corrections appliquées par catégorie
- Fichiers modifiés (YAML, PHP, .feature)
- Tests créés/restaurés/mis à jour avec leur statut
- Résultats de validation (tests passés/échoués)
- Problèmes restants ou avertissements

## Checklist finale avant de terminer

- [ ] Tous les champs supprimés sont restaurés avec `deprecationReason`
- [ ] Toutes les queries supprimées sont restaurées avec `deprecationReason`
- [ ] Tous les arguments supprimés sont restaurés en optionnel avec description dépréciée
- [ ] Arguments dépréciés NOT dans les expressions `resolve`
- [ ] Resolvers PHP ne contiennent PAS les paramètres dépréciés
- [ ] Resolvers implémentent QueryInterface ou MutationInterface
- [ ] Tous les fichiers .feature des queries/mutations dépréciées sont restaurés
- [ ] Tous les fichiers .feature des nouvelles queries/mutations existent
- [ ] Tous les tests Behat passent (anciens ET nouveaux)
- [ ] Assets GraphQL régénérés avec succès
- [ ] Cache de test vidé et réchauffé
- [ ] Aucune erreur de BC break ne subsiste

---
