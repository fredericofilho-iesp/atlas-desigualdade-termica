# Atlas de Desigualdade Térmica — unidades subnacionais da América Latina e Caribe
# Executar na raiz do repositório: Rscript R/30_unidades_latam.R
# Requer: install.packages(c("sf", "jsonlite"))
# Fonte: geoBoundaries (William & Mary geoLab), primeiro nível administrativo (ADM1:
# estados, províncias, departamentos, regiões), versão simplificada, licenças abertas.
# Saída: dados/brutos/latam_adm1.rds (EPSG:4326; colunas id, nome, iso3, pais_*).
# Variável de ambiente: PAISES=URY,PRY limita aos países dados (teste).
suppressPackageStartupMessages({ library(sf); library(jsonlite) })
source("R/00_paises_latam.R")
sf_use_s2(FALSE)
options(timeout = 600)

lim <- strsplit(Sys.getenv("PAISES", ""), ",")[[1]]
isos <- if (length(lim) && nzchar(lim[1])) intersect(PAISES_LATAM$iso3, lim) else PAISES_LATAM$iso3

baixar_adm1 <- function(iso) {
  for (tipo in c("gbOpen", "gbHumanitarian", "gbAuthoritative")) {
    meta <- tryCatch(fromJSON(paste0("https://www.geoboundaries.org/api/current/", tipo, "/", iso, "/ADM1/")),
                     error = function(e) NULL)
    if (is.null(meta) || is.null(meta$simplifiedGeometryGeoJSON)) next
    g <- tryCatch(st_read(meta$simplifiedGeometryGeoJSON, quiet = TRUE), error = function(e) NULL)
    if (is.null(g) || !nrow(g)) next
    g <- st_make_valid(st_transform(g, 4326))
    nome <- if ("shapeName" %in% names(g)) as.character(g$shapeName) else paste0(iso, "-", seq_len(nrow(g)))
    message(sprintf("  %s: %d unidades (%s, %s)", iso, nrow(g), tipo, meta$boundaryYearRepresented %||% "?"))
    return(st_sf(id = paste0(iso, "-", sprintf("%03d", seq_len(nrow(g)))), nome = nome, iso3 = iso,
                 fonte = tipo, geometry = st_geometry(g)))
  }
  message("  ", iso, ": sem ADM1 no geoBoundaries — usa o país inteiro")
  NULL
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

# Nomes do geoBoundaries: alguns vêm sem acento, com erro de digitação, em caixa alta,
# em inglês ou com UTF-8 lido duas vezes (Chile). Corrige para a forma oficial local.
CORRECOES <- c(
  "ARG|La Roja" = "La Rioja",
  "BRA|Amapa" = "Amapá", "BRA|Para" = "Pará", "BRA|Maranhao" = "Maranhão", "BRA|Ceara" = "Ceará",
  "BRA|Rio Granda do Norte" = "Rio Grande do Norte", "BRA|Paraiba" = "Paraíba", "BRA|Piaui" = "Piauí",
  "BRA|Rondonia" = "Rondônia", "BRA|Goias" = "Goiás", "BRA|Espirito Santo" = "Espírito Santo",
  "BRA|Rio de Jeneiro" = "Rio de Janeiro", "BRA|Sao Paulo" = "São Paulo", "BRA|Parana" = "Paraná",
  "BHS|Biminis" = "Bimini",
  "CHL|Aysén del Gral.Ibañez del Campo" = "Aysén", "CHL|Magallanes y Antártica Chilena" = "Magallanes",
  "CHL|Libertador Bernardo O'Higgins" = "O'Higgins", "CHL|Metropolitana de Santiago" = "Metropolitana de Santiago",
  "COL|Bogota Capital District" = "Bogotá",
  "COL|Archipiélago de San Andrés, Providencia y Santa Catalina" = "San Andrés y Providencia",
  "CUB|Isle of Youth" = "Isla de la Juventud", "CUB|Havana" = "La Habana", "CUB|Pinar del Rio" = "Pinar del Río",
  "CUB|Ciego de Avila" = "Ciego de Ávila", "CUB|Sancti Spiritus" = "Sancti Spíritus",
  "DOM|La Estrelleta" = "Elías Piña", "DOM|Hermanas" = "Hermanas Mirabal",
  "ECU|Sucumbios" = "Sucumbíos", "ECU|Manabi" = "Manabí",
  "GUY|Barina-Waini" = "Barima-Waini",
  "MEX|Distrito Federal" = "Ciudad de México", "MEX|Mexico" = "México", "MEX|Michoacan de Ocampo" = "Michoacán",
  "MEX|Nuevo Leon" = "Nuevo León", "MEX|Queretaro de Arteaga" = "Querétaro", "MEX|San Luis Potosi" = "San Luis Potosí",
  "MEX|Yucatan" = "Yucatán", "MEX|Coahuila de Zaragoza" = "Coahuila", "MEX|Veracruz de Ignacio de la Llave" = "Veracruz",
  "NIC|Rio San Juan" = "Río San Juan", "NIC|Leon" = "León", "NIC|Matagalpa (Departemento)" = "Matagalpa",
  "NIC|Jinotega (Departamento)" = "Jinotega", "NIC|North Carribean Coast Autonomous Region" = "Costa Caribe Norte",
  "NIC|South Atlantic Autonomous Region" = "Costa Caribe Sur",
  "PAN|Colón Province" = "Colón",
  "PER|Municipalidad Metropolitana de Lima" = "Lima Metropolitana", "PER|Lima" = "Lima Provincias", "PER|El Callao" = "Callao",
  "PRY|ASUNCION" = "Asunción", "PRY|CONCEPCION" = "Concepción", "PRY|SAN PEDRO" = "San Pedro", "PRY|CORDILLERA" = "Cordillera",
  "PRY|GUAIRA" = "Guairá", "PRY|CAAGUAZU" = "Caaguazú", "PRY|CAAZAPA" = "Caazapá", "PRY|ITAPUA" = "Itapúa",
  "PRY|MISIONES" = "Misiones", "PRY|PARAGUARI" = "Paraguarí", "PRY|ALTO PARANA" = "Alto Paraná", "PRY|CENTRAL" = "Central",
  "PRY|ÑEEMBUCU" = "Ñeembucú", "PRY|AMAMBAY" = "Amambay", "PRY|CANINDEYU" = "Canindeyú", "PRY|PRESIDENTE HAYES" = "Presidente Hayes",
  "PRY|BOQUERON" = "Boquerón", "PRY|ALTO PARAGUAY" = "Alto Paraguay")
corrigir_nomes <- function(nome, iso) {
  nome <- enc2utf8(as.character(nome))
  dupla <- grepl("Ã", nome)                       # "RegiÃ³n": UTF-8 lido como latin1
  if (any(dupla)) { x <- iconv(nome[dupla], "UTF-8", "latin1"); Encoding(x) <- "UTF-8"; nome[dupla] <- ifelse(is.na(x), nome[dupla], x) }
  nome <- sub("^Región (de |del )", "", nome)       # Chile
  nome <- sub("^Provincia (de )?", "", nome)            # Costa Rica, Panamá
  nome <- sub("^Departamento de ", "", nome)            # El Salvador
  nome <- sub("^Département (de l'|de la |des |du )", "", nome)  # Haiti
  nome <- sub(" Department$", "", nome)
  chave <- paste0(iso, "|", nome)
  unname(ifelse(chave %in% names(CORRECOES), CORRECOES[chave], nome))
}

lista <- lapply(isos, baixar_adm1)
falta <- isos[vapply(lista, is.null, TRUE)]
u <- do.call(rbind, Filter(Negate(is.null), lista))
if (length(falta)) {
  # Países sem ADM1 (raro): a unidade é o próprio país, pela união do geoBoundaries ADM0.
  for (iso in falta) {
    meta <- fromJSON(paste0("https://www.geoboundaries.org/api/current/gbOpen/", iso, "/ADM0/"))
    g <- st_make_valid(st_transform(st_read(meta$simplifiedGeometryGeoJSON, quiet = TRUE), 4326))
    u <- rbind(u, st_sf(id = paste0(iso, "-000"), nome = PAISES_LATAM$es[PAISES_LATAM$iso3 == iso], iso3 = iso,
                        fonte = "gbOpen ADM0", geometry = st_union(st_geometry(g))))
  }
}
# Recorta reivindicações antárticas e ilhas muito ao sul (ex.: Tierra del Fuego no geoBoundaries).
u <- suppressWarnings(st_crop(u, st_bbox(c(xmin = -120, ymin = -60, xmax = -25, ymax = 35), crs = st_crs(4326))))
u <- u[!st_is_empty(u), ]
u <- st_cast(u, "MULTIPOLYGON", warn = FALSE)
u$nome <- corrigir_nomes(u$nome, u$iso3)
u$rotulo <- paste0(u$nome, " (", u$iso3, ")")
dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)
saveRDS(u, "dados/brutos/latam_adm1.rds")
message("Unidades: ", nrow(u), " em ", length(unique(u$iso3)), " países")
