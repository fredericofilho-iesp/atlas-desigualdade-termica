/*
 * Atlas — traduções (inglês, português, espanhol) e seletor de idioma.
 *
 * Elementos com data-i18n="chave" recebem o texto traduzido (innerHTML).
 * data-i18n-attr="aria-label:chave;title:chave" traduz atributos.
 * Ordem de escolha do idioma: ?lang= na URL > escolha salva > idioma do
 * navegador (pt/es) > inglês.
 *
 * Para acrescentar um idioma: copie o bloco `en`, traduza e inclua o código
 * em IDIOMAS.
 */
(function () {
  'use strict';

  var IDIOMAS = [
    { codigo: 'en', nome: 'English', locale: 'en-US', html: 'en' },
    { codigo: 'pt', nome: 'Português', locale: 'pt-BR', html: 'pt-BR' },
    { codigo: 'es', nome: 'Español', locale: 'es', html: 'es' }
  ];

  var T = {
    en: {
      'site.title': 'Heat Inequality Atlas',
      'site.subtitle': 'Heat exposure, social vulnerability and climate justice',
      'nav.label': 'Atlas scales',
      'nav.home': 'Home',
      'nav.rio': 'Rio de Janeiro (city)',
      'nav.rj': 'Rio de Janeiro State',
      'nav.br': 'Brazil',
      'nav.la': 'Latin America',
      'nav.method': 'Methodology',
      'nav.soon': 'coming soon',
      'lang.label': 'Language',
      'footer': 'Academic project under development · <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">Code, data and documentation on GitHub</a> · Basemap © OpenStreetMap · OpenFreeMap',

      'map.indicator': 'Indicator',
      'map.loading': 'Loading…',
      'map.loadingLayer': 'Loading boundary layer…',
      'map.clickHint': 'Click an area on the map to see its values.',
      'map.sourcesTitle': 'Planned sources',
      'map.detailsIn': 'Details in <a href="../metodologia/">Methodology</a>.',
      'map.boundariesOnly': 'Boundaries only',
      'map.basemapOnly': 'Basemap only',
      'map.pending': 'pending',
      'map.noData': 'no data',
      'map.unit': 'Area',
      'map.units': 'areas',
      'map.code': 'Code',
      'map.noIndicatorsYet': 'Heat and socioeconomic indicators have not been published for this scale yet.',
      'map.source': 'Source',
      'map.period': 'Period',
      'map.classes': 'Classes',
      'map.quantiles': 'quantiles',
      'map.equalIntervals': 'equal intervals',
      'map.fixedIntervals': 'fixed intervals',
      'map.nClasses': '{n} classes',
      'map.loaded': 'Layer loaded: {fonte} — {n} {unidades}.',
      'map.loadedNoCount': 'Layer loaded: {fonte}.',
      'map.nIndicators': '{n} indicator(s) published.',
      'map.noIndicators': 'No indicators attached yet.',
      'map.layerError': 'Could not load the boundary layer. Showing the basemap only.',
      'map.libError': 'Could not load the mapping library (MapLibre).',
      'map.unavailable': 'Map unavailable.',
      'map.badgeBasemap': 'Basemap',
      'map.ariaInteractive': 'Interactive map',
      'map.ariaNavigable': 'Navigable map',

      'rio.title': 'City of Rio de Janeiro',
      'rio.desc': '2022 Census tracts (IBGE).',
      'rio.notice': '<strong>Under construction.</strong> The official census tract boundaries are in place; heat and socioeconomic indicators have not been published yet.',
      'rio.sources': 'IBGE (2022 Census, tract boundaries), Landsat imagery (land surface temperature), MapBiomas (vegetation cover), Data.Rio.',
      'rio.noLayer': 'Census tract layer not processed yet. Run the “Prepare atlas layers” workflow on GitHub Actions.',
      'rio.planned': ['Land surface temperature (Landsat)', 'Household income', 'Vegetation cover', 'Population aged 65+', 'Black and brown population'],

      'rj.title': 'Rio de Janeiro State',
      'rj.desc': 'The state’s 92 municipalities.',
      'rj.notice': '<strong>Under construction.</strong> First step: municipal boundaries (IBGE 2022). Indicators will be added after validation in the city of Rio.',
      'rj.sources': 'IBGE (2022 municipal boundaries, 2022 Census), Ipea, MODIS, ERA5-Land, MapBiomas.',
      'rj.noLayer': 'Municipal layer not processed yet. Run the “Prepare atlas layers” workflow on GitHub Actions.',
      'rj.planned': ['Land surface temperature (MODIS)', 'Extreme heat days (ERA5-Land)', 'Income per capita', 'Vegetation cover', 'Population aged 65+'],

      'br.title': 'Brazil',
      'br.desc': 'Brazilian municipalities.',
      'br.notice': '<strong>Planned.</strong> This scale will use municipalities and, for large datasets, PMTiles layers hosted outside GitHub.',
      'br.sources': 'IBGE, Ipea, ERA5-Land (Copernicus), MODIS, MapBiomas.',
      'br.noLayer': 'Planned scale. The 5,570 municipalities will be published in an optimised format (PMTiles).',
      'br.planned': ['Air temperature (ERA5-Land)', 'Extreme heat days (ERA5-Land)', 'Land surface temperature (MODIS)', 'Income per capita', 'Vegetation cover'],

      'la.title': 'Latin America',
      'la.desc': 'Countries and subnational units.',
      'la.notice': '<strong>Planned.</strong> To keep countries comparable, the first layer uses only internationally harmonised products (ERA5-Land, MODIS, WorldPop, GHSL). National data will be a complementary layer, with differences documented.',
      'la.sources': 'ERA5-Land, MODIS, WorldPop, GHSL, ESA WorldCover, CEPALSTAT, World Bank, geoBoundaries, SALURBAL.',
      'la.noLayer': 'Planned scale. Will use internationally harmonised data only.',
      'la.planned': ['Air temperature (ERA5-Land)', 'Land surface temperature (MODIS)', 'Population (WorldPop)', 'Urbanisation (GHSL)', 'Land cover (ESA WorldCover)', 'Social indicators (CEPALSTAT)'],

      'home.title': 'Who is most exposed to heat?',
      'home.lead': 'An open atlas to examine how exposure to extreme heat is distributed across space and how it relates to income, race, age and urban infrastructure, at four scales.',
      'home.rio.d': '2022 census tracts', 'home.rj.d': '92 municipalities',
      'home.br.d': '5,570 municipalities', 'home.la.d': 'Countries and subnational units',
      'status.building': 'Under construction', 'status.planned': 'Planned',
      'home.body': '<h2>Three dimensions, analysed separately</h2><p><strong>Exposure</strong> (land surface temperature, air temperature, extreme heat days), <strong>sensitivity</strong> (age, income, race, housing conditions) and <strong>adaptive capacity</strong> (vegetation, sanitation, access to water). Heat inequality is not only a difference in temperature: a hot area may have the resources to protect itself, while a cooler area may concentrate highly vulnerable people.</p><h2>Principles</h2><ul><li>Land surface temperature (satellite) and air temperature (reanalysis) are different measures and are never mixed.</li><li>Every published indicator states its source, period, unit and aggregation method.</li><li>Area-level correlations do not support causal conclusions about individuals.</li><li>Scripts and processed data are kept in the repository for reproducibility.</li></ul><p>See the <a href="metodologia/">methodology</a>.</p>',

      'method.title': 'Methodology',
      'method.body': '<p class="lead">Status: planning. No heat or socioeconomic indicator has been published yet. This page is updated with each new indicator.</p><h2>Scales and spatial units</h2><table><thead><tr><th>Scale</th><th>Unit</th><th>Main sources</th></tr></thead><tbody><tr><td>City of Rio de Janeiro</td><td>2022 census tracts</td><td>IBGE, Data.Rio, Landsat, MapBiomas</td></tr><tr><td>Rio de Janeiro State</td><td>Municipalities (92)</td><td>IBGE, Ipea, MODIS, ERA5-Land, MapBiomas</td></tr><tr><td>Brazil</td><td>Municipalities (5,570)</td><td>IBGE, Ipea, ERA5-Land, MODIS, MapBiomas</td></tr><tr><td>Latin America</td><td>Countries and subnational units</td><td>ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL</td></tr></tbody></table><h2>Analytical dimensions</h2><table><thead><tr><th>Dimension</th><th>Candidate indicators</th></tr></thead><tbody><tr><td>Heat exposure</td><td>Land surface temperature, air temperature, heatwave frequency, extreme heat days</td></tr><tr><td>Socioeconomic vulnerability</td><td>Income, poverty, education, race, household crowding</td></tr><tr><td>Demographic vulnerability</td><td>Older adults, children, population density</td></tr><tr><td>Adaptive capacity</td><td>Vegetation cover, street trees, sanitation, access to water</td></tr></tbody></table><h2>Principles</h2><ol><li>Land surface temperature (LST, from satellites) and air temperature (stations or reanalysis) are distinct physical concepts and appear as separate indicators.</li><li>For each indicator we record unit, period, original resolution, treatment of missing values and spatial aggregation method.</li><li>No simulated data is presented as an observation.</li><li>Cross-country comparisons use only internationally harmonised products; national data appears as a complementary layer, with differences in definitions documented.</li><li>Area-level associations (ecological fallacy) are not interpreted as individual or causal relationships.</li></ol><h2>Map classification</h2><p>By default each indicator is split into five quantile classes, computed in R at publication time. The method and class limits are shown in the map legend.</p><h2>Reproducibility</h2><p>The R scripts that download, process and publish each layer are in the <code>R/</code> folder of the <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">repository</a>.</p>'
    },

    pt: {
      'site.title': 'Atlas Interativo de Desigualdade Térmica',
      'site.subtitle': 'Exposição ao calor, vulnerabilidade social e justiça climática',
      'nav.label': 'Escalas do atlas',
      'nav.home': 'Início',
      'nav.rio': 'Rio de Janeiro (cidade)',
      'nav.rj': 'Estado do RJ',
      'nav.br': 'Brasil',
      'nav.la': 'América Latina',
      'nav.method': 'Metodologia',
      'nav.soon': 'em breve',
      'lang.label': 'Idioma',
      'footer': 'Projeto acadêmico em desenvolvimento · <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">Código, dados e documentação no GitHub</a> · Mapa-base © OpenStreetMap · OpenFreeMap',

      'map.indicator': 'Indicador',
      'map.loading': 'Carregando…',
      'map.loadingLayer': 'Carregando camada territorial…',
      'map.clickHint': 'Clique em uma unidade no mapa para ver seus valores.',
      'map.sourcesTitle': 'Fontes previstas',
      'map.detailsIn': 'Detalhes em <a href="../metodologia/">Metodologia</a>.',
      'map.boundariesOnly': 'Apenas limites territoriais',
      'map.basemapOnly': 'Mapa-base',
      'map.pending': 'pendente',
      'map.noData': 'sem dado',
      'map.unit': 'Unidade',
      'map.units': 'unidades',
      'map.code': 'Código',
      'map.noIndicatorsYet': 'Indicadores térmicos e socioeconômicos ainda não publicados para esta escala.',
      'map.source': 'Fonte',
      'map.period': 'Período',
      'map.classes': 'Classes',
      'map.quantiles': 'quantis',
      'map.equalIntervals': 'intervalos iguais',
      'map.fixedIntervals': 'intervalos fixos',
      'map.nClasses': '{n} classes',
      'map.loaded': 'Camada carregada: {fonte} — {n} {unidades}.',
      'map.loadedNoCount': 'Camada carregada: {fonte}.',
      'map.nIndicators': '{n} indicador(es) publicados.',
      'map.noIndicators': 'Sem indicadores associados ainda.',
      'map.layerError': 'Erro ao carregar a camada territorial. Exibindo apenas o mapa-base.',
      'map.libError': 'Não foi possível carregar a biblioteca cartográfica (MapLibre).',
      'map.unavailable': 'Mapa indisponível.',
      'map.badgeBasemap': 'Mapa-base',
      'map.ariaInteractive': 'Mapa interativo',
      'map.ariaNavigable': 'Mapa navegável',

      'rio.title': 'Município do Rio de Janeiro',
      'rio.desc': 'Setores censitários do Censo 2022 (IBGE).',
      'rio.notice': '<strong>Em construção.</strong> A malha oficial de setores já está no mapa; os indicadores térmicos e socioeconômicos ainda não foram publicados.',
      'rio.sources': 'IBGE (Censo 2022, malha de setores), imagens Landsat (temperatura da superfície), MapBiomas (cobertura vegetal), Data.Rio.',
      'rio.noLayer': 'Malha censitária ainda não processada. Rode o workflow “Preparar camadas do atlas” no GitHub Actions.',
      'rio.planned': ['Temperatura da superfície (Landsat)', 'Renda domiciliar', 'Cobertura vegetal', 'População com 65 anos ou mais', 'População preta e parda'],

      'rj.title': 'Estado do Rio de Janeiro',
      'rj.desc': 'Os 92 municípios fluminenses.',
      'rj.notice': '<strong>Em construção.</strong> Primeiro passo: limites municipais (IBGE 2022). Indicadores entram depois da validação no município do Rio.',
      'rj.sources': 'IBGE (malha municipal 2022, Censo 2022), Ipea, MODIS, ERA5-Land, MapBiomas.',
      'rj.noLayer': 'Malha municipal ainda não processada. Rode o workflow “Preparar camadas do atlas” no GitHub Actions.',
      'rj.planned': ['Temperatura da superfície (MODIS)', 'Dias de calor extremo (ERA5-Land)', 'Renda per capita', 'Cobertura vegetal', 'População com 65 anos ou mais'],

      'br.title': 'Brasil',
      'br.desc': 'Municípios brasileiros.',
      'br.notice': '<strong>Planejado.</strong> Esta escala usará municípios e, para bases grandes, camadas em PMTiles hospedadas fora do GitHub.',
      'br.sources': 'IBGE, Ipea, ERA5-Land (Copernicus), MODIS, MapBiomas.',
      'br.noLayer': 'Escala planejada. Os 5.570 municípios serão publicados em formato otimizado (PMTiles).',
      'br.planned': ['Temperatura do ar (ERA5-Land)', 'Dias de calor extremo (ERA5-Land)', 'Temperatura da superfície (MODIS)', 'Renda per capita', 'Cobertura vegetal'],

      'la.title': 'América Latina',
      'la.desc': 'Países e unidades subnacionais.',
      'la.notice': '<strong>Planejado.</strong> Para garantir comparabilidade entre países, a primeira camada usa só produtos com metodologia comum (ERA5-Land, MODIS, WorldPop, GHSL). Dados nacionais entram como camada complementar, com as diferenças documentadas.',
      'la.sources': 'ERA5-Land, MODIS, WorldPop, GHSL, ESA WorldCover, CEPALSTAT, Banco Mundial, geoBoundaries, SALURBAL.',
      'la.noLayer': 'Escala planejada. Usará apenas dados harmonizados internacionalmente.',
      'la.planned': ['Temperatura do ar (ERA5-Land)', 'Temperatura da superfície (MODIS)', 'População (WorldPop)', 'Urbanização (GHSL)', 'Cobertura do solo (ESA WorldCover)', 'Indicadores sociais (CEPALSTAT)'],

      'home.title': 'Quem está mais exposto ao calor?',
      'home.lead': 'Um atlas aberto para investigar como a exposição ao calor extremo se distribui no território e como ela se relaciona com renda, raça, idade e infraestrutura urbana, em quatro escalas.',
      'home.rio.d': 'Setores censitários 2022', 'home.rj.d': '92 municípios',
      'home.br.d': '5.570 municípios', 'home.la.d': 'Países e unidades subnacionais',
      'status.building': 'Em construção', 'status.planned': 'Planejado',
      'home.body': '<h2>Três dimensões, analisadas separadamente</h2><p><strong>Exposição</strong> (temperatura da superfície, temperatura do ar, dias de calor extremo), <strong>sensibilidade</strong> (idade, renda, raça/cor, condições de moradia) e <strong>capacidade de adaptação</strong> (vegetação, saneamento, acesso à água). Desigualdade térmica não é só diferença de temperatura: uma área quente pode ter recursos para se proteger, e uma área menos quente pode concentrar populações muito vulneráveis.</p><h2>Princípios</h2><ul><li>Temperatura da superfície (satélite) e temperatura do ar (reanálise) são medidas diferentes e nunca são misturadas.</li><li>Cada indicador publicado traz fonte, período, unidade e método de agregação.</li><li>Correlações entre áreas não autorizam conclusões causais sobre indivíduos.</li><li>Scripts e dados processados ficam no repositório para reprodução.</li></ul><p>Veja a <a href="metodologia/">metodologia</a>.</p>',

      'method.title': 'Metodologia',
      'method.body': '<p class="lead">Estado: planejamento. Nenhum indicador térmico ou socioeconômico foi publicado ainda. Esta página será atualizada a cada indicador incluído.</p><h2>Escalas e unidades territoriais</h2><table><thead><tr><th>Escala</th><th>Unidade</th><th>Fontes principais</th></tr></thead><tbody><tr><td>Município do Rio de Janeiro</td><td>Setores censitários 2022</td><td>IBGE, Data.Rio, Landsat, MapBiomas</td></tr><tr><td>Estado do Rio de Janeiro</td><td>Municípios (92)</td><td>IBGE, Ipea, MODIS, ERA5-Land, MapBiomas</td></tr><tr><td>Brasil</td><td>Municípios (5.570)</td><td>IBGE, Ipea, ERA5-Land, MODIS, MapBiomas</td></tr><tr><td>América Latina</td><td>Países e unidades subnacionais</td><td>ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL</td></tr></tbody></table><h2>Dimensões analíticas</h2><table><thead><tr><th>Dimensão</th><th>Indicadores candidatos</th></tr></thead><tbody><tr><td>Exposição térmica</td><td>Temperatura da superfície, temperatura do ar, frequência de ondas de calor, dias de calor extremo</td></tr><tr><td>Vulnerabilidade socioeconômica</td><td>Renda, pobreza, escolaridade, raça/cor, densidade domiciliar</td></tr><tr><td>Vulnerabilidade demográfica</td><td>População idosa, crianças, densidade populacional</td></tr><tr><td>Capacidade de adaptação</td><td>Cobertura vegetal, arborização, saneamento, acesso à água</td></tr></tbody></table><h2>Princípios</h2><ol><li>Temperatura da superfície terrestre (LST, por satélite) e temperatura do ar (estações ou reanálise) são conceitos físicos distintos e aparecem como indicadores separados.</li><li>Para cada indicador registramos unidade, período, resolução original, tratamento de ausências e método de agregação espacial.</li><li>Nenhum dado simulado é apresentado como observação.</li><li>Comparações entre países usam apenas produtos harmonizados internacionalmente; dados nacionais aparecem como camada complementar, com diferenças de definição documentadas.</li><li>Associações entre áreas (falácia ecológica) não são interpretadas como relações individuais ou causais.</li></ol><h2>Classificação dos mapas</h2><p>Por padrão, cada indicador é dividido em cinco classes por quantis, calculadas em R no momento da publicação. O método e os limites de cada classe aparecem na legenda do mapa.</p><h2>Reprodutibilidade</h2><p>Os scripts em R que baixam, processam e publicam cada camada estão na pasta <code>R/</code> do <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">repositório</a>.</p>'
    },

    es: {
      'site.title': 'Atlas Interactivo de Desigualdad Térmica',
      'site.subtitle': 'Exposición al calor, vulnerabilidad social y justicia climática',
      'nav.label': 'Escalas del atlas',
      'nav.home': 'Inicio',
      'nav.rio': 'Río de Janeiro (ciudad)',
      'nav.rj': 'Estado de Río de Janeiro',
      'nav.br': 'Brasil',
      'nav.la': 'América Latina',
      'nav.method': 'Metodología',
      'nav.soon': 'próximamente',
      'lang.label': 'Idioma',
      'footer': 'Proyecto académico en desarrollo · <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">Código, datos y documentación en GitHub</a> · Mapa base © OpenStreetMap · OpenFreeMap',

      'map.indicator': 'Indicador',
      'map.loading': 'Cargando…',
      'map.loadingLayer': 'Cargando capa territorial…',
      'map.clickHint': 'Haga clic en una unidad del mapa para ver sus valores.',
      'map.sourcesTitle': 'Fuentes previstas',
      'map.detailsIn': 'Detalles en <a href="../metodologia/">Metodología</a>.',
      'map.boundariesOnly': 'Solo límites territoriales',
      'map.basemapOnly': 'Mapa base',
      'map.pending': 'pendiente',
      'map.noData': 'sin dato',
      'map.unit': 'Unidad',
      'map.units': 'unidades',
      'map.code': 'Código',
      'map.noIndicatorsYet': 'Los indicadores térmicos y socioeconómicos aún no se han publicado para esta escala.',
      'map.source': 'Fuente',
      'map.period': 'Período',
      'map.classes': 'Clases',
      'map.quantiles': 'cuantiles',
      'map.equalIntervals': 'intervalos iguales',
      'map.fixedIntervals': 'intervalos fijos',
      'map.nClasses': '{n} clases',
      'map.loaded': 'Capa cargada: {fonte} — {n} {unidades}.',
      'map.loadedNoCount': 'Capa cargada: {fonte}.',
      'map.nIndicators': '{n} indicador(es) publicados.',
      'map.noIndicators': 'Todavía sin indicadores asociados.',
      'map.layerError': 'No se pudo cargar la capa territorial. Se muestra solo el mapa base.',
      'map.libError': 'No se pudo cargar la biblioteca cartográfica (MapLibre).',
      'map.unavailable': 'Mapa no disponible.',
      'map.badgeBasemap': 'Mapa base',
      'map.ariaInteractive': 'Mapa interactivo',
      'map.ariaNavigable': 'Mapa navegable',

      'rio.title': 'Municipio de Río de Janeiro',
      'rio.desc': 'Sectores censales del Censo 2022 (IBGE).',
      'rio.notice': '<strong>En construcción.</strong> La cartografía oficial de sectores censales ya está en el mapa; los indicadores térmicos y socioeconómicos aún no se han publicado.',
      'rio.sources': 'IBGE (Censo 2022, sectores censales), imágenes Landsat (temperatura de superficie), MapBiomas (cobertura vegetal), Data.Rio.',
      'rio.noLayer': 'Capa de sectores censales aún no procesada. Ejecute el workflow “Preparar capas del atlas” en GitHub Actions.',
      'rio.planned': ['Temperatura de superficie (Landsat)', 'Ingreso del hogar', 'Cobertura vegetal', 'Población de 65 años o más', 'Población negra y parda'],

      'rj.title': 'Estado de Río de Janeiro',
      'rj.desc': 'Los 92 municipios del estado.',
      'rj.notice': '<strong>En construcción.</strong> Primer paso: límites municipales (IBGE 2022). Los indicadores se incorporarán tras la validación en la ciudad de Río.',
      'rj.sources': 'IBGE (límites municipales 2022, Censo 2022), Ipea, MODIS, ERA5-Land, MapBiomas.',
      'rj.noLayer': 'Capa municipal aún no procesada. Ejecute el workflow “Preparar capas del atlas” en GitHub Actions.',
      'rj.planned': ['Temperatura de superficie (MODIS)', 'Días de calor extremo (ERA5-Land)', 'Ingreso per cápita', 'Cobertura vegetal', 'Población de 65 años o más'],

      'br.title': 'Brasil',
      'br.desc': 'Municipios brasileños.',
      'br.notice': '<strong>Planificado.</strong> Esta escala usará municipios y, para bases grandes, capas PMTiles alojadas fuera de GitHub.',
      'br.sources': 'IBGE, Ipea, ERA5-Land (Copernicus), MODIS, MapBiomas.',
      'br.noLayer': 'Escala planificada. Los 5.570 municipios se publicarán en un formato optimizado (PMTiles).',
      'br.planned': ['Temperatura del aire (ERA5-Land)', 'Días de calor extremo (ERA5-Land)', 'Temperatura de superficie (MODIS)', 'Ingreso per cápita', 'Cobertura vegetal'],

      'la.title': 'América Latina',
      'la.desc': 'Países y unidades subnacionales.',
      'la.notice': '<strong>Planificado.</strong> Para garantizar la comparabilidad entre países, la primera capa usa solo productos armonizados internacionalmente (ERA5-Land, MODIS, WorldPop, GHSL). Los datos nacionales serán una capa complementaria, con las diferencias documentadas.',
      'la.sources': 'ERA5-Land, MODIS, WorldPop, GHSL, ESA WorldCover, CEPALSTAT, Banco Mundial, geoBoundaries, SALURBAL.',
      'la.noLayer': 'Escala planificada. Usará solo datos armonizados internacionalmente.',
      'la.planned': ['Temperatura del aire (ERA5-Land)', 'Temperatura de superficie (MODIS)', 'Población (WorldPop)', 'Urbanización (GHSL)', 'Cobertura del suelo (ESA WorldCover)', 'Indicadores sociales (CEPALSTAT)'],

      'home.title': '¿Quién está más expuesto al calor?',
      'home.lead': 'Un atlas abierto para analizar cómo se distribuye en el territorio la exposición al calor extremo y cómo se relaciona con el ingreso, la raza, la edad y la infraestructura urbana, en cuatro escalas.',
      'home.rio.d': 'Sectores censales 2022', 'home.rj.d': '92 municipios',
      'home.br.d': '5.570 municipios', 'home.la.d': 'Países y unidades subnacionales',
      'status.building': 'En construcción', 'status.planned': 'Planificado',
      'home.body': '<h2>Tres dimensiones, analizadas por separado</h2><p><strong>Exposición</strong> (temperatura de superficie, temperatura del aire, días de calor extremo), <strong>sensibilidad</strong> (edad, ingreso, raza, condiciones de vivienda) y <strong>capacidad de adaptación</strong> (vegetación, saneamiento, acceso al agua). La desigualdad térmica no es solo una diferencia de temperatura: un área calurosa puede contar con recursos para protegerse, y un área menos calurosa puede concentrar poblaciones muy vulnerables.</p><h2>Principios</h2><ul><li>La temperatura de superficie (satélite) y la temperatura del aire (reanálisis) son medidas distintas y nunca se mezclan.</li><li>Cada indicador publicado indica fuente, período, unidad y método de agregación.</li><li>Las correlaciones entre áreas no permiten conclusiones causales sobre individuos.</li><li>Los scripts y datos procesados se conservan en el repositorio para su reproducción.</li></ul><p>Vea la <a href="metodologia/">metodología</a>.</p>',

      'method.title': 'Metodología',
      'method.body': '<p class="lead">Estado: planificación. Todavía no se ha publicado ningún indicador térmico ni socioeconómico. Esta página se actualizará con cada nuevo indicador.</p><h2>Escalas y unidades territoriales</h2><table><thead><tr><th>Escala</th><th>Unidad</th><th>Fuentes principales</th></tr></thead><tbody><tr><td>Municipio de Río de Janeiro</td><td>Sectores censales 2022</td><td>IBGE, Data.Rio, Landsat, MapBiomas</td></tr><tr><td>Estado de Río de Janeiro</td><td>Municipios (92)</td><td>IBGE, Ipea, MODIS, ERA5-Land, MapBiomas</td></tr><tr><td>Brasil</td><td>Municipios (5.570)</td><td>IBGE, Ipea, ERA5-Land, MODIS, MapBiomas</td></tr><tr><td>América Latina</td><td>Países y unidades subnacionales</td><td>ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL</td></tr></tbody></table><h2>Dimensiones analíticas</h2><table><thead><tr><th>Dimensión</th><th>Indicadores candidatos</th></tr></thead><tbody><tr><td>Exposición térmica</td><td>Temperatura de superficie, temperatura del aire, frecuencia de olas de calor, días de calor extremo</td></tr><tr><td>Vulnerabilidad socioeconómica</td><td>Ingreso, pobreza, escolaridad, raza, hacinamiento</td></tr><tr><td>Vulnerabilidad demográfica</td><td>Personas mayores, niños, densidad de población</td></tr><tr><td>Capacidad de adaptación</td><td>Cobertura vegetal, arbolado, saneamiento, acceso al agua</td></tr></tbody></table><h2>Principios</h2><ol><li>La temperatura de la superficie terrestre (LST, por satélite) y la temperatura del aire (estaciones o reanálisis) son conceptos físicos distintos y aparecen como indicadores separados.</li><li>Para cada indicador registramos unidad, período, resolución original, tratamiento de datos faltantes y método de agregación espacial.</li><li>Ningún dato simulado se presenta como observación.</li><li>Las comparaciones entre países usan solo productos armonizados internacionalmente; los datos nacionales aparecen como capa complementaria, con las diferencias de definición documentadas.</li><li>Las asociaciones entre áreas (falacia ecológica) no se interpretan como relaciones individuales o causales.</li></ol><h2>Clasificación de los mapas</h2><p>Por defecto, cada indicador se divide en cinco clases por cuantiles, calculadas en R al publicarlo. El método y los límites de cada clase aparecen en la leyenda del mapa.</p><h2>Reproducibilidad</h2><p>Los scripts en R que descargan, procesan y publican cada capa están en la carpeta <code>R/</code> del <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">repositorio</a>.</p>'
    }
  };

  // ---------- escolha do idioma ----------
  function valido(c) { return !!T[c]; }
  function lerSalvo() { try { return localStorage.getItem('atlas-idioma'); } catch (e) { return null; } }
  function salvar(c) { try { localStorage.setItem('atlas-idioma', c); } catch (e) { /* ignora */ } }

  function idiomaInicial() {
    var q = new URLSearchParams(location.search).get('lang');
    if (q && valido(q)) return q;
    var s = lerSalvo();
    if (s && valido(s)) return s;
    var nav = (navigator.languages || [navigator.language || '']);
    for (var i = 0; i < nav.length; i++) {
      var c = String(nav[i]).slice(0, 2).toLowerCase();
      if (c === 'pt' || c === 'es') return c;
      if (c === 'en') return 'en';
    }
    return 'en';
  }

  var atual = idiomaInicial();

  function t(chave, vars) {
    var v = (T[atual] && T[atual][chave]);
    if (v === undefined) v = T.en[chave];
    if (v === undefined) return chave;
    if (typeof v === 'string' && vars) {
      v = v.replace(/\{(\w+)\}/g, function (_, k) { return vars[k] === undefined ? '' : vars[k]; });
    }
    return v;
  }

  // Texto vindo dos manifestos: string simples ou {pt, en, es}.
  function tr(valor) {
    if (valor === null || valor === undefined) return '';
    if (typeof valor === 'object') return valor[atual] || valor.en || valor.pt || '';
    return String(valor);
  }

  function info() { for (var i = 0; i < IDIOMAS.length; i++) if (IDIOMAS[i].codigo === atual) return IDIOMAS[i]; return IDIOMAS[0]; }

  function aplicar() {
    document.documentElement.lang = info().html;
    document.querySelectorAll('[data-i18n]').forEach(function (el) {
      el.innerHTML = t(el.getAttribute('data-i18n'));
    });
    document.querySelectorAll('[data-i18n-attr]').forEach(function (el) {
      el.getAttribute('data-i18n-attr').split(';').forEach(function (par) {
        var p = par.split(':');
        if (p.length === 2) el.setAttribute(p[0].trim(), t(p[1].trim()));
      });
    });
    var tit = document.body && document.body.getAttribute('data-i18n-titulo');
    document.title = tit ? t(tit) + ' · ' + t('site.title') : t('site.title');
    // Mantém o idioma ao navegar entre páginas (também funciona sem localStorage).
    document.querySelectorAll('a[data-nav]').forEach(function (a) {
      var base = a.getAttribute('data-nav');
      a.setAttribute('href', base + (atual === 'en' ? '' : '?lang=' + atual));
    });
    var sel = document.getElementById('idioma');
    if (sel) sel.value = atual;
  }

  function definir(c) {
    if (!valido(c) || c === atual) return;
    atual = c;
    salvar(c);
    var u = new URL(location.href);
    if (c === 'en') u.searchParams.delete('lang'); else u.searchParams.set('lang', c);
    history.replaceState(null, '', u);
    aplicar();
    document.dispatchEvent(new CustomEvent('atlas:idioma', { detail: { idioma: c } }));
  }

  function montarSeletor() {
    var sel = document.getElementById('idioma');
    if (!sel) return;
    sel.innerHTML = IDIOMAS.map(function (i) {
      return '<option value="' + i.codigo + '" lang="' + i.html + '">' + i.nome + '</option>';
    }).join('');
    sel.value = atual;
    sel.addEventListener('change', function (e) { definir(e.target.value); });
  }

  window.AtlasI18n = {
    t: t, tr: tr, definir: definir, aplicar: aplicar,
    get idioma() { return atual; },
    get locale() { return info().locale; },
    idiomas: IDIOMAS.map(function (i) { return i.codigo; }),
    _dicionario: T
  };

  document.addEventListener('DOMContentLoaded', function () { montarSeletor(); aplicar(); });
})();
