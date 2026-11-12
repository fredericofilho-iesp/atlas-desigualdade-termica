# Atlas de Desigualdade Térmica — idade e cor ou raça por setor (Rio)
# Executar na raiz do repositório: Rscript R/07_demografia_rio.R
# Requer: install.packages("jsonlite")
# Depende de: R/03 (temperatura), R/06 (arborização) para as análises de exposição.
#
# Fonte: IBGE, Censo 2022, Agregados por Setores Censitários (universo),
#        arquivos "demografia" e "cor_ou_raca".
#        https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/
# Variáveis (dicionário de 20/05/2026):
#   V01006 moradores · V01031 0 a 4 anos · V01040 60 a 69 · V01041 70 ou mais
#   V01317 branca · V01318 preta · V01319 amarela · V01320 parda · V01321 indígena
# O IBGE não separa 65+ nesse arquivo; usamos 60+ (pessoa idosa, Lei 10.741/2003).
#
# Indicadores (% dos moradores): pop_60mais, pop_0a4, pop_preta_parda.
# Setores com menos de MIN_MORADORES moradores ficam sem dado.
#
# Exposição por grupo (dados/processados/rio/exposicao_grupos.json):
# temperatura média da superfície e % em faces com árvores ponderadas pelo
# número de pessoas de cada grupo em cada setor, isto é, o valor do setor onde
# vive a pessoa média do grupo. Diferença preta e parda − branca com IC 95%
# por bootstrap de setores. Leitura ecológica: não é exposição individual.

suppressPackageStartupMessages({ library(jsonlite) })
source("R/00_publicar_camada.R")
source("R/00_ibge_ftp.R")
set.seed(2022)

BASE <- "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/"
PASTA <- "dados/brutos/demografia"
COD_MUN <- "3304557"
MIN_MORADORES <- 20

if (!file.exists("dados/brutos/rio_setores_2022.rds")) local(source("R/01_importar_ibge.R", local = TRUE))
malha <- readRDS("dados/brutos/rio_setores_2022.rds")
setores <- as.character(malha$CD_SETOR)

pasta_csv <- paste0(BASE, "Agregados_por_Setor_csv/")
ler_tema <- function(padrao) {
  z <- grep(padrao, listar(pasta_csv), value = TRUE)[1]
  stopifnot(!is.na(z))
  t <- ler_csv_ibge(extrair_csv(baixar_ibge(z, PASTA), PASTA), prefixo = COD_MUN)
  message(basename(z), ": ", nrow(t), " setores do Rio")
  t
}
dem <- ler_tema("demografia_BR\\.zip$")
cor <- ler_tema("cor_ou_raca_BR\\.zip$")
stopifnot(all(c("V01006", "V01031", "V01040", "V01041") %in% names(dem)),
          all(sprintf("V0%d", 1317:1321) %in% names(cor)))

pega <- function(tab, v) numero_ibge(tab[[v]])[match(setores, tab$CD_SETOR)]
n <- data.frame(
  CD_SETOR  = setores,
  moradores = pega(dem, "V01006"),
  a0_4      = pega(dem, "V01031"),
  a60_69    = pega(dem, "V01040"),
  a70       = pega(dem, "V01041"),
  branca    = pega(cor, "V01317"),
  preta     = pega(cor, "V01318"),
  amarela   = pega(cor, "V01319"),
  parda     = pega(cor, "V01320"),
  indigena  = pega(cor, "V01321")
)
n$a60 <- n$a60_69 + n$a70
n$preta_parda <- n$preta + n$parda
total_cor <- n$branca + n$preta + n$amarela + n$parda + n$indigena
ok <- is.finite(n$moradores) & n$moradores >= MIN_MORADORES
okc <- ok & is.finite(total_cor) & total_cor > 0

saida <- data.frame(
  CD_SETOR = setores,
  pop_60mais = ifelse(ok, round(100 * n$a60 / n$moradores, 1), NA_real_),
  pop_0a4 = ifelse(ok, round(100 * n$a0_4 / n$moradores, 1), NA_real_),
  pop_preta_parda = ifelse(okc, round(100 * n$preta_parda / total_cor, 1), NA_real_)
)
tot <- function(v) sum(n[[v]], na.rm = TRUE)
message("Moradores: ", tot("moradores"), " | 60+: ", round(100 * tot("a60") / tot("moradores"), 1),
        "% | 0–4: ", round(100 * tot("a0_4") / tot("moradores"), 1),
        "% | pretos e pardos: ", round(100 * tot("preta_parda") / sum(total_cor, na.rm = TRUE), 1), "%")
message("Setores com valor: idade ", sum(ok), " | cor ou raça ", sum(okc), " de ", length(setores))

