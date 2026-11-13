# Atlas de Desigualdade Térmica — desigualdade térmica interna e Gini entre setores
# Executar na raiz do repositório: Rscript R/42_amplitude_gini.R
# Requer: install.packages(c("sf", "jsonlite"))   (e, para o Rio, R/01 já rodado ou a
#         malha de setores do RJ em dados/brutos/RJ_setores_CD2022.gpkg)
#
# Três medidas por área (bairro no município do Rio; município no estado do RJ e no Brasil),
# todas calculadas a partir dos setores censitários de 2022:
#   amp_lst       AMPLITUDE TÉRMICA: temperatura da superfície no percentil 90 menos no
#                 percentil 10 dos moradores (setores ponderados pelos moradores). É a
#                 distância entre "o setor mais quente e o mais ameno" sem depender de um
#                 único setor atípico (mata, galpão industrial, aeroporto).
#   gini_setores  GINI ENTRE SETORES da renda média do responsável, com os setores
#                 ponderados pelo número de responsáveis. Mede a desigualdade de renda
#                 ENTRE os setores (bairros, vizinhanças); ignora a desigualdade dentro de
#                 cada setor e, por isso, fica abaixo do Gini entre pessoas. Até esta
#                 versão, o IBGE não publicou o Gini do Censo 2022 por município.
#   gap_renda     diferença entre os 20% mais pobres e os 20% mais ricos (já existe para
#                 municípios em R/14 e R/22; aqui só para os bairros do Rio, mesmo método)
# e dois mapas bivariados (3 × 3, terços de áreas): amplitude × Gini e diferença
# pobres − ricos × Gini, com o eixo do Gini invertido (magenta = mais desigual nas duas).
# Só áreas com MIN_SETORES setores com dado (30 por município; 20 por bairro do Rio).
# No Rio, cada setor recebe o valor do seu bairro, e os limites dos bairros vão para
# dados/processados/rio/contornos.geojson, desenhados por cima dos setores.
suppressPackageStartupMessages({ library(sf); library(jsonlite) })
source("R/00_publicar_camada.R")
sf_use_s2(FALSE)
ESC <- strsplit(Sys.getenv("ESCALAS", "rio,estado-rj,brasil"), ",")[[1]]

# ---- funções ----
mp <- function(x, w) sum(x * w) / sum(w)
grupos_pond <- function(x, w, k) {
  o <- order(x); meio <- (cumsum(w[o]) - w[o] / 2) / sum(w)
  g <- integer(length(x)); g[o] <- pmin(k, floor(meio * k) + 1L); g
}
quantil_pond <- function(x, w, p) {
  o <- order(x); x <- x[o]; w <- w[o]; meio <- (cumsum(w) - w / 2) / sum(w)
  stats::approx(meio, x, xout = p, rule = 2, ties = "ordered")$y
}
gini_pond <- function(x, w) {
  o <- order(x); x <- x[o]; w <- w[o]
  p <- c(0, cumsum(w) / sum(w)); l <- c(0, cumsum(x * w) / sum(x * w))
  1 - sum(diff(p) * (l[-1] + l[-length(l)]))
}
medidas <- function(s, min_setores) {
  t <- s[is.finite(s$lst) & is.finite(s$moradores) & s$moradores > 0, ]
  r <- s[is.finite(s$renda_media) & is.finite(s$domicilios) & s$domicilios > 0, ]
  tr <- r[is.finite(r$lst), ]
  amp <- if (nrow(t) >= min_setores) quantil_pond(t$lst, t$moradores, 0.9) - quantil_pond(t$lst, t$moradores, 0.1) else NA_real_
  gin <- if (nrow(r) >= min_setores) gini_pond(r$renda_media, r$domicilios) else NA_real_
  gap <- NA_real_
  if (nrow(tr) >= min_setores) { q <- grupos_pond(tr$renda_media, tr$domicilios, 5)
    gap <- mp(tr$lst[q == 1], tr$domicilios[q == 1]) - mp(tr$lst[q == 5], tr$domicilios[q == 5]) }
  c(amp_lst = amp, gini_setores = gin, gap_renda = gap, n = nrow(t))
}
por_area <- function(s, area, min_setores) {
  a <- split(s, s[[area]])
  m <- t(vapply(a, medidas, numeric(4), min_setores = min_setores))
  data.frame(area = names(a), m, row.names = NULL)
}
ler <- function(escala, id, chave) {
  x <- utils::read.csv(file.path("dados/indicadores", escala, paste0(id, ".csv")), colClasses = setNames("character", chave))
  setNames(as.numeric(x[[2]]), x[[1]])
}
relato <- function(nome, m) {
  ok <- is.finite(m$amp_lst) & is.finite(m$gini_setores)
  message(sprintf("%s: %d áreas | com amplitude %d, com Gini %d, com diferença %d | amplitude mediana %.1f °C | Gini mediano %.2f",
                  nome, nrow(m), sum(is.finite(m$amp_lst)), sum(is.finite(m$gini_setores)), sum(is.finite(m$gap_renda)),
                  stats::median(m$amp_lst, na.rm = TRUE), stats::median(m$gini_setores, na.rm = TRUE)))
  r1 <- suppressWarnings(stats::cor(m$amp_lst, m$gini_setores, method = "spearman", use = "complete.obs"))
  r2 <- suppressWarnings(stats::cor(m$gap_renda, m$gini_setores, method = "spearman", use = "complete.obs"))
  message(sprintf("  correlação de Spearman com o Gini: amplitude %.2f | diferença pobres − ricos %.2f", r1, r2))
  o <- order(-m$gini_setores); message("  maiores Gini: ", paste(sprintf("%s %.2f", m$area[o][1:6], m$gini_setores[o][1:6]), collapse = ", "))
  o <- order(-m$amp_lst); message("  maiores amplitudes: ", paste(sprintf("%s %.1f", m$area[o][1:6], m$amp_lst[o][1:6]), collapse = ", "))
  c(amp = r1, gap = r2)
}

