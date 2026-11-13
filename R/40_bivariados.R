# Atlas de Desigualdade Térmica — mapas bivariados (temperatura × renda, cor ou raça, indígenas)
# Executar na raiz do repositório: Rscript R/40_bivariados.R
# Requer: install.packages(c("sf", "jsonlite"))   (e R/01 já rodado, para a malha do Rio)
# Usa só indicadores já salvos em dados/indicadores/ e os pesos (moradores, domicílios)
# das tabelas por setor; republica as três camadas brasileiras.
#
# Classes 3 × 3: nos setores do Rio, terços ponderados pelos moradores; nos mapas de
# municípios, terços de municípios (ponderar pela população faria a capital do RJ, com
# ~40% dos moradores do estado, ocupar quase um terço sozinha).
# Nos eixos de grupos (% preta e parda, % indígena) o eixo x é invertido, para que o canto
# magenta marque sempre a combinação mais desfavorável: mais quente e mais pobre, ou mais
# quente e com maior presença do grupo.
#   Rio (setores)            temperatura no verão × % preta e parda   (renda já existe: R/05)
#   Estado do RJ (municípios) temperatura × renda; temperatura × % preta e parda
#   Brasil (municípios)       diferença para a média do estado × renda; × % preta e parda;
#                             × % indígena (classes fixas: < 1%, 1–10%, ≥ 10%)
# No Brasil, o eixo de temperatura é a diferença para a média do próprio estado: comparar
# municípios de climas diferentes misturaria desigualdade com geografia (ver R/22).
# Indígenas: só na escala nacional. No município e no estado do RJ, pessoas indígenas são
# ~0,1% da população; quase todas as unidades cairiam na mesma classe.
# Fonte do % indígena por município: SIDRA/IBGE, tabela 9605 (Censo 2022, cor ou raça).
suppressPackageStartupMessages({ library(sf); library(jsonlite) })
source("R/00_publicar_camada.R")
options(timeout = 600)
ESC <- strsplit(Sys.getenv("ESCALAS", "rio,estado-rj,brasil"), ",")[[1]]

ler <- function(escala, id, chave) {
  x <- utils::read.csv(file.path("dados/indicadores", escala, paste0(id, ".csv")), colClasses = setNames("character", chave))
  setNames(x[[2]], x[[1]])
}
soma_mun <- function(tab, v) tapply(tab[[v]], tab$CD_MUN, sum, na.rm = TRUE)
TXT <- list(
  temp = list(en = "Surface temperature", pt = "Temperatura da superfície", es = "Temperatura de superficie"),
  temp_uf = list(en = "Surface temperature vs. own state", pt = "Temperatura da superfície vs. o próprio estado", es = "Temperatura de superficie vs. su estado"),
  ct = list(en = c("Cooler", "Intermediate temp.", "Hotter"), pt = c("Menos quente", "Temp. intermediária", "Mais quente"),
            es = c("Menos cálido", "Temp. intermedia", "Más cálido")),
  renda = list(en = "Household head income", pt = "Renda do responsável", es = "Ingreso del responsable"),
  cr = list(en = c("lower income", "middle income", "higher income"), pt = c("renda mais baixa", "renda média", "renda mais alta"),
            es = c("ingreso más bajo", "ingreso medio", "ingreso más alto")),
  pp = list(en = "Black population (preta and parda)", pt = "População preta e parda", es = "Población negra (preta y parda)"),
  cpp = list(en = c("more Black residents", "intermediate share", "fewer Black residents"),
             pt = c("mais pretos e pardos", "proporção intermediária", "menos pretos e pardos"),
             es = c("más población negra", "proporción intermedia", "menos población negra")),
  ind = list(en = "Indigenous population", pt = "População indígena", es = "Población indígena"),
  cind = list(en = c("10% or more Indigenous", "1–10% Indigenous", "under 1% Indigenous"),
              pt = c("10% ou mais indígenas", "1–10% indígenas", "menos de 1% indígenas"),
              es = c("10% o más indígenas", "1–10% indígenas", "menos de 1% indígenas")))
