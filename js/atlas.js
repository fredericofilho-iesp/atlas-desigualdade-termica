/*
 * Atlas Interativo de Desigualdade Térmica — motor cartográfico compartilhado.
 *
 * Cada página de escala define window.ATLAS_CONFIG e carrega este arquivo.
 * Os dados vêm de um manifesto (camada.json) gerado em R por publicar_camada().
 * Veja docs/CONTRATO_DE_DADOS.md.
 */
(function () {
  'use strict';

  // Paletas sequenciais (5 classes). Cores escolhidas para leitura em fundo claro.
  var PALETAS = {
    calor:  ['#fee8c8', '#fdbb84', '#fc8d59', '#e34a33', '#b30000'],
    renda:  ['#eff3ff', '#bdd7e7', '#6baed6', '#3182bd', '#08519c'],
    verde:  ['#edf8e9', '#bae4b3', '#74c476', '#31a354', '#006d2c'],
    pessoas:['#f2f0f7', '#cbc9e2', '#9e9ac8', '#756bb1', '#54278f'],
    // Divergente: azul (mais frio que a referência) → branco → vermelho (mais quente).
    divergente: ['#2166ac', '#92c5de', '#f7f7f7', '#f4a582', '#b2182b'],
    // Bivariada 3×3 (J. Stevens), índice = código − 1. Linhas: temperatura
    // baixa→alta; colunas: renda baixa→alta. Quente e mais pobre = magenta.
    bivariada: ['#e8e8e8', '#ace4e4', '#5ac8c8',
                '#dfb0d6', '#a5add3', '#5698b9',
                '#be64ac', '#8c62aa', '#3b4994']
  };
  var COR_SEM_DADO = '#d9dde0';

  // Mapa-base: OpenFreeMap "Positron" (vetorial, gratuito, sem chave de API).
  // Os dados entram abaixo da primeira camada de rótulos, para que nomes de
  // bairros e ruas fiquem legíveis por cima do mapa coroplético.
  // Se o estilo não carregar, usa os tiles padrão do OpenStreetMap.
  var ESTILO_BASE = 'https://tiles.openfreemap.org/styles/positron';

  function estiloReserva() {
    return {
      version: 8,
      sources: {
        osm: {
          type: 'raster', tileSize: 256,
          tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }
      },
      layers: [{ id: 'osm', type: 'raster', source: 'osm', paint: { 'raster-saturation': -0.8, 'raster-opacity': 0.8 } }]
    };
  }

  async function estiloBase() {
    try {
      var ctrl = new AbortController();
      var t = setTimeout(function () { ctrl.abort(); }, 6000);
      var r = await fetch(ESTILO_BASE, { signal: ctrl.signal });
      clearTimeout(t);
      if (r.ok) return await r.json();
    } catch (e) { /* cai no estilo de reserva */ }
    return estiloReserva();
  }

  // Id da primeira camada de texto do mapa-base (os dados ficam abaixo dela).
  function primeiraCamadaDeRotulo(map) {
    var camadas = (map.getStyle() && map.getStyle().layers) || [];
    for (var i = 0; i < camadas.length; i++) if (camadas[i].type === 'symbol') return camadas[i].id;
    return undefined;
  }

  // Rótulos do mapa-base no idioma escolhido (esquema OpenMapTiles: name:xx).
  // Só altera camadas cujo texto já vem de um campo de nome.
  function rotulosNoIdioma(map, idioma) {
    var campos = idioma === 'en'
      ? [['get', 'name:en'], ['get', 'name_en'], ['get', 'name']]
      : [['get', 'name:' + idioma], ['get', 'name']];
    var expr = ['coalesce'].concat(campos);
    ((map.getStyle() && map.getStyle().layers) || []).forEach(function (l) {
      if (l.type !== 'symbol' || !l.layout || !l.layout['text-field']) return;
      if (JSON.stringify(l.layout['text-field']).indexOf('name') === -1) return;
      try { map.setLayoutProperty(l.id, 'text-field', expr); } catch (e) { /* ignora */ }
    });
  }

  // ---------- utilidades puras (exportadas para teste) ----------

  var I = (typeof window !== 'undefined' && window.AtlasI18n) || {
    t: function (k) { return k === 'map.noData' ? 'no data' : k; },
    tr: function (v) { return v && typeof v === 'object' ? (v.en || v.pt || '') : (v == null ? '' : String(v)); },
    locale: 'en-US', idioma: 'en'
  };

  function formatarValor(v, unidade, casas) {
    if (v === null || v === undefined || v === '' || Number.isNaN(Number(v))) return I.t('map.noData');
    var x = Number(v);
    var f = Math.pow(10, casas == null ? 2 : casas);
    if (Math.round(x * f) === 0) x = 0;  // evita "-0,0"
    var n = x.toLocaleString(I.locale, {
      minimumFractionDigits: casas == null ? 0 : casas,
      maximumFractionDigits: casas == null ? 2 : casas
    });
    if (unidade === 'R$') return 'R$ ' + n;
    if (unidade === '%') return n + '%';
    return unidade ? n + ' ' + unidade : n;
  }

  // Expressão MapLibre "step" a partir das quebras calculadas em R.
  // quebras = limites internos (n-1 valores para n classes).
  function expressaoCor(campo, quebras, cores) {
    var exp = ['step', ['to-number', ['get', campo]], cores[0]];
    for (var i = 0; i < quebras.length; i++) exp.push(quebras[i], cores[i + 1]);
    return ['case',
      ['any', ['!', ['has', campo]], ['==', ['get', campo], null]], COR_SEM_DADO,
      exp];
  }

  function coresPara(ind) {
    var p = PALETAS[ind.paleta] || PALETAS.calor;
    var n = (ind.quebras || []).length + 1;
    if (n <= p.length) return p.slice(p.length - n);
    return p;
  }

  function rotulosLegenda(ind) {
    var q = ind.quebras || [];
    var casas = ind.casas_decimais;
    var r = [];
    for (var i = 0; i <= q.length; i++) {
      if (i === 0) r.push('< ' + formatarValor(q[0], '', casas));
      else if (i === q.length) r.push('≥ ' + formatarValor(q[i - 1], '', casas));
      else r.push(formatarValor(q[i - 1], '', casas) + ' – ' + formatarValor(q[i], '', casas));
    }
    return r;
  }

  // "quantis" / "intervalos_iguais" + número de classes → texto no idioma.
  // Aceita também o formato antigo (texto livre).
  function textoClassificacao(ind) {
    var c = ind.classificacao;
    if (!c) return '';
    if (typeof c === 'object') return I.tr(c);
    var n = (ind.quebras || []).length + 1;
    if (c === 'quantis') return I.t('map.quantiles') + ' (' + I.t('map.nClasses', { n: n }) + ')';
    if (c === 'intervalos_iguais') return I.t('map.equalIntervals') + ' (' + I.t('map.nClasses', { n: n }) + ')';
    if (c === 'manual') return I.t('map.fixedIntervals');
    return String(c);
  }

  function escapar(s) {
    return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; });
  }

  if (typeof window === 'undefined') {
    module.exports = { formatarValor: formatarValor, expressaoCor: expressaoCor,
      rotulosLegenda: rotulosLegenda, coresPara: coresPara };
    return;
  }

  // ---------- interface ----------

  var cfg = window.ATLAS_CONFIG || {};
  var $ = function (id) { return document.getElementById(id); };
  var estado = { manifesto: null, indicador: null, selecionado: null, status: null, mapa: null };

  // O status é guardado como função para ser refeito quando o idioma muda.
  function status(fn) { estado.status = fn; var el = $('status-camada'); if (el) el.textContent = fn(); }
  function chave(k) { return (cfg.chave || cfg.escala) + '.' + k; }

  function preencherIndicadores(manifesto) {
    var sel = $('indicador');
    var anterior = sel.value;
    sel.innerHTML = '';
    var base = document.createElement('option');
    base.value = '';
    base.textContent = manifesto ? I.t('map.boundariesOnly') : I.t('map.basemapOnly');
    sel.appendChild(base);

    var publicados = (manifesto && manifesto.indicadores) || [];
    var ids = {};
    publicados.forEach(function (ind) {
      ids[ind.id] = true;
      var o = document.createElement('option');
      o.value = ind.id;
      var u = I.tr(ind.unidade);
      o.textContent = I.tr(ind.rotulo) + (u ? ' (' + u + ')' : '');
      sel.appendChild(o);
    });
    // Indicadores previstos aparecem desabilitados, para deixar claro o que falta.
    var previstos = I.t(chave('planned'));
    (Array.isArray(previstos) ? previstos : []).forEach(function (rotulo) {
      var o = document.createElement('option');
      o.disabled = true;
      o.textContent = rotulo + ' — ' + I.t('map.pending');
      sel.appendChild(o);
    });
    sel.disabled = false;
    if (anterior !== undefined && (anterior === '' || ids[anterior]) && estado.mapa) sel.value = anterior;
    else if (publicados.length) sel.value = publicados[0].id;
  }

  // Rótulos dos tercis de um eixo bivariado: "< a", "a – b", "≥ b".
  function rotulosTercis(eixo) {
    var l = eixo.limites || [], u = eixo.unidade || '';
    // A unidade já aparece no título do eixo; aqui só os números.
    var f = function (v) { return formatarValor(v, '', u === 'R$' ? 0 : 1); };
    return ['< ' + f(l[0]), f(l[0]) + ' – ' + f(l[1]), '≥ ' + f(l[1])];
  }

  function categoriaBivariada(cod) {
    cod = Number(cod);
    if (!(cod >= 1 && cod <= 9)) return I.t('map.noData');
    var t = Math.floor((cod - 1) / 3) + 1, r = ((cod - 1) % 3) + 1;
    return I.t('biv.t' + t) + ' · ' + I.t('biv.r' + r);
  }

  function legendaBivariada(ind) {
    var p = PALETAS.bivariada, ex = ind.eixos || {}, x = ex.x || {}, y = ex.y || {};
    var rx = rotulosTercis(x), ry = rotulosTercis(y);
    var html = '<p class="legenda-titulo">' + escapar(I.tr(ind.rotulo)) + '</p>';
    html += '<div class="biv"><div class="biv-y">' + escapar(I.tr(y.rotulo)) + (y.unidade ? ' (' + y.unidade + ')' : '') + ' →</div>';
    html += '<table class="biv-grade" role="presentation"><tbody>';
    for (var t = 3; t >= 1; t--) {
      html += '<tr><th scope="row">' + ry[t - 1] + '</th>';
      for (var r = 1; r <= 3; r++) {
        var cod = (t - 1) * 3 + r;
        html += '<td title="' + escapar(categoriaBivariada(cod)) + '" style="background:' + p[cod - 1] + '"></td>';
      }
      html += '</tr>';
    }
    html += '<tr><th></th>' + rx.map(function (v) { return '<th class="biv-x">' + v + '</th>'; }).join('') + '</tr>';
    html += '</tbody></table><div class="biv-xt">' + escapar(I.tr(x.rotulo)) + (x.unidade ? ' (' + x.unidade + ')' : '') + ' →</div></div>';
    html += '<p class="legenda-meta">' + I.t('biv.note') + '</p>';
    return html;
  }

  function desenharLegenda(ind) {
    var el = $('legenda');
    if (!ind) { el.hidden = true; el.innerHTML = ''; return; }
    if (ind.tipo === 'bivariado') { el.innerHTML = legendaBivariada(ind); el.hidden = false; return; }
    var cores = coresPara(ind);
    var rot = rotulosLegenda(ind);
    var u = I.tr(ind.unidade);
    var html = '<p class="legenda-titulo">' + escapar(I.tr(ind.rotulo)) + (u ? ' <span>(' + escapar(u) + ')</span>' : '') + '</p><ul>';
    for (var i = 0; i < cores.length; i++) {
      html += '<li><i style="background:' + cores[i] + '"></i>' + rot[i] + '</li>';
    }
    html += '<li><i style="background:' + COR_SEM_DADO + '"></i>' + I.t('map.noData') + '</li></ul>';
    var meta = [];
    if (ind.fonte) meta.push(I.t('map.source') + ': ' + escapar(I.tr(ind.fonte)));
    if (ind.periodo) meta.push(I.t('map.period') + ': ' + escapar(I.tr(ind.periodo)));
    var cl = textoClassificacao(ind);
    if (cl) meta.push(I.t('map.classes') + ': ' + escapar(cl));
    if (meta.length) html += '<p class="legenda-meta">' + meta.join(' · ') + '</p>';
    el.innerHTML = html;
    el.hidden = false;
  }

  function corContorno(cor) {
    return ['case', ['boolean', ['feature-state', 'selecionado'], false], '#111', cor];
  }

  function aplicarIndicador(map, id) {
    var ind = null;
    (estado.manifesto.indicadores || []).forEach(function (i) { if (i.id === id) ind = i; });
    estado.indicador = ind;
    if (ind) {
      var cor = ind.tipo === 'bivariado'
        ? ['match', ['to-number', ['get', ind.id], 0], 1, PALETAS.bivariada[0], 2, PALETAS.bivariada[1], 3, PALETAS.bivariada[2],
           4, PALETAS.bivariada[3], 5, PALETAS.bivariada[4], 6, PALETAS.bivariada[5],
           7, PALETAS.bivariada[6], 8, PALETAS.bivariada[7], 9, PALETAS.bivariada[8], COR_SEM_DADO]
        : expressaoCor(ind.id, ind.quebras || [], coresPara(ind));
      map.setPaintProperty('unidades-preenchimento', 'fill-color', cor);
      map.setPaintProperty('unidades-preenchimento', 'fill-opacity', 0.78);
      map.setPaintProperty('unidades-contorno', 'line-color', corContorno('#ffffff'));
      map.setPaintProperty('unidades-contorno', 'line-opacity', 0.7);
    } else {
      // Só limites: preenchimento leve e contorno escuro, para os limites ficarem visíveis.
      map.setPaintProperty('unidades-preenchimento', 'fill-color', '#2f7f95');
      map.setPaintProperty('unidades-preenchimento', 'fill-opacity', 0.08);
      map.setPaintProperty('unidades-contorno', 'line-color', corContorno('#1f5f72'));
      map.setPaintProperty('unidades-contorno', 'line-opacity', 0.9);
    }
    desenharLegenda(ind);
    if (estado.selecionado) mostrarFicha(estado.selecionado);
  }

  function mostrarFicha(props) {
    var m = estado.manifesto;
    var g = m.geometria || {};
    var nome = props[g.rotulo] || props[g.id] || '';
    var html = '<h3>' + escapar(I.tr(m.unidade) || I.t('map.unit')) + ': ' + escapar(nome) + '</h3>';
    if (g.rotulo && g.rotulo !== g.id && props[g.id]) html += '<p class="codigo">' + I.t('map.code') + ': ' + escapar(props[g.id]) + '</p>';
    var inds = m.indicadores || [];
    if (!inds.length) {
      html += '<p>' + I.t('map.noIndicatorsYet') + '</p>';
    } else {
      html += '<dl>';
      inds.forEach(function (ind) {
        var ativo = estado.indicador && estado.indicador.id === ind.id;
        html += '<div' + (ativo ? ' class="ativo"' : '') + '><dt>' + escapar(I.tr(ind.rotulo)) + '</dt><dd>' +
          (ind.tipo === 'bivariado' ? escapar(categoriaBivariada(props[ind.id]))
            : formatarValor(props[ind.id], I.tr(ind.unidade), ind.casas_decimais)) + '</dd></div>';
      });
      html += '</dl>';
    }
    $('ficha').innerHTML = html;
  }

  function textoCarregado() {
    var m = estado.manifesto;
    var n = m.quantidade_unidades;
    var nInd = (m.indicadores || []).length;
    var fonte = I.tr(m.fonte_geometria) || '';
    var plural = (I.tr(m.unidade_plural) || I.t('map.units')).toLowerCase();
    var s = n ? I.t('map.loaded', { fonte: fonte, n: Number(n).toLocaleString(I.locale), unidades: plural })
              : I.t('map.loadedNoCount', { fonte: fonte });
    return s + ' ' + (nInd ? I.t('map.nIndicators', { n: nInd }) : I.t('map.noIndicators'));
  }

  function atualizarBadge() {
    var m = estado.manifesto;
    $('badge-mapa').textContent = m
      ? (I.tr(m.unidade_plural) || '') + (m.fonte_curta ? ' • ' + I.tr(m.fonte_curta) : '')
      : I.t('map.badgeBasemap');
  }

  function carregarScript(src) {
    return new Promise(function (ok, falha) {
      var s = document.createElement('script');
      s.src = src; s.onload = ok; s.onerror = falha;
      document.head.appendChild(s);
    });
  }

  async function carregarManifesto() {
    if (!cfg.manifesto) return null;
    try {
      var r = await fetch(cfg.manifesto, { cache: 'no-cache' });
      if (!r.ok) return null;
      return await r.json();
    } catch (e) { return null; }
  }

  async function adicionarCamada(map, manifesto) {
    var g = manifesto.geometria || {};
    var base = cfg.manifesto.replace(/[^/]*$/, '');
    var url = /^https?:/.test(g.url) ? g.url : base + g.url;
    var fonte;
    if (g.tipo === 'pmtiles') {
      // Bases grandes (Brasil, América Latina) usam PMTiles hospedados fora do GitHub.
      if (!window.pmtiles) await carregarScript('https://unpkg.com/pmtiles@3.2.1/dist/pmtiles.js');
      var proto = new window.pmtiles.Protocol();
      maplibregl.addProtocol('pmtiles', proto.tile);
      fonte = { type: 'vector', url: 'pmtiles://' + url, promoteId: g.id };
    } else {
      fonte = { type: 'geojson', data: url, promoteId: g.id };
    }
    map.addSource('unidades', fonte);
    var antes = primeiraCamadaDeRotulo(map);
    var extra = g.tipo === 'pmtiles' ? { 'source-layer': g.camada_vetorial || 'unidades' } : {};
    var k = cfg.espessuraContorno || 1;
    map.addLayer(Object.assign({
      id: 'unidades-preenchimento', type: 'fill', source: 'unidades',
      paint: { 'fill-color': '#7fb6c5', 'fill-opacity': 0.12 }
    }, extra), antes);
    map.addLayer(Object.assign({
      id: 'unidades-contorno', type: 'line', source: 'unidades',
      paint: {
        'line-color': corContorno('#1f5f72'),
        'line-width': ['case', ['boolean', ['feature-state', 'selecionado'], false], 2.4,
          ['interpolate', ['linear'], ['zoom'], 6, 0.4 * k, 10, 0.5 * k, 14, 1.2 * k]]
      }
    }, extra), antes);

    var idSel = null;
    map.on('click', 'unidades-preenchimento', function (e) {
      var f = e.features && e.features[0];
      if (!f) return;
      var alvo = { source: 'unidades' };
      if (g.tipo === 'pmtiles') alvo.sourceLayer = g.camada_vetorial || 'unidades';
      if (idSel !== null) map.setFeatureState(Object.assign({ id: idSel }, alvo), { selecionado: false });
      idSel = f.id;
      if (idSel !== undefined && idSel !== null) map.setFeatureState(Object.assign({ id: idSel }, alvo), { selecionado: true });
      estado.selecionado = f.properties;
      mostrarFicha(f.properties);
    });
    map.on('mouseenter', 'unidades-preenchimento', function () { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', 'unidades-preenchimento', function () { map.getCanvas().style.cursor = ''; });
  }

  // ---------- painel calor × renda (quintos) ----------
  async function carregarPainel() {
    if (!cfg.painelCalorRenda) return;
    try {
      var r = await fetch(cfg.painelCalorRenda, { cache: 'no-cache' });
      if (!r.ok) return;
      estado.painel = await r.json();
      desenharPainel();
    } catch (e) { /* painel é opcional */ }
  }

  function desenharPainel() {
    var el = $('painel-desigualdade'), d = estado.painel;
    if (!el || !d || !d.quintos) return;
    var qs = d.quintos, vals = qs.map(function (q) { return q.lst_media; });
    var min = Math.min.apply(null, vals), max = Math.max.apply(null, vals);
    var base = Math.floor(min - 1), topo = Math.ceil(max);
    var dif = d.diferenca_q1_q5, ic = d.ic95 || [];
    var f1 = function (v) { return formatarValor(Math.abs(v), '', 1); };
    var frase = I.t(dif >= 0 ? 'ineq.hotter' : 'ineq.cooler', { d: f1(dif), lo: formatarValor(ic[0], '', 1), hi: formatarValor(ic[1], '', 1) });
    var imax = vals.indexOf(max);
    if (imax > 0 && imax < vals.length - 1) {
      var ord = I.t('ineq.ord');
      frase += ' ' + I.t('ineq.peak', { n: Array.isArray(ord) ? ord[imax] : String(imax + 1) });
    }
    var html = '<h2>' + I.t('ineq.title') + '</h2><p class="ineq-frase">' + frase + '</p><ul class="barras">';
    qs.forEach(function (q, i) {
      var w = Math.max(2, 100 * (q.lst_media - base) / (topo - base));
      var rot = i === 0 ? I.t('ineq.q1') : (i === qs.length - 1 ? I.t('ineq.q5') : I.t('ineq.qn', { n: q.quinto }));
      var faixa = formatarValor(q.renda_min, 'R$', 0) + ' – ' + formatarValor(q.renda_max, 'R$', 0);
      html += '<li title="' + escapar(faixa) + '"><span class="barra-rot">' + rot + '</span>' +
        '<span class="barra-trilho"><span class="barra" style="width:' + w.toFixed(1) + '%"></span></span>' +
        '<span class="barra-val">' + formatarValor(q.lst_media, '°C', 1) + '</span></li>';
    });
    html += '</ul><p class="status">' + I.t('ineq.note', { base: base }) + '</p>';
    el.innerHTML = html;
    el.hidden = false;
  }

  // ---------- painel árvores × renda ----------
  async function carregarPainelArvores() {
    if (!cfg.painelArvores) return;
    try {
      var r = await fetch(cfg.painelArvores, { cache: 'no-cache' });
      if (!r.ok) return;
      estado.painelArv = await r.json();
      desenharPainelArvores();
    } catch (e) { /* opcional */ }
  }

  function desenharPainelArvores() {
    var el = $('painel-arvores'), d = estado.painelArv;
    if (!el || !d || !d.por_quinto_de_renda) return;
    var qs = d.por_quinto_de_renda, pa = d.por_quinto_de_arborizacao || [];
    var f0 = function (v) { return formatarValor(v, '', 0); };
    var frase = I.t('arv.sentence', { a: f0(qs[0].arv_com_arvores), b: f0(qs[qs.length - 1].arv_com_arvores) });
    if (pa.length >= 2) {
      var dif = pa[0].lst_media - pa[pa.length - 1].lst_media;
      if (dif > 0) frase += ' ' + I.t('arv.cooler', { d: formatarValor(dif, '', 1) });
    }
    var html = '<h2>' + I.t('arv.title') + '</h2><p class="ineq-frase">' + frase + '</p><ul class="barras verde">';
    qs.forEach(function (q, i) {
      var rot = i === 0 ? I.t('ineq.q1') : (i === qs.length - 1 ? I.t('ineq.q5') : I.t('ineq.qn', { n: q.quinto }));
      html += '<li><span class="barra-rot">' + rot + '</span>' +
        '<span class="barra-trilho"><span class="barra" style="width:' + Math.max(1, q.arv_com_arvores).toFixed(1) + '%"></span></span>' +
        '<span class="barra-val">' + formatarValor(q.arv_com_arvores, '%', 0) + '</span></li>';
    });
    html += '</ul><p class="status">' + I.t('arv.note') + '</p>';
    el.innerHTML = html;
    el.hidden = false;
  }

  // ---------- painel exposição por grupo (cor ou raça, idade) ----------
  var GRUPOS_PAINEL = ['moradores', 'branca', 'preta', 'parda', 'a60', 'a0_4'];

  async function carregarPainelGrupos() {
    if (!cfg.painelGrupos) return;
    try {
      var r = await fetch(cfg.painelGrupos, { cache: 'no-cache' });
      if (!r.ok) return;
      estado.painelGrp = await r.json();
      desenharPainelGrupos();
    } catch (e) { /* opcional */ }
  }

  function desenharPainelGrupos() {
    var el = $('painel-grupos'), d = estado.painelGrp;
    if (!el || !d || !d.grupos) return;
    var por = {}; d.grupos.forEach(function (g) { por[g.grupo] = g; });
    var gs = GRUPOS_PAINEL.filter(function (k) { return por[k]; }).map(function (k) { return por[k]; });
    var ic = d.ic95 || [], pp = por.preta_parda, br = por.branca;
    var dif = d.diferenca_preta_parda_branca;
    var frase = I.t(dif >= 0 ? 'grp.sentence' : 'grp.sentenceCooler', {
      d: formatarValor(Math.abs(dif), '', 2),
      lo: formatarValor(ic[0], '', 2), hi: formatarValor(ic[1], '', 2)
    });
    if (pp && br && isFinite(pp.arv_com_arvores) && isFinite(br.arv_com_arvores)) {
      frase += I.t(pp.arv_com_arvores <= br.arv_com_arvores ? 'grp.treesFewer' : 'grp.treesMore', {
        a: formatarValor(pp.arv_com_arvores, '', 0), b: formatarValor(br.arv_com_arvores, '', 0) });
    } else frase += '.';
    var html = '<h2>' + I.t('grp.title') + '</h2><p class="ineq-frase">' + frase + '</p>' +
      '<table class="tabela-grupos"><thead><tr><th></th><th>' + I.t('grp.colTemp') + '</th><th>' + I.t('grp.colTrees') + '</th></tr></thead><tbody>';
    gs.forEach(function (g) {
      html += '<tr' + (g.grupo === 'moradores' ? ' class="total"' : '') + '><th scope="row">' + I.t('grp.' + g.grupo) + '</th>' +
        '<td>' + formatarValor(g.lst_media, '°C', 1) + '</td>' +
        '<td>' + formatarValor(g.arv_com_arvores, '%', 0) + '</td></tr>';
    });
    html += '</tbody></table><p class="status">' + I.t('grp.note') + '</p>';
    el.innerHTML = html;
    el.hidden = false;
  }

  // Troca de idioma sem recarregar a página.
  document.addEventListener('atlas:idioma', function () {
    var map = estado.mapa;
    preencherIndicadores(estado.manifesto);
    if (estado.status) status(estado.status);
    atualizarBadge();
    if (map && estado.manifesto && map.getLayer && map.getLayer('unidades-preenchimento')) {
      desenharLegenda(estado.indicador);
      if (estado.selecionado) mostrarFicha(estado.selecionado);
    }
    if (map && map.isStyleLoaded && map.isStyleLoaded()) rotulosNoIdioma(map, I.idioma);
    desenharPainel();
    desenharPainelArvores();
    desenharPainelGrupos();
  });

  async function iniciar() {
    if (!window.maplibregl) {
      $('mapa').textContent = I.t('map.libError');
      status(function () { return I.t('map.unavailable'); });
      return;
    }
    var map = new maplibregl.Map({
      container: 'mapa',
      style: await estiloBase(),
      center: cfg.centro || [-43.4, -22.9],
      zoom: cfg.zoom || 10,
      minZoom: cfg.zoomMinimo || 2,
      maxZoom: 17,
      attributionControl: { compact: true }
    });
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
    map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }), 'bottom-left');
    window.atlasMapa = map;

    var manifesto = await carregarManifesto();
    estado.manifesto = manifesto;
    preencherIndicadores(manifesto);
    atualizarBadge();
    carregarPainel();
    carregarPainelArvores();
    carregarPainelGrupos();

    map.on('load', async function () {
      rotulosNoIdioma(map, I.idioma);
      if (!manifesto) {
        status(function () { return I.t(chave('noLayer')); });
        estado.mapa = map;
        return;
      }
      try {
        await adicionarCamada(map, manifesto);
        status(textoCarregado);
        aplicarIndicador(map, $('indicador').value);
        $('indicador').addEventListener('change', function (e) { aplicarIndicador(map, e.target.value); });
      } catch (e) {
        console.error(e);
        status(function () { return I.t('map.layerError'); });
      }
      estado.mapa = map;
    });
  }

  document.addEventListener('DOMContentLoaded', iniciar);
})();
