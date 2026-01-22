#!/bin/bash
# Read JSON input once
input=$(cat)

# Fonctions d'aide pour les extractions communes
get_model_name() { echo "$input" | jq -r '.model.display_name'; }
get_current_dir() { echo "$input" | jq -r '.workspace.current_dir'; }
get_cost() { echo "$input" | jq -r '.cost.total_cost_usd'; }
get_lines_added() { echo "$input" | jq -r '.cost.total_lines_added // 0'; }
get_lines_removed() { echo "$input" | jq -r '.cost.total_lines_removed // 0'; }

# Nouvelles fonctions pour le context window (mise à jour Claude Code)
# Utiliser current_usage pour le contexte actuel (comme /context)
get_current_input_tokens() { echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0'; }
get_cache_read_tokens() { echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0'; }
get_cache_creation_tokens() { echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0'; }
get_context_size() { echo "$input" | jq -r '.context_window.context_window_size // 200000'; }

get_git_branch() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local branch=$(git branch --show-current 2>/dev/null)
        if [ -n "$branch" ]; then
            echo " | 🌿 $branch"
        fi
    fi
}

# Fonction pour calculer le contexte (utilise current_usage comme /context)
calculate_context_percentage() {
    local input_tokens=$1
    local cache_read=$2
    local cache_creation=$3
    local context_size=$4
    
    # Total = input_tokens + cache_read + cache_creation
    local total_tokens=$((input_tokens + cache_read + cache_creation))
    
    if [[ "$context_size" -eq 0 ]]; then
        echo "0"
        return
    fi
    
    # Calculer le pourcentage
    local percentage=$(LC_NUMERIC=C awk "BEGIN {printf \"%.1f\", ($total_tokens / $context_size) * 100}")
    echo "$percentage"
}

# Fonction pour créer une progress bar
create_progress_bar() {
    local percentage=$1
    local width=20  # Largeur de la barre
    
    # Codes ANSI pour les couleurs
    local color_green='\033[0;32m'
    local color_yellow='\033[0;33m'
    local color_red='\033[0;31m'
    local reset='\033[0m'
    
    # Vérifier que percentage est valide
    if [[ -z "$percentage" || "$percentage" == "0" || "$percentage" == "0.0" ]]; then
        echo -e "Context: ${color_green}●${reset} [░░░░░░░░░░░░░░░░░░░░] 0.0%"
        return
    fi
    
    # Calcul du remplissage - forcer locale C
    local filled=$(LC_NUMERIC=C awk "BEGIN {printf \"%.0f\", ($percentage / 100) * $width}")
    
    # S'assurer que filled est un nombre valide
    if [[ -z "$filled" ]]; then
        filled=0
    fi
    
    # Construction de la barre
    local bar=""
    for ((i=0; i<width; i++)); do
        if (( i < filled )); then
            bar+="█"
        else
            bar+="░"
        fi
    done
    
    # Couleur selon le remplissage - forcer locale C
    local is_green=$(LC_NUMERIC=C awk "BEGIN {print ($percentage < 50) ? 1 : 0}")
    local is_yellow=$(LC_NUMERIC=C awk "BEGIN {print ($percentage >= 50 && $percentage < 80) ? 1 : 0}")
    
    if [ "$is_green" -eq 1 ]; then
        echo -e "Context: ${color_green}●${reset} [$bar] ${percentage}%"
    elif [ "$is_yellow" -eq 1 ]; then
        echo -e "Context: ${color_yellow}●${reset} [$bar] ${percentage}%"
    else
        echo -e "Context: ${color_red}●${reset} [$bar] ${percentage}%"
    fi
}

# Utiliser les fonctions d'aide
MODEL=$(get_model_name)
DIR=$(get_current_dir)
GIT_BRANCH=$(get_git_branch)
COST=$(get_cost)
COST_FORMATTED=$(printf "%.2f" "$COST")

# Récupérer les tokens directement du JSON (utilise current_usage)
INPUT_TOKENS=$(get_current_input_tokens)
CACHE_READ=$(get_cache_read_tokens)
CACHE_CREATION=$(get_cache_creation_tokens)
CONTEXT_SIZE=$(get_context_size)

# DEBUG - écrire le JSON complet pour analyse
echo "$input" > /tmp/statusline-debug.json

# Calculer le contexte
CONTEXT_PERCENTAGE=$(calculate_context_percentage "$INPUT_TOKENS" "$CACHE_READ" "$CACHE_CREATION" "$CONTEXT_SIZE")
PROGRESS_BAR=$(create_progress_bar "$CONTEXT_PERCENTAGE")

# Codes couleur ANSI
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "[$MODEL] 📁 ${DIR##*/}$GIT_BRANCH | ${GREEN}\$${COST_FORMATTED}${RESET}
$PROGRESS_BAR"
