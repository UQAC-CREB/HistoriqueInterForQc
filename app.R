# ===============================
# Interventions forestières — version optimisée
# ===============================

library(shiny)
library(leaflet)
library(terra)
library(sf)
library(dplyr)
library(ggplot2)
library(shinyWidgets)
library(readr)
library(leafgl)


# =======================
# Sources de données: GitHub ou local
# =======================
USE_GITHUB   <- TRUE  # mets FALSE pour revenir en local

# -> Renseigne tes infos GitHub :
GH_USER      <- "UQAC-CREB"
GH_REPO      <- "HistoriqueInterForQc"
GH_BRANCH    <- "main"

# Dossier de cache pour les fichiers rapatriés de GitHub
cache_dir <- file.path(tempdir(), "if_cache")
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

# Construit l'URL RAW GitHub
gh_raw_url <- function(path) {
  sprintf("https://raw.githubusercontent.com/%s/%s/%s/%s",
          GH_USER, GH_REPO, GH_BRANCH, path)
}

# Télécharge une fois vers le cache et retourne le chemin local
gh_get_file <- function(path_rel) {
  url  <- gh_raw_url(path_rel)
  dest <- file.path(cache_dir, gsub("[/\\\\]", "_", path_rel))
  if (!file.exists(dest)) {
    try({
      utils::download.file(url, destfile = dest, mode = "wb", quiet = TRUE)
    }, silent = TRUE)
    if (!file.exists(dest) || file.size(dest) == 0) {
      stop(sprintf("Téléchargement GitHub échoué: %s", url))
    }
  }
  dest
}


# --------- Terra/GDAL options (perf) ----------
# terraOptions(memfrac = 0.6, todisk = TRUE, tempdir = tempdir())

# =======================
# Chemins / données
# =======================

# CSV (URL GitHub directe possible avec readr)
chemin_csv <- if (USE_GITHUB) gh_raw_url("data/table_barplot.csv") else "data/table_barplot.csv"

# vecteur UA simplifié (.rds via cache si GitHub)
uasag_path  <- if (USE_GITHUB) gh_get_file("data/uasag_simpl.rds") else "data/uasag_simpl.rds"
uasag_simpl <- readRDS(uasag_path)

# 🎨 Palette
palette_classes <- c(
  "CP"    = "#377eb8",
  "CR"    = "#4daf4a",
  "EPC"   = "#984ea3",
  "PL"    = "#e41a1c",
  "CT-CPR"= "#ff7f00"
)
classes_nom <- c(
  "CP"    = "Coupe partielle",
  "CR"    = "Coupe de récupération",
  "EPC"   = "Éclaircie précommerciale",
  "PL"    = "Plantation",
  "CT-CPR"= "Coupe protection régèn./totale"
)
classe_labels <- setNames(names(classes_nom), paste(names(classes_nom), " - ", classes_nom))

periodes   <- c("1960-1969","1970-1979","1980-1989","1990-1999","2000-2009","2010-2019","2020-2029")
terr_choix <- c("02371", "02471", "02571", "02751")

# 📊 Lecture de la table agrégée (CSV) — UNE SEULE FOIS
df_agg <- readr::read_csv(chemin_csv, show_col_types = FALSE) |>
  dplyr::filter(TERRITOIRE %in% terr_choix)

# BBox figé (WGS84)
bb <- c(xmin = -74.43331,  ymin = 47.39345, xmax = -69.80989, ymax = 51.76088 )

# Centroides UA (pré-calculés en dur)
centro_df <- data.frame(
  TERRITOIRE = c("02371","02471","02571","02751"),
  lon = c(-71.5, -70.95, -73.30718, -72.09900),
  lat = c( 48.0,   50.20,  49.78314,  49.41)
)
centroides_ua <- sf::st_as_sf(centro_df, coords = c("lon","lat"), crs = 4326)

######
# --- cache en mémoire pour les périodes déjà lues ---
.cache_vec <- new.env(parent = emptyenv())
path_vec_base <- "data/vec"  # racine dans le repo (ou local)

# charge paresseusement un .rds par période (depuis GitHub si USE_GITHUB)
load_period <- function(p) {
  key <- paste0("p_", p)
  if (!exists(key, envir = .cache_vec)) {
    rel <- file.path(path_vec_base, paste0("IntFor_", p, ".rds"))
    f <- if (USE_GITHUB) gh_get_file(rel) else rel
    if (!file.exists(f)) {
      showNotification(paste("Fichier manquant :", basename(rel)), type = "error")
      assign(key, sf::st_sf(Periode=character(), CLASS=character(),
                            geometry=sf::st_sfc(crs=4326)), envir = .cache_vec)
    } else {
      assign(key, readRDS(f), envir = .cache_vec)
    }
  }
  get(key, envir = .cache_vec)
}

