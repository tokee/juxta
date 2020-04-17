// Provides basic search functionality for juxta
// Must be included _after_ the dropdown selector on the web page

searchConfig = {
    defaultSearchImage: true,
    defaultSearchPath: false,
    defaultSearchMeta: true,
    defaultSearchMode: 'infix', // Possible values: prefix, infix
    defaultCaseSensitive: false,
    maxMatches: 1000,
}

// https://stackoverflow.com/questions/610406/javascript-equivalent-to-printf-string-format
String.prototype.format = function() {
    var formatted = this;
    for (var i = 0; i < arguments.length; i++) {
        var regexp = new RegExp('\\{'+i+'\\}', 'gi');
        formatted = formatted.replace(regexp, arguments[i]);
    }
    return formatted;
};


var svg = null;
var diffusor = null;
var svgString = '';
var homeBounds = null;
function createSVGOverlay() {
    homeBounds = myDragon.viewport.getHomeBounds();
    /* Must be before the svg so that it is positioned underneath */
    diffusor = document.createElement("div");
    diffusor.id = "diffusor-overlay";
    myDragon.addOverlay({
        element: diffusor,
        location: homeBounds
    });

    svg = document.createElement("div");
    svg.id = "svg-overlay";
    myDragon.addOverlay({
        element: svg,
//        location: new OpenSeadragon.Rect(0, 0, 1.05, 1)
        location: homeBounds
    });
    svgString = '';
}
createSVGOverlay();

function clearSVGOverlay() {
    if (diffusor) {
        svgString = '';
        updateSVGOverlay('');
        diffusor.style.opacity = 0.0;
    } else {
        createSVGOverlay();
    }
}
console.log("HomeBounds: " + JSON.stringify(myDragon.viewport.getHomeBounds()));

var jprops = overlays.jprops;
console.log("jprops: " + JSON.stringify(jprops));
function updateSVGOverlay(svgXML) {

    svgString += svgXML;
    svg.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" style="position:absolute;z-index:10;margin:0;padding:0;top:0;left:0;width:100%;height:100%" viewBox="{0} {1} {2} {3}">{4}</svg>'.format(homeBounds.x, homeBounds.y, homeBounds.width, homeBounds.height, svgString);

    //    svg.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" style="position:absolute;z-index:10;margin:0;padding:0;top:0;left:0;width:100%;height:100%" viewBox="{0} {1} {2} {3}">{4}</svg>'.format(0, 0, 1, 1, svgString);
    
//    svg.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" style="position:absolute;z-index:10;margin:0;padding:0;top:0;left:0;width:100%;height:100%" viewBox="0 0 ' + jprops.colCount + ' ' + jprops.rowCount + '">' + svgString + '</svg>';
    diffusor.style.opacity = 0.8;
}

function addBoxes(boxIDs) {
    var svgBoxes = '';
    for (var i = 0 ; i < boxIDs.length; i++) {
        svgBoxes += getBox(boxIDs[i]);
    }
    updateSVGOverlay(svgBoxes);
}
function addBox(boxID) {
    updateSVGOverlay(getBox(boxID));
}
function getBox(boxID) {
    x = boxID % jprops.colCount;
    y = Math.floor(boxID / jprops.colCount);
    boxW = 1 / jprops.colCount;
    boxH = 1 / jprops.rowCount;
    lineWidth = 0.01 * 1 / Math.min(jprops.colCount, jprops.rowCount);
 
   xFactor = homeBounds.width+homeBounds.x;
    yFactor = homeBounds.height+homeBounds.y;
    
//    console.log("box={0], x={1}, y={2}, xFactor={3}, yFactor={4}".format(boxID, x, y, xFactor, yFactor));
    //boxW *= xFactor;
    //boxH *= yFactor;
    x = x / jprops.colCount;
    y = y / jprops.rowCount * 0.923;
    boxH *= 0.923;
    
    return'<rect x="{0}" y="{1}" width="{2}" height="{3}" style="fill:transparent;stroke-width:{4};stroke:{5}" />\n'.format(x, y, boxW, boxH, lineWidth, "#8888ff");
}

