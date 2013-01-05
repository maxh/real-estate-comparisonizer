/** offline_tasks.dart: A helper program for offline data processing.
 *  
 *  Takes one of two arguments: fetch or blacklist
 *  
 *  > dart offline_tasks.dart fetch
 *  If Street View doesn't have imagery at a requested (lat,lng), it gives a 
 *  404. To avoid this, this script preprocesses the census data to find a
 *  (lat,lng) with imagery for each zip code. It uses the Geocoding API to find
 *  the (lat,lng) of the city provided in the census file.
 *  
 *  > dart offline_tasks.dart blacklist
 *  Adds a "#" to the beginning of each line with a blacklisted zip in the file
 *  PROCESSED_ZIPS. Blacklisted zips are stored in BLACKLIST but have no effect
 *  until this offline task is run.
 *   
 * */

import 'dart:io';
import 'dart:uri';
import 'dart:utf';
import 'dart:json';

import 'shared/zip_area.dart';
import 'shared/constants.dart';

class Fetcher {  
  // To avoid limits on the Geocoding API, do this in patches.
  const int NUM_TO_PROCESS = 500;
  
  Queue<ZipArea> requestQueue;
  Queue<ZipArea> results;
  ZipArea cur;
  var httpClientFactory;
  
  Fetcher() {
    // TODO(maxh): If no input file is found, retrieve it from CENSUS_URL.
    File o = new File(PROCESSED_ZIPS);
    Future<List<String>> finishedReading = o.readAsLines(Encoding.ASCII);
    finishedReading.then((List<String> lines) {
      File i = new File(CENSUS_ZIPS);
      Future<List<String>> finishedReading = i.readAsLines(Encoding.ASCII);
      finishedReading.then(parseZipAreas(lines.length+1));
    });  
  }
  
  String clean(String inStr) {
      return inStr.
          replaceAll(new RegExp("[^A-Za-z0-9 ]"), "").
          replaceAll(" ","+");
  }
  
  void startRequests() {
    httpClientFactory = new HttpClient();
    results = new Queue<ZipArea>();
    sendNextRequest();
  }
  
  void sendNextRequest() {
    cur = requestQueue.removeFirst();
    var urlStringBuffer = new StringBuffer(GEOCODE_URL);
    var u = new Uri(urlStringBuffer.
        add(clean(cur.city)).add("+").
        add(clean(cur.state)).add("&").
        add("components=postal_code:${cur.zip}").
        toString());
    
    HttpClientConnection connection = httpClientFactory.getUrl(u);
    connection.onResponse = handleResponse;
    connection.onError = (e) {
      throw "== ERROR CONNECTING: $e";
    };
  }
  
  void handleResponse(HttpClientResponse resp) {
    print("== Response recieved. Status code: ${resp.statusCode}");
    if (resp.statusCode!=200) {
      print("== Headers: ${resp.headers}");
      return;
    }
    
    var buffer = new StringBuffer();
    var input = resp.inputStream;
    input.onData = () => buffer.add(new String.fromCharCodes(input.read()));
    input.onClosed = () {
      try {
        var respMap = JSON.parse(buffer.toString());
        int zipcode = getZip(respMap["results"][0]["address_components"]);
        print("Processing zipcode: ${cur.zip}");
        
        cur.lat = respMap["results"][0]["geometry"]["location"]["lat"];
        cur.lng = respMap["results"][0]["geometry"]["location"]["lng"];
  
        results.add(cur);
      }
      catch (e) {
        if (buffer.toString().contains("OVER_QUERY_LIMIT")) {
          print ("== OVER QUERY LIMIT. STOPPING REQUESTS.");
          throw e;
        }
        print ("== ERROR PARSING INPUT.\n"
        "==   CUR ZIPCODE: ${cur.zip}\n"
        "==   INPUT: ${buffer.toString()}\n"
        "==   ERROR: $e\n"
        "==   CONTINUING...\n");
        
      }
      if (requestQueue.length > 0)
        sendNextRequest();
      else // This was the last request!
        writeToFile();
    };
    input.onError = (e) {
      throw "== ERROR READING INPUT.\n"
            "==   CUR ZIPCODE: ${cur.zip}\n"
            "==   INPUT SO FAR: ${buffer.toString()}\n"
            "==   ERROR: $e\n";
    };
  }
  
  void writeToFile() {
    httpClientFactory.shutdown();
    File f = new File(PROCESSED_ZIPS);
    for (ZipArea z in results)
      f.writeAsStringSync(z.toRawZipLine(), 
                          FileMode.APPEND);
  }
  
  int getZip(List<Map> addressComponents) {
    for (Map addressComponent in addressComponents) {
      if (addressComponent["types"].contains("postal_code"))
        return int.parse(addressComponent["long_name"]);
    }
    return -1;
  }
  
  Function parseZipAreas(int firstToProcess) {
    return (List<String> lines) {
      requestQueue = new Queue<ZipArea>();
      for (var i = firstToProcess; 
             i < firstToProcess+NUM_TO_PROCESS && i < lines.length; 
               i++) {
        var a = lines[i].split(",");
        String zipCode = a[1].replaceAll('"', "");
        
        // Add this zip area to the map if it's not there already.
        requestQueue.add(new ZipArea(
            /* zip: */ zipCode,
            /* state: */ a[2].replaceAll('"', ""),
            /* city: */ a[3].replaceAll('"', ""),
            /* lng: */ double.parse(a[4])*-1,
            /* lat: */ double.parse(a[5]),
            /* population: */ int.parse(a[6])));
      }
      startRequests();
    };
  }
}

class Blacklister {
  static void processBlacklist() {
     File f = new File(BLACKLIST);
     var linesFuture = f.readAsLines();
     linesFuture.then((List<String> lines) {
       // TODO: add a # at the beginning of lines with blacklisted zips.
     });
  }
}

void main() {
  List<String> args = (new Options()).arguments;
  if (args.contains("fetch")) {
    Fetcher f = new Fetcher();
  }
  else if (args.contains("blacklist")) {
    Blacklister.processBlacklist();
  }
  else 
    print("Usage: dart offline_tasks.sh { fetch | blacklist }");
}
