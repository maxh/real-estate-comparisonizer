import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;

const String IMAGERY_CHECK = "http://maps.google.com/cbk?output=json&hl=en&"
                             "radius=50&cb_client=maps_sv&v=4&ll=";
const String ZWS_URL = "http://www.zillow.com/webservice/GetDemographics.htm";
const String ZWS_ID = "X1-ZWz1bjkopnfi8b_avwne";

// A tuple of the two zipcode areas currently being compared.
List<Map> zipAreas;

var maps;
var streetViewPortals;
var outstandingRequests = 0;

void main() {
  layoutDom();
  initStreetViewPortals();
  ZipAreaLoader.loadRandomZip(0);
  ZipAreaLoader.loadRandomZip(1);
}

class ZipAreaLoader {
  
  static loadRandomZip(int index) {
    return new HttpRequest.get("/random-zip?index=$index",
      (result) { 
        print(result.responseText);
        var json = JSON.parse(result.responseText);
        int i = int.parse(json["index"]);
        zipAreas[int.parse(json["index"])] = json["value"];
        checkForImagery(i);
    });
  }
  
  static HttpRequest checkForImagery(int i) {
    String url = "${IMAGERY_CHECK}${zipAreas[i]['lat']},${zipAreas[i]['lng']}";
    return new HttpRequest.get(url,
      (result) {
        if (result.responseText == "{}")
          loadRandomZip(i);
        else {
          requestPropertyTax(i);
        }
      }
    );
  }
  
  // Gets the property tax for the neighborhood at portal i.
  static HttpRequest requestPropertyTax(int i) {
    String url = "/proxy?url=$ZWS_URL"
        "&zws-id=$ZWS_ID&zip=${zipAreas[i]['zip']}";
    return new HttpRequest.get(url,
      (result) {
        Document respXml = result.responseXml;
        List<Element> attrs = respXml.queryAll("attribute");
        for (Element attr in attrs) {
          if (attr.query("name") == null)
            continue;
          if (attr.query("name").text != "Property Tax")
            continue;
          int propertyTax = 0;
          if (attr.query("values zip value") == null) {
            print("${zipAreas[i]["zip"]} has no prop. tax value in Zillow.");
            blacklist(zipAreas[i]["zip"]);
            loadRandomZip(i);
          }
          else {
            propertyTax = int.parse(attr.query("values zip value").text);
            print(attr.query("values zip value").text);
          }
          zipAreas[i].putIfAbsent("propertyTax", () => propertyTax);
          // Update the Street View portal.
          js.scoped(() {
            streetViewPortals[i].setPosition(
                new js.Proxy(maps.LatLng, zipAreas[i]['lat'], 
                             zipAreas[i]['lng']));
          });
        }
      }
    );
  }
}

void blacklist(String zipcode) {
  print("Blacklisting ${zipcode}...");
  new HttpRequest.get("/blacklist?zip=${zipcode}",
      (result) => {} );
}

void layoutDom() {
  void addContainer(int i) {
    Element container = query("#template_container").clone(true);
    container.id = "container$i";
    query("#battlefield").append(container);
    
    // Handle the user guessing that this is the more expensive zip.
    query("#container$i .win").on.click.add((e) {
      if(zipAreas[i]["propertyTax"]>zipAreas[(i+1)%2]["propertyTax"])
        query("#right").text = (int.parse(query("#right").text)+1).toString();
      else
        query("#wrong").text = (int.parse(query("#wrong").text)+1).toString();
      ZipAreaLoader.loadRandomZip(0);
      ZipAreaLoader.loadRandomZip(1);
    });
    
    // Handle the user blacklisting this zip.
    query("#container$i .blacklist").on.click.add((e) {
      blacklist(zipAreas[i]["zip"]);
    });
  }
  
  // Use the helper function above to clone container DOM from the templates.
  addContainer(0);
  addContainer(1);
}

void initStreetViewPortals() {
  streetViewPortals = new List<js.Proxy>();
  js.scoped(() {
    void addPortal (int i, var options) {
      streetViewPortals.add(new js.Proxy(maps.StreetViewPanorama,
        query("#container$i .map_canvas"), js.map(options)));
      js.retain(streetViewPortals[i]);
    }
    
    maps = js.context.google.maps;
    js.retain(maps);
    
    var streetViewOptions = {
      'panControl': false,
      'zoomControl': false,
      'addressControl': false,
      'linksControl': false,
      'pov': {
        'heading': 34,
        'pitch': 10,
        'zoom': 1,
      }
    };

    addPortal(0, streetViewOptions);
    addPortal(1, streetViewOptions);
  });
}