nota <- function(onde, quem, grupo) list(
  en = sprintf("Each third groups about one third of the %s. Magenta: hotter %s with %s.", quem$en, onde$en, grupo$en),
  pt = sprintf("Cada terço reúne cerca de um terço %s. Magenta: %s mais quentes e com %s.", quem$pt, onde$pt, grupo$pt),
  es = sprintf("Cada tercio agrupa alrededor de un tercio %s. Magenta: %s más cálidos y con %s.", quem$es, onde$es, grupo$es))
ex <- function(ind, rot, cls, unidade, casas) list(indicador = ind, rotulo = rot, classes = cls, unidade = unidade, casas = casas)
relato <- function(nome, b) message(sprintf("%s: %s | limites y %s | x %s", nome, paste(table(factor(b$classe, 1:9)), collapse = " "),
                                            paste(round(b$lim_y, 2), collapse = "/"), paste(round(b$lim_x, 1), collapse = "/")))
MET_PP <- c(en = "Population-weighted terciles of surface temperature and of the Black (preta and parda) share of residents; the group axis runs from more to fewer Black residents",
            pt = "Tercis, ponderados pela população, da temperatura da superfície e da proporção de moradores pretos e pardos; o eixo do grupo vai de mais para menos pretos e pardos",
            es = "Terciles, ponderados por población, de la temperatura de superficie y de la proporción de residentes negros (pretos y pardos); el eje del grupo va de más a menos población negra")
MUN <- function(m) c(en = sub("Population-weighted terciles", "Terciles (of municipalities)", m[["en"]]),
                     pt = sub("Tercis, ponderados pela população,", "Tercis (de municípios)", m[["pt"]]),
                     es = sub("Terciles, ponderados por población,", "Terciles (de municipios)", m[["es"]]))
MET_RENDA <- c(en = "Population-weighted terciles of surface temperature and of household-head income",
               pt = "Tercis, ponderados pela população, da temperatura da superfície e da renda do responsável",
               es = "Terciles, ponderados por población, de la temperatura de superficie y del ingreso del responsable")

