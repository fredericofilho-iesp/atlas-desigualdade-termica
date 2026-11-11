/* Protótipo: apenas mapa-base, sem indicadores científicos. */
const map = L.map('map', {scrollWheelZoom: false}).setView([-22.9068,-43.1729], 11);
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19,
  attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>'
}).addTo(map);
L.control.scale({imperial:false}).addTo(map);
