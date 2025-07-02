#!/bin/bash

# Script para remover emojis do arquivo draw.io

FILE="FIAPX-Architecture-Complete.drawio"

# Backup do arquivo original
cp "$FILE" "${FILE}.backup"

# Remove emojis específicos
sed -i 's/🔒 //g' "$FILE"
sed -i 's/📈 //g' "$FILE"
sed -i 's/📤 //g' "$FILE"
sed -i 's/💾 //g' "$FILE"
sed -i 's/📊 //g' "$FILE"
sed -i 's/📥 //g' "$FILE"
sed -i 's/📋 //g' "$FILE"
sed -i 's/⚖️ //g' "$FILE"

echo "Emojis removidos do arquivo $FILE"
echo "Backup salvo como ${FILE}.backup"
