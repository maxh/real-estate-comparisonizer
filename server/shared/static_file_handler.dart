library staticFileHandler;

import 'dart:io';

// From Seth Ladd's chat app.
class StaticFileHandler {
  final String basePath;
  
  StaticFileHandler(this.basePath);
  
  _send404(HttpResponse response) {
    response.statusCode = HttpStatus.NOT_FOUND;
    response.outputStream.close();
  }

  // TODO: etags, last-modified-since support
  onRequest(HttpRequest request, HttpResponse response) {
    print("== Request for ${request.path}");
    final String path = request.path == '/' ? '/index.html' : request.path;
    final File file = new File('${basePath}${path}');
    print("== Looking in ${basePath}${path}");
    file.exists().then((found) {
      if (found) {
        file.fullPath().then((String fullPath) {
          print("== Fullpath is $fullPath");
          if ((fullPath.contains("/public/") ||
              fullPath.contains(".pub-cache/hosted")) && (
              fullPath.endsWith(".dart") ||
              fullPath.endsWith(".html") ||
              fullPath.endsWith(".css") ||
              fullPath.endsWith(".js"))) {
            file.openInputStream().pipe(response.outputStream);
          } else {
            print("== Fullpath does not meet security criteria");
            _send404(response);
          }
        });
      } else {
        print("== File not found at all");
        _send404(response);
      }
    }); 
  }
}