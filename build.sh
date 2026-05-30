#!/bin/bash

# ==============================================
#  SI7ES7RIKE - Build players.js + carousel.js
#  Équivalent bash de build.ps1
#  Double-clique sur ce fichier pour mettre à jour le site !
#  Il scanne data/players/*.json et génère data/players.js
#  Il scanne carousel/ et génère data/carousel.js
# ==============================================

# Vérification de la présence de jq
if ! command -v jq &> /dev/null; then
    echo -e "\e[31m  ERREUR : 'jq' n'est pas installé sur ce système.\e[0m"
    echo -e "\e[31m  Installe-le via 'sudo apt install jq' ou ton gestionnaire de paquets.\e[0m"
    read -p "Appuie sur Entrée pour fermer"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYERS_DIR="$SCRIPT_DIR/data/players"
OUTPUT_FILE="$SCRIPT_DIR/data/players.js"
PHOTOS_DIR="$SCRIPT_DIR/photos"
CAROUSEL_DIR="$SCRIPT_DIR/carousel"
CAROUSEL_OUTPUT="$SCRIPT_DIR/data/carousel.js"

shopt -s nullglob
json_files=("$PLAYERS_DIR"/*.json)

if [ ${#json_files[@]} -eq 0 ]; then
    echo ""
    echo -e "\e[31m  ERREUR : Aucun fichier .json trouvé dans data/players/\e[0m"
    echo -e "\e[31m  Mets les fichiers de tes joueurs là-dedans !\e[0m"
    echo ""
    read -p "Appuie sur Entrée pour fermer"
    exit 1
fi

echo ""
echo -e "\e[32m  === SI7ES7RIKE Build ===\e[0m"
echo ""

players_json="[]"

for file in "${json_files[@]}"; do
    filename=$(basename "$file")
    basename="${filename%.*}"

    # Supprime les champs _AIDE (top-level et récursif dans les sous-objets)
    # "walk" parcourt tout l'arbre JSON et ignore les clés commençant par "_AIDE"
    clean_json=$(jq -c 'walk(if type == "object" then with_entries(select(.key | startswith("_AIDE") | not)) else . end)' "$file" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$clean_json" ]; then
        echo -e "\e[31m  x ERREUR dans $filename : JSON invalide\e[0m"
        continue
    fi

    pseudo=$(echo "$clean_json" | jq -r '.pseudo // ""')
    if [ -z "$pseudo" ] || [ "$pseudo" == "null" ]; then
        pseudo="$basename"
    fi

    # Auto-detect photo si le champ est vide ou si le fichier n'existe pas
    photo_field=$(echo "$clean_json" | jq -r '.photo // ""')
    if [ -z "$photo_field" ] || [ "$photo_field" == "null" ] || [ ! -f "$SCRIPT_DIR/$photo_field" ]; then
        found_photo=$(find "$PHOTOS_DIR" -maxdepth 1 -type f -name "${basename}.*" 2>/dev/null | head -n 1)
        if [ -n "$found_photo" ]; then
            found_name=$(basename "$found_photo")
            clean_json=$(echo "$clean_json" | jq -c --arg p "photos/$found_name" '.photo = $p')
            echo -e "\e[33m    -> photo auto-détectée: photos/$found_name\e[0m"
        fi
    fi

    echo -e "\e[36m  + $pseudo \e[90m($filename)\e[0m"

    players_json=$(echo "$players_json" | jq -c --argjson obj "$clean_json" '. += [$obj]')
done

# Génère le fichier players.js
echo -n "var PLAYERS_DATA = " > "$OUTPUT_FILE"
echo "$players_json" | jq '{players: .}' >> "$OUTPUT_FILE"
echo ";" >> "$OUTPUT_FILE"

# ==============================================
#  CAROUSEL: scanne carousel/ pour les images
# ==============================================
carousel_json="[]"
if [ -d "$CAROUSEL_DIR" ]; then
    # Trouve toutes les images selon l'extension
    mapfile -t carousel_files < <(find "$CAROUSEL_DIR" -maxdepth 1 -type f -regextype posix-extended -iregex '.*\.(png|jpg|jpeg|gif|webp|bmp)$' | sort)

    if [ ${#carousel_files[@]} -gt 0 ]; then
        echo ""
        echo -e "\e[32m  === Carousel ===\e[0m"
        for img in "${carousel_files[@]}"; do
            img_name=$(basename "$img")
            base_name="${img_name%.*}"
            # Remplace les underscores et tirets par des espaces pour la légende
            caption=$(echo "$base_name" | tr '_-' '  ')
            
            slide_json=$(jq -n -c --arg src "carousel/$img_name" --arg cap "$caption" '{src: $src, caption: $cap}')
            carousel_json=$(echo "$carousel_json" | jq -c --argjson obj "$slide_json" '. += [$obj]')
            
            echo -e "\e[36m  + $img_name\e[0m"
        done
        echo -e "\e[32m  ${#carousel_files[@]} image(s) dans le carousel\e[0m"
    fi
fi

# Génère le fichier carousel.js
echo -n "var CAROUSEL_DATA = " > "$CAROUSEL_OUTPUT"
echo "$carousel_json" | jq '.' >> "$CAROUSEL_OUTPUT"
echo ";" >> "$CAROUSEL_OUTPUT"

# ==============================================
#  GÉNÉRATION DU DOSSIER BUILD
# ==============================================
BUILD_DIR="$SCRIPT_DIR/build"
echo ""
echo -e "\e[36m  === Création du dossier 'build' ===\e[0m"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/data"

cp "$OUTPUT_FILE" "$BUILD_DIR/data/" 2>/dev/null
cp "$CAROUSEL_OUTPUT" "$BUILD_DIR/data/" 2>/dev/null
[ -d "$PHOTOS_DIR" ] && cp -r "$PHOTOS_DIR" "$BUILD_DIR/"
[ -d "$CAROUSEL_DIR" ] && cp -r "$CAROUSEL_DIR" "$BUILD_DIR/"
[ -d "$SCRIPT_DIR/css" ] && cp -r "$SCRIPT_DIR/css" "$BUILD_DIR/" 2>/dev/null
[ -d "$SCRIPT_DIR/js" ] && cp -r "$SCRIPT_DIR/js" "$BUILD_DIR/" 2>/dev/null
[ -d "$SCRIPT_DIR/assets" ] && cp -r "$SCRIPT_DIR/assets" "$BUILD_DIR/" 2>/dev/null
[ -d "$SCRIPT_DIR/images" ] && cp -r "$SCRIPT_DIR/images" "$BUILD_DIR/" 2>/dev/null
[ -d "$SCRIPT_DIR/img" ] && cp -r "$SCRIPT_DIR/img" "$BUILD_DIR/" 2>/dev/null
find "$SCRIPT_DIR" -maxdepth 1 -type f \( -iname "*.html" -o -iname "*.css" -o -iname "*.js" \) -exec cp {} "$BUILD_DIR/" \;

echo ""
count=$(echo "$players_json" | jq 'length')
echo -e "\e[32m  $count joueur(s) généré(s) dans data/players.js\e[0m"
echo -e "\e[32m  Le dossier 'build/' est prêt pour le serveur !\e[0m"
echo -e "\e[32m  Tu peux ouvrir build/index.html !\e[0m"
echo ""
read -p "Appuie sur Entrée pour fermer"
