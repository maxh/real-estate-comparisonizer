import 'dart:io';
import 'dart:uri';
import 'dart:math';
import 'dart:json';

import 'shared/zip_area.dart';
import 'shared/static_file_handler.dart';
import 'shared/constants.dart';

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
    server.defaultRequestHandler = new StaticFileHandler("./public/").onRequest;
    
    var port;
    try {
      port = int.parse(Platform.environment['PORT']);
      print("== Using PORT env ($port).");
    }
    catch (e) {
      port = 8080;
      print("== No PORT env variable detected. Using 8080.");
    }
    server.listen(HOSTNAME, port);
    
    var httpClientFactory = new HttpClient();
    
    // If this zip isn't already in the blacklist, add it.
    server.addRequestHandler(
      (HttpRequest req) => req.path.contains("/blacklist"),
      (HttpRequest req, HttpResponse resp) {
        print("== Request for /blacklist");
        File f = new File(BLACKLIST);
        var s = f.readAsString();
        s.then((String cur_blacklist) {
          int zip = int.parse(req.queryParameters["zip"]);
          if (!cur_blacklist.contains(zip.toString()))
            f.writeAsString('${zip}\n', FileMode.APPEND);
          resp.outputStream.close();
        });
      }
    );
    
    // Responds a random zip + meta data.
    server.addRequestHandler(
      (HttpRequest req) => req.path == "/random-zip",
      (HttpRequest req, HttpResponse resp) {
        print("== Request for /random-zip");
        int index = int.parse(req.queryParameters["index"]);
        resp.outputStream.write(randomZipAreaJson(index).charCodes);
        resp.outputStream.close();
      }
    );
    
    // An endpoint to make requests on behalf of client-side code.
    server.addRequestHandler(
        (HttpRequest reqFromClient) => reqFromClient.path.contains("/proxy"),
        (HttpRequest reqFromClient, HttpResponse respToClient) {
          print("== Request for /proxy");
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
  
  String randomZipAreaJson(int index) {
    Random r = new Random();
    String l1;
    l1 = "#"; // # at the beginning of a line means the zip is blacklisted
    while (l1[0] == "#")
      l1 = rawZipLines.removeAt(r.nextInt(rawZipLines.length));
    return '{"index":$index,'
            '"value":${ZipArea.jsonFromRawZipLine(l1)}}';
  }
}

main() {
  RealEstateCompServer s = new RealEstateCompServer();
}
