# Atlas de Desigualdade Térmica — América Latina: desigualdade térmica por renda DENTRO das cidades
# Executar na raiz do repositório: Rscript R/33_renda_latam.R
# Requer: install.packages(c("sf", "terra", "rstac", "jsonlite", "exactextractr", "readxl"))
# Depende de: R/30 (unidades ADM1), R/31 (paises.json); downloads em dados/brutos/{mex,col}
#
# Não existe uma medida de renda por bairro comparável entre países. Usamos, em cada país,
# a melhor medida socioeconômica oficial por pequena área urbana, e comparamos sempre
# dentro do mesmo município, para não confundir desigualdade com clima regional:
#   BRA  renda média do responsável (Censo 2022), setores urbanos         — IBGE
#   MEX  índice de marginação urbana 2020 por AGEB urbana (Censo 2020)    — CONAPO + INEGI
#   COL  índice de pobreza multidimensional por manzana (CNPV 2018)       — DANE
# Temperatura: MODIS/Aqua, trimestre mais quente de cada pixel, 2022–2024 (mesmo método
# de R/21 e R/31). No Brasil, reaproveita dados/indicadores/brasil-setores/lst_modis.csv.gz.
#
# Para cada pequena área: d = temperatura − média do seu município (ponderada pela população);
# quintos socioeconômicos dentro do município (ponderados pela população; Q1 = mais pobres).
# Diferença = média de d no Q1 − média de d no Q5. Só municípios com >= 20 áreas.
# Validação: município do Rio (Censo + MODIS) deve dar ~ +3,6 °C; Landsat 30 m deu +3,0 °C.
#
# Saídas: indicador america-latina/gap_renda_cidade (por ADM1);
#         dados/processados/america-latina/renda_paises.json (fundido em paises.json).
# Variável de ambiente: PAISES_RENDA=BRA,MEX,COL (padrão: todos os disponíveis).
suppressPackageStartupMessages({ library(sf); library(terra); library(jsonlite); library(exactextractr) })
source("R/00_publicar_camada.R")
source("R/00_modis.R")
source("R/00_paises_latam.R")
sf_use_s2(FALSE)
set.seed(2020)
MIN_AREAS <- 20
DIR_PROC <- "dados/processados/america-latina"
if (!file.exists("dados/brutos/latam_adm1.rds")) source("R/30_unidades_latam.R", local = new.env())
u <- readRDS("dados/brutos/latam_adm1.rds")
lim <- strsplit(Sys.getenv("PAISES_RENDA", "BRA,MEX,COL"), ",")[[1]]
mp <- function(v, w) { k <- is.finite(v) & is.finite(w) & w > 0; if (!any(k)) NA_real_ else sum(v[k] * w[k]) / sum(w[k]) }
t0 <- Sys.time()
minutos <- function() sprintf("%.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))

# ---- temperatura MODIS para México e Colômbia (tiles em cache de R/31) ----
modis_vrt <- function(isos) {
  area <- u[u$iso3 %in% isos, ]
  tl <- modis_tiles(area)
  pasta <- "dados/brutos/modis-latam"; dir.create(pasta, recursive = TRUE, showWarnings = FALSE)
  arqs <- unlist(lapply(names(tl$tiles), function(n) modis_processar(n, tl$tiles[[n]], tl$doc, pasta)))
  vrt(arqs, file.path(pasta, paste0("renda_", paste(isos, collapse = "_"), ".vrt")), overwrite = TRUE)
}
# ADM1 por ponto (ponto interno de cada pequena área)
adm1_de <- function(geom, iso) {
  ui <- u[u$iso3 == iso, ]
  p <- suppressWarnings(st_point_on_surface(st_transform(st_make_valid(geom), 4326)))
  i <- st_intersects(p, ui)
  vapply(i, function(z) if (length(z)) ui$id[z[1]] else NA_character_, "")
}

areas <- list()

# ---- Brasil: setores urbanos, renda do responsável ----
if ("BRA" %in% lim) {
  cc <- c(CD_SETOR = "character", CD_MUN = "character")
  ce <- read.csv(gzfile("dados/indicadores/brasil-setores/censo.csv.gz"), colClasses = cc)
  ls <- read.csv(gzfile("dados/indicadores/brasil-setores/lst_modis.csv.gz"), colClasses = c(CD_SETOR = "character"))
  b <- merge(ce, ls, by = "CD_SETOR")
  arv <- b[, c("arv_sem", "arv_1_2", "arv_3_4", "arv_5")]
  # A pesquisa do entorno (arborização) só cobre setores urbanos: serve de marcador de área urbana.
  urb <- rowSums(arv, na.rm = TRUE) > 0
  message(sprintf("BRA: %d setores com temperatura; %.0f%% urbanos (com pesquisa do entorno)", nrow(b), 100 * mean(urb)))
  b <- b[urb, ]
  uf_nome <- c("11" = "Rondônia", "12" = "Acre", "13" = "Amazonas", "14" = "Roraima", "15" = "Pará", "16" = "Amapá",
               "17" = "Tocantins", "21" = "Maranhão", "22" = "Piauí", "23" = "Ceará", "24" = "Rio Grande do Norte",
               "25" = "Paraíba", "26" = "Pernambuco", "27" = "Alagoas", "28" = "Sergipe", "29" = "Bahia",
               "31" = "Minas Gerais", "32" = "Espírito Santo", "33" = "Rio de Janeiro", "35" = "São Paulo",
               "41" = "Paraná", "42" = "Santa Catarina", "43" = "Rio Grande do Sul", "50" = "Mato Grosso do Sul",
               "51" = "Mato Grosso", "52" = "Goiás", "53" = "Distrito Federal")
  ub <- u[u$iso3 == "BRA", ]
  id_uf <- setNames(ub$id[match(uf_nome, ub$nome)], names(uf_nome))
  if (anyNA(id_uf)) message("  UFs sem unidade correspondente: ", paste(uf_nome[is.na(id_uf)], collapse = ", "))
  areas$BRA <- data.frame(iso3 = "BRA", area = b$CD_SETOR, mun = b$CD_MUN, id = unname(id_uf[substr(b$CD_MUN, 1, 2)]),
                          pop = b$moradores, ses = b$renda_media, lst = b$lst_quente)
}

# ---- México: AGEB urbanas, índice de marginação urbana (CONAPO) ----
if ("MEX" %in% lim) {
  imu <- as.data.frame(readxl::read_excel("dados/brutos/mex/IMU_2020.xls", sheet = "IMU_2020"))
  zipm <- "dados/brutos/mex/mg_2020_integrado.zip"
  lista <- unzip(zipm, list = TRUE)$Name
  shp <- grep("(^|/)00a\\.(shp|shx|dbf|prj|cpg)$", lista, value = TRUE, useBytes = TRUE)
  unzip(zipm, files = shp, exdir = "dados/brutos/mex", junkpaths = TRUE)
  g <- st_read("dados/brutos/mex/00a.shp", quiet = TRUE)
  g <- g[g$CVEGEO %in% imu$CVE_AGEB, ]
  message(sprintf("MEX: %d AGEB no índice, %d com geometria (%s)", nrow(imu), nrow(g), minutos()))
  r <- modis_vrt("MEX")[[1]]
  g$lst <- exact_extract(r, st_transform(g, crs(r)), "mean", progress = FALSE)
  m <- imu[match(g$CVEGEO, imu$CVE_AGEB), ]
  nm <- unique(data.frame(k = paste("MEX", substr(imu$CVE_AGEB, 1, 5)),
                          n = ifelse(sprintf("%02d", as.integer(imu$ENT)) == "09", paste0(imu$NOM_MUN, " (CDMX)"), imu$NOM_MUN)))
  nomes_mex <- setNames(nm$n, nm$k)
  areas$MEX <- data.frame(iso3 = "MEX", area = g$CVEGEO, mun = substr(g$CVEGEO, 1, 5), id = adm1_de(st_geometry(g), "MEX"),
                          pop = as.numeric(m$POB_TOTAL), ses = as.numeric(m$IM_2020),   # maior = menos marginalizado
                          lst = g$lst)
  rm(g); gc()
  message("MEX: temperatura extraída (", minutos(), ")")
}

# ---- Colômbia: manzanas das cabeceras, pobreza multidimensional (DANE) ----
if ("COL" %in% lim) {
  pc <- "dados/brutos/col"
  unzip(file.path(pc, "SHP_VULNRB_IPMxMZ.zip"), exdir = pc, junkpaths = TRUE)
  g <- st_read(file.path(pc, "VULNRB_IPMxMZ.shp"), quiet = TRUE)
  g <- g[is.finite(g$ipm), ]
  # População por manzana: MGN 2018 integrado com o Censo (só a tabela .dbf)
  lm <- unzip(file.path(pc, "SHP_MGN2018_INTGRD_MANZ.zip"), list = TRUE)$Name
  dbf <- grep("\\.dbf$", lm, value = TRUE)[1]
  unzip(file.path(pc, "SHP_MGN2018_INTGRD_MANZ.zip"), files = dbf, exdir = pc, junkpaths = TRUE)
  mz <- foreign::read.dbf(file.path(pc, basename(dbf)), as.is = TRUE)
  chave <- names(mz)[vapply(mz, function(v) mean(as.character(v)[seq_len(min(2000, length(v)))] %in% g$COD_DANE) > 0.5, TRUE)][1]
  message("COL: ", nrow(g), " manzanas com IPM; chave no MGN: ", chave, "; colunas: ", paste(head(names(mz), 40), collapse = " "))
  pop <- as.numeric(mz$TP27_PERSO[match(g$COD_DANE, mz[[chave]])])
  message(sprintf("COL: população encontrada para %.0f%% das manzanas (%.1f mi pessoas)", 100 * mean(is.finite(pop)), sum(pop, na.rm = TRUE) / 1e6))
  r <- modis_vrt("COL")[[1]]
  pts <- suppressWarnings(st_point_on_surface(st_make_valid(st_geometry(g))))
  lst <- terra::extract(r, vect(st_transform(pts, crs(r))))[[2]]
  areas$COL <- data.frame(iso3 = "COL", area = g$COD_DANE, mun = g$COD_MPIO, id = adm1_de(pts, "COL"),
                          pop = pop, ses = -as.numeric(g$ipm),   # menos pobreza = mais rico
                          lst = lst)
  rm(g, mz); gc()
  message("COL: temperatura extraída (", minutos(), ")")
}

# ---- diferença dentro das cidades ----
a <- do.call(rbind, areas); rm(areas)
a <- a[is.finite(a$pop) & a$pop > 0 & is.finite(a$ses) & is.finite(a$lst), ]
cont <- table(paste(a$iso3, a$mun)); a <- a[paste(a$iso3, a$mun) %in% names(cont)[cont >= MIN_AREAS], ]
a <- do.call(rbind, lapply(split(a, paste(a$iso3, a$mun)), function(s) {
  s$d <- s$lst - mp(s$lst, s$pop)
  o <- order(s$ses); cum <- cumsum(s$pop[o]) / sum(s$pop)
  q <- integer(nrow(s)); q[o] <- pmin(5L, pmax(1L, as.integer(ceiling(cum * 5 - 1e-9))))
  s$q <- q; s
}))
gap_de <- function(s) if (sum(s$q == 1) >= 10 && sum(s$q == 5) >= 10)
  mp(s$d[s$q == 1], s$pop[s$q == 1]) - mp(s$d[s$q == 5], s$pop[s$q == 5]) else NA_real_
# referência sem controle de município (quintos nacionais): mostra o quanto o clima regional pesa
gap_nacional <- function(s) {
  o <- order(s$ses); cum <- cumsum(s$pop[o]) / sum(s$pop); q <- integer(nrow(s)); q[o] <- pmin(5L, pmax(1L, as.integer(ceiling(cum * 5 - 1e-9))))
  mp(s$lst[q == 1], s$pop[q == 1]) - mp(s$lst[q == 5], s$pop[q == 5])
}
# As maiores cidades de cada país (pela população das áreas analisadas), com nome
NOMES_MUN <- c(
  "BRA 3550308" = "São Paulo", "BRA 3304557" = "Rio de Janeiro", "BRA 5300108" = "Brasília", "BRA 2304400" = "Fortaleza",
  "BRA 2927408" = "Salvador", "BRA 3106200" = "Belo Horizonte", "BRA 1302603" = "Manaus", "BRA 4106902" = "Curitiba",
  "BRA 2611606" = "Recife", "BRA 5208707" = "Goiânia", "BRA 1501402" = "Belém", "BRA 4314902" = "Porto Alegre",
  "COL 11001" = "Bogotá", "COL 05001" = "Medellín", "COL 76001" = "Cali", "COL 08001" = "Barranquilla",
  "COL 13001" = "Cartagena", "COL 54001" = "Cúcuta", "COL 25754" = "Soacha", "COL 68001" = "Bucaramanga",
  "COL 08758" = "Soledad", "COL 05088" = "Bello", "COL 50001" = "Villavicencio", "COL 73001" = "Ibagué")
if (exists("nomes_mex")) NOMES_MUN <- c(NOMES_MUN, nomes_mex)
chave_mun <- paste(a$iso3, a$mun)
pop_mun <- tapply(a$pop, chave_mun, sum)
cidades <- lapply(split(names(pop_mun), sub(" .*", "", names(pop_mun))), function(ch) {
  ch <- ch[ch %in% names(NOMES_MUN)]
  ch <- head(ch[order(-pop_mun[ch])], 6)
  lapply(ch, function(k) { s <- a[chave_mun == k, ]
    list(nome = unname(NOMES_MUN[k]), gap = round(gap_de(s), 2), pop = round(sum(s$pop)), areas = nrow(s)) })
})
message("Maiores cidades (dentro do município; validação: Rio de Janeiro ~ +3 °C):")
for (iso in names(cidades)) for (c in cidades[[iso]]) message(sprintf("  %s %-26s %+.2f °C (%d áreas, %.1f mi)", iso, c$nome, c$gap, c$areas, c$pop / 1e6))

uni <- do.call(rbind, lapply(split(a, a$id), function(s) data.frame(id = s$id[1], gap_renda_cidade = round(gap_de(s), 2),
                                                                      areas = nrow(s))))
uni$gap_renda_cidade[uni$areas < 50] <- NA
message("Unidades com diferença: ", sum(is.finite(uni$gap_renda_cidade)), " | positivas (mais pobres mais quentes): ",
        sum(uni$gap_renda_cidade > 0, na.rm = TRUE))

medida <- list(
  BRA = list(en = "household-head income (2022 Census, urban tracts)", pt = "renda do responsável (Censo 2022, setores urbanos)",
             es = "ingreso del responsable del hogar (Censo 2022, sectores urbanos)"),
  MEX = list(en = "urban marginalisation index (CONAPO 2020, urban AGEB)", pt = "índice de marginação urbana (CONAPO 2020, AGEB urbanas)",
             es = "índice de marginación urbana (CONAPO 2020, AGEB urbanas)"),
  COL = list(en = "multidimensional poverty (DANE, 2018 Census, urban blocks)", pt = "pobreza multidimensional (DANE, Censo 2018, quarteirões urbanos)",
             es = "pobreza multidimensional (DANE, Censo 2018, manzanas urbanas)"))
renda <- lapply(split(a, a$iso3), function(s) {
  # somas por município: a reamostragem (bootstrap por município) só soma linhas
  pm <- do.call(rbind, lapply(split(s, s$mun), function(z) c(
    s1 = sum((z$d * z$pop)[z$q == 1]), w1 = sum(z$pop[z$q == 1]), n1 = sum(z$q == 1),
    s5 = sum((z$d * z$pop)[z$q == 5]), w5 = sum(z$pop[z$q == 5]), n5 = sum(z$q == 5))))
  gp <- function(m) { t <- colSums(m); if (t["n1"] < 10 || t["n5"] < 10) NA_real_ else unname(t["s1"] / t["w1"] - t["s5"] / t["w5"]) }
  bs <- replicate(500, gp(pm[sample(nrow(pm), replace = TRUE), , drop = FALSE]))
  list(gap = round(gp(pm), 2), ic95 = round(unname(quantile(bs, c(0.025, 0.975), na.rm = TRUE)), 2),
       gap_nacional = round(gap_nacional(s), 2), areas = nrow(s), municipios = nrow(pm),
       pop = round(sum(s$pop)), medida = medida[[s$iso3[1]]], cidades = cidades[[s$iso3[1]]])
})
for (iso in names(renda)) with(renda[[iso]], message(sprintf("%s: dentro das cidades %+.2f °C (IC95 %+.2f a %+.2f) | sem controle %+.2f | %d áreas, %d municípios, %.1f mi pessoas",
                                                            iso, gap, ic95[1], ic95[2], gap_nacional, areas, municipios, pop / 1e6)))
write_json(renda, file.path(DIR_PROC, "renda_paises.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
# funde em paises.json (R/31 faz o mesmo quando roda depois)
pj <- file.path(DIR_PROC, "paises.json")
if (file.exists(pj)) {
  P <- read_json(pj)
  P$paises <- lapply(P$paises, function(p) { p$renda <- renda[[p$iso3]]; p })
  write_json(P, pj, auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null", null = "null")
}

fonte <- c(en = "IBGE 2022 Census; CONAPO/INEGI 2020; DANE 2018 Census; MODIS/Aqua MYD11A2 v6.1 (NASA)",
           pt = "IBGE Censo 2022; CONAPO/INEGI 2020; DANE Censo 2018; MODIS/Aqua MYD11A2 v6.1 (NASA)",
           es = "IBGE Censo 2022; CONAPO/INEGI 2020; DANE Censo 2018; MODIS/Aqua MYD11A2 v6.1 (NASA)")
salvar_indicadores(uni, escala = "america-latina", id = "id", indicadores = list(
  indicador("gap_renda_cidade",
    rotulo = c(en = "Heat inequality within cities: poorest fifth minus richest fifth", pt = "Desigualdade térmica dentro das cidades: quinto mais pobre menos o mais rico",
               es = "Desigualdad térmica dentro de las ciudades: quintil más pobre menos el más rico"),
    unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1, ordem = 13, quebras = c(-2, -0.5, 0.5, 2), fonte = fonte,
    periodo = c(en = "Hottest three months of each place, 2022–2024; censuses 2018–2022", pt = "Três meses mais quentes de cada lugar, 2022–2024; censos de 2018 a 2022",
                es = "Tres meses más cálidos de cada lugar, 2022–2024; censos de 2018 a 2022"),
    metodo = c(en = "Small urban areas ranked into fifths within their own municipality by the best official socioeconomic measure of each country (Brazil: household-head income; Mexico: urban marginalisation index; Colombia: multidimensional poverty). Difference in MODIS surface temperature (deviation from the municipal mean) between the poorest and richest fifth, weighted by population. Only Brazil, Mexico and Colombia so far",
               pt = "Pequenas áreas urbanas ordenadas em quintos dentro do próprio município pela melhor medida socioeconômica oficial de cada país (Brasil: renda do responsável; México: índice de marginação urbana; Colômbia: pobreza multidimensional). Diferença de temperatura da superfície MODIS (desvio em relação à média do município) entre o quinto mais pobre e o mais rico, ponderada pela população. Por enquanto só Brasil, México e Colômbia",
               es = "Pequeñas áreas urbanas ordenadas en quintiles dentro de su propio municipio según la mejor medida socioeconómica oficial de cada país (Brasil: ingreso del responsable; México: índice de marginación urbana; Colombia: pobreza multidimensional). Diferencia de temperatura de superficie MODIS (desvío respecto a la media municipal) entre el quintil más pobre y el más rico, ponderada por población. Por ahora solo Brasil, México y Colombia"))
))
source("R/32_publicar_latam.R")
message("Concluído (", minutos(), ")")
