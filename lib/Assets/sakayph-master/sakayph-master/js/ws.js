/*
 * Copyright 2013 Thomas Dy, Philip Cheang under the terms of the
 * MIT license found at http://sakay.ph/LICENSE
 */
var geocoder = function() {
  var API = 'https://nominatim.openstreetmap.org';

  function toLegacyResult(item) {
    return {
      formatted_address: item.display_name,
      geometry: {
        location: {
          lat: function() { return parseFloat(item.lat); },
          lng: function() { return parseFloat(item.lon); }
        }
      },
      raw: item
    };
  }

  function callNominatim(endpoint, data) {
    return Q(reqwest({
      url: API+endpoint,
      type: 'json',
      crossOrigin: true,
      data: data
    })).then(function(results) {
      if (!Array.isArray(results)) results = [results];
      return results.map(toLegacyResult);
    });
  }

  return {
    fromName: Q.fbind(function(query, bounds) {
      return callNominatim('/search', {
        q: query,
        format: 'json',
        countrycodes: 'ph',
        limit: 5,
        viewbox: [
          bounds.getWest(),
          bounds.getSouth(),
          bounds.getEast(),
          bounds.getNorth()
        ].join(',')
      });
    }),
    fromLatLng: Q.fbind(function(latlng) {
      return callNominatim('/reverse', {
        lat: latlng.lat,
        lon: latlng.lng,
        format: 'json'
      });
    })
  }
}();

var staticMaps = function() {
  var API = 'https://staticmap.openstreetmap.de/staticmap.php';
  var HEIGHT = 260;
  var WIDTH = 400;

  function formatPoint(point) {
    return point.lat.toFixed(6)+','+point.lon.toFixed(6);
  }

  return function url(leg) {
    var start = leg.from;
    var end = leg.to;

    var queryString = "";
    queryString += "?size="+WIDTH+"x"+HEIGHT;
    queryString += "&markers="+formatPoint(start)+",greenA";
    queryString += "|"+formatPoint(end)+",redB";
    return API+queryString;
  }
}();

var otp = function() {
  var API = 'http://sakay.ph/api'

  function callApi(endpoint, data) {
    return Q(reqwest({
      url: API+endpoint,
      type: 'jsonp',
      data: data
    }));
  }

  return {
    route: function(from, to, mode) {
      var d = new Date();
      return callApi('/plan', {
        date: d.getFullYear()+'-'+(d.getMonth()+1)+'-'+d.getDate(),
        time: '11:59am',
        mode: mode,
        fromPlace: latlng2str(from),
        toPlace: latlng2str(to)
      })
    }
  }
}();
