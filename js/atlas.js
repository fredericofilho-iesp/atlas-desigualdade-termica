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
    divergente: ['#2166ac', '#92c5de', '#f7f7f7', '#f4a582', '#b2182b']
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
    var n = Number(v).toLocaleString(I.locale, {
      minimumFractionDigits: casas == null ? 0 : casas,
      maximumFractionDigits: casas == null ? 2 : casas
    });
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

  function desenharLegenda(ind) {
    var el = $('legenda');
    if (!ind) { el.hidden = true; el.innerHTML = ''; return; }
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
      map.setPaintProperty('unidades-preenchimento', 'fill-color', expressaoCor(ind.id, ind.quebras || [], coresPara(ind)));
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
          formatarValor(props[ind.id], I.tr(ind.unidade), ind.casas_decimais) + '</dd></div>';
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