# ===============================
# UI
# ===============================
ui <- fluidPage(
  tags$style(HTML("
    .header-title {
      background-color: #2C3E50;
      color: white;
      padding: 20px;
      font-size: 22px;
      font-weight: bold;
      text-align: left;
      text-transform: uppercase;
      margin-bottom: 20px;
      box-shadow: 2px 2px 8px rgba(0,0,0,0.2);
    }
    .box-style {
      background-color: #f9f9f9;
      border: 1px solid #ccc;
      border-radius: 8px;
      padding: 20px;
      box-shadow: 2px 2px 8px rgba(0,0,0,0.1);
      height: 700px;
      overflow-y: auto;
    }
    .irs--shiny .irs-line,
    .irs--shiny .irs-bar,
    .irs--shiny .irs-bar-edge,
    .irs--shiny .irs-single {
      background-color: #ddd !important;
      border-color: #ddd !important;
      color: black !important;
    }
    .irs--shiny .irs-handle {
      border-color: #999 !important;
      background-color: #999 !important;
    }
  ")),
  
  div("INTERVENTIONS FORESTIÈRES DANS LES UNITÉS D'AMÉNAGEMENTS DU SAGUENAY-Lac-ST-JEAN DE 1960 À 2022", class = "header-title"),
  
  fluidRow(
    column(6,
           div(class = "box-style",
               sliderTextInput(
                 "periode", "Choisir une période :", 
                 choices = periodes, selected = periodes[1], grid = TRUE,
                 animate = animationOptions(interval = 1500, loop = FALSE), 
                 width = "100%"
               ),
               selectInput("classe", "Type d'intervention :", choices = classe_labels, selected = "CP"),
               plotOutput("barplot", height = "400px")
           )
    ),
    column(6,
           div(class = "box-style",
               leafletOutput("carte", height = "640px")
           )
    )
  )
)

# ===============================
# SERVER
# ===============================
server <- function(input, output, session) {
  # --- debounce des entrées ---
  classe_db  <- debounce(reactive(input$classe), 250)
  periode_db <- debounce(reactive(input$periode), 250)
  
  # Données pour le graphique
  donnees_aggregées <- reactive({
    df_agg |>
      filter(CLASS == classe_db()) |>
      mutate(
        Selection = Periode == periode_db(),
        TERRITOIRE_LABEL = paste("UA", TERRITOIRE)
      )
  })
  
  # 🗺️ Carte initiale (fond + UA + labels)
  output$carte <- renderLeaflet({
    leaflet(options = leafletOptions(preferCanvas = TRUE)) |>
      addProviderTiles("CartoDB.Positron", group = "Fond gris") |>
      addProviderTiles("Esri.WorldImagery", group = "Imagerie") |>
      fitBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]]) |>
      
      # UA en CONTOURS UNIQUEMENT, non-interactifs (pas de hover/click)
      addPolygons(
        data   = uasag_simpl,
        fill   = FALSE,
        color  = "grey35",
        weight = 1,
        opacity= 1,
        smoothFactor = 0.7,
        group  = "UA (polygones)",
        options = pathOptions(pointerEvents = "none")
      ) |>
      
      # Étiquettes fixes (centroïdes)
      addLabelOnlyMarkers(
        data = centroides_ua,
        label = ~TERRITOIRE,
        labelOptions = labelOptions(
          noHide = TRUE, direction = "center", textOnly = TRUE,
          style = list(
            "font-weight" = "bold", "font-size" = "14px",
            "color" = "black", "text-shadow" = "1px 1px 2px #fff"
          )
        ),
        group = "Étiquettes UA"
      ) |>
      
      addLayersControl(
        baseGroups    = c("Fond gris", "Imagerie"),
        overlayGroups = c("UA (polygones)", "Étiquettes UA", "IntFor"),
        options = layersControlOptions(collapsed = FALSE)
      )
  })
  
  # --- helper centralisé pour rendre les polygones IntFor ---
  render_intfor <- function(period, classe) {
    id <- showNotification("Chargement des polygones…", type = "message", duration = NULL)
    on.exit(removeNotification(id), add = TRUE)
    
    # charge + filtre
    g <- load_period(period)
    g_cls <- dplyr::filter(g, CLASS == classe)
    
    # nettoyage & coercitions robustes
    g_cls <- sf::st_make_valid(g_cls)
    g_cls <- sf::st_zm(g_cls, drop = TRUE, what = "ZM")
    g_poly <- try(suppressWarnings(sf::st_collection_extract(g_cls, "POLYGON")), silent = TRUE)
    if (inherits(g_poly, "try-error")) g_poly <- g_cls
    
    types <- sf::st_geometry_type(g_poly)
    keep  <- types %in% c("POLYGON", "MULTIPOLYGON")
    g_poly <- g_poly[keep, ]
    g_poly <- g_poly[!sf::st_is_empty(g_poly), ]
    suppressWarnings(g_poly <- sf::st_cast(g_poly, "MULTIPOLYGON"))
    
    if (nrow(g_poly) == 0) {
      leafletProxy("carte") |> clearGroup("IntFor") |> removeControl("legend_intfor")
      showNotification("Aucun polygone à afficher pour cette sélection.", type = "warning")
      return(invisible(FALSE))
    }
    
    # couleur associée à la classe sélectionnée
    col <- unname(palette_classes[classe])
    leg_label <- paste0(classe, " - ", classes_nom[[classe]])
    
    # tentative leafgl
    ok_leafgl <- TRUE
    try({
      leafletProxy("carte") |>
        clearGroup("IntFor") |>
        leafgl::addGlPolygons(
          data       = g_poly,
          color      = col,
          weight     = 1,
          fillColor  = col,
          fillOpacity= 0.6,
          group      = "IntFor"
        ) |>
        removeControl("legend_intfor") |>
        addLegend(
          position = "bottomright",
          colors   = col,
          labels   = leg_label,
          opacity  = 0.8,
          title    = "Type d'intervention",
          layerId  = "legend_intfor"
        )
    }, silent = TRUE) -> res
    if (inherits(res, "try-error")) ok_leafgl <- FALSE
    
    # fallback addPolygons si leafgl refuse
    if (!ok_leafgl) {
      leafletProxy("carte") |>
        clearGroup("IntFor") |>
        addPolygons(
          data       = g_poly,
          color      = col,
          weight     = 1, opacity = 1,
          fillColor  = col,
          fillOpacity= 0.6,
          group      = "IntFor"
        ) |>
        removeControl("legend_intfor") |>
        addLegend(
          position = "bottomright",
          colors   = col,
          labels   = leg_label,
          opacity  = 0.8,
          title    = "Type d'intervention",
          layerId  = "legend_intfor"
        )
    }
    
    invisible(TRUE)
  }
  
  # 🔄 Mise à jour à chaque changement période/classe
  observeEvent(list(classe_db(), periode_db()), {
    render_intfor(periode_db(), classe_db())
  }, ignoreInit = TRUE)
  
  # 📈 Graphique
  output$barplot <- renderPlot({
    df <- donnees_aggregées()
    col_sel <- unname(palette_classes[classe_db()])
    ggplot(df, aes(x = Periode, y = Surface)) +
      geom_col(fill = "#d0d0d0") +
      geom_col(data = df[df$Selection, , drop = FALSE], fill = col_sel) +
      facet_wrap(~TERRITOIRE_LABEL, ncol = 2) +
      scale_y_continuous(labels = scales::comma_format()) +
      scale_x_discrete(limits = periodes) +
      labs(
        title = "Superficie (ha) par type d'intervention pour chaque unité d'aménagement.",
        y = "Superficie (ha)", x = "Période"
      ) +
      theme_minimal(base_size = 14) +
      theme(
        strip.background = element_rect(fill = "#D4D4D4", color = "grey40"),
        strip.text = element_text(color = "black", face = "bold", size = 14),
        axis.text.y = element_text(face = "bold", size = 10),
        axis.text.x = element_text(angle = 25, hjust = 1),
        axis.title.x = element_text(face = "bold", size = 14, margin = margin(t = 15)),
        axis.title.y = element_text(face = "bold", size = 14, margin = margin(r = 10)),
        plot.title = element_text(size = 14, face = "bold")
      )
  })
  
  # ▶️ Afficher IntFor par défaut au chargement (une seule fois)
  session$onFlushed(function() {
    render_intfor(isolate(periode_db()), isolate(classe_db()))
  }, once = TRUE)
}

shinyApp(ui, server)
