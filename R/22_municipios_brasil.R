# Atlas de Desigualdade Térmica — indicadores municipais do Brasil
# Executar na raiz do repositório: Rscript R/22_municipios_brasil.R
# Requer: install.packages("jsonlite")
# Depende de: R/20 (Censo por setor) e R/21 (temperatura MODIS por setor).
# Mesma lógica de R/14 (estado do RJ), com a temperatura do trimestre mais quente (MODIS).
#
# Os indicadores municipais são AGREGADOS DOS SETORES, ponderados pelas pessoas:
#   lst_pop          temperatura média da superfície no verão onde vivem os moradores
#                    (média dos setores ponderada por moradores) — não é média da área,
#                    que seria dominada por florestas e áreas rurais
#   lst_dif_uf       lst_pop menos o valor do estado (UF) a que o município pertence
#   renda_media_resp renda média dos responsáveis (média dos setores ponderada por responsáveis)
#   arv_com_arvores  % dos moradores observados em faces de quadra com árvores
#   pop_preta_parda, pop_60mais  % dos moradores
#   gap_renda        DESIGUALDADE INTERNA: temperatura dos 20% de domicílios mais pobres
#                    menos a dos 20% mais ricos, dentro do município (quintos ponderados
#                    por domicílios). Só municípios com >= MIN_SETORES setores com dados.
#   gap_cor          temperatura de pretos e pardos menos a de brancos, dentro do município
#                    (só se cada grupo tiver >= MIN_PESSOAS pessoas em setores com dado)
#
# Também grava os resumos NACIONAIS (todos os setores do país) nos mesmos
# formatos dos painéis do município do Rio:
#   dados/processados/brasil/{calor_renda, arborizacao_resumo, exposicao_grupos}.json
# e republica a camada (R/23_publicar_brasil.R).

suppressPackageStartupMessages({ library(jsonlite) })
source("R/00_publicar_camada.R")
set.seed(2022)
MIN_SETORES <- 30
MIN_PESSOAS <- 2000
DIR <- "dados/indicadores/brasil-setores"

censo <- utils::read.csv(gzfile(file.path(DIR, "censo.csv.gz")), colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
lst <- utils::read.csv(gzfile(file.path(DIR, "lst_modis.csv.gz")), colClasses = c(CD_SETOR = "character"))
lst$lst_verao <- lst$lst_quente   # mesmo nome de coluna dos scripts do RJ: aqui, o trimestre mais quente
d <- merge(censo, lst[, c("CD_SETOR", "lst_verao")], by = "CD_SETOR", all.x = TRUE)
d$UF <- substr(d$CD_MUN, 1, 2)
d$arv_obs <- with(d, arv_sem + arv_1_2 + arv_3_4 + arv_5)
d$arv_com <- with(d, arv_1_2 + arv_3_4 + arv_5)
d$preta_parda <- d$preta + d$parda
message("Setores: ", nrow(d), " | com temperatura: ", sum(is.finite(d$lst_verao)))

mp <- function(v, w) { k <- is.finite(v) & is.finite(w) & w > 0; if (!any(k)) return(NA_real_); sum(v[k] * w[k]) / sum(w[k]) }
razao <- function(a, b) { k <- is.finite(a) & is.finite(b); if (!any(k) || sum(b[k]) == 0) return(NA_real_); 100 * sum(a[k]) / sum(b[k]) }
grupos_pond <- function(x, w, k) {
  o <- order(x); meio <- (cumsum(w[o]) - w[o] / 2) / sum(w)
  g <- integer(length(x)); g[o] <- pmin(k, floor(meio * k) + 1L); g
}
gap_q <- function(s) {
  s <- s[is.finite(s$lst_verao) & is.finite(s$renda_media) & is.finite(s$domicilios) & s$domicilios > 0, ]
  if (nrow(s) < MIN_SETORES) return(NA_real_)
  q <- grupos_pond(s$renda_media, s$domicilios, 5)
  mp(s$lst_verao[q == 1], s$domicilios[q == 1]) - mp(s$lst_verao[q == 5], s$domicilios[q == 5])
}
gap_c <- function(s) {
  s <- s[is.finite(s$lst_verao), ]
  if (sum(s$preta_parda, na.rm = TRUE) < MIN_PESSOAS || sum(s$branca, na.rm = TRUE) < MIN_PESSOAS) return(NA_real_)
  mp(s$lst_verao, s$preta_parda) - mp(s$lst_verao, s$branca)
}

estado_lst <- mp(d$lst_verao, d$moradores)
mun <- do.call(rbind, lapply(split(d, d$CD_MUN), function(s) data.frame(
  code_muni = s$CD_MUN[1],
  setores = nrow(s), setores_lst = sum(is.finite(s$lst_verao)),
  moradores = sum(s$moradores, na.rm = TRUE),
  lst_pop = mp(s$lst_verao, s$moradores),
  renda_media_resp = mp(s$renda_media, s$domicilios),
  arv_com_arvores = razao(s$arv_com, s$arv_obs),
  pop_preta_parda = razao(s$preta_parda, s$moradores),
  pop_60mais = razao(s$a60, s$moradores),
  gap_renda = gap_q(s),
  gap_cor = gap_c(s)
)))
uf_lst <- vapply(split(d, d$UF), function(s) mp(s$lst_verao, s$moradores), 0)
mun$lst_dif_uf <- mun$lst_pop - uf_lst[substr(mun$code_muni, 1, 2)]
num <- sapply(mun, is.numeric); mun[num] <- lapply(mun[num], function(v) round(v, 2))
stopifnot(nrow(mun) >= 5560)
message(sprintf("Brasil: %.2f °C onde vivem os moradores | municípios com desigualdade interna por renda: %d, por cor: %d",
                estado_lst, sum(is.finite(mun$gap_renda)), sum(is.finite(mun$gap_cor))))
o <- order(-mun$gap_renda); message("Maiores diferenças internas (mais pobres − mais ricos, °C):")
for (i in utils::head(o[is.finite(mun$gap_renda[o])], 10)) message(sprintf("  %s  %.2f  (%d setores)", mun$code_muni[i], mun$gap_renda[i], mun$setores_lst[i]))

# ---- resumos estaduais (mesmos formatos dos painéis do Rio) ----
dir.create("dados/processados/brasil", recursive = TRUE, showWarnings = FALSE)
gj <- function(x, f) write_json(x, file.path("dados/processados/brasil", f), auto_unbox = TRUE, pretty = TRUE, digits = NA)

a <- d[is.finite(d$lst_verao) & is.finite(d$renda_media) & is.finite(d$domicilios) & d$domicilios > 0, ]
a$q <- grupos_pond(a$renda_media, a$domicilios, 5)
quintos <- lapply(1:5, function(q) { s <- a[a$q == q, ]; list(quinto = q, setores = nrow(s), domicilios = sum(s$domicilios),
  renda_min = round(min(s$renda_media)), renda_max = round(max(s$renda_media)), lst_media = round(mp(s$lst_verao, s$domicilios), 2)) })
dif <- quintos[[1]]$lst_media - quintos[[5]]$lst_media
boot <- replicate(500, { b <- a[sample.int(nrow(a), replace = TRUE), ]; b$q <- grupos_pond(b$renda_media, b$domicilios, 5)
  mp(b$lst_verao[b$q == 1], b$domicilios[b$q == 1]) - mp(b$lst_verao[b$q == 5], b$domicilios[b$q == 5]) })
gj(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), escopo = "Brasil, todos os setores",
        setores_usados = nrow(a), domicilios_usados = sum(a$domicilios), quintos = quintos,
        diferenca_q1_q5 = round(dif, 2), ic95 = round(stats::quantile(boot, c(.025, .975), names = FALSE), 2),
        bootstrap = 500, spearman_setores = round(stats::cor(a$lst_verao, a$renda_media, method = "spearman"), 3)),
   "calor_renda.json")
message(sprintf("Brasil — quintos de renda (°C): %s | Q1−Q5 = %.2f", paste(sapply(quintos, `[[`, "lst_media"), collapse = " / "), dif))

b <- d[is.finite(d$arv_obs) & d$arv_obs >= 20, ]; b$pct <- 100 * b$arv_com / b$arv_obs; b$pct5 <- 100 * b$arv_5 / b$arv_obs
br <- b[is.finite(b$renda_media) & is.finite(b$domicilios) & b$domicilios > 0, ]; br$q <- grupos_pond(br$renda_media, br$domicilios, 5)
bl <- b[is.finite(b$lst_verao), ]; bl$q <- grupos_pond(bl$pct5 + bl$pct / 1000, bl$arv_obs, 5)
gj(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), escopo = "Brasil, todos os setores",
        cidade_com_arvores = round(razao(b$arv_com, b$arv_obs), 1),
        por_quinto_de_renda = lapply(1:5, function(q) { s <- br[br$q == q, ]; list(quinto = q, domicilios = sum(s$domicilios),
          arv_com_arvores = round(mp(s$pct, s$domicilios), 1), arv_5mais = round(mp(s$pct5, s$domicilios), 1)) }),
        por_quinto_de_arborizacao = lapply(1:5, function(q) { s <- bl[bl$q == q, ]; list(quinto = q, moradores = sum(s$arv_obs),
          arv_5mais_min = round(min(s$pct5), 1), arv_5mais_max = round(max(s$pct5), 1), lst_media = round(mp(s$lst_verao, s$arv_obs), 2)) })),
   "arborizacao_resumo.json")

d$pct_arv <- ifelse(is.finite(d$arv_obs) & d$arv_obs >= 20, 100 * d$arv_com / d$arv_obs, NA)
gr <- c("moradores", "branca", "preta", "parda", "preta_parda", "a60", "a0_4")
k <- which(is.finite(d$lst_verao))
dif_c <- mp(d$lst_verao, d$preta_parda) - mp(d$lst_verao, d$branca)
bc <- replicate(500, { s <- sample(k, replace = TRUE); mp(d$lst_verao[s], d$preta_parda[s]) - mp(d$lst_verao[s], d$branca[s]) })
gj(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), escopo = "Brasil, todos os setores",
        grupos = lapply(gr, function(g) list(grupo = g, pessoas = round(sum(d[[g]][k], na.rm = TRUE)),
          lst_media = round(mp(d$lst_verao, d[[g]]), 2), arv_com_arvores = round(mp(d$pct_arv, d[[g]]), 1))),
        diferenca_preta_parda_branca = round(dif_c, 2), ic95 = round(stats::quantile(bc, c(.025, .975), names = FALSE), 2),
        bootstrap = 500, diferenca_arvores_pp = round(mp(d$pct_arv, d$preta_parda) - mp(d$pct_arv, d$branca), 1)),
   "exposicao_grupos.json")
message(sprintf("Brasil — pretos e pardos − brancos: %.2f °C", dif_c))

# ---- indicadores municipais ----
fonte_lst <- c(en = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE 2022 Census", pt = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022", es = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022")
fonte_censo <- c(en = "IBGE, 2022 Census (tract aggregates)", pt = "IBGE, Censo 2022 (agregados por setor)", es = "IBGE, Censo 2022 (agregados por sector)")
per_lst <- c(en = "Hottest three months of each place, 2022–2024 (early afternoon)", pt = "Três meses mais quentes de cada lugar, 2022–2024 (início da tarde)", es = "Tres meses más cálidos de cada lugar, 2022–2024 (primera hora de la tarde)")
per22 <- c(en = "2022", pt = "2022", es = "2022")
salvar_indicadores(mun, escala = "brasil", id = "code_muni", indicadores = list(
  indicador("lst_pop", rotulo = c(en = "Surface temperature in the hottest season, where people live", pt = "Temperatura da superfície na época mais quente, onde as pessoas moram",
                                  es = "Temperatura de superficie en la época más cálida, donde vive la gente"),
    unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = 10, fonte = fonte_lst, periodo = per_lst,
    metodo = c(en = "MODIS 1 km daytime land surface temperature averaged over the hottest three consecutive months of each pixel; mean of census-tract values weighted by residents",
               pt = "Temperatura da superfície diurna MODIS (1 km) média dos três meses consecutivos mais quentes de cada pixel; média dos setores censitários ponderada pelos moradores",
               es = "Temperatura de superficie diurna MODIS (1 km) promedio de los tres meses consecutivos más cálidos de cada píxel; media de los sectores censales ponderada por residentes")),
  indicador("lst_dif_uf", rotulo = c(en = "Surface temperature: difference from own state", pt = "Temperatura da superfície: diferença para o próprio estado",
                                         es = "Temperatura de superficie: diferencia respecto a su estado"),
    unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1, ordem = 11, quebras = c(-3, -1, 1, 3),
    fonte = fonte_lst, periodo = per_lst,
    metodo = c(en = "Municipal value minus the value of its state (all tracts of the state, weighted by residents)",
               pt = "Valor do município menos o do seu estado (todos os setores da UF, ponderados pelos moradores)",
               es = "Valor del municipio menos el de su estado (todos los sectores de la UF, ponderados por residentes)")),
  indicador("gap_renda", rotulo = c(en = "Heat gap: poorest − richest fifth (within municipality)",
                                    pt = "Desigualdade térmica: 20% mais pobres − 20% mais ricos (no município)",
                                    es = "Brecha térmica: 20% más pobre − 20% más rico (en el municipio)"),
    unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1, ordem = 12, quebras = c(-2, -0.5, 0.5, 2),
    fonte = fonte_lst, periodo = per_lst,
    metodo = c(en = paste0("Household-weighted surface temperature of the poorest minus the richest income fifth of the municipality's tracts; only municipalities with at least ", MIN_SETORES, " tracts with data. Red: the poorest live in hotter places; blue: in cooler places"),
               pt = paste0("Temperatura da superfície, ponderada por domicílios, do quinto mais pobre menos a do quinto mais rico dos setores do município; só municípios com ao menos ", MIN_SETORES, " setores com dado. Vermelho: os mais pobres moram em lugares mais quentes; azul: em lugares menos quentes"),
               es = paste0("Temperatura de superficie, ponderada por hogares, del quintil más pobre menos la del más rico de los sectores del municipio; solo municipios con al menos ", MIN_SETORES, " sectores con dato. Rojo: los más pobres viven en lugares más cálidos; azul: en lugares menos cálidos"))),
  indicador("gap_cor", rotulo = c(en = "Heat gap: Black and brown − white residents (within municipality)",
                                  pt = "Desigualdade térmica: pretos e pardos − brancos (no município)",
                                  es = "Brecha térmica: negros y pardos − blancos (en el municipio)"),
    unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 2, ordem = 13, quebras = c(-0.5, -0.15, 0.15, 0.5),
    fonte = fonte_lst, periodo = per_lst,
    metodo = c(en = "Surface temperature where the average Black and brown resident lives minus where the average white resident lives",
               pt = "Temperatura da superfície onde vive o morador preto ou pardo médio menos onde vive o morador branco médio",
               es = "Temperatura de superficie donde vive el residente negro o pardo promedio menos donde vive el residente blanco promedio")),
  indicador("renda_media_resp", rotulo = c(en = "Average income of household heads", pt = "Renda média do responsável pelo domicílio",
                                           es = "Ingreso medio del responsable del hogar"),
    unidade = "R$", paleta = "renda", dimensao = "sensibilidade", casas_decimais = 0, ordem = 20, fonte = fonte_censo,
    periodo = c(en = "July 2022 (nominal R$)", pt = "julho de 2022 (R$ nominais)", es = "julio de 2022 (R$ nominales)"),
    metodo = c(en = "Tract means of household heads with income, weighted by household heads. Not per capita income.",
               pt = "Médias dos setores (responsáveis com rendimentos) ponderadas pelos responsáveis. Não é renda per capita.",
               es = "Medias de los sectores (responsables con ingresos) ponderadas por responsables. No es ingreso per cápita.")),
  indicador("arv_com_arvores", rotulo = c(en = "Residents on blocks with street trees", pt = "Moradores em faces de quadra com árvores",
                                          es = "Residentes en frentes de manzana con árboles"),
    unidade = "%", paleta = "verde", dimensao = "adaptacao", casas_decimais = 0, ordem = 40, quebras = c(20, 40, 60, 80),
    fonte = fonte_censo, periodo = per22,
    metodo = c(en = "Residents on block faces with at least one tree / residents observed in the surroundings survey",
               pt = "Moradores em faces com ao menos uma árvore / moradores observados na pesquisa do entorno",
               es = "Residentes en frentes con al menos un árbol / residentes observados en la encuesta del entorno")),
  indicador("pop_preta_parda", rotulo = c(en = "Black population (preta and parda)", pt = "População preta e parda", es = "Población negra (preta y parda)"),
    unidade = "%", paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 0, ordem = 52, quebras = c(20, 40, 60, 80),
    fonte = fonte_censo, periodo = per22),
  indicador("pop_60mais", rotulo = c(en = "Population aged 60+", pt = "População com 60 anos ou mais", es = "Población de 60 años o más"),
    unidade = "%", paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 0, ordem = 50, fonte = fonte_censo, periodo = per22)
))

source("R/23_publicar_brasil.R")
