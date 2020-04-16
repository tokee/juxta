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

function clearSearch() {
    console.log("Clearing previous search result")
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
                simpleSearch(this.value);
            }
        }
    } else {
        console.log("Unable to locate select-element 'fixed_search': Predefined searches will not be available");
    }
}
enableSearch();
