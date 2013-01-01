import 'dart:html';
import 'dart:json';
import 'package:js/js.dart' as js;

const String LOCAL_URL = "http://127.0.0.1:8080";
const String ZILLOW_URL = "http://www.zillow.com/webservice/GetDemographics.htm";
const String ZWS_ID = "X1-ZWz1bjkopnfi8b_avwne";

// A tuple of the two zipcode areas currently being compared.
List<Map> zipAreas;

var maps;
var streetViewPortals;
var outstandingRequests = 0;

void main() {
  layoutDom();
  initStreetViewPortals();
  loadZipAreas();
}

void loadZipAreas() {
  HttpRequest requestPropertyTax(int i) {
    String url = "$LOCAL_URL/proxy?url=$ZILLOW_URL"
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
            print("${zipAreas[i]["zip"]} has no property tax value in Zillow.");
            blacklist(zipAreas[i]["zip"]);
            //loadZipAreas();
          }
          else {
            propertyTax = int.parse(attr.query("values zip value").text);
            print(attr.query("values zip value").text);
          }
          zipAreas[i].putIfAbsent("propertyTax", () => propertyTax);
          // Update the Street View portal.
          js.scoped(() {
            streetViewPortals[i].setPosition(
                new js.Proxy(maps.LatLng, zipAreas[i]['lat'], zipAreas[i]['lng'])); 
          });
        }
      }
    );
  }
  
  HttpRequest getRandomZips = new HttpRequest.get("$LOCAL_URL/random-zips",
    (result) { 
      print(result.responseText);
      zipAreas = JSON.parse(result.responseText);
      requestPropertyTax(0);
      requestPropertyTax(1);
  });
}

void blacklist(String zipcode) {
  print("Blacklisting ${zipcode}...");
  new HttpRequest.get("$LOCAL_URL/blacklist-zip?zip=${zipcode}",
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
      loadZipAreas();
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