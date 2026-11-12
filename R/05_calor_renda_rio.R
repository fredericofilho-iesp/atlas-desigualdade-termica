# Atlas de Desigualdade Térmica — calor × renda no município do Rio
# Executar na raiz do repositório: Rscript R/05_calor_renda_rio.R
# Depende de: R/03_temperatura_superficie_rio.R e R/04_renda_rio.R
#
# 1. Quintos de renda ponderados por domicílios
#    Os setores são ordenados pela renda média do responsável e agrupados de
#    modo que cada quinto reúna ~20% dos domicílios da cidade. Para cada quinto
#    calculamos a temperatura média da superfície, ponderada por domicílios:
#    é a temperatura do setor onde vive o domicílio médio daquele quinto.
#    Indicador-síntese: diferença Q1 (20% mais pobres) − Q5 (20% mais ricos).
#    Intervalo de confiança de 95% por bootstrap de setores (2.000 repetições).
#
# 2. Classificação bivariada (3 × 3)
#    Tercis de temperatura da superfície × tercis de renda, ambos ponderados
#    por domicílios (cada tercil reúne ~1/3 dos domicílios). Código 1–9:
#    código = (tercil de temperatura − 1) × 3 + tercil de renda.
#
# Leitura: são associações entre áreas (falácia ecológica). Não dizem que cada
# domicílio pobre está mais exposto, nem que a renda causa a temperatura.
#
# Saídas: dados/indicadores/rio/biv_lst_renda.{csv,json}
#         dados/processados/rio/calor_renda.json (quintos, para o painel do site)
#         e republica a camada do site.

suppressPackageStartupMessages({ library(jsonlite) })
source("R/00_publicar_camada.R")
set.seed(2022)

ler <- function(id) utils::read.csv(file.path("dados/indicadores/rio", paste0(id, ".csv")),
                                    colClasses = c(CD_SETOR = "character"))
d <- Reduce(function(a, b) merge(a, b, by = "CD_SETOR", all = TRUE),
            list(ler("lst_verao"), ler("renda_media_resp"), ler("_apoio_domicilios")))
ok <- is.finite(d$lst_verao) & is.finite(d$renda_media_resp) & is.finite(d$domicilios) & d$domicilios > 0
a <- d[ok, ]
message("Setores com temperatura, renda e domicílios: ", nrow(a), "/", nrow(d),
        " | domicílios cobertos: ", sum(a$domicilios), " de ", sum(d$domicilios, na.rm = TRUE))

# Grupos ponderados: posição pelo ponto médio do domicílio acumulado.
grupos_ponderados <- function(x, w, k) {
  o <- order(x)
  meio <- (cumsum(w[o]) - w[o] / 2) / sum(w)
  g <- integer(length(x)); g[o] <- pmin(k, floor(meio * k) + 1L)
  g
}
limites <- function(x, g) vapply(seq_len(max(g) - 1), function(j) (max(x[g == j]) + min(x[g == j + 1])) / 2, 0)

# ---- 1. quintos ----
a$quinto <- grupos_ponderados(a$renda_media_resp, a$domicilios, 5)
resumo_q <- do.call(rbind, lapply(1:5, function(q) {
  s <- a[a$quinto == q, ]
  data.frame(quinto = q, setores = nrow(s), domicilios = sum(s$domicilios),
             renda_min = min(s$renda_media_resp), renda_max = max(s$renda_media_resp),
             lst_media = stats::weighted.mean(s$lst_verao, s$domicilios))
}))
dif <- resumo_q$lst_media[1] - resumo_q$lst_media[5]

boot <- replicate(2000, {
  b <- a[sample.int(nrow(a), replace = TRUE), ]
  b$q <- grupos_ponderados(b$renda_media_resp, b$domicilios, 5)
  stats::weighted.mean(b$lst_verao[b$q == 1], b$domicilios[b$q == 1]) -
    stats::weighted.mean(b$lst_verao[b$q == 5], b$domicilios[b$q == 5])
})
ic <- stats::quantile(boot, c(.025, .975), names = FALSE)

# Correlação de postos (setores, ponderada não; descritiva).
rho <- stats::cor(a$lst_verao, a$renda_media_resp, method = "spearman")

print(transform(resumo_q, lst_media = round(lst_media, 2)), row.names = FALSE)
message(sprintf("Diferença Q1 − Q5: %.2f °C (IC 95%%: %.2f a %.2f) | Spearman setores: %.2f", dif, ic[1], ic[2], rho))

dir.create("dados/processados/rio", recursive = TRUE, showWarnings = FALSE)
write_json(list(
  gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  indicador_temperatura = "lst_verao", indicador_renda = "renda_media_resp",
  peso = "domicílios (responsáveis em DPPO, Censo 2022)",
  setores_usados = nrow(a), domicilios_usados = sum(a$domicilios),
  quintos = lapply(seq_len(nrow(resumo_q)), function(i) as.list(transform(resumo_q[i, ],
    lst_media = round(lst_media, 2), renda_min = round(renda_min), renda_max = round(renda_max)))),
  diferenca_q1_q5 = round(dif, 2), ic95 = round(ic, 2), bootstrap = 2000,
  spearman_setores = round(rho, 3)
), "dados/processados/rio/calor_renda.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)

# ---- 2. bivariado ----
a$t_temp  <- grupos_ponderados(a$lst_verao, a$domicilios, 3)
a$t_renda <- grupos_ponderados(a$renda_media_resp, a$domicilios, 3)
lim_temp <- round(limites(a$lst_verao, a$t_temp), 1)
lim_renda <- round(limites(a$renda_media_resp, a$t_renda), -1)
d$biv_lst_renda <- NA_real_
d$biv_lst_renda[ok] <- (a$t_temp - 1) * 3 + a$t_renda
tab <- table(factor(d$biv_lst_renda, 1:9))
message("Setores por classe bivariada (1–9): ", paste(tab, collapse = " "))
message("Limites dos tercis — temperatura (°C): ", paste(lim_temp, collapse = " / "),
        " | renda (R$): ", paste(lim_renda, collapse = " / "))

salvar_indicadores(d, escala = "rio", id = "CD_SETOR", indicadores = list(
  indicador("biv_lst_renda",
    rotulo = c(en = "Surface temperature × income (bivariate)",
               pt = "Temperatura da superfície × renda (bivariado)",
               es = "Temperatura de superficie × ingreso (bivariado)"),
    paleta = "bivariada", dimensao = "exposicao", casas_decimais = 0, ordem = 5,
    tipo = "bivariado",
    eixos = list(
      y = list(indicador = "lst_verao", limites = lim_temp, unidade = "°C",
               rotulo = list(en = "Surface temperature", pt = "Temperatura da superfície", es = "Temperatura de superficie")),
      x = list(indicador = "renda_media_resp", limites = lim_renda, unidade = "R$",
               rotulo = list(en = "Household head income", pt = "Renda do responsável", es = "Ingreso del responsable"))),
    fonte = c(en = "Landsat 8–9 (USGS); IBGE 2022 Census", pt = "Landsat 8–9 (USGS); IBGE, Censo 2022",
              es = "Landsat 8–9 (USGS); IBGE, Censo 2022"),
    metodo = c(en = "Household-weighted terciles of summer surface temperature and of household-head income",
               pt = "Tercis, ponderados por domicílios, da temperatura da superfície no verão e da renda do responsável",
               es = "Terciles, ponderados por hogares, de la temperatura de superficie en verano y del ingreso del responsable"))
))

source("R/10_publicar_rio.R")
