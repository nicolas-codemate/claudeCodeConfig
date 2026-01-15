# RGPD Request Command

Automatise les demandes RGPD (suppression, accès, portabilité des données personnelles).

## Workflow

1. **Rechercher le contact DPO** de l'entreprise mentionnée via web search :
   - Mots-clés : `[nom entreprise] DPO contact RGPD privacy policy`
   - Chercher sur les pages : politique de confidentialité, mentions légales, contact

2. **Identifier le type de demande** :
   - Suppression (Art. 17) - défaut pour spam/marketing
   - Accès (Art. 15) - obtenir copie des données
   - Opposition (Art. 21) - arrêter le marketing
   - Portabilité (Art. 20) - export des données

3. **Rédiger le mail** en utilisant les templates de `/home/nicolas/.claude/skills/rgpd-request/references/templates.md`

4. **Fournir le mail prêt à envoyer** avec :
   - Destinataire (email DPO)
   - Objet
   - Corps du message personnalisé

## Déclencheurs

Utiliser cette commande quand l'utilisateur mentionne :
- "RGPD", "supprimer mes données", "droit à l'oubli"
- "désabonnement", "spam", "emails marketing"
- "mes données personnelles", "DPO"
