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

      'biv.t1': 'Cooler', 'biv.t2': 'Intermediate temp.', 'biv.t3': 'Hotter',
      'biv.r1': 'lower income', 'biv.r2': 'middle income', 'biv.r3': 'higher income',
      'biv.note': 'Each third groups about one third of the city’s households. Magenta: hotter and lower-income tracts.',
      'ineq.title': 'Heat and income',
      'ineq.hotter': 'Households in the poorest fifth live in tracts whose surfaces are on average <strong>{d} °C hotter</strong> than those of the richest fifth (95% CI {lo} to {hi} °C).',
      'ineq.cooler': 'Households in the poorest fifth live in tracts whose surfaces are on average <strong>{d} °C cooler</strong> than those of the richest fifth (95% CI {lo} to {hi} °C).',
      'ineq.peak': 'The highest average is in the <strong>{n} income fifth</strong>, not the poorest: the gap is mainly between the richest fifth and the rest of the city.',
      'ineq.ord': ['first', 'second', 'third', 'fourth', 'fifth'],
      'arv.title': 'Street trees and income',
      'arv.sentence': 'In the poorest fifth of households, <strong>{a}%</strong> of residents live on blocks with at least one street tree; in the richest fifth, <strong>{b}%</strong>.',
      'arv.cooler': 'Tracts in the most-treed fifth have surfaces {d} °C cooler, on average, than those in the least-treed fifth.',
      'arv.note': 'Share of residents on block faces with at least one tree (census enumerator observation, 2022), by fifth of household-head income, weighted by households. Area-level association.',
      'grp.title': 'Who lives in the hottest places?',
      'grp.sentence': 'Black and brown residents (<em>pretos</em> and <em>pardos</em>) live in tracts whose surfaces are on average <strong>{d} °C hotter</strong> than those of white residents (95% CI {lo} to {hi} °C)',
      'grp.sentenceCooler': 'Black and brown residents (<em>pretos</em> and <em>pardos</em>) live in tracts whose surfaces are on average <strong>{d} °C cooler</strong> than those of white residents (95% CI {lo} to {hi} °C)',
      'grp.treesFewer': ', and fewer of them live on blocks with street trees ({a}% vs {b}%).',
      'grp.treesMore': ', and more of them live on blocks with street trees ({a}% vs {b}%).',
      'grp.colTemp': 'Surface temp.', 'grp.colTrees': 'On blocks with trees',
      'grp.moradores': 'All residents', 'grp.branca': 'White', 'grp.preta': 'Black (preta)', 'grp.parda': 'Brown (parda)',
      'grp.a60': 'Aged 60+', 'grp.a0_4': 'Children 0–4',
      'grp.note': 'Values of the tract where the average person of each group lives (weighted by the group’s population per tract). 2022 Census self-declared color or race. Area-level association.',
      'ineq.q1': 'Poorest 20%', 'ineq.q5': 'Richest 20%', 'ineq.qn': 'Fifth {n}',
      'ineq.note': 'Mean summer surface temperature by fifth of household-head income, weighted by households. Bars start at {base} °C. Area-level association, not individual exposure; see Methodology.',

      'rio.title': 'City of Rio de Janeiro',
      'rio.desc': '2022 Census tracts (IBGE).',
      'rio.notice': '<strong>Published:</strong> summer land surface temperature (Landsat 8–9, summers 2022/23 to 2024/25). Surface temperature is not air temperature: it shows how hot surfaces get on clear summer mornings. Also available: income, street trees, age and color or race (2022 Census), and a bivariate map of heat × income.',
      'rio.sources': 'IBGE (2022 Census: tract boundaries, household-head income, street trees), Landsat imagery (land surface temperature), MapBiomas (vegetation cover), Data.Rio.',
      'rio.noLayer': 'Census tract layer not processed yet. Run the “Prepare atlas layers” workflow on GitHub Actions.',
      'rio.planned': ['Tree canopy cover (satellite)'],

      'rj.title': 'Rio de Janeiro State',
      'rj.desc': 'The state’s 92 municipalities.',
      'rj.notice': '<strong>How to read:</strong> municipal values are built from all census tracts in the state and weighted by people, so temperature is measured <em>where people live</em>, not averaged over forests and farmland. The two “heat gap” indicators show inequality <em>inside</em> each municipality: red means the poorer group (or Black and brown residents) lives in hotter places, blue in cooler ones. In many smaller municipalities the richer households live in the denser, hotter town centre, while poorer ones live in rural, greener areas. Panels below summarise all tracts in the state.',
      'rj.sources': 'Landsat 8–9 (USGS, via Microsoft Planetary Computer); IBGE, 2022 Census (tract boundaries, income, color or race, age, street trees); municipal boundaries via geobr (Ipea).',
      'rj.noLayer': 'Municipal layer not processed yet. Run the “Prepare atlas layers” workflow on GitHub Actions.',
      'rj.planned': ['Extreme heat days (ERA5-Land)'],

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
      'home.rio.d': '2022 census tracts', 'home.rj.d': '92 municipalities, built from all census tracts',
      'home.br.d': '5,570 municipalities', 'home.la.d': 'Countries and subnational units',
      'status.building': 'In progress', 'status.planned': 'Planned',
      'home.body': '<h2>Three dimensions, analysed separately</h2><p><strong>Exposure</strong> (land surface temperature, air temperature, extreme heat days), <strong>sensitivity</strong> (age, income, race, housing conditions) and <strong>adaptive capacity</strong> (vegetation, sanitation, access to water). Heat inequality is not only a difference in temperature: a hot area may have the resources to protect itself, while a cooler area may concentrate highly vulnerable people.</p><h2>Principles</h2><ul><li>Land surface temperature (satellite) and air temperature (reanalysis) are different measures and are never mixed.</li><li>Every published indicator states its source, period, unit and aggregation method.</li><li>Area-level correlations do not support causal conclusions about individuals.</li><li>Scripts and processed data are kept in the repository for reproducibility.</li></ul><p>See the <a href="metodologia/">methodology</a>.</p>',

      'method.title': 'Methodology',
      'method.body': '<p class="lead">Status: city of Rio and Rio de Janeiro State, with summer surface temperature, income, street trees, age, color or race and their relationships. This page is updated with each new indicator.</p><h2>Scales and spatial units</h2><table><thead><tr><th>Scale</th><th>Unit</th><th>Main sources</th></tr></thead><tbody><tr><td>City of Rio de Janeiro</td><td>2022 census tracts</td><td>IBGE, Data.Rio, Landsat, MapBiomas</td></tr><tr><td>Rio de Janeiro State</td><td>Municipalities (92), built from 2022 census tracts</td><td>IBGE, Ipea, Landsat; ERA5-Land planned</td></tr><tr><td>Brazil</td><td>Municipalities (5,570)</td><td>IBGE, Ipea, ERA5-Land, MODIS, MapBiomas</td></tr><tr><td>Latin America</td><td>Countries and subnational units</td><td>ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL</td></tr></tbody></table><h2>Analytical dimensions</h2><table><thead><tr><th>Dimension</th><th>Candidate indicators</th></tr></thead><tbody><tr><td>Heat exposure</td><td>Land surface temperature, air temperature, heatwave frequency, extreme heat days</td></tr><tr><td>Socioeconomic vulnerability</td><td>Income, poverty, education, race, household crowding</td></tr><tr><td>Demographic vulnerability</td><td>Older adults, children, population density</td></tr><tr><td>Adaptive capacity</td><td>Vegetation cover, street trees, sanitation, access to water</td></tr></tbody></table><h2>Principles</h2><ol><li>Land surface temperature (LST, from satellites) and air temperature (stations or reanalysis) are distinct physical concepts and appear as separate indicators.</li><li>For each indicator we record unit, period, original resolution, treatment of missing values and spatial aggregation method.</li><li>No simulated data is presented as an observation.</li><li>Cross-country comparisons use only internationally harmonised products; national data appears as a complementary layer, with differences in definitions documented.</li><li>Area-level associations (ecological fallacy) are not interpreted as individual or causal relationships.</li></ol><h2>Summer land surface temperature (city of Rio)</h2><p><strong>Data:</strong> Landsat 8 and 9, Collection 2 Level-2 surface temperature band (USGS), accessed through Microsoft Planetary Computer. All scenes from 1 December to 31 March in the summers of 2022/23, 2023/24 and 2024/25 with scene cloud cover below 70% (27 scenes, WRS-2 path 217, row 76). Overpass at about 10 a.m. local time.</p><p><strong>Processing:</strong> pixels flagged as fill, cloud, dilated cloud, cirrus, cloud shadow or water in the QA_PIXEL band are removed. For each 30 m pixel we take the median of all valid observations, requiring at least 3. Each census tract receives the area-weighted median of the pixels it covers; tracts with less than half a valid pixel are left without data.</p><p><strong>Difference from the city median:</strong> tract value minus the median of all tracts (41.8 °C). Fixed classes: below −4, −4 to −1.5, −1.5 to 1.5, 1.5 to 4, above 4 °C.</p><p><strong>Limits:</strong> land surface temperature measures how hot surfaces (roofs, pavement, vegetation) get, not the air temperature people breathe, and only on clear mornings. It is a good indicator of the spatial pattern of urban heat, not of thermal comfort or health risk on its own. The script, the list of scenes and the 30 m raster are in the repository.</p><h2>Household-head income (city of Rio)</h2><p><strong>Data:</strong> IBGE, 2022 Census, universe results, <em>Census tract aggregates – Income of the household head</em> (release of May 2026). Variables V06004 (mean) and V06006 (median) monthly nominal income of household heads <em>with income</em> in occupied private permanent households, and V06001 (number of household heads), used as weight. Values in nominal R$ of July 2022 (1 minimum wage = R$ 1,212). 13,368 of 13,782 tracts have data; the rest have no households or were suppressed by IBGE for confidentiality.</p><p><strong>Limits:</strong> this is not per capita household income. Heads without income are excluded from the mean, so tracts with many such households look better off than they are.</p><h2>Heat × income</h2><p><strong>Income fifths:</strong> tracts are ordered by mean household-head income and grouped so that each fifth holds about 20% of the city’s households (≈487,000). For each fifth we compute the household-weighted mean summer surface temperature. The 95% confidence interval of the difference between the poorest and richest fifths comes from 2,000 bootstrap resamples of tracts.</p><p><strong>Result (2022/23–2024/25 summers):</strong> poorest fifth 41.6 °C, second 41.9 °C, third 42.7 °C, fourth 42.2 °C, richest 38.5 °C. Difference poorest − richest: 3.0 °C (95% CI 2.9 to 3.2). The relationship is not linear: the hottest surfaces are in middle-income tracts, and the main divide separates the richest fifth from the rest of the city. Part of the poorest fifth lives in hillside favelas next to forest and in less dense areas of the West Zone, where surfaces are cooler.</p><p><strong>Bivariate map:</strong> household-weighted terciles of temperature (limits 40.5 and 43.0 °C) and of income (R$ 2,000 and R$ 3,900), combined into 9 classes.</p><p><strong>Reading:</strong> these are associations between areas (ecological fallacy). They do not show that each low-income household is more exposed, nor that income causes temperature.</p><h2>Street trees (city of Rio)</h2><p><strong>Data:</strong> IBGE, 2022 Census, <em>urban characteristics of the surroundings of households</em>, residents file. Variables V05230–V05233: residents of occupied private households, in tracts selected for the surroundings survey, by the number of trees on their block face (none, 1–2, 3–4, 5 or more), as observed by census enumerators. Block faces not observed (V05234, 0.9% of residents) are excluded. 13,235 tracts have data (at least 20 residents observed); tracts outside the survey, mostly non-urban, have none.</p><p><strong>Indicators:</strong> share of residents on block faces with at least one tree, and with 5 or more trees. City-wide: 64.5% and 37.9%.</p><p><strong>Result:</strong> by income fifth, the share of residents on blocks with trees rises from 26% (poorest) to 51%, 74%, 84% and 95% (richest); with 5+ trees, from 8% to 79%. Tracts in the most-treed fifth have summer surfaces about 1.9 °C cooler than those in the least-treed fifth.</p><p><strong>Limits:</strong> this is a count of trees on the street in front of the home, not canopy cover, and does not include parks, forests or backyards. In favelas, block faces are often narrow alleys where street trees are rare even close to forest.</p><h2>Age and color or race (city of Rio)</h2><p><strong>Data:</strong> IBGE, 2022 Census, census tract aggregates (universe), <em>demography</em> and <em>color or race</em> files. Variables V01006 (residents), V01031 (aged 0–4), V01040 + V01041 (aged 60–69 and 70+), V01318 (preta) and V01320 (parda). The census does not separate 65+ in this file; we use 60+, the legal definition of older person in Brazil. Color or race is self-declared using IBGE categories; <em>preta</em> and <em>parda</em> together form the Black population in Brazilian statistics.</p><p><strong>Indicators:</strong> share of residents aged 60+, aged 0–4, and preta or parda. City-wide: 20.2%, 5.0% and 54.4% (white: 45.3%). Tracts with fewer than 20 residents have no data. IBGE suppresses small counts for confidentiality; this mostly affects the yellow (Asian-descendant) and Indigenous groups, which are counted as zero where suppressed and are not shown separately.</p><p><strong>Exposure by group:</strong> the household-weighting used for income is replaced by the number of people of each group in each tract. Result: white residents 41.0 °C and 73.5% on blocks with trees; preta 41.9 °C and 55.3%; parda 41.8 °C and 57.3%. Black and brown − white: 0.83 °C (95% CI 0.78 to 0.88), 16.8 percentage points fewer on treed blocks. Older adults (41.4 °C, 72.8%) are not more exposed than the average resident, because they are concentrated in older, wealthier neighborhoods; children 0–4 are slightly more exposed (41.5 °C, 57.7%).</p><h2>Rio de Janeiro State</h2><p>The state map shows the 92 municipalities, but every value is built from the 2022 census tracts (about 41,700 tracts in the IBGE boundary file). This keeps the state scale consistent with the city of Rio and measures heat <em>where people live</em>: a municipality with large forested or rural areas is not made to look cooler simply because most of its area is uninhabited.</p><p><strong>Surface temperature.</strong> Same imagery, summers and cloud mask as the city of Rio (Landsat 8–9, December–March, 2022/23 to 2024/25), but summarised scene by scene: for each scene, the mean of clear pixels in each tract (weighted by the share of each pixel inside the tract), used only when at least half of the tract is clear; scenes from the same date are averaged, and the tract value is the median across dates (at least 3). This avoids building a per-pixel composite across ten Landsat tiles and two UTM zones. In the 13,733 tracts of the city of Rio, the two methods agree closely (correlation 0.994; mean difference 0.02 °C).</p><p><strong>Municipal values.</strong> Temperature is the mean of tract values weighted by residents; income is weighted by household heads; shares (Black and brown population, older adults, residents on treed blocks) are summed over tracts before dividing. The “difference from state” indicator subtracts the state value (all tracts, weighted by residents).</p><p><strong>Inequality within each municipality.</strong> <em>Poorest − richest:</em> surface temperature of the poorest fifth of households minus the richest fifth, with fifths formed from that municipality’s own tracts (household-weighted); only municipalities with at least 30 tracts with data. <em>Black and brown − white:</em> group-weighted mean temperature difference, only where each group has at least 2,000 people in tracts with data. Municipalities below these thresholds appear without a value rather than with an unstable estimate. The panels below the map summarise all tracts in the state, with 95% bootstrap intervals (500 replicates).</p><h2>Map classification</h2><p>By default each indicator is split into five quantile classes, computed in R at publication time. The method and class limits are shown in the map legend.</p><h2>Reproducibility</h2><p>The R scripts that download, process and publish each layer are in the <code>R/</code> folder of the <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">repository</a>.</p>'
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

      'biv.t1': 'Menos quente', 'biv.t2': 'Temp. intermediária', 'biv.t3': 'Mais quente',
      'biv.r1': 'renda mais baixa', 'biv.r2': 'renda média', 'biv.r3': 'renda mais alta',
      'biv.note': 'Cada terço reúne cerca de um terço dos domicílios da cidade. Magenta: setores mais quentes e de renda mais baixa.',
      'ineq.title': 'Calor e renda',
      'ineq.hotter': 'Os domicílios do quinto mais pobre vivem em setores cujas superfícies são, em média, <strong>{d} °C mais quentes</strong> que as do quinto mais rico (IC 95%: {lo} a {hi} °C).',
      'ineq.cooler': 'Os domicílios do quinto mais pobre vivem em setores cujas superfícies são, em média, <strong>{d} °C menos quentes</strong> que as do quinto mais rico (IC 95%: {lo} a {hi} °C).',
      'ineq.peak': 'A maior média está no <strong>{n} quinto</strong>, e não no mais pobre: a diferença se dá sobretudo entre o quinto mais rico e o resto da cidade.',
      'ineq.ord': ['1º', '2º', '3º', '4º', '5º'],
      'arv.title': 'Árvores e renda',
      'arv.sentence': 'No quinto mais pobre dos domicílios, <strong>{a}%</strong> dos moradores vivem em faces de quadra com ao menos uma árvore; no quinto mais rico, <strong>{b}%</strong>.',
      'arv.cooler': 'Os setores do quinto mais arborizado têm superfícies, em média, {d} °C menos quentes que os do quinto menos arborizado.',
      'arv.note': 'Proporção de moradores em faces de quadra com ao menos uma árvore (observação do recenseador, 2022), por quinto da renda do responsável, ponderada por domicílios. Associação entre áreas.',
      'grp.title': 'Quem mora nos lugares mais quentes?',
      'grp.sentence': 'Os moradores pretos e pardos vivem em setores cujas superfícies são, em média, <strong>{d} °C mais quentes</strong> que as dos moradores brancos (IC 95%: {lo} a {hi} °C)',
      'grp.sentenceCooler': 'Os moradores pretos e pardos vivem em setores cujas superfícies são, em média, <strong>{d} °C menos quentes</strong> que as dos moradores brancos (IC 95%: {lo} a {hi} °C)',
      'grp.treesFewer': ', e uma parcela menor deles vive em faces de quadra com árvores ({a}% contra {b}%).',
      'grp.treesMore': ', e uma parcela maior deles vive em faces de quadra com árvores ({a}% contra {b}%).',
      'grp.colTemp': 'Temp. superfície', 'grp.colTrees': 'Em faces com árvores',
      'grp.moradores': 'Todos os moradores', 'grp.branca': 'Brancos', 'grp.preta': 'Pretos', 'grp.parda': 'Pardos',
      'grp.a60': '60 anos ou mais', 'grp.a0_4': 'Crianças de 0 a 4',
      'grp.note': 'Valores do setor onde vive a pessoa média de cada grupo (ponderados pela população do grupo em cada setor). Cor ou raça autodeclarada, Censo 2022. Associação entre áreas.',
      'ineq.q1': '20% mais pobres', 'ineq.q5': '20% mais ricos', 'ineq.qn': '{n}º quinto',
      'ineq.note': 'Temperatura média da superfície no verão por quinto da renda do responsável, ponderada por domicílios. As barras começam em {base} °C. Associação entre áreas, não exposição individual; veja a Metodologia.',

      'rio.title': 'Município do Rio de Janeiro',
      'rio.desc': 'Setores censitários do Censo 2022 (IBGE).',
      'rio.notice': '<strong>Publicado:</strong> temperatura da superfície no verão (Landsat 8–9, verões 2022/23 a 2024/25). Temperatura da superfície não é temperatura do ar: ela mostra o quanto as superfícies esquentam em manhãs de verão sem nuvens. Também disponíveis: renda, arborização do entorno, idade e cor ou raça (Censo 2022), e o mapa bivariado calor × renda.',
      'rio.sources': 'IBGE (Censo 2022: malha de setores, renda do responsável, arborização do entorno), imagens Landsat (temperatura da superfície), MapBiomas (cobertura vegetal), Data.Rio.',
      'rio.noLayer': 'Malha censitária ainda não processada. Rode o workflow “Preparar camadas do atlas” no GitHub Actions.',
      'rio.planned': ['Cobertura de copa (satélite)'],

      'rj.title': 'Estado do Rio de Janeiro',
      'rj.desc': 'Os 92 municípios fluminenses.',
      'rj.notice': '<strong>Como ler:</strong> os valores municipais são calculados a partir de todos os setores censitários do estado e ponderados pelas pessoas; assim, a temperatura é medida <em>onde as pessoas moram</em>, não na média de florestas e áreas rurais. Os dois indicadores de “desigualdade térmica” mostram a desigualdade <em>dentro</em> de cada município: vermelho indica que o grupo mais pobre (ou os moradores pretos e pardos) mora em lugares mais quentes; azul, em lugares menos quentes. Em muitos municípios menores, os domicílios mais ricos ficam no centro urbano, mais denso e quente, e os mais pobres em áreas rurais e mais verdes. Os painéis abaixo resumem todos os setores do estado.',
      'rj.sources': 'Landsat 8–9 (USGS, via Microsoft Planetary Computer); IBGE, Censo 2022 (malha de setores, renda, cor ou raça, idade, arborização do entorno); malha municipal via geobr (Ipea).',
      'rj.noLayer': 'Malha municipal ainda não processada. Rode o workflow “Preparar camadas do atlas” no GitHub Actions.',
      'rj.planned': ['Dias de calor extremo (ERA5-Land)'],

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
      'home.rio.d': 'Setores censitários 2022', 'home.rj.d': '92 municípios, a partir de todos os setores',
      'home.br.d': '5.570 municípios', 'home.la.d': 'Países e unidades subnacionais',
      'status.building': 'Em construção', 'status.planned': 'Planejado',
      'home.body': '<h2>Três dimensões, analisadas separadamente</h2><p><strong>Exposição</strong> (temperatura da superfície, temperatura do ar, dias de calor extremo), <strong>sensibilidade</strong> (idade, renda, raça/cor, condições de moradia) e <strong>capacidade de adaptação</strong> (vegetação, saneamento, acesso à água). Desigualdade térmica não é só diferença de temperatura: uma área quente pode ter recursos para se proteger, e uma área menos quente pode concentrar populações muito vulneráveis.</p><h2>Princípios</h2><ul><li>Temperatura da superfície (satélite) e temperatura do ar (reanálise) são medidas diferentes e nunca são misturadas.</li><li>Cada indicador publicado traz fonte, período, unidade e método de agregação.</li><li>Correlações entre áreas não autorizam conclusões causais sobre indivíduos.</li><li>Scripts e dados processados ficam no repositório para reprodução.</li></ul><p>Veja a <a href="metodologia/">metodologia</a>.</p>',

      'method.title': 'Metodologia',
      'method.body': '<p class="lead">Estado: município do Rio e estado do Rio de Janeiro, com temperatura da superfície no verão, renda, arborização do entorno, idade, cor ou raça e as relações entre eles. Esta página é atualizada a cada indicador incluído.</p><h2>Escalas e unidades territoriais</h2><table><thead><tr><th>Escala</th><th>Unidade</th><th>Fontes principais</th></tr></thead><tbody><tr><td>Município do Rio de Janeiro</td><td>Setores censitários 2022</td><td>IBGE, Data.Rio, Landsat, MapBiomas</td></tr><tr><td>Estado do Rio de Janeiro</td><td>Municípios (92), calculados a partir dos setores de 2022</td><td>IBGE, Ipea, Landsat; ERA5-Land previsto</td></tr><tr><td>Brasil</td><td>Municípios (5.570)</td><td>IBGE, Ipea, ERA5-Land, MODIS, MapBiomas</td></tr><tr><td>América Latina</td><td>Países e unidades subnacionais</td><td>ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL</td></tr></tbody></table><h2>Dimensões analíticas</h2><table><thead><tr><th>Dimensão</th><th>Indicadores candidatos</th></tr></thead><tbody><tr><td>Exposição térmica</td><td>Temperatura da superfície, temperatura do ar, frequência de ondas de calor, dias de calor extremo</td></tr><tr><td>Vulnerabilidade socioeconômica</td><td>Renda, pobreza, escolaridade, raça/cor, densidade domiciliar</td></tr><tr><td>Vulnerabilidade demográfica</td><td>População idosa, crianças, densidade populacional</td></tr><tr><td>Capacidade de adaptação</td><td>Cobertura vegetal, arborização, saneamento, acesso à água</td></tr></tbody></table><h2>Princípios</h2><ol><li>Temperatura da superfície terrestre (LST, por satélite) e temperatura do ar (estações ou reanálise) são conceitos físicos distintos e aparecem como indicadores separados.</li><li>Para cada indicador registramos unidade, período, resolução original, tratamento de ausências e método de agregação espacial.</li><li>Nenhum dado simulado é apresentado como observação.</li><li>Comparações entre países usam apenas produtos harmonizados internacionalmente; dados nacionais aparecem como camada complementar, com diferenças de definição documentadas.</li><li>Associações entre áreas (falácia ecológica) não são interpretadas como relações individuais ou causais.</li></ol><h2>Temperatura da superfície no verão (município do Rio)</h2><p><strong>Dados:</strong> Landsat 8 e 9, banda de temperatura da superfície da Collection 2 Level-2 (USGS), acessada pelo Microsoft Planetary Computer. Todas as cenas de 1º de dezembro a 31 de março dos verões 2022/23, 2023/24 e 2024/25 com cobertura de nuvens abaixo de 70% (27 cenas, órbita/ponto WRS-2 217/076). Passagem por volta das 10h (horário local).</p><p><strong>Processamento:</strong> são descartados os pixels marcados na banda QA_PIXEL como preenchimento, nuvem, nuvem dilatada, cirro, sombra de nuvem ou água. Para cada pixel de 30 m tomamos a mediana de todas as observações válidas, exigindo pelo menos 3. Cada setor censitário recebe a mediana ponderada pela área dos pixels que cobre; setores com menos de meio pixel válido ficam sem dado.</p><p><strong>Diferença para a mediana da cidade:</strong> valor do setor menos a mediana de todos os setores (41,8 °C). Classes fixas: abaixo de −4, −4 a −1,5, −1,5 a 1,5, 1,5 a 4, acima de 4 °C.</p><p><strong>Limites:</strong> a temperatura da superfície mede o quanto as superfícies (telhados, asfalto, vegetação) esquentam, não a temperatura do ar que as pessoas respiram, e apenas em manhãs sem nuvens. É um bom indicador do padrão espacial do calor urbano, mas não, sozinha, de conforto térmico ou risco à saúde. O script, a lista de cenas e o raster de 30 m estão no repositório.</p><h2>Renda do responsável (município do Rio)</h2><p><strong>Dados:</strong> IBGE, Censo 2022, resultados do universo, <em>Agregados por setores censitários – Rendimento do responsável</em> (versão de maio de 2026). Variáveis V06004 (média) e V06006 (mediana) do rendimento nominal mensal das pessoas responsáveis <em>com rendimentos</em> por domicílios particulares permanentes ocupados, e V06001 (pessoas responsáveis), usada como peso. Valores em R$ nominais de julho de 2022 (1 salário mínimo = R$ 1.212). 13.368 dos 13.782 setores têm dado; os demais não têm domicílios ou foram suprimidos pelo IBGE por sigilo.</p><p><strong>Limites:</strong> não é renda domiciliar per capita. Responsáveis sem rendimento ficam fora da média, o que faz setores com muitos desses domicílios parecerem em melhor situação do que estão.</p><h2>Calor × renda</h2><p><strong>Quintos de renda:</strong> os setores são ordenados pela renda média do responsável e agrupados de modo que cada quinto reúna cerca de 20% dos domicílios da cidade (≈487 mil). Para cada quinto calculamos a temperatura média da superfície no verão, ponderada por domicílios. O intervalo de confiança de 95% da diferença entre o quinto mais pobre e o mais rico vem de 2.000 reamostragens bootstrap de setores.</p><p><strong>Resultado (verões 2022/23–2024/25):</strong> quinto mais pobre 41,6 °C, segundo 41,9 °C, terceiro 42,7 °C, quarto 42,2 °C, mais rico 38,5 °C. Diferença mais pobre − mais rico: 3,0 °C (IC 95%: 2,9 a 3,2). A relação não é linear: as superfícies mais quentes estão nos setores de renda intermediária, e a principal divisão separa o quinto mais rico do resto da cidade. Parte do quinto mais pobre vive em favelas de encosta junto à floresta e em áreas menos densas da Zona Oeste, onde as superfícies são menos quentes.</p><p><strong>Mapa bivariado:</strong> tercis, ponderados por domicílios, de temperatura (limites 40,5 e 43,0 °C) e de renda (R$ 2.000 e R$ 3.900), combinados em 9 classes.</p><p><strong>Leitura:</strong> são associações entre áreas (falácia ecológica). Não mostram que cada domicílio de baixa renda está mais exposto, nem que a renda causa a temperatura.</p><h2>Arborização do entorno (município do Rio)</h2><p><strong>Dados:</strong> IBGE, Censo 2022, <em>características urbanísticas do entorno dos domicílios</em>, arquivo de moradores. Variáveis V05230–V05233: moradores em domicílios particulares permanentes ocupados, em setores escolhidos para a pesquisa do entorno, segundo o número de árvores na face de quadra (nenhuma, 1–2, 3–4, 5 ou mais), observado pelo recenseador. Faces não observadas (V05234, 0,9% dos moradores) ficam fora. 13.235 setores têm dado (ao menos 20 moradores observados); setores fora da pesquisa, em geral não urbanos, ficam sem dado.</p><p><strong>Indicadores:</strong> proporção de moradores em faces com ao menos uma árvore e com 5 ou mais árvores. Na cidade: 64,5% e 37,9%.</p><p><strong>Resultado:</strong> por quinto de renda, a proporção de moradores em faces com árvores sobe de 26% (mais pobres) para 51%, 74%, 84% e 95% (mais ricos); com 5 ou mais árvores, de 8% para 79%. Os setores do quinto mais arborizado têm superfícies no verão cerca de 1,9 °C menos quentes que os do quinto menos arborizado.</p><p><strong>Limites:</strong> é a contagem de árvores na rua em frente ao domicílio, não cobertura de copa, e não inclui parques, florestas ou quintais. Nas favelas, as faces de quadra costumam ser becos estreitos, onde árvores de rua são raras mesmo perto da floresta.</p><h2>Idade e cor ou raça (município do Rio)</h2><p><strong>Dados:</strong> IBGE, Censo 2022, agregados por setores censitários (universo), arquivos <em>demografia</em> e <em>cor ou raça</em>. Variáveis V01006 (moradores), V01031 (0 a 4 anos), V01040 + V01041 (60 a 69 e 70 anos ou mais), V01318 (preta) e V01320 (parda). O arquivo não separa 65+; usamos 60+, definição legal de pessoa idosa no Brasil. Cor ou raça é autodeclarada segundo as categorias do IBGE; pretos e pardos formam a população negra nas estatísticas brasileiras.</p><p><strong>Indicadores:</strong> proporção de moradores com 60 anos ou mais, de 0 a 4 anos e pretos ou pardos. Na cidade: 20,2%, 5,0% e 54,4% (brancos: 45,3%). Setores com menos de 20 moradores ficam sem dado. O IBGE suprime contagens pequenas por sigilo; isso afeta sobretudo amarelos e indígenas, contados como zero onde suprimidos e não mostrados em separado.</p><p><strong>Exposição por grupo:</strong> a ponderação por domicílios usada na renda é substituída pelo número de pessoas de cada grupo em cada setor. Resultado: brancos 41,0 °C e 73,5% em faces com árvores; pretos 41,9 °C e 55,3%; pardos 41,8 °C e 57,3%. Pretos e pardos − brancos: 0,83 °C (IC 95%: 0,78 a 0,88) e 16,8 pontos percentuais a menos em faces arborizadas. As pessoas idosas (41,4 °C, 72,8%) não estão mais expostas que o morador médio, porque se concentram em bairros mais antigos e de renda mais alta; as crianças de 0 a 4 anos estão um pouco mais expostas (41,5 °C, 57,7%).</p><h2>Estado do Rio de Janeiro</h2><p>O mapa estadual mostra os 92 municípios, mas todos os valores são calculados a partir dos setores censitários de 2022 (cerca de 41.700 setores na malha do IBGE). Isso mantém a escala estadual coerente com o município do Rio e mede o calor <em>onde as pessoas moram</em>: um município com grandes áreas de floresta ou rurais não parece mais fresco só porque a maior parte do seu território é desabitada.</p><p><strong>Temperatura da superfície.</strong> Mesmas imagens, verões e máscara de nuvens do município do Rio (Landsat 8–9, dezembro a março, 2022/23 a 2024/25), mas resumidas imagem por imagem: em cada cena, a média dos pixels limpos de cada setor (ponderada pela fração de cada pixel dentro do setor), usada só quando ao menos metade do setor está sem nuvens; cenas da mesma data são combinadas pela média, e o valor do setor é a mediana entre datas (no mínimo 3). Isso evita montar um mosaico pixel a pixel sobre dez quadrantes Landsat e duas zonas UTM. Nos 13.733 setores do município do Rio, os dois métodos praticamente coincidem (correlação de 0,994; diferença média de 0,02 °C).</p><p><strong>Valores municipais.</strong> A temperatura é a média dos setores ponderada pelos moradores; a renda é ponderada pelos responsáveis; as proporções (população preta e parda, pessoas idosas, moradores em quadras com árvores) somam as contagens dos setores antes de dividir. O indicador “diferença para o estado” subtrai o valor estadual (todos os setores, ponderado pelos moradores).</p><p><strong>Desigualdade dentro de cada município.</strong> <em>Mais pobres − mais ricos:</em> temperatura da superfície do quinto mais pobre dos domicílios menos a do quinto mais rico, com os quintos formados pelos setores do próprio município (ponderados por domicílios); só municípios com ao menos 30 setores com dados. <em>Pretos e pardos − brancos:</em> diferença das médias ponderadas pela população de cada grupo, só onde cada grupo tem ao menos 2.000 pessoas em setores com dado. Municípios abaixo desses limites aparecem sem valor, em vez de com uma estimativa instável. Os painéis abaixo do mapa resumem todos os setores do estado, com intervalos de 95% por bootstrap (500 réplicas).</p><h2>Classificação dos mapas</h2><p>Por padrão, cada indicador é dividido em cinco classes por quantis, calculadas em R no momento da publicação. O método e os limites de cada classe aparecem na legenda do mapa.</p><h2>Reprodutibilidade</h2><p>Os scripts em R que baixam, processam e publicam cada camada estão na pasta <code>R/</code> do <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">repositório</a>.</p>'
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

      'biv.t1': 'Menos cálido', 'biv.t2': 'Temp. intermedia', 'biv.t3': 'Más cálido',
      'biv.r1': 'ingreso más bajo', 'biv.r2': 'ingreso medio', 'biv.r3': 'ingreso más alto',
      'biv.note': 'Cada tercio agrupa alrededor de un tercio de los hogares de la ciudad. Magenta: sectores más cálidos y de menor ingreso.',
      'ineq.title': 'Calor e ingreso',
      'ineq.hotter': 'Los hogares del quintil más pobre viven en sectores cuyas superficies son, en promedio, <strong>{d} °C más cálidas</strong> que las del quintil más rico (IC 95%: {lo} a {hi} °C).',
      'ineq.cooler': 'Los hogares del quintil más pobre viven en sectores cuyas superficies son, en promedio, <strong>{d} °C menos cálidas</strong> que las del quintil más rico (IC 95%: {lo} a {hi} °C).',
      'ineq.peak': 'El promedio más alto está en el <strong>{n} quintil</strong>, no en el más pobre: la brecha se da sobre todo entre el quintil más rico y el resto de la ciudad.',
      'ineq.ord': ['primer', 'segundo', 'tercer', 'cuarto', 'quinto'],
      'arv.title': 'Árboles e ingreso',
      'arv.sentence': 'En el quintil más pobre de los hogares, <strong>{a}%</strong> de los residentes vive en frentes de manzana con al menos un árbol; en el quintil más rico, <strong>{b}%</strong>.',
      'arv.cooler': 'Los sectores del quintil más arbolado tienen superficies, en promedio, {d} °C menos cálidas que los del quintil menos arbolado.',
      'arv.note': 'Proporción de residentes en frentes de manzana con al menos un árbol (observación del censista, 2022), por quintil del ingreso del responsable, ponderada por hogares. Asociación entre áreas.',
      'grp.title': '¿Quién vive en los lugares más calurosos?',
      'grp.sentence': 'Los residentes negros y pardos (<em>pretos</em> y <em>pardos</em>) viven en sectores cuyas superficies son, en promedio, <strong>{d} °C más cálidas</strong> que las de los residentes blancos (IC 95%: {lo} a {hi} °C)',
      'grp.sentenceCooler': 'Los residentes negros y pardos (<em>pretos</em> y <em>pardos</em>) viven en sectores cuyas superficies son, en promedio, <strong>{d} °C menos cálidas</strong> que las de los residentes blancos (IC 95%: {lo} a {hi} °C)',
      'grp.treesFewer': ', y una proporción menor de ellos vive en frentes de manzana con árboles ({a}% frente a {b}%).',
      'grp.treesMore': ', y una proporción mayor de ellos vive en frentes de manzana con árboles ({a}% frente a {b}%).',
      'grp.colTemp': 'Temp. superficie', 'grp.colTrees': 'En frentes con árboles',
      'grp.moradores': 'Todos los residentes', 'grp.branca': 'Blancos', 'grp.preta': 'Negros (pretos)', 'grp.parda': 'Pardos',
      'grp.a60': '60 años o más', 'grp.a0_4': 'Niños de 0 a 4',
      'grp.note': 'Valores del sector donde vive la persona promedio de cada grupo (ponderados por la población del grupo en cada sector). Color o raza autodeclarada, Censo 2022. Asociación entre áreas.',
      'ineq.q1': '20% más pobre', 'ineq.q5': '20% más rico', 'ineq.qn': 'Quintil {n}',
      'ineq.note': 'Temperatura media de superficie en verano por quintil del ingreso del responsable, ponderada por hogares. Las barras empiezan en {base} °C. Asociación entre áreas, no exposición individual; vea la Metodología.',

      'rio.title': 'Municipio de Río de Janeiro',
      'rio.desc': 'Sectores censales del Censo 2022 (IBGE).',
      'rio.notice': '<strong>Publicado:</strong> temperatura de superficie en verano (Landsat 8–9, veranos 2022/23 a 2024/25). La temperatura de superficie no es la temperatura del aire: muestra cuánto se calientan las superficies en mañanas de verano despejadas. También disponibles: ingreso, arbolado del entorno, edad y color o raza (Censo 2022), y el mapa bivariado calor × ingreso.',
      'rio.sources': 'IBGE (Censo 2022: sectores censales, ingreso del responsable, arbolado del entorno), imágenes Landsat (temperatura de superficie), MapBiomas (cobertura vegetal), Data.Rio.',
      'rio.noLayer': 'Capa de sectores censales aún no procesada. Ejecute el workflow “Preparar capas del atlas” en GitHub Actions.',
      'rio.planned': ['Cobertura de copa (satélite)'],

      'rj.title': 'Estado de Río de Janeiro',
      'rj.desc': 'Los 92 municipios del estado.',
      'rj.notice': '<strong>Cómo leer:</strong> los valores municipales se calculan a partir de todos los sectores censales del estado y se ponderan por personas; así, la temperatura se mide <em>donde vive la gente</em>, no como promedio de bosques y zonas rurales. Los dos indicadores de “brecha térmica” muestran la desigualdad <em>dentro</em> de cada municipio: rojo indica que el grupo más pobre (o los residentes negros y pardos) vive en lugares más cálidos; azul, en lugares menos cálidos. En muchos municipios pequeños, los hogares más ricos están en el centro urbano, más denso y cálido, y los más pobres en zonas rurales y más verdes. Los paneles de abajo resumen todos los sectores del estado.',
      'rj.sources': 'Landsat 8–9 (USGS, vía Microsoft Planetary Computer); IBGE, Censo 2022 (sectores censales, ingreso, color o raza, edad, arbolado del entorno); límites municipales vía geobr (Ipea).',
      'rj.noLayer': 'Capa municipal aún no procesada. Ejecute el workflow “Preparar capas del atlas” en GitHub Actions.',
      'rj.planned': ['Días de calor extremo (ERA5-Land)'],

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
      'home.rio.d': 'Sectores censales 2022', 'home.rj.d': '92 municipios, a partir de todos los sectores',
      'home.br.d': '5.570 municipios', 'home.la.d': 'Países y unidades subnacionales',
      'status.building': 'En construcción', 'status.planned': 'Planificado',
      'home.body': '<h2>Tres dimensiones, analizadas por separado</h2><p><strong>Exposición</strong> (temperatura de superficie, temperatura del aire, días de calor extremo), <strong>sensibilidad</strong> (edad, ingreso, raza, condiciones de vivienda) y <strong>capacidad de adaptación</strong> (vegetación, saneamiento, acceso al agua). La desigualdad térmica no es solo una diferencia de temperatura: un área calurosa puede contar con recursos para protegerse, y un área menos calurosa puede concentrar poblaciones muy vulnerables.</p><h2>Principios</h2><ul><li>La temperatura de superficie (satélite) y la temperatura del aire (reanálisis) son medidas distintas y nunca se mezclan.</li><li>Cada indicador publicado indica fuente, período, unidad y método de agregación.</li><li>Las correlaciones entre áreas no permiten conclusiones causales sobre individuos.</li><li>Los scripts y datos procesados se conservan en el repositorio para su reproducción.</li></ul><p>Vea la <a href="metodologia/">metodología</a>.</p>',

      'method.title': 'Metodología',
      'method.body': '<p class="lead">Estado: municipio de Río y estado de Río de Janeiro, con temperatura de superficie en verano, ingreso, arbolado del entorno, edad, color o raza y sus relaciones. Esta página se actualiza con cada nuevo indicador.</p><h2>Escalas y unidades territoriales</h2><table><thead><tr><th>Escala</th><th>Unidad</th><th>Fuentes principales</th></tr></thead><tbody><tr><td>Municipio de Río de Janeiro</td><td>Sectores censales 2022</td><td>IBGE, Data.Rio, Landsat, MapBiomas</td></tr><tr><td>Estado de Río de Janeiro</td><td>Municipios (92), calculados a partir de los sectores de 2022</td><td>IBGE, Ipea, Landsat; ERA5-Land previsto</td></tr><tr><td>Brasil</td><td>Municipios (5.570)</td><td>IBGE, Ipea, ERA5-Land, MODIS, MapBiomas</td></tr><tr><td>América Latina</td><td>Países y unidades subnacionales</td><td>ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL</td></tr></tbody></table><h2>Dimensiones analíticas</h2><table><thead><tr><th>Dimensión</th><th>Indicadores candidatos</th></tr></thead><tbody><tr><td>Exposición térmica</td><td>Temperatura de superficie, temperatura del aire, frecuencia de olas de calor, días de calor extremo</td></tr><tr><td>Vulnerabilidad socioeconómica</td><td>Ingreso, pobreza, escolaridad, raza, hacinamiento</td></tr><tr><td>Vulnerabilidad demográfica</td><td>Personas mayores, niños, densidad de población</td></tr><tr><td>Capacidad de adaptación</td><td>Cobertura vegetal, arbolado, saneamiento, acceso al agua</td></tr></tbody></table><h2>Principios</h2><ol><li>La temperatura de la superficie terrestre (LST, por satélite) y la temperatura del aire (estaciones o reanálisis) son conceptos físicos distintos y aparecen como indicadores separados.</li><li>Para cada indicador registramos unidad, período, resolución original, tratamiento de datos faltantes y método de agregación espacial.</li><li>Ningún dato simulado se presenta como observación.</li><li>Las comparaciones entre países usan solo productos armonizados internacionalmente; los datos nacionales aparecen como capa complementaria, con las diferencias de definición documentadas.</li><li>Las asociaciones entre áreas (falacia ecológica) no se interpretan como relaciones individuales o causales.</li></ol><h2>Temperatura de superficie en verano (municipio de Río)</h2><p><strong>Datos:</strong> Landsat 8 y 9, banda de temperatura de superficie de la Collection 2 Level-2 (USGS), obtenida a través de Microsoft Planetary Computer. Todas las escenas del 1 de diciembre al 31 de marzo de los veranos 2022/23, 2023/24 y 2024/25 con nubosidad de escena inferior al 70% (27 escenas, órbita/punto WRS-2 217/076). Paso del satélite hacia las 10 h (hora local).</p><p><strong>Procesamiento:</strong> se descartan los píxeles marcados en la banda QA_PIXEL como relleno, nube, nube dilatada, cirro, sombra de nube o agua. Para cada píxel de 30 m se toma la mediana de todas las observaciones válidas, con un mínimo de 3. Cada sector censal recibe la mediana ponderada por área de los píxeles que cubre; los sectores con menos de medio píxel válido quedan sin dato.</p><p><strong>Diferencia respecto a la mediana de la ciudad:</strong> valor del sector menos la mediana de todos los sectores (41,8 °C). Clases fijas: menos de −4, −4 a −1,5, −1,5 a 1,5, 1,5 a 4, más de 4 °C.</p><p><strong>Límites:</strong> la temperatura de superficie mide cuánto se calientan las superficies (techos, asfalto, vegetación), no la temperatura del aire que respiran las personas, y solo en mañanas despejadas. Es un buen indicador del patrón espacial del calor urbano, pero no, por sí sola, del confort térmico ni del riesgo para la salud. El script, la lista de escenas y el ráster de 30 m están en el repositorio.</p><h2>Ingreso del responsable del hogar (municipio de Río)</h2><p><strong>Datos:</strong> IBGE, Censo 2022, resultados del universo, <em>Agregados por sectores censales – Ingreso del responsable</em> (versión de mayo de 2026). Variables V06004 (media) y V06006 (mediana) del ingreso nominal mensual de los responsables <em>con ingresos</em> de hogares particulares permanentes ocupados, y V06001 (número de responsables), usada como ponderador. Valores en R$ nominales de julio de 2022 (1 salario mínimo = R$ 1.212). 13.368 de los 13.782 sectores tienen dato; el resto no tiene hogares o fue suprimido por el IBGE por confidencialidad.</p><p><strong>Límites:</strong> no es ingreso del hogar per cápita. Los responsables sin ingresos quedan fuera de la media, lo que hace que los sectores con muchos de esos hogares parezcan en mejor situación de la real.</p><h2>Calor × ingreso</h2><p><strong>Quintiles de ingreso:</strong> los sectores se ordenan por ingreso medio del responsable y se agrupan de modo que cada quintil reúna cerca del 20% de los hogares de la ciudad (≈487.000). Para cada quintil se calcula la temperatura media de superficie en verano, ponderada por hogares. El intervalo de confianza del 95% de la diferencia entre el quintil más pobre y el más rico proviene de 2.000 remuestreos bootstrap de sectores.</p><p><strong>Resultado (veranos 2022/23–2024/25):</strong> quintil más pobre 41,6 °C, segundo 41,9 °C, tercero 42,7 °C, cuarto 42,2 °C, más rico 38,5 °C. Diferencia más pobre − más rico: 3,0 °C (IC 95%: 2,9 a 3,2). La relación no es lineal: las superficies más cálidas están en los sectores de ingreso intermedio, y la principal división separa al quintil más rico del resto de la ciudad. Parte del quintil más pobre vive en favelas de ladera junto al bosque y en zonas menos densas de la Zona Oeste, donde las superficies son menos cálidas.</p><p><strong>Mapa bivariado:</strong> terciles, ponderados por hogares, de temperatura (límites 40,5 y 43,0 °C) y de ingreso (R$ 2.000 y R$ 3.900), combinados en 9 clases.</p><p><strong>Lectura:</strong> son asociaciones entre áreas (falacia ecológica). No muestran que cada hogar de bajos ingresos esté más expuesto, ni que el ingreso cause la temperatura.</p><h2>Arbolado del entorno (municipio de Río)</h2><p><strong>Datos:</strong> IBGE, Censo 2022, <em>características urbanísticas del entorno de los hogares</em>, archivo de residentes. Variables V05230–V05233: residentes de hogares particulares permanentes ocupados, en sectores seleccionados para la encuesta del entorno, según el número de árboles en su frente de manzana (ninguno, 1–2, 3–4, 5 o más), observado por el censista. Los frentes no observados (V05234, 0,9% de los residentes) se excluyen. 13.235 sectores tienen dato (al menos 20 residentes observados); los sectores fuera de la encuesta, en general no urbanos, quedan sin dato.</p><p><strong>Indicadores:</strong> proporción de residentes en frentes con al menos un árbol y con 5 o más árboles. En la ciudad: 64,5% y 37,9%.</p><p><strong>Resultado:</strong> por quintil de ingreso, la proporción de residentes en frentes con árboles sube del 26% (más pobres) al 51%, 74%, 84% y 95% (más ricos); con 5 o más árboles, del 8% al 79%. Los sectores del quintil más arbolado tienen superficies en verano cerca de 1,9 °C menos cálidas que los del quintil menos arbolado.</p><p><strong>Límites:</strong> es el recuento de árboles en la calle frente al hogar, no cobertura de copa, y no incluye parques, bosques ni patios. En las favelas, los frentes de manzana suelen ser callejones estrechos donde los árboles de calle son escasos incluso cerca del bosque.</p><h2>Edad y color o raza (municipio de Río)</h2><p><strong>Datos:</strong> IBGE, Censo 2022, agregados por sectores censales (universo), archivos <em>demografía</em> y <em>color o raza</em>. Variables V01006 (residentes), V01031 (0 a 4 años), V01040 + V01041 (60 a 69 y 70 años o más), V01318 (preta) y V01320 (parda). El archivo no separa 65+; usamos 60+, definición legal de persona mayor en Brasil. El color o raza es autodeclarado según las categorías del IBGE; pretos y pardos forman la población negra en las estadísticas brasileñas.</p><p><strong>Indicadores:</strong> proporción de residentes de 60 años o más, de 0 a 4 años y pretos o pardos. En la ciudad: 20,2%, 5,0% y 54,4% (blancos: 45,3%). Los sectores con menos de 20 residentes quedan sin dato. El IBGE suprime los recuentos pequeños por confidencialidad; esto afecta sobre todo a los grupos amarillo e indígena, que se cuentan como cero donde están suprimidos y no se muestran por separado.</p><p><strong>Exposición por grupo:</strong> la ponderación por hogares usada para el ingreso se sustituye por el número de personas de cada grupo en cada sector. Resultado: blancos 41,0 °C y 73,5% en frentes con árboles; pretos 41,9 °C y 55,3%; pardos 41,8 °C y 57,3%. Negros y pardos − blancos: 0,83 °C (IC 95%: 0,78 a 0,88) y 16,8 puntos porcentuales menos en frentes arbolados. Las personas mayores (41,4 °C, 72,8%) no están más expuestas que el residente promedio, porque se concentran en barrios más antiguos y de mayor ingreso; los niños de 0 a 4 años están algo más expuestos (41,5 °C, 57,7%).</p><h2>Estado de Río de Janeiro</h2><p>El mapa estatal muestra los 92 municipios, pero todos los valores se calculan a partir de los sectores censales de 2022 (unos 41.700 sectores en la cartografía del IBGE). Así la escala estatal es coherente con el municipio de Río y el calor se mide <em>donde vive la gente</em>: un municipio con grandes áreas forestales o rurales no parece más fresco solo porque la mayor parte de su territorio está deshabitada.</p><p><strong>Temperatura de superficie.</strong> Mismas imágenes, veranos y máscara de nubes que el municipio de Río (Landsat 8–9, diciembre a marzo, 2022/23 a 2024/25), pero resumidas escena por escena: en cada escena, la media de los píxeles despejados de cada sector (ponderada por la fracción de cada píxel dentro del sector), usada solo cuando al menos la mitad del sector está despejada; las escenas de una misma fecha se promedian y el valor del sector es la mediana entre fechas (mínimo 3). Esto evita construir un mosaico píxel a píxel sobre diez cuadrantes Landsat y dos zonas UTM. En los 13.733 sectores del municipio de Río, ambos métodos casi coinciden (correlación de 0,994; diferencia media de 0,02 °C).</p><p><strong>Valores municipales.</strong> La temperatura es la media de los sectores ponderada por residentes; el ingreso se pondera por jefes de hogar; las proporciones (población negra y parda, personas mayores, residentes en cuadras con árboles) suman los conteos de los sectores antes de dividir. El indicador “diferencia respecto al estado” resta el valor estatal (todos los sectores, ponderado por residentes).</p><p><strong>Desigualdad dentro de cada municipio.</strong> <em>Más pobres − más ricos:</em> temperatura de superficie del quinto más pobre de los hogares menos la del quinto más rico, con quintos formados por los sectores del propio municipio (ponderados por hogares); solo municipios con al menos 30 sectores con datos. <em>Negros y pardos − blancos:</em> diferencia de medias ponderadas por la población de cada grupo, solo donde cada grupo tiene al menos 2.000 personas en sectores con datos. Los municipios por debajo de estos umbrales aparecen sin valor en lugar de con una estimación inestable. Los paneles bajo el mapa resumen todos los sectores del estado, con intervalos del 95% por bootstrap (500 réplicas).</p><h2>Clasificación de los mapas</h2><p>Por defecto, cada indicador se divide en cinco clases por cuantiles, calculadas en R al publicarlo. El método y los límites de cada clase aparecen en la leyenda del mapa.</p><h2>Reproducibilidad</h2><p>Los scripts en R que descargan, procesan y publican cada capa están en la carpeta <code>R/</code> del <a href="https://github.com/fredericofilho-iesp/atlas-desigualdade-termica">repositorio</a>.</p>'
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