# ---- textos ----
TXT <- list(
  amp = list(en = "Temperature range", pt = "Amplitude térmica", es = "Amplitud térmica"),
  camp = list(en = c("Smaller range", "Intermediate range", "Larger range"), pt = c("Amplitude menor", "Amplitude intermediária", "Amplitude maior"),
              es = c("Amplitud menor", "Amplitud intermedia", "Amplitud mayor")),
  gap = list(en = "Poorest − richest fifth", pt = "20% mais pobres − 20% mais ricos", es = "20% más pobre − 20% más rico"),
  cgap = list(en = c("Poorest cooler or equal", "Small gap", "Poorest hotter"), pt = c("Mais pobres menos ou igualmente quentes", "Diferença pequena", "Mais pobres mais quentes"),
              es = c("Más pobres menos o igual de cálidos", "Diferencia pequeña", "Más pobres más cálidos")),
  gini = list(en = "Income Gini between tracts", pt = "Gini da renda entre setores", es = "Gini del ingreso entre sectores"),
  cgini = list(en = c("more unequal", "intermediate inequality", "less unequal"), pt = c("mais desigual", "desigualdade intermediária", "menos desigual"),
               es = c("más desigual", "desigualdad intermedia", "menos desigual")))
ex <- function(ind, rot, cls, unidade, casas) list(indicador = ind, rotulo = rot, classes = cls, unidade = unidade, casas = casas)
MET_AMP <- c(en = "Within each area: surface temperature at the 90th percentile of residents minus the 10th percentile (census tracts weighted by residents); only areas with at least %d tracts with data",
             pt = "Dentro de cada área: temperatura da superfície no percentil 90 dos moradores menos no percentil 10 (setores censitários ponderados pelos moradores); só áreas com pelo menos %d setores com dado",
             es = "Dentro de cada área: temperatura de superficie en el percentil 90 de los residentes menos en el percentil 10 (sectores censales ponderados por residentes); solo áreas con al menos %d sectores con dato")
MET_GINI <- c(en = "Gini index of mean household-head income across census tracts, weighted by household heads (inequality between tracts, not between people: it is lower than the person-level Gini); only areas with at least %d tracts with data",
              pt = "Índice de Gini da renda média do responsável entre os setores censitários, ponderados pelo número de responsáveis (desigualdade entre setores, não entre pessoas: fica abaixo do Gini entre pessoas); só áreas com pelo menos %d setores com dado",
              es = "Índice de Gini del ingreso medio del responsable entre sectores censales, ponderados por el número de responsables (desigualdad entre sectores, no entre personas: es menor que el Gini entre personas); solo áreas con al menos %d sectores con dato")
