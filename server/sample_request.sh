#/bin/sh

curl -v \
-H "Host: maps.googleapis.com" \
-H "Connection: keep-alive" \
-H "Cache-Control: no-cache" \
-H "Pragma: no-cache" \
-H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.95 Safari/537.11" \
-H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
-H "Accept-Language: en-US,en;q=0.8" \
-H "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3" \
'http://maps.googleapis.com/maps/api/geocode/json?sensor=false&address=mountain+view+ca+94043'

#-H "Accept-Encoding: gzip,deflate,sdch" \
