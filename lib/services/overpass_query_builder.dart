/// Overpass API sorgu + bounding-box üreteçleri (saf, IO'suz, test edilebilir).
/// map_screen'deki `_fetchHikingLayer` / `_fetchOverpassLayer` sorgu kurulum
/// mantığından çıkarıldı. Yanlış bbox/sorgu = bozuk erişilebilirlik katmanı
/// (ürünün varlık sebebi), bu yüzden birim testiyle korunur
/// (test/unit/overpass_query_builder_test.dart).
/// HTTP çağrısı ve JSON→UI (Polyline/Marker) eşlemesi bilinçli olarak ekranda
/// (map_screen) kaldı; burada yalnızca saf string üretimi var.
/// (bkz. vault/07-Performance/10-Cache-CDN.md, vault/01-Frontend/01-On-Yuz.md)
library;

/// Merkez etrafında Overpass "south,west,north,east" bbox dizesi üretir
/// (lat ± [latDelta], lon ± [lonDelta], 6 ondalık).
String overpassBoundingBox(
  double centerLat,
  double centerLon, {
  required double latDelta,
  required double lonDelta,
}) {
  final south = (centerLat - latDelta).toStringAsFixed(6);
  final north = (centerLat + latDelta).toStringAsFixed(6);
  final west = (centerLon - lonDelta).toStringAsFixed(6);
  final east = (centerLon + lonDelta).toStringAsFixed(6);
  return '$south,$west,$north,$east';
}

/// Yaya yolları (footway · pedestrian · path · steps) Overpass QL sorgusu.
String hikingOverpassQuery(String bbox) {
  return '[out:json][timeout:25];('
      'way["highway"="footway"]($bbox);'
      'way["highway"="pedestrian"]($bbox);'
      'way["highway"="path"]["foot"!="no"]($bbox);'
      'way["highway"="steps"]($bbox);'
      ');out body;>;out skel qt;';
}

/// Erişilebilirlik (hissedilebilir yüzey / tekerlekli sandalye / asansör /
/// engelli otoparkı) Overpass QL sorgusu. Yalnızca aktif katmanların way+node
/// bloklarını ekler. Blok sırası map_screen'deki orijinal sorguyla birebir
/// korunur (way blokları önce, node blokları sonra).
String accessibilityOverpassQuery(
  String bbox, {
  required bool tactile,
  required bool wheelchair,
  required bool elevator,
  bool parking = false,
}) {
  final buf = StringBuffer('[out:json][timeout:30];(');
  // Way sorgusu — yollar / kaldırımlar (polyline)
  if (tactile) {
    buf.write('way["tactile_paving"="yes"]($bbox);');
  }
  if (wheelchair) {
    buf.write('way["wheelchair"="yes"]($bbox);');
    buf.write('way["wheelchair"="designated"]($bbox);');
  }
  // Node sorgusu — tekil mekan noktaları (marker)
  if (wheelchair) {
    buf.write('node["wheelchair"="yes"]($bbox);');
    buf.write('node["wheelchair"="designated"]($bbox);');
  }
  if (tactile) {
    buf.write('node["tactile_paving"="yes"]($bbox);');
  }
  if (elevator) {
    buf.write('node["highway"="elevator"]($bbox);');
    buf.write('node["railway"="elevator"]($bbox);');
  }
  // Engelli otoparkı — wheelchair=yes/designated tag'li otopark noktaları.
  if (parking) {
    buf.write('node["amenity"="parking"]["wheelchair"="yes"]($bbox);');
    buf.write('node["amenity"="parking"]["wheelchair"="designated"]($bbox);');
    buf.write('node["amenity"="parking_space"]["wheelchair"="designated"]($bbox);');
  }
  buf.write(');out body;>;out skel qt;');
  return buf.toString();
}