MET_GAP <- c(en = "Household-weighted mean surface temperature of the poorest fifth of households minus the richest fifth, with fifths formed from the area's own tracts; only areas with at least %d tracts with data",
             pt = "Temperatura média da superfície (ponderada por domicílios) dos 20% de domicílios mais pobres menos a dos 20% mais ricos, com os quintos formados pelos setores da própria área; só áreas com pelo menos %d setores com dado",
             es = "Temperatura media de superficie (ponderada por hogares) del 20% de hogares más pobre menos la del 20% más rico, con quintiles formados por los sectores de la propia área; solo áreas con al menos %d sectores con dato")
fmt <- function(m, n) setNames(lapply(names(m), function(k) sprintf(m[[k]], n)), names(m))
MET_BIV <- function(onde) c(
  en = sprintf("Terciles (of %s, unweighted) of each measure; the Gini axis runs from more to less unequal, so magenta marks %s with both larger heat inequality and larger income inequality", onde$en, onde$en),
  pt = sprintf("Tercis (de %s, sem ponderação) de cada medida; o eixo do Gini vai do mais ao menos desigual, de modo que o magenta marca %s com maior desigualdade térmica e maior desigualdade de renda", onde$pt, onde$pt),
  es = sprintf("Terciles (de %s, sin ponderar) de cada medida; el eje del Gini va de más a menos desigual, de modo que el magenta marca %s con mayor desigualdad térmica y mayor desigualdad de ingreso", onde$es, onde$es))
nota <- function(onde, r) list(
  en = sprintf("Each third groups about one third of the %s. Magenta: larger heat inequality and more unequal income. Rank correlation with the Gini: %s.", onde$en, sub("-", "−", sprintf("%.2f", r))),
  pt = sprintf("Cada terço reúne cerca de um terço dos %s. Magenta: maior desigualdade térmica e renda mais desigual. Correlação (Spearman) com o Gini: %s.", onde$pt, sub("-", "−", sub("\\.", ",", sprintf("%.2f", r)))),
  es = sprintf("Cada tercio agrupa alrededor de un tercio de los %s. Magenta: mayor desigualdad térmica e ingreso más desigual. Correlación (Spearman) con el Gini: %s.", onde$es, sub("-", "−", sub("\\.", ",", sprintf("%.2f", r)))))

