// Provides overlay for the source image being pointed at
// Override juxtaCallback for custom behaviour or override createHeader & createFooter
// for smaller tweaks to default behaviour

function createOverlay(juxtaProperties, dragon) {
    // TODO: Switch getElementById to class under a given div
    this.jprops = juxtaProperties;
    this.dragonbox = document.getElementById('zoom-display');
    this.infobox = document.getElementById('infobox');
    this.header = document.getElementById('header');
    this.footer = document.getElementById('footer');
    this.imagePoint = 0;
    this.myDragon = dragon;

    this.metaCacheMax = 10;
    this.metaCache = [];

    this.boxPanMarginFraction = 1/100;
    
    // Connect overlay handling to the dragon
    if (myDragon.isOpen()) {
        attachToOpenDragon(juxtaProperties, myDragon);
    } else {
        myDragon.addHandler('open', function() {
            attachToOpenDragon(juxtaProperties, myDragon);
        });
    }

    // If metadata is preloaded, add it to the cache
    if (typeof preloaded !== 'undefined') {
        var preloadEntry = {
            status: 'ready',
            source: '0_0.json',
            meta: preloaded.meta,
            prefix: preloaded.prefix,
            postfix: preloaded.postfix
        }
        metaCache.push(preloadEntry);
    }

    // Expects the dragon to be open
    this.attachToOpenDragon = function() {
        var tracker = new OpenSeadragon.MouseTracker({
            element: myDragon.container,
            moveHandler: focusChanged
        });
        myDragon.addHandler('animation', handleChangeEvent);
        myDragon.addHandler('canvas-drag', focusChanged);
        myDragon.addHandler('canvas-click', focusChanged);
        //myDragon.addHandler('canvas-key', juxtaKeyCallback);
        //window.addEventListener("keydown", juxtaKeyCallback);
        tracker.setTracking(true);
        myDragon.addHandler('canvas-key', function (e) { 
            juxtaKeyCallback(e.originalEvent);
            //e.preventDefault = true; // disable default keyboard controls
            // TODO: Allow WASD?
            e.preventVerticalPan = true; // disable vertical panning with arrows and W or S keys
            e.preventHorizontalPan = true; // disable horizontal panning with arrows and A or D keys
        });
    }

    this.rawToWeb = function(rawX, rawY) {
        var ip = new OpenSeadragon.Point(rawX * jprops.rawW * jprops.tileSize, rawY * jprops.rawH * jprops.tileSize);
        var wp = myDragon.viewport.imageToViewportCoordinates(ip);
        var rwp = myDragon.viewport.pixelFromPoint(wp);
        return rwp;
    }

    this.currentImageGridX = function() {
        return Math.floor(imagePoint.x / jprops.tileSize / jprops.rawW);
    }
    this.currentImageGridY = function() {
        return Math.floor(imagePoint.y / jprops.tileSize / jprops.rawH);
    }
    
    this.handleChange = function(rawX = currentImageGridX(), rawY = currentImageGridY()) {
        roundWebPoint = rawToWeb(rawX, rawY);
        roundWebBRPoint = rawToWeb(rawX+1, rawY+1);
        roundWebBRPoint.x = roundWebBRPoint.x-1;
        roundWebBRPoint.y = roundWebBRPoint.y-1;
        juxtaExpand(rawX, rawY,
                    Math.floor(roundWebPoint.x), Math.floor(roundWebPoint.y),
                    Math.floor(roundWebBRPoint.x-roundWebPoint.x), Math.floor(roundWebBRPoint.y-roundWebPoint.y));
    }
    // Used for catching animation events, so result.x&y are not changed
    this.handleChangeEvent = function() {
        console.log("Animation callback");
        handleChange(result.x, result.y);
    }

    // https://openseadragon.github.io/examples/viewport-coordinates/
    this.focusChanged = function(event) {
        webPoint = event.position;
        viewportPoint = myDragon.viewport.pointFromPixel(webPoint);
        imagePoint = myDragon.viewport.viewportToImageCoordinates(viewportPoint);
        handleChange();
    }

    this.createHeader = function(x, y, image, meta) {
        return image == "" ? '(' + x + ', ' + y + ')' : image;
    }
    this.createFooter = function(x, y, image, meta) {
        return meta;
    }

    this.showFullInfo = function(boxWidth, boxHeight) {
        return boxWidth >= 150;
    }
    this.showInfoBox = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta) {
        return validPos && "missing" != image;
    }
    this.showFooter = function(x, y, image, meta) {
        // No longer valid
        //return (typeof(juxtaMeta) != 'undefined');
        return meta != "";
    }

    this.beforeCallback = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta) { }
    this.afterCallback = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta) { }

    // Called on mouse-move outside of a valid image
    this.juxtaCallbackNotValid = function() { }

    // Called when the mouse is moved over a valid image
    this.juxtaCallback = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta) {
        beforeCallback(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta);
        var sf = showFooter(x, y, image, meta);
        if (showInfoBox(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta)) {
            infobox.style.visibility='visible';

            infobox.style.left = boxX + 'px';
            infobox.style.top = boxY + 'px';
            infobox.style.width = boxWidth + 'px';
            infobox.style.height = boxHeight + 'px';

            header.style.width = (boxWidth-16) + 'px';
            header.style.height = '1em';
            header.innerHTML= createHeader(x, y, image, meta);
            header.style.left = boxX + 'px';
            header.style.top = (boxY-header.clientHeight) + 'px';

            footer.style.left = boxX + 'px';
            footer.style.top = (boxY+boxHeight) + 'px';
            footer.style.width = (boxWidth-32) + 'px';
            footer.innerHTML = createFooter(x, y, image, meta);
            if (sf) {
                infobox.style.borderBottom = 'none';
                infobox.borderBottomLeftRadius = '0';
                infobox.borderBottomRightRadius = '0';
            } else {
                footer.style.visibility = 'hidden';
                infobox.style.borderBottom = '3px solid red';
                infobox.borderBottomLeftRadius = '10px';
                infobox.borderBottomRightRadius = '10px';
            }
            if ( !showFullInfo(boxWidth, boxHeight) ) {
                //      header.style.pointerEvents = 'none';
                header.style.visibility = 'hidden';
                footer.style.visibility = 'hidden';
                infobox.style.borderTop = '3px solid red';
                infobox.style.borderBottom = '3px solid red';
            } else {
                //      header.style.pointerEvents = 'auto';
                header.style.visibility = 'visible';
                if (sf) {
                    footer.style.visibility = 'visible';
                }      
                infobox.style.borderTop = 'none';
                if (sf) {  
                    infobox.style.borderBottom = 'none';
                }  
            }
        } else {
            infobox.style.visibility='hidden';
            header.style.visibility='hidden';
            footer.style.visibility='hidden';
        }
        afterCallback(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta);
    };

    this.fitView = function(images) {
        console.log("Fitting view to hold at least " + images + " images");
        var candidates = [];
        switch (images) {
        case 1:
            candidates.push([1, 1]);
            break;
        case 2:
            candidates.push([1, 2]);
            candidates.push([2, 1]);
            break;
        case 3:
            candidates.push([1, 3]);
            candidates.push([3, 1]);
            candidates.push([2, 2]);
            break;
        case 4:
            candidates.push([1, 4]);
            candidates.push([4, 1]);
            candidates.push([2, 2]);
            break;
        case 5:
            candidates.push([1, 5]);
            candidates.push([5, 1]);
            candidates.push([2, 3]);
            candidates.push([3, 2]);
            break;
        case 6:
            candidates.push([1, 6]);
            candidates.push([6, 1]);
            candidates.push([2, 3]);
            candidates.push([3, 2]);
            break;
        case 7:
            candidates.push([1, 7]);
            candidates.push([7, 1]);
            candidates.push([3, 3]);
            candidates.push([4, 2]);
            candidates.push([2, 4]);
            break;
        case 8:
            candidates.push([1, 8]);
            candidates.push([8, 1]);
            candidates.push([3, 3]);
            candidates.push([4, 2]);
            candidates.push([2, 4]);
            break;
        case 9:
            candidates.push([1, 9]);
            candidates.push([9, 1]);
            candidates.push([3, 3]);
            candidates.push([5, 2]);
            candidates.push([2, 5]);
            break;
        default:
            console.err("Error: Unsupported image count of " + images + " in fitView");
            return;
        }
        var smallestVE = [Infinity, Infinity];
        var smallestFraction = Infinity;
        // ###
        var visibleV = myDragon.viewport.getBounds();
        var visibleVE = myDragon.viewport.viewportToViewerElementRectangle(visibleV);
        for (var i = 0 ; i < candidates.length ; i++) {
            var candidateBoxes = candidates[i];
            var candidateVE = [candidateBoxes[0]*result.boxWidth, candidateBoxes[1]*result.boxHeight];
            var candidateFraction = Math.max(candidateVE[0]/visibleVE.width, candidateVE[1]/visibleVE.height);
            if (candidateFraction < smallestFraction) {
                smallestVE = candidateVE;
            }
        }
        // Best box-layout found, adjusting view
        var fittedVE = new OpenSeadragon.Rect(result.boxX, result.boxY, smallestVE[0], smallestVE[1]);
        var fittedV = myDragon.viewport.viewerElementToViewportRectangle(fittedVE);
        var hMarginV = visibleV.width*boxPanMarginFraction;
        var vMarginV = visibleV.width*boxPanMarginFraction;
        fittedV.x -= hMarginV;
        fittedV.y -= vMarginV;
        fittedV.width += 2*hMarginV;
        fittedV.height += 2*vMarginV;
        console.log("Fitting from " + JSON.stringify(result));
        console.log("Fitting ve   " + JSON.stringify(fittedVE));
        console.log("Fitting v    " + JSON.stringify(fittedV));
        myDragon.viewport.fitBounds(fittedV);
     }
    
    // Called when a key is pressed
    // TODO: Bind 1-9 to zoom (1 box, 2 boxes, 3 boxes (1x3, 3x1 or 2x2), 4, 5 (1x5, 5x1, 2x3, 3x2), 6 (2x3, 3x2)...
    this.juxtaKeyCallback = function (e) {
        console.log("Keycall pre-result " + JSON.stringify(result));
        switch (e.keyCode) {
        case 38: // up
            if (e.ctrlKey) {
                result.y = 0;
            } else {
                if (result.y > 0) {
                    result.y--;
                }
            }
            updateResultFromKeyPress();
            break;
        case 40: // down
            if (e.ctrlKey) {
                result.y = jprops.rowCount-1;
            } else {
                if (result.y < jprops.rowCount-1) {
                    result.y++;
                }
            }
            updateResultFromKeyPress();
            break;
        case 37: // left
            if (e.ctrlKey) {
                result.x = 0;
            } else {
                if (result.x > 0 || result.y > 0) {
                    result.x--;
                }
                if (result.x == -1) {
                    result.x = jprops.colCount-1;
                    result.y--;
                }
            }
            updateResultFromKeyPress();
            break;
        case 39: // right
            if (e.ctrlKey) {
                result.x = jprops.colCount-1;
            } else {
                if (result.x < jprops.colCount-1 || result.y < jprops.rowCount-1) {
                    result.x++;
                }
                if (result.x == jprops.colCount) {
                    result.x = 0;
                    result.y++;
                }
            }
            updateResultFromKeyPress();
            break;
        }
        if (e.keyCode >= 49 && e.keyCode <= 57) { // ###
            console.log("Before fit: " + JSON.stringify(result));
            fitView(e.keyCode-48); 
            console.log("Before upd: " + JSON.stringify(result));
            //updateResultFromKeyPress();
            console.log("After upd:  " + JSON.stringify(result));
        }
        
        // TODO: preventDefault
        // TODO: Handle unfilled bottom row
        
        // up=38, down=40, left=37, right=39
        //console.log("boxX=" + result.x + "/" + jprops.colCount);
        //console.log(e.keyCode);
        //e.preventDefault = true;
    }
    
    this.result = {
        fired: true,
        x: 0, y: 0,
        boxX: 0, boxY: 0,
        boxWidth: 0, boxHeight: 0,
        validPos: true,
        image: '',
        meta: ''
    };
    this.fireResult = function(){
        if (result.fired) {
            return;
        }
        result.fired = true;
        juxtaCallback(result.x, result.y, result.boxX, result.boxY, result.boxWidth, result.boxHeight,
                      result.validPos, result.image, result.meta);
    }

    this.ensureSelectionIsVisible = function() {
        var boxVE = new OpenSeadragon.Rect(result.boxX, result.boxY, result.boxWidth, result.boxHeight);
        var boxV = myDragon.viewport.viewerElementToViewportRectangle(boxVE);
        var deltaV = new OpenSeadragon.Point(0, 0);
        var visibleV = myDragon.viewport.getBounds();
        var changed = false;

        var hMarginV = visibleV.width*boxPanMarginFraction;
        if (boxV.x < visibleV.x) {
            deltaV.x = boxV.x-visibleV.x-hMarginV;
            changed = true;
        } else if (boxV.x+boxV.width > visibleV.x+visibleV.width) {
            deltaV.x = (boxV.x+boxV.width)-(visibleV.x+visibleV.width)+hMarginV;
            changed = true;
        }
        
        var vMarginV = visibleV.height*boxPanMarginFraction;
        if (boxV.y < visibleV.y) {
            deltaV.y = boxV.y-visibleV.y-vMarginV;
            changed = true;
        } else if (boxV.y+boxV.height > visibleV.y+visibleV.height) {
            deltaV.y = (boxV.y+boxV.height)-(visibleV.y+visibleV.height)+vMarginV;
            changed = true;
        }
        
        if (changed) {
            myDragon.viewport.panBy(deltaV, false);
        }
        return changed;
    }
    
    // x & y are valid, fake the rest
    updateResultFromKeyPress = function() {
        console.log("updateResultFromKeyPress (" + result.x + ", " + result.y + ")");
        handleChange(result.x, result.y);
        if (ensureSelectionIsVisible()) {
            console.log("Enforcing visibility changed view. Updating box position with (" + result.x + ", " + result.y + ")");
            handleChange(result.x, result.y);
        }
    }
    
    // Returns false if a new request must be started
    this.tryFire = function() {
        if (result.fired) {
            return true
        }
        var metaSource = Math.floor(result.x/jprops.asyncMetaSide) + '_' + Math.floor(result.y/jprops.asyncMetaSide) + '.json';
        var arrayLength = metaCache.length;

        // Determine the width of the async box (might be on the right edge)
        var aSide = jprops.asyncMetaSide;
        var fullHASyncs = Math.floor(jprops.colCount/jprops.asyncMetaSide);
        if ( jprops.colCount%jprops.asyncMetaSide != 0 && result.x >= fullHASyncs*jprops.asyncMetaSide ) { // On the edge
            aSide = jprops.colCount-fullHASyncs*jprops.asyncMetaSide;
        }
        var origoX=result.x%jprops.asyncMetaSide;
        var origoY=result.y%jprops.asyncMetaSide;
        for (var i = 0; i < arrayLength; i++) {
            if (metaCache[i].source == metaSource) {
                if (metaCache[i].status == 'ready') {
                    var index = origoY*aSide +origoX;
                    var full = metaCache[i].meta[index];
                    if (jprops.metaIncludesOrigin) {
                        // TODO: Move pre- and post-fix to the json metadata files
                        result.image = metaCache[i].prefix + full.split('|')[0] + metaCache[i].postfix;
                        // TODO: Create a better splitter that handles multiple |
                        result.meta = full.split('|')[1];
                    } else {
                        result.meta = full;
                    }
                    if (typeof(result.meta) == 'undefined') { // Happens for single images without metadata
                        result.meta = '';
                    }
                    //                console.log("Firing x=" + result.x + ", y=" + result.y + ", aside=" + aSide + ", index=" + index + ", meta=" + result.meta);
                    fireResult();
                    return true;
                }
                //            console.log("Returning due to pending " + metaSource);
                // In transit, so the async call should return at some point. Note that result is set!
                // TODO: Ensure that timed out requests are handled properly
                return true;
            }
        }
    }


    // If meta-data for the requested image is available, it is updated immediately.
    // If there is a pending request for the block containing the meta, the notifyMeta
    // is updated.
    // If there is no pending request for the block, notifyMeta is updated and a new
    // async request is initiated.
    this.prepareMeta = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos) {
        if (!validPos) {
            // TODO: Set meta to "" and fire event
            juxtaCallbackNotValid();
            return
        };
        //console.log("prepareMeta(" + x + ", " + y + ", ...) called");

        result.fired = false;
        result.x = x;
        result.y = y;
        result.boxX = boxX;
        result.boxY = boxY;
        result.boxWidth = boxWidth;
        result.boxHeight = boxHeight;
        result.validPos = validPos;
        result.image = '';
        result.meta = '';
        result.prefix = '';
        result.postfix = '';
        
        if (tryFire()) {
            return;
        }

        // Create an async call to get the meta data
        var metaSource = Math.floor(x/jprops.asyncMetaSide) + '_' + Math.floor(y/jprops.asyncMetaSide) + '.json';
        //    console.log("x=" + x + ", jprops.asyncMetaSide=" + jprops.asyncMetaSide);
        var cacheEntry = {
            status: 'pending',
            source: metaSource
        };
        metaCache.push(cacheEntry);
        if (metaCache.length > metaCacheMax) {
            //        console.log("Cache full, pruning");
            metaCache.shift();
        }
        
        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function() {
            if (xhttp.readyState != 4) {
                return;
            }
            if (xhttp.status == 200) {
                //        console.log("Got: " + xhttp.responseText);
                var rJSON = JSON.parse(xhttp.responseText);
                xhttp.cacheEntry.meta = rJSON.meta;
                xhttp.cacheEntry.prefix = rJSON.prefix;
                xhttp.cacheEntry.postfix = rJSON.postfix;
                xhttp.cacheEntry.status = 'ready';
                //            console.log("meta: " + xhttp.cacheEntry.meta);
                tryFire();
                //            console.log("Check that result is still covered by this response and if so, fire it");
            } else {
                console.log("Unable to get response for " + cacheEntry.source + " with status " + xhttp.status);
                // TODO: Figure out how to signal the error to the GUI - maybe "N/A" as image & meta?
                var arrayLength = metaCache.length;
                for (var i = 0; i < arrayLength; i++) {
                    if (metaCache[i].source == metaSource) {
                        metaCache.splice(i, 1);
                        break;
                    }
                }
            }
        }
        xhttp.cacheEntry = cacheEntry;
        //    console.log("Requesting meta/" + metaSource);
        // TODO: Add optional meta-folder-prefix here
        xhttp.open("GET", "meta/" + metaSource, true);
        xhttp.send();
    }

    this.juxtaExpand = function(x, y, boxX, boxY, boxWidth, boxHeight) {
        var meta="";
        var image = "";
        var validPos = false;
        imageIndex = y*jprops.colCount+x;
        if (x >= 0 && x < jprops.colCount && y >= 0 && y < jprops.rowCount && imageIndex < jprops.imageCount) {
            validPos = true;
            //    if (typeof(juxtaImages) != 'undefined') {
            //      image = juxtaPrefix + juxtaImages[imageIndex] + juxtaPostfix;
            //    }
            
            //    if (typeof(juxtaMeta) != 'undefined') {
            //      meta = juxtaMeta[imageIndex];
            //    }
        }
        //  juxtaCallback(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta);
        prepareMeta(x, y, boxX, boxY, boxWidth, boxHeight, validPos);
    }

    return this;
}
