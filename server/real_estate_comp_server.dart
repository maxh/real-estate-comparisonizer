import 'dart:io';
import 'dart:uri';
import 'dart:math';
import 'dart:json';

import './zip_area.dart';
import './constants.dart';

class RealEstateCompServer {
  
  List<String> rawZipLines;
  HttpClient httpClientFactory;
  
  RealEstateCompServer() { 
    print("== Preparing server...");  
    // Load zip codes from local file.
    File f = new File(PROCESSED_ZIPS);
    Future<List<String>> finishedReading = f.readAsLines(Encoding.ASCII);
    finishedReading.then((List<String> lines) {
      rawZipLines = lines;
      print("== I just digested ${rawZipLines.length} zip codes.");
      startServer();
    });
  }
  
  void startServer() {
    var server = new HttpServer();
    var httpClientFactory = new HttpClient();
    
    server.listen('127.0.0.1', 8080);
    
    // Returns two random zip codes and meta data.
    server.addRequestHandler(
      (HttpRequest req) => req.path.contains("/blacklist"),
      (HttpRequest req, HttpResponse resp) {
        resp.headers.add("Access-Control-Allow-Origin", "*");
        File f = new File(BLACKLIST);
        var s = f.readAsString();
        s.then((String cur_blacklist) {
          int zip = int.parse(req.queryParameters["zip"]);
          // If this zip isn't already in the blacklist, add it.
          if (!cur_blacklist.contains(zip.toString()))
            f.writeAsString('${zip}\n', FileMode.APPEND);
        });
      }
    );
    
    // Returns two random zip codes and meta data.
    server.addRequestHandler(
      (HttpRequest req) => req.path == "/random-zips",
      (HttpRequest req, HttpResponse resp) {
        resp.headers.add("Access-Control-Allow-Origin", "*");
        resp.outputStream.write(randomZipAreasJson().charCodes);
        resp.outputStream.close();
      }
    );
    
    // An endpoint to make requests on behalf of client-side code.
    server.addRequestHandler(
        (HttpRequest reqFromClient) => reqFromClient.path.contains("/proxy"),
        (HttpRequest reqFromClient, HttpResponse respToClient) {
          respToClient.headers.add("Access-Control-Allow-Origin", "*");
          
          // The remote hostname and params are encoded in the query to /proxy.
          var params = reqFromClient.queryParameters;
          print("Request to /proxy received with params: ${params}");
          
          // Build the remote request URL from params.
          StringBuffer s = new StringBuffer(params["url"]);
          s = s.add("?");
          for (String param in params.keys) {
            if (param == "url")
              continue; 
            s = s.add(param).add("=").add(params[param]).add("&");
          }
          Uri u = new Uri(s.toString());
          
          // Send request to remote server.
          HttpClientConnection connWithRemote = httpClientFactory.getUrl(u);
          
          // Relay the response from the remote server to the client.
          connWithRemote.onResponse = (HttpClientResponse respFromRemote) =>
            respFromRemote.inputStream.pipe(respToClient.outputStream);
          
          connWithRemote.onError = (e) =>
            throw "== ERROR CONNECTING TO URL: $u"
                  "== ERROR MESSAGE: $e";
        }
    );
    print("== Server up! Awaiting requests...");
  }
  
  String randomZipAreasJson() {
    Random r = new Random();
    String l1, l2;
    l1 = l2 = "#"; // # at the beginning of a line means the zip is blacklisted
    while (l1[0] == "#")
      l1 = rawZipLines.removeAt(r.nextInt(rawZipLines.length));
    while (l2[0] == "#")
      l2 = rawZipLines.removeAt(r.nextInt(rawZipLines.length));
    return "[${ZipArea.jsonFromRawZipLine(l1)},"
            "${ZipArea.jsonFromRawZipLine(l2)}]";
  }
}

main() {
  RealEstateCompServer s = new RealEstateCompServer();
}