#' Indicadores para uma escala. `m` tem as colunas area, amp_lst, gini_setores, gap_renda;
#' `d` é a tabela a salvar (uma linha por unidade do mapa) e `chave` liga d a m.
indicadores_escala <- function(m, d, chave, id, escala, onde, min_setores, fonte, periodo, com_gap, rotulo_area) {
  r <- relato(escala, m)
  k <- match(d[[chave]], m$area)
  d$amp_lst <- m$amp_lst[k]; d$gini_setores <- m$gini_setores[k]
  if (com_gap) d$gap_renda_bairro <- m$gap_renda[k]
  gap_col <- if (com_gap) "gap_renda_bairro" else "gap_renda"
  if (!com_gap) d$gap_renda <- ler(escala, "gap_renda", id)[as.character(d[[id]])]
  # tercis de áreas (cada área conta uma vez, mesmo no Rio, onde a tabela é por setor)
  u <- !duplicated(d[[chave]]) & !is.na(k)
  b1 <- classe_bivariada(d$amp_lst[u], d$gini_setores[u], rep(1, sum(u)), inverso_x = TRUE)
  b2 <- classe_bivariada(d[[gap_col]][u], d$gini_setores[u], rep(1, sum(u)), inverso_x = TRUE)
  d$biv_amp_gini <- b1$classe[match(d[[chave]], d[[chave]][u])]
  d$biv_gap_gini <- b2$classe[match(d[[chave]], d[[chave]][u])]
  message(sprintf("  bivariados: amplitude × Gini %s | diferença × Gini %s",
                  paste(table(factor(b1$classe, 1:9)), collapse = " "), paste(table(factor(b2$classe, 1:9)), collapse = " ")))
  sufixo <- function(x) if (is.null(rotulo_area)) x else setNames(paste0(x, rotulo_area[names(x)]), names(x))
  inds <- list(
    indicador("amp_lst", rotulo = sufixo(c(en = "Heat inequality: hottest vs. coolest tenth of residents", pt = "Desigualdade térmica: 10% mais quentes vs. 10% mais amenos",
                                         es = "Desigualdad térmica: 10% más cálido vs. 10% más templado")),
      unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = 16, fonte = fonte, periodo = periodo,
      metodo = fmt(MET_AMP, min_setores)),
    indicador("gini_setores", rotulo = sufixo(c(en = "Income inequality between tracts (Gini)", pt = "Desigualdade de renda entre setores (Gini)",
                                              es = "Desigualdad de ingreso entre sectores (Gini)")),
      paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 2, ordem = 21,
      fonte = c(en = "IBGE 2022 Census, household-head income by census tract", pt = "IBGE, Censo 2022, rendimento do responsável por setor",
                es = "IBGE, Censo 2022, ingreso del responsable por sector"), periodo = c(en = "2022", pt = "2022", es = "2022"),
      metodo = fmt(MET_GINI, min_setores)),
    indicador_bivariado("biv_amp_gini",
      rotulo = c(en = "Heat inequality × income inequality (bivariate)", pt = "Desigualdade térmica × desigualdade de renda (bivariado)",
                 es = "Desigualdad térmica × desigualdad de ingreso (bivariado)"),
      b = b1, y = ex("amp_lst", TXT$amp, TXT$camp, "°C", 1), x = ex("gini_setores", TXT$gini, TXT$cgini, "", 2),
      nota = nota(onde, r[["amp"]]), ordem = 33, fonte = fonte, metodo = MET_BIV(onde), periodo = periodo),
    indicador_bivariado("biv_gap_gini",
      rotulo = c(en = "Poorest − richest heat gap × income inequality (bivariate)", pt = "Diferença térmica pobres − ricos × desigualdade de renda (bivariado)",
                 es = "Diferencia térmica pobres − ricos × desigualdad de ingreso (bivariado)"),
      b = b2, y = ex(gap_col, TXT$gap, TXT$cgap, "°C", 1), x = ex("gini_setores", TXT$gini, TXT$cgini, "", 2),
      nota = nota(onde, r[["gap"]]), ordem = 34, fonte = fonte, metodo = MET_BIV(onde), periodo = periodo))
  if (com_gap) inds <- c(inds, list(
    indicador("gap_renda_bairro", rotulo = sufixo(c(en = "Heat gap: poorest − richest fifth", pt = "Desigualdade térmica: 20% mais pobres − 20% mais ricos",
                                                  es = "Brecha térmica: 20% más pobre − 20% más rico")),
      unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1, ordem = 15, quebras = c(-2, -0.5, 0.5, 2),
      fonte = fonte, periodo = periodo, metodo = fmt(MET_GAP, min_setores))))
  salvar_indicadores(d, escala = escala, id = id, indicadores = inds)
}
# ---- Rio: bairros ----
if ("rio" %in% ESC) {
  gp <- "dados/brutos/RJ_setores_CD2022.gpkg"
  if (!file.exists(gp)) source("R/01_importar_ibge.R", local = new.env())
  malha <- st_read(gp, layer = st_layers(gp)$name[1], quiet = TRUE)
  names(malha)[names(malha) != attr(malha, "sf_column")] <- toupper(names(malha)[names(malha) != attr(malha, "sf_column")])
  malha <- malha[as.character(malha$CD_MUN) == "3304557", ]
  stopifnot("NM_BAIRRO" %in% names(malha))
  bairro <- tapply(as.character(malha$NM_BAIRRO), as.character(malha$CD_SETOR), `[`, 1)
  cs <- utils::read.csv("dados/indicadores/estado-rj-setores/censo.csv", colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
  cs <- cs[cs$CD_MUN == "3304557", ]
  lst <- ler("rio", "lst_verao", "CD_SETOR")          # Landsat 30 m, mediana por setor (R/03)
  cs$lst <- lst[cs$CD_SETOR]; cs$bairro <- bairro[cs$CD_SETOR]
  message("Rio: ", length(unique(cs$bairro[!is.na(cs$bairro)])), " bairros; setores sem bairro: ", sum(is.na(cs$bairro)))
  m <- por_area(cs[!is.na(cs$bairro), ], "bairro", 20)
  d <- data.frame(CD_SETOR = sort(unique(c(names(lst), as.character(malha$CD_SETOR))))); d$bairro <- bairro[d$CD_SETOR]
  onde <- list(en = "neighbourhoods", pt = "bairros", es = "barrios")
  indicadores_escala(m, d, "bairro", "CD_SETOR", "rio", onde, 20,
    fonte = c(en = "Landsat 8–9 (USGS); IBGE 2022 Census (tracts and neighbourhoods)", pt = "Landsat 8–9 (USGS); IBGE, Censo 2022 (setores e bairros)",
              es = "Landsat 8–9 (USGS); IBGE, Censo 2022 (sectores y barrios)"),
    periodo = c(en = "Summers 2022/23–2024/25; 2022 Census", pt = "Verões 2022/23–2024/25; Censo 2022", es = "Veranos 2022/23–2024/25; Censo 2022"),
    com_gap = TRUE, rotulo_area = c(en = " (by neighbourhood)", pt = " (por bairro)", es = " (por barrio)"))
  o <- order(-m$gap_renda); message("  bairros com maior diferença pobres − ricos: ",
    paste(sprintf("%s %.1f", m$area[o][1:8], m$gap_renda[o][1:8]), collapse = ", "))
  gravar_contornos(malha, "NM_BAIRRO", "dados/processados/rio/contornos.geojson", 15, 31983, area_min = 1e3)
  source("R/10_publicar_rio.R", local = new.env())
}

# ---- Estado do RJ: municípios ----
if ("estado-rj" %in% ESC) {
  cs <- utils::read.csv("dados/indicadores/estado-rj-setores/censo.csv", colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
  lst <- utils::read.csv("dados/indicadores/estado-rj-setores/lst_verao.csv", colClasses = c(CD_SETOR = "character"))
  cs$lst <- lst$lst_verao[match(cs$CD_SETOR, lst$CD_SETOR)]
  m <- por_area(cs, "CD_MUN", 30)
  d <- data.frame(code_muni = sort(unique(cs$CD_MUN))); d$mun <- d$code_muni
  onde <- list(en = "municipalities", pt = "municípios", es = "municipios")
  indicadores_escala(m, d, "mun", "code_muni", "estado-rj", onde, 30,
    fonte = c(en = "Landsat 8–9 (USGS); IBGE 2022 Census", pt = "Landsat 8–9 (USGS); IBGE, Censo 2022", es = "Landsat 8–9 (USGS); IBGE, Censo 2022"),
    periodo = c(en = "Summers 2022/23–2024/25; 2022 Census", pt = "Verões 2022/23–2024/25; Censo 2022", es = "Veranos 2022/23–2024/25; Censo 2022"),
    com_gap = FALSE, rotulo_area = NULL)
  source("R/15_publicar_estado_rj.R", local = new.env())
}

# ---- Brasil: municípios ----
if ("brasil" %in% ESC) {
  cs <- utils::read.csv("dados/indicadores/brasil-setores/censo.csv.gz", colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
  lst <- utils::read.csv("dados/indicadores/brasil-setores/lst_modis.csv.gz", colClasses = c(CD_SETOR = "character"))
  cs$lst <- lst$lst_quente[match(cs$CD_SETOR, lst$CD_SETOR)]
  m <- por_area(cs, "CD_MUN", 30)
  d <- data.frame(code_muni = sort(unique(cs$CD_MUN))); d$mun <- d$code_muni
  onde <- list(en = "municipalities", pt = "municípios", es = "municipios")
  indicadores_escala(m, d, "mun", "code_muni", "brasil", onde, 30,
    fonte = c(en = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE 2022 Census", pt = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022", es = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022"),
    periodo = c(en = "Hottest three months, 2022–2024; 2022 Census", pt = "Três meses mais quentes, 2022–2024; Censo 2022", es = "Tres meses más cálidos, 2022–2024; Censo 2022"),
    com_gap = FALSE, rotulo_area = NULL)
  source("R/23_publicar_brasil.R", local = new.env())
}