# ---- Rio: setores ----
if ("rio" %in% ESC) {
  cs <- utils::read.csv("dados/indicadores/estado-rj-setores/censo.csv", colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
  cs <- cs[cs$CD_MUN == "3304557", ]
  lst <- ler("rio", "lst_verao", "CD_SETOR"); pp <- ler("rio", "pop_preta_parda", "CD_SETOR")
  d <- data.frame(CD_SETOR = names(lst), lst = lst)
  d$pp <- pp[d$CD_SETOR]; d$w <- cs$moradores[match(d$CD_SETOR, cs$CD_SETOR)]
  b <- classe_bivariada(d$lst, d$pp, d$w, inverso_x = TRUE); relato("Rio, temperatura × pretos e pardos", b)
  d$biv_lst_pretaparda <- b$classe
  salvar_indicadores(d, escala = "rio", id = "CD_SETOR", indicadores = list(
    indicador_bivariado("biv_lst_pretaparda",
      rotulo = c(en = "Surface temperature × Black population (bivariate)", pt = "Temperatura da superfície × população preta e parda (bivariado)",
                 es = "Temperatura de superficie × población negra (bivariado)"),
      b = b, y = ex("lst_verao", TXT$temp, TXT$ct, "°C", 1), x = ex("pop_preta_parda", TXT$pp, TXT$cpp, "%", 0),
      nota = nota(list(en = "tracts", pt = "setores", es = "sectores"), list(en = "city’s residents", pt = "dos moradores da cidade", es = "de los residentes de la ciudad"),
                  list(en = "more Black residents", pt = "mais pretos e pardos", es = "más población negra")),
      ordem = 31, fonte = c(en = "Landsat 8–9 (USGS); IBGE 2022 Census", pt = "Landsat 8–9 (USGS); IBGE, Censo 2022", es = "Landsat 8–9 (USGS); IBGE, Censo 2022"),
      metodo = MET_PP)))
  source("R/10_publicar_rio.R", local = new.env())
}

# ---- Estado do RJ: municípios ----
if ("estado-rj" %in% ESC) {
  cs <- utils::read.csv("dados/indicadores/estado-rj-setores/censo.csv", colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
  w <- soma_mun(cs, "moradores")
  lst <- ler("estado-rj", "lst_pop", "code_muni")
  d <- data.frame(code_muni = names(lst), lst = lst)
  d$renda <- ler("estado-rj", "renda_media_resp", "code_muni")[d$code_muni]
  d$pp <- ler("estado-rj", "pop_preta_parda", "code_muni")[d$code_muni]
  d$w <- ifelse(is.finite(w[d$code_muni]), 1, NA)   # terços de municípios (a capital pesaria ~40%)
  b1 <- classe_bivariada(d$lst, d$renda, d$w); relato("RJ, temperatura × renda", b1)
  b2 <- classe_bivariada(d$lst, d$pp, d$w, inverso_x = TRUE); relato("RJ, temperatura × pretos e pardos", b2)
  d$biv_lst_renda <- b1$classe; d$biv_lst_pretaparda <- b2$classe
  fonte <- c(en = "Landsat 8–9 (USGS); IBGE 2022 Census", pt = "Landsat 8–9 (USGS); IBGE, Censo 2022", es = "Landsat 8–9 (USGS); IBGE, Censo 2022")
  onde <- list(en = "municipalities", pt = "municípios", es = "municipios")
  quem <- list(en = "state’s municipalities", pt = "dos municípios do estado", es = "de los municipios del estado")
  salvar_indicadores(d, escala = "estado-rj", id = "code_muni", indicadores = list(
    indicador_bivariado("biv_lst_renda",
      rotulo = c(en = "Surface temperature × income (bivariate)", pt = "Temperatura da superfície × renda (bivariado)", es = "Temperatura de superficie × ingreso (bivariado)"),
      b = b1, y = ex("lst_pop", TXT$temp, TXT$ct, "°C", 1), x = ex("renda_media_resp", TXT$renda, TXT$cr, "R$", -1),
      nota = nota(onde, quem, list(en = "lower income", pt = "renda mais baixa", es = "menor ingreso")), ordem = 30, fonte = fonte, metodo = MUN(MET_RENDA)),
    indicador_bivariado("biv_lst_pretaparda",
      rotulo = c(en = "Surface temperature × Black population (bivariate)", pt = "Temperatura da superfície × população preta e parda (bivariado)",
                 es = "Temperatura de superficie × población negra (bivariado)"),
      b = b2, y = ex("lst_pop", TXT$temp, TXT$ct, "°C", 1), x = ex("pop_preta_parda", TXT$pp, TXT$cpp, "%", 0),
      nota = nota(onde, quem, list(en = "more Black residents", pt = "mais pretos e pardos", es = "más población negra")), ordem = 31, fonte = fonte, metodo = MUN(MET_PP))))
  source("R/15_publicar_estado_rj.R", local = new.env())
}

# ---- Brasil: municípios ----
if ("brasil" %in% ESC) {
  cs <- utils::read.csv(gzfile("dados/indicadores/brasil-setores/censo.csv.gz"), colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
  w <- soma_mun(cs, "moradores")
  dif <- ler("brasil", "lst_dif_uf", "code_muni")
  d <- data.frame(code_muni = names(dif), dif = dif)
  d$renda <- ler("brasil", "renda_media_resp", "code_muni")[d$code_muni]
  d$pp <- ler("brasil", "pop_preta_parda", "code_muni")[d$code_muni]
  d$w <- ifelse(is.finite(w[d$code_muni]), 1, NA)   # terços de municípios, como no estado
  # % indígena por município (SIDRA 9605: população residente por cor ou raça, Censo 2022)
  sid <- tryCatch(fromJSON("https://apisidra.ibge.gov.br/values/t/9605/n6/all/v/93/p/all/c86/all?formato=json"), error = function(e) NULL)
  d$ind <- NA_real_
  if (!is.null(sid)) {
    cab <- unlist(sid[1, ]); sid <- sid[-1, ]
    cm <- names(cab)[cab == "Município (Código)"][1]; cc <- names(cab)[cab == "Cor ou raça"][1]
    # outras classificações da tabela (ex.: idade, sexo): fica só a linha "Total" de cada uma
    outras <- setdiff(names(cab)[grepl("^D[0-9]+N$", names(cab))], c(sub("C$", "N", cm), sub("C$", "N", cc)))
    outras <- outras[!cab[outras] %in% c("Município", "Variável", "Ano", "Unidade de Medida")]
    for (o in outras) if (any(sid[[o]] == "Total")) { message("  SIDRA: fixa ", cab[[o]], " = Total"); sid <- sid[sid[[o]] == "Total", ] }
    message("  SIDRA cabeçalho: ", paste(names(cab), cab, sep = "=", collapse = " | "))
    message("  SIDRA categorias: ", paste(names(table(sid[[cc]])), table(sid[[cc]]), sep = ":", collapse = " "))
    print(utils::head(sid[sid[[cm]] == "3304557", ], 12))
    val <- suppressWarnings(as.numeric(sid$V))
    tot <- tapply(val[sid[[cc]] == "Total"], sid[[cm]][sid[[cc]] == "Total"], sum)
    ind <- tapply(val[sid[[cc]] == "Indígena"], sid[[cm]][sid[[cc]] == "Indígena"], sum)
    d$ind <- round(100 * ind[d$code_muni] / tot[d$code_muni], 2)
    message(sprintf("SIDRA 9605: %d municípios; pessoas indígenas (cor ou raça): %.0f mil (%.2f%%)", length(tot), sum(ind, na.rm = TRUE) / 1e3,
                    100 * sum(ind, na.rm = TRUE) / sum(tot, na.rm = TRUE)))
  } else message("SIDRA indisponível: sem o mapa de indígenas nesta rodada")
  b1 <- classe_bivariada(d$dif, d$renda, d$w); relato("Brasil, temperatura (vs. UF) × renda", b1)
  b2 <- classe_bivariada(d$dif, d$pp, d$w, inverso_x = TRUE); relato("Brasil, temperatura (vs. UF) × pretos e pardos", b2)
  d$biv_dif_renda <- b1$classe; d$biv_dif_pretaparda <- b2$classe
  fonte <- c(en = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE 2022 Census", pt = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022",
             es = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022")
  onde <- list(en = "municipalities (relative to their state)", pt = "municípios (em relação ao seu estado)", es = "municipios (respecto a su estado)")
  quem <- list(en = "country’s municipalities", pt = "dos municípios do país", es = "de los municipios del país")
  nota_uf <- c(en = " Temperature axis: difference from the state average, so that regional climate does not mix with inequality.",
               pt = " Eixo da temperatura: diferença para a média do estado, para que o clima regional não se misture à desigualdade.",
               es = " Eje de la temperatura: diferencia respecto a la media del estado, para que el clima regional no se mezcle con la desigualdad.")
  com_uf <- function(n) { for (l in names(n)) n[[l]] <- paste0(n[[l]], nota_uf[[l]]); n }
  met_uf <- function(m) c(en = paste0(m[["en"]], "; temperature as difference from the state average"),
                          pt = paste0(m[["pt"]], "; temperatura como diferença para a média do estado"),
                          es = paste0(m[["es"]], "; temperatura como diferencia respecto a la media del estado"))
  ey <- ex("lst_dif_uf", TXT$temp_uf, TXT$ct, "°C", 1)
  inds <- list(
    indicador_bivariado("biv_dif_renda",
      rotulo = c(en = "Surface temperature × income (bivariate, within states)", pt = "Temperatura da superfície × renda (bivariado, dentro dos estados)",
                 es = "Temperatura de superficie × ingreso (bivariado, dentro de los estados)"),
      b = b1, y = ey, x = ex("renda_media_resp", TXT$renda, TXT$cr, "R$", -1),
      nota = com_uf(nota(onde, quem, list(en = "lower income", pt = "renda mais baixa", es = "menor ingreso"))), ordem = 30, fonte = fonte, metodo = met_uf(MUN(MET_RENDA))),
    indicador_bivariado("biv_dif_pretaparda",
      rotulo = c(en = "Surface temperature × Black population (bivariate, within states)", pt = "Temperatura da superfície × população preta e parda (bivariado, dentro dos estados)",
                 es = "Temperatura de superficie × población negra (bivariado, dentro de los estados)"),
      b = b2, y = ey, x = ex("pop_preta_parda", TXT$pp, TXT$cpp, "%", 0),
      nota = com_uf(nota(onde, quem, list(en = "more Black residents", pt = "mais pretos e pardos", es = "más población negra"))), ordem = 31, fonte = fonte, metodo = met_uf(MUN(MET_PP))))
  if (any(is.finite(d$ind))) {
    b3 <- classe_bivariada(d$dif, d$ind, d$w, quebras_x = c(1, 10), inverso_x = TRUE); relato("Brasil, temperatura (vs. UF) × indígenas", b3)
    d$biv_dif_indigena <- b3$classe; d$pop_indigena <- d$ind
    inds <- c(inds, list(
      indicador("pop_indigena", rotulo = c(en = "Indigenous population", pt = "População indígena", es = "Población indígena"),
        unidade = "%", paleta = "pessoas", dimensao = "sensibilidade", casas_decimais = 1, ordem = 63, quebras = c(0.5, 1, 5, 10),
        fonte = c(en = "IBGE 2022 Census (SIDRA table 9605)", pt = "IBGE, Censo 2022 (SIDRA, tabela 9605)", es = "IBGE, Censo 2022 (SIDRA, tabla 9605)"),
        periodo = c(en = "2022", pt = "2022", es = "2022"),
        metodo = c(en = "Residents who declared Indigenous color or race, as a share of all residents",
                   pt = "Moradores que declararam cor ou raça indígena, sobre o total de moradores",
                   es = "Residentes que declararon color o raza indígena, sobre el total de residentes")),
      indicador_bivariado("biv_dif_indigena",
        rotulo = c(en = "Surface temperature × Indigenous population (bivariate, within states)", pt = "Temperatura da superfície × população indígena (bivariado, dentro dos estados)",
                   es = "Temperatura de superficie × población indígena (bivariado, dentro de los estados)"),
        b = b3, y = ey, x = ex("pop_indigena", TXT$ind, TXT$cind, "%", 0),
        nota = list(en = paste0("Temperature: thirds of municipalities. Indigenous share: fixed classes (under 1%, 1–10%, 10% or more). Magenta: hotter municipalities with 10% or more Indigenous residents.", nota_uf[["en"]]),
                    pt = paste0("Temperatura: terços dos municípios. Proporção indígena: classes fixas (menos de 1%, 1–10%, 10% ou mais). Magenta: municípios mais quentes e com 10% ou mais de indígenas.", nota_uf[["pt"]]),
                    es = paste0("Temperatura: tercios de los municipios. Proporción indígena: clases fijas (menos de 1%, 1–10%, 10% o más). Magenta: municipios más cálidos y con 10% o más de indígenas.", nota_uf[["es"]])),
        ordem = 32, fonte = c(en = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE 2022 Census (SIDRA 9605)", pt = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022 (SIDRA 9605)",
                              es = "MODIS/Aqua MYD11A2 v6.1 (NASA); IBGE, Censo 2022 (SIDRA 9605)"),
        metodo = c(en = "Terciles (of municipalities) of the temperature difference from the state average; fixed classes of the Indigenous share of residents",
                   pt = "Tercis (de municípios) da diferença de temperatura para a média do estado; classes fixas da proporção de moradores indígenas",
                   es = "Terciles (de municipios) de la diferencia de temperatura respecto a la media del estado; clases fijas de la proporción de residentes indígenas"))))
  }
  salvar_indicadores(d, escala = "brasil", id = "code_muni", indicadores = inds)
  source("R/23_publicar_brasil.R", local = new.env())
}
