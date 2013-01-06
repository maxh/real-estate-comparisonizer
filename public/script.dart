import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;

const String IMAGERY_CHECK = "http://maps.google.com/cbk?output=json&hl=en&"
                             "radius=50&cb_client=maps_sv&v=4&ll=";
const String ZWS_URL = "http://www.zillow.com/webservice/GetDemographics.htm";
const String ZWS_ID = "X1-ZWz1bjkopnfi8b_avwne";

// A list of the two zipcode areas currently being compared.
List<Map> zipAreas;

// JS objects
var maps, sv;
var streetViewPortals;

void main() {
  zipAreas = new List<Map>();
  layoutDom();
  initStreetViewPortals();
  ZipAreaLoader.loadRandomZip(0);
  ZipAreaLoader.loadRandomZip(1);
}

class ZipAreaLoader {
  
  static loadRandomZip(int index) {
    while (zipAreas.length<index+1)
      zipAreas.add(null);
    return new HttpRequest.get("/random-zip?index=$index",
      (result) { 
        print(result.responseText);
        var json_result = JSON.parse(result.responseText);
        zipAreas[index] = json_result["value"];
        // Check if this lat+lng has StreetView imagery.
        js.scoped((){
          sv.getPanoramaByLocation(
              new js.Proxy(maps.LatLng, zipAreas[index]['lat'], 
                zipAreas[index]['lng']), 50,
                new js.Callback.once((data, status) {
                  // If no, load another zip.
                  if (status != maps.StreetViewStatus.OK) {
                    print("${zipAreas[index]["zip"]} has no sv imagery.");
                    blacklist(zipAreas[index]['zip']);
                    ZipAreaLoader.loadRandomZip(index);
                  }
                  // If yes, check to see if it has property tax.
                  else
                    ZipAreaLoader.requestPropertyTax(index);
                })
              );
        });
    });
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
          // If no prop. tax, load another zip.
          if (attr.query("values zip value") == null) {
            print("${zipAreas[i]["zip"]} has no prop. tax value in Zillow.");
            blacklist(zipAreas[i]["zip"]);
            loadRandomZip(i);
          }
          else {
            propertyTax = int.parse(attr.query("values zip value").text);
            print(attr.query("values zip value").text);
            zipAreas[i].putIfAbsent("propertyTax", () => propertyTax);
            // Update the Street View portal.
            js.scoped(() {
              streetViewPortals[i].setPosition(
                  new js.Proxy(maps.LatLng, zipAreas[i]['lat'], 
                               zipAreas[i]['lng']));
            });
          }
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
      if(zipAreas[i]["propertyTax"] != null
          && zipAreas[(i+1)%2]["propertyTax"] != null)
        if(zipAreas[i]["propertyTax"]>zipAreas[(i+1)%2]["propertyTax"])
          query("#right").text = (int.parse(query("#right").text)+1).toString();
        else
          query("#wrong").text = (int.parse(query("#wrong").text)+1).toString();
      ZipAreaLoader.loadRandomZip(0);
      ZipAreaLoader.loadRandomZip(1);
    });
  }
  
  // Use the helper function above to clone container DOM from the templates.
  addContainer(0);
  addContainer(1);
}

void initStreetViewPortals() {
  streetViewPortals = new List<js.Proxy>();
  js.scoped(() {
    // Helper function to add a portal. Called below.
    void addPortal (int i, var options) {
      streetViewPortals.add(new js.Proxy(maps.StreetViewPanorama,
        query("#container$i .map_canvas"), js.map(options)));
      js.retain(streetViewPortals[i]);
    }
    
    maps = js.context.google.maps;
    js.retain(maps);
    
    sv = new js.Proxy(maps.StreetViewService);
    js.retain(sv);
    
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