# ---- exposição por grupo ----
ler <- function(id) utils::read.csv(file.path("dados/indicadores/rio", paste0(id, ".csv")),
                                    colClasses = c(CD_SETOR = "character"))
x <- Reduce(function(a, b) merge(a, b, by = "CD_SETOR", all.x = TRUE),
            list(n, ler("lst_verao"), ler("arv_com_arvores")))
grupos <- c("moradores", "branca", "preta", "parda", "preta_parda", "amarela", "indigena", "a60", "a70", "a0_4")
media_p <- function(v, w) { k <- is.finite(v) & is.finite(w) & w > 0; sum(v[k] * w[k]) / sum(w[k]) }
expo <- lapply(grupos, function(g) list(
  grupo = g, pessoas = round(sum(x[[g]][is.finite(x$lst_verao)], na.rm = TRUE)),
  lst_media = round(media_p(x$lst_verao, x[[g]]), 2),
  arv_com_arvores = round(media_p(x$arv_com_arvores, x[[g]]), 1)))
names(expo) <- grupos
dif <- expo$preta_parda$lst_media - expo$branca$lst_media
k <- which(is.finite(x$lst_verao))
boot <- replicate(2000, { s <- sample(k, replace = TRUE)
  media_p(x$lst_verao[s], x$preta_parda[s]) - media_p(x$lst_verao[s], x$branca[s]) })
ic <- round(stats::quantile(boot, c(.025, .975), names = FALSE), 2)
dif_arv <- expo$preta_parda$arv_com_arvores - expo$branca$arv_com_arvores

for (e in expo) message(sprintf("  %-12s %9d pessoas  %.2f °C  %5.1f%% em faces com árvore",
                                e$grupo, e$pessoas, e$lst_media, e$arv_com_arvores))
message(sprintf("Pretos e pardos − brancos: %.2f °C (IC 95%%: %.2f a %.2f) | árvores: %.1f pontos percentuais",
                dif, ic[1], ic[2], dif_arv))

dir.create("dados/processados/rio", recursive = TRUE, showWarnings = FALSE)
write_json(list(
  gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  fonte = "IBGE, Censo 2022 (universo), demografia e cor ou raça por setor; Landsat 8–9; IBGE entorno",
  grupos = unname(expo),
  diferenca_preta_parda_branca = round(dif, 2), ic95 = ic, bootstrap = 2000,
  diferenca_arvores_pp = round(dif_arv, 1)
), "dados/processados/rio/exposicao_grupos.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)

# ---- indicadores ----
fonte <- c(en = "IBGE, 2022 Census (universe)", pt = "IBGE, Censo 2022 (universo)", es = "IBGE, Censo 2022 (universo)")
periodo <- c(en = "2022", pt = "2022", es = "2022")
salvar_indicadores(saida, escala = "rio", id = "CD_SETOR", indicadores = list(
  indicador("pop_60mais",
    rotulo = c(en = "Population aged 60+", pt = "População com 60 anos ou mais", es = "Población de 60 años o más"),
    unidade = "%", paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 0, ordem = 50,
    fonte = fonte, periodo = periodo,
    metodo = c(en = "Residents aged 60 or older as a share of all residents (V01040 + V01041) / V01006",
               pt = "Moradores com 60 anos ou mais sobre o total de moradores (V01040 + V01041) / V01006",
               es = "Residentes de 60 años o más sobre el total de residentes (V01040 + V01041) / V01006")),
  indicador("pop_0a4",
    rotulo = c(en = "Children aged 0–4", pt = "Crianças de 0 a 4 anos", es = "Niños de 0 a 4 años"),
    unidade = "%", paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 1, ordem = 51,
    fonte = fonte, periodo = periodo,
    metodo = c(en = "Residents aged 0–4 as a share of all residents (V01031 / V01006)",
               pt = "Moradores de 0 a 4 anos sobre o total de moradores (V01031 / V01006)",
               es = "Residentes de 0 a 4 años sobre el total de residentes (V01031 / V01006)")),
  indicador("pop_preta_parda",
    rotulo = c(en = "Black and brown population (preta and parda)", pt = "População preta e parda",
               es = "Población negra y parda (preta y parda)"),
    unidade = "%", paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 0, ordem = 52,
    quebras = c(20, 40, 60, 80), fonte = fonte, periodo = periodo,
    metodo = c(en = "Residents self-declared preta or parda as a share of residents with declared color or race (IBGE categories)",
               pt = "Moradores autodeclarados pretos ou pardos sobre os moradores com cor ou raça declarada (categorias do IBGE)",
               es = "Residentes autodeclarados pretos o pardos sobre los residentes con color o raza declarada (categorías del IBGE)"))
))

source("R/10_publicar_rio.R")
