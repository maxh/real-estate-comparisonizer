library zipArea;

// Google Maps endpoint that resolves an address to lat and lng.
const String GEOCODE_URL = "http://maps.googleapis.com/maps/"
  "api/geocode/json?sensor=false&address=";

// US Census file with zip code information on the web.
const String CENSUS_URL = 
  "http://www.census.gov/tiger/tms/gazetteer/zips.txt";

// Local copy of the input file.
const String CENSUS_ZIPS = "./server/data/census_zips.txt";

// Preprocessed zipcodes.
const String PROCESSED_ZIPS = "./server/data/out_zips.txt";

// Blacklisted zipcodes.
const String BLACKLIST = "./server/data/blacklist.txt";

const String HOSTNAME = "0.0.0.0";