for (var i = 0 ; i < 15 ; i++) {
    for (var j = 0 ; j < 15 ; j++) {
     //   addBox(i*14+(j*3));
    }
}

//updateSVGOverlay('<rect x="-2.125" y="0" width="4" height="4" style="fill:transparent;stroke-width:0.1;stroke:#ffffff" />\n')
//updateSVGOverlay('<rect x="-1.46" y="0" width="13" height="19" style="fill:transparent;stroke-width:0.1;stroke:#00ffff" />\n')
    
function clearSearch() {
    console.log("Clearing previous search result")
    clearSVGOverlay();
}

// Returns { matchCount: int, matches: [index*] }
function searchAndDisplay(query, searchImage = searchConfig.defaultSearchImage, searchPath = searchConfig.defaultSearchPath, searchMeta = searchConfig.defaultSearchMeta, searchMode = searchConfig.defaultSearchMode, caseSensitive = searchConfig.defaultCaseSensitive) {
    clearSearch();
    var result = simpleSearch(query, searchImage, searchPath, searchMeta, searchMode, caseSensitive);
    addBoxes(result.matches);
    return result;
}

// Returns { matchCount: int, matches: [index*] }
function simpleSearch(query, searchImage = searchConfig.defaultSearchImage, searchPath = searchConfig.defaultSearchPath, searchMeta = searchConfig.defaultSearchMeta, searchMode = searchConfig.defaultSearchMode, caseSensitive = searchConfig.defaultCaseSensitive) {
    var metaCache = overlays.metaCache[0];
    if (metaCache.status != 'ready') {
        console.error("Error: Cannot perform search for '" + query + "' as no overlays.metaCache is available");
        return
    }
    if (metaCache.source != "0_0.json") {
        console.error("Error: overlays.metaCache[0].source == '" + metaCache.source + "'. It should be '0_0.json'. Make sure to set ASYNC_META_SIDE to more than the number of horizontal and vertical images in the collage when rendering");
        return;
    }
    console.log("Searching for '" + query + "'");
        
    var matches = [];
    var matchCount = 0;
    var queryL = caseSensitive ? query : query.toLowerCase();
    for (var index = 0 ; index < metaCache.meta.length ; index++) {
        var full = metaCache.meta[index];
        if (jprops.metaIncludesOrigin) {
            // TODO: Move pre- and post-fix to the json metadata files
            var path = metaCache.prefix + full.split('|')[0] + metaCache.postfix;
            var last = path.lastIndexOf("/");
            var image = last == -1 ? path : path.substr(last+1);
                
            // TODO: Create a better splitter that handles multiple |
            var meta = full.split('|')[1];
        } else {
            meta = full;
        }
        if (typeof(result.meta) == 'undefined') { // Happens for single images without metadata
            meta = '';
        }
        if (!caseSensitive) {
            path = path.toLowerCase();
            image = image.toLowerCase();
            meta = meta.toLowerCase();
        }

        
        if ((searchImage && (searchMode == 'prefix' && image.startsWith(query)) || (searchMode == 'infix' && image.includes(query))) ||
            (searchPath && (searchMode == 'prefix' && path.startsWith(query)) || (searchMode == 'infix' && path.includes(query))) ||
            (searchMeta && (searchMode == 'prefix' && meta.startsWith(query)) || (searchMode == 'infix' && meta.includes(query)))) {
            matchCount++;
            if (matchCount <= searchConfig.maxMatches) {
                matches.push(index);
             }
        }
    }
    console.log("Got " + matchCount + " matches for query '" + query + "'");
    return { matchCount: matchCount, matches: matches };
}

function enableSearch() {
    // Optional drop down with predefined searches
    if (document.getElementById('fixed_search')) {
        console.log("Enabling predefined searches");
        document.getElementById('fixed_search').onchange = function() {
            if (this.value == 'clear') {
                clearSearch();
            } else {
                searchAndDisplay(this.value);
            }
        }
    } else {
        console.log("Unable to locate select-element 'fixed_search': Predefined searches will not be available");
    }
}
enableSearch();

