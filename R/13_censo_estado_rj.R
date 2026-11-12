# Atlas de Desigualdade Térmica — dados do Censo 2022 por setor, estado do RJ
# Executar na raiz do repositório: Rscript R/13_censo_estado_rj.R
# Requer: install.packages("jsonlite")
#
# Reúne, para todos os setores do estado (código começando com 33), as mesmas
# variáveis usadas no município do Rio (ver R/04, R/06 e R/07):
#   Rendimento do responsável: V06001 (responsáveis em DPPO), V06004 (renda média
#     das pessoas responsáveis com rendimentos)
#   Demografia: V01006 moradores, V01031 0–4, V01040 60–69, V01041 70+
#   Cor ou raça: V01317 branca, V01318 preta, V01320 parda
#   Entorno (moradores): V05230 sem árvores, V05231 1–2, V05232 3–4, V05233 5+
# Valores suprimidos pelo IBGE (sigilo) ficam ausentes.
# Saída: dados/indicadores/estado-rj-setores/censo.csv (contagens por setor)

source("R/00_ibge_ftp.R")
UF <- "33"
PASTA <- "dados/brutos/censo-estado"
SAIDA <- "dados/indicadores/estado-rj-setores"
FTP <- "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/"

ler <- function(pasta_url, padrao) {
  z <- achar(pasta_url, padrao)[1]   # desce até 2 subpastas
  if (is.na(z)) stop("Arquivo não encontrado: ", padrao, " em ", pasta_url,
                     "\nConteúdo: ", paste(listar(pasta_url), collapse = " | "))
  t <- ler_csv_ibge(extrair_csv(baixar_ibge(z, PASTA), PASTA), prefixo = UF)
  message(utils::URLdecode(basename(z)), ": ", nrow(t), " setores do RJ")
  t
}
agreg <- paste0(FTP, "Agregados_por_Setores_Censitarios/Agregados_por_Setor_csv/")
renda <- ler(paste0(FTP, "Agregados_por_Setores_Censitarios_Rendimento_do_Responsavel/"), "^Agregados_por_setores_renda.*csv.*\\.zip$")
dem   <- ler(agreg, "demografia_BR\\.zip$")
cor   <- ler(agreg, "cor_ou_raca_BR\\.zip$")
ent   <- ler(paste0(FTP, "Agregados_por_Setores_Censitarios_Caracteristicas_urbanisticas_do_entorno_dos_domicilios/Agregados_por_Setor_csv/"),
             "setores_entorno_moradores.*\\.zip$")

setores <- sort(unique(c(renda$CD_SETOR, dem$CD_SETOR, cor$CD_SETOR, ent$CD_SETOR)))
pega <- function(tab, v) { stopifnot(v %in% names(tab)); numero_ibge(tab[[v]])[match(setores, tab$CD_SETOR)] }
out <- data.frame(
  CD_SETOR = setores, CD_MUN = substr(setores, 1, 7),
  domicilios = pega(renda, "V06001"), renda_media = pega(renda, "V06004"),
  moradores = pega(dem, "V01006"), a0_4 = pega(dem, "V01031"),
  a60 = pega(dem, "V01040") + pega(dem, "V01041"),
  branca = pega(cor, "V01317"), preta = pega(cor, "V01318"), parda = pega(cor, "V01320"),
  arv_sem = pega(ent, "V05230"), arv_1_2 = pega(ent, "V05231"),
  arv_3_4 = pega(ent, "V05232"), arv_5 = pega(ent, "V05233")
)
dir.create(SAIDA, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, file.path(SAIDA, "censo.csv"), row.names = FALSE, na = "")
message("Setores: ", nrow(out), " | municípios: ", length(unique(out$CD_MUN)),
        " | moradores: ", sum(out$moradores, na.rm = TRUE),
        " | domicílios (responsáveis): ", sum(out$domicilios, na.rm = TRUE))
