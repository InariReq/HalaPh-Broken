/* Lightweight map initialization fallback for Sakay.ph web assets.
   This provides a Leaflet-based OpenStreetMap view when the full routing
   stack isn't ready, avoiding a white screen on view route.
*/
(function() {
  var initMap = function() {
    if (typeof L === 'undefined') {
      // Leaflet not loaded yet; retry shortly
      setTimeout(initMap, 200);
      return;
    }
    var mapEl = document.getElementById('map');
    if (!mapEl) return;
    try {
      var map = L.map('map').setView([14.5995, 120.9842], 12); // Manila center
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors'
      }).addTo(map);
      // Expose global for other helpers (e.g., resize guards)
      window.map = map;
    } catch (e) {
      console.error('Sakay.ph map.js init error:', e);
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initMap);
  } else {
    initMap();
  }

  // Expose a soft resize helper to be compatible with existing code
  window._sakay_map_refit = function() {
    if (window.map && typeof window.map.invalidateSize === 'function') {
      window.map.invalidateSize();
    }
  };
})();
