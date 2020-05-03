// Handles bookmarking based on pan, zoom and selected tile

function restoreFromURL() {
    // We store the match immediately so that the MouseTracker does not mess up the initial URL
    var myRegexp = /.*#x:([0-9.-]+),y:([0-9.-]+),w:([0-9.-]+),h:([0-9.-]+),tileX:([0-9.-]+),tileY:([0-9.-]+),tile:(.+)/
    var match = myRegexp.exec(window.location.href);
        
    var gotoURL = function() {
        if (match) {
            // Get the select-box in place
            overlays.result.x = parseInt(match[5]);
            overlays.result.y = parseInt(match[6]);
            updateResultFromKeyPress();

            // Restore pan & zoom
            var rect = new OpenSeadragon.Rect(parseFloat(match[1]), parseFloat(match[2]), parseFloat(match[3]), parseFloat(match[4]));
            myDragon.viewport.fitBounds(rect);

          }
        }
        
    myDragon.viewport.viewer.addHandler("open", gotoURL);
    window.onhashchange = gotoURL;
    window.onload = gotoURL;
}
restoreFromURL()

function precise(x) {
    return Number.parseFloat(x).toPrecision(4);
}

overlays.afterCallback = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta) {
   var viewportBounds = myDragon.viewport.getBounds();
    var state = 'x:' + precise(viewportBounds.x) + ',y:' + precise(viewportBounds.y) +
        ',w:' + precise(viewportBounds.width) + ',h:' + precise(viewportBounds.height) +
        ',tileX:' + x + ',tileY:' + y + ',tile:' + image.substring(image.lastIndexOf('/')+1).replace(/\.[^/.]+$/, "");
    if (window.history.replaceState) {
        newLoc = window.location.href.replace(/#.*/, "") + '#' + state;
        window.history.replaceState({ }, document.title, newLoc);
    }
}



        
