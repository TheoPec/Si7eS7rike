# ==============================================
#  SI7ES7RIKE - Build players.js + carousel.js
#  Double-clique sur ce fichier pour mettre a jour le site !
#  Il scanne data/players/*.json et genere data/players.js
#  Il scanne carousel/ et genere data/carousel.js
# ==============================================

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$playersDir = Join-Path $scriptDir "data\players"
$outputFile = Join-Path $scriptDir "data\players.js"

# Trouve tous les .json dans data/players/
$jsonFiles = Get-ChildItem -Path $playersDir -Filter "*.json" -File | Sort-Object Name

if ($jsonFiles.Count -eq 0) {
    Write-Host ""
    Write-Host "  ERREUR : Aucun fichier .json trouve dans data\players\" -ForegroundColor Red
    Write-Host "  Mets les fichiers de tes joueurs la-dedans !" -ForegroundColor Red
    Write-Host ""
    Read-Host "Appuie sur Entree pour fermer"
    exit 1
}

Write-Host ""
Write-Host "  === SI7ES7RIKE Build ===" -ForegroundColor Green
Write-Host ""

$players = @()

foreach ($file in $jsonFiles) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $json = $content | ConvertFrom-Json

        # Supprime les champs _AIDE (au cas ou le pote les a laisses)
        $cleanJson = $content | ConvertFrom-Json
        $propsToRemove = @($cleanJson.PSObject.Properties | Where-Object { $_.Name -like "_AIDE*" } | ForEach-Object { $_.Name })
        foreach ($prop in $propsToRemove) {
            $cleanJson.PSObject.Properties.Remove($prop)
        }
        # Nettoie aussi les _AIDE dans les sous-objets
        foreach ($prop in $cleanJson.PSObject.Properties) {
            if ($prop.Value -is [PSCustomObject]) {
                $subPropsToRemove = @($prop.Value.PSObject.Properties | Where-Object { $_.Name -like "_AIDE*" } | ForEach-Object { $_.Name })
                foreach ($subProp in $subPropsToRemove) {
                    $prop.Value.PSObject.Properties.Remove($subProp)
                }
            }
        }

        $pseudo = if ($cleanJson.pseudo) { $cleanJson.pseudo } else { $file.BaseName }

        # Auto-detect photo si le champ est vide ou pointe vers un fichier inexistant
        $photoField = $cleanJson.photo
        if (-not $photoField -or -not (Test-Path (Join-Path $scriptDir $photoField))) {
            $playerId = $file.BaseName
            $photosDir = Join-Path $scriptDir "photos"
            $found = Get-ChildItem -Path $photosDir -Filter "$playerId.*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $cleanJson.photo = "photos/$($found.Name)"
                Write-Host "    -> photo auto-detectee: photos/$($found.Name)" -ForegroundColor DarkYellow
            }
        }

        Write-Host "  + $pseudo" -ForegroundColor Cyan -NoNewline
        Write-Host " ($($file.Name))" -ForegroundColor DarkGray

        $players += $cleanJson
    }
    catch {
        Write-Host "  x ERREUR dans $($file.Name) : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Genere le fichier players.js
$wrapper = [PSCustomObject]@{ players = $players }
$jsonOutput = $wrapper | ConvertTo-Json -Depth 10 -Compress:$false

# Remplace les echappements Unicode PowerShell par les vrais caracteres
$jsonOutput = [System.Text.RegularExpressions.Regex]::Replace($jsonOutput, '\\u([0-9a-fA-F]{4})', {
    param($m)
    [char]([Convert]::ToInt32($m.Groups[1].Value, 16))
})

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$jsContent = "var PLAYERS_DATA = $jsonOutput;"
[System.IO.File]::WriteAllText($outputFile, $jsContent, $utf8NoBom)

# ==============================================
#  CAROUSEL: scanne carousel/ pour les images
# ==============================================
$carouselDir = Join-Path $scriptDir "carousel"
$carouselOutput = Join-Path $scriptDir "data\carousel.js"

$slides = @()
if (Test-Path $carouselDir) {
    $imageFiles = Get-ChildItem -Path $carouselDir -File | Where-Object { $_.Extension -match '\.(png|jpg|jpeg|gif|webp|bmp)$' } | Sort-Object Name
    foreach ($img in $imageFiles) {
        # Le nom du fichier (sans extension) sert de legende
        # Remplace les underscores et tirets par des espaces
        $caption = $img.BaseName -replace '[_-]', ' '
        $slide = [PSCustomObject]@{
            src     = "carousel/$($img.Name)"
            caption = $caption
        }
        $slides += $slide
    }
    if ($imageFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "  === Carousel ===" -ForegroundColor Green
        foreach ($img in $imageFiles) {
            Write-Host "  + $($img.Name)" -ForegroundColor Cyan
        }
        Write-Host "  $($imageFiles.Count) image(s) dans le carousel" -ForegroundColor Green
    }
}

$carouselJson = $slides | ConvertTo-Json -Depth 5 -Compress:$false
# Si un seul element, ConvertTo-Json ne met pas de tableau
if ($slides.Count -le 1) {
    $carouselJson = "[$carouselJson]"
}
if ($slides.Count -eq 0) {
    $carouselJson = "[]"
}
$carouselJs = "var CAROUSEL_DATA = $carouselJson;"
[System.IO.File]::WriteAllText($carouselOutput, $carouselJs, $utf8NoBom)

Write-Host ""
Write-Host "  $($players.Count) joueur(s) genere(s) dans data\players.js" -ForegroundColor Green
Write-Host "  Tu peux ouvrir index.html !" -ForegroundColor Green
Write-Host ""
Read-Host "Appuie sur Entree pour fermer"
