library zipArea;

class ZipArea {
  String zip, state, city; // zip codes are Strings to preserve leading 0s.
  double lat, lng;
  int population;
  
  // Order is consistent with the input file from the census.
  ZipArea(this.zip,this.state,this.city,this.lng,this.lat,this.population);
  
  ZipArea.fromRawZipLine(String s) {
    var vals = s.split(",");
    zip = s[0];
    state = s[1];
    city = s[2];
    lng = double.parse(s[4]);
    lat = double.parse(s[3]);
    population = int.parse(s[5]);
  }
  
  String toRawZipLine() {
    return "${zip},${state},${city},${lat},${lng},${population}\n";
  }
  
  String toJson() {
    return '{'
      '"zip":"${this.zip}",'
      '"state":"${this.state}",'
      '"city":"${this.city}",'
      '"lat":${this.lat},'
      '"lng":${this.lng},'
      '"population":${this.population}'
      '}';
  }
  
  static String jsonFromRawZipLine(String i) {
    var s = i.split(",");
    return '{'
      '"zip":"${s[0]}",'
      '"state":"${s[1]}",'
      '"city":"${s[2]}",'
      '"lat":${s[3]},'
      '"lng":${s[4]},'
      '"population":${s[5]}'
      '}';
  }
}
