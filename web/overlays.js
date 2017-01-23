// Provides overlay for the source image being pointed at
// Override juxtaCallback for custom behaviour or override createHeader & createFooter
// for smaller tweaks to default behaviour

var dragonbox = document.getElementById('zoom-display');
var infobox = document.getElementById('infobox');
var header = document.getElementById('header');
var footer = document.getElementById('footer');
var imagePoint = 0;

function rawToWeb(rawX, rawY) {
    var ip = new OpenSeadragon.Point(rawX * juxtaRawW * juxtaTileSize, rawY * juxtaRawH * juxtaTileSize);
    var wp = myDragon.viewport.imageToViewportCoordinates(ip);
    var rwp = myDragon.viewport.pixelFromPoint(wp);
    return rwp;
}

function handleChange() {
    var rawX = Math.floor(imagePoint.x / juxtaTileSize / juxtaRawW);
    var rawY = Math.floor(imagePoint.y / juxtaTileSize / juxtaRawH);
    roundWebPoint = rawToWeb(rawX, rawY);
    roundWebBRPoint = rawToWeb(rawX+1, rawY+1);
    roundWebBRPoint.x = roundWebBRPoint.x-1;
    roundWebBRPoint.y = roundWebBRPoint.y-1;
    var zoom = myDragon.viewport.getZoom(true);
    juxtaExpand(rawX, rawY,
                Math.floor(roundWebPoint.x), Math.floor(roundWebPoint.y),
                Math.floor(roundWebBRPoint.x-roundWebPoint.x), Math.floor(roundWebBRPoint.y-roundWebPoint.y));
}                      

// https://openseadragon.github.io/examples/viewport-coordinates/
myDragon.addHandler('open', function() {
    var tracker = new OpenSeadragon.MouseTracker({
        element: myDragon.container,
        moveHandler: function(event) {
            var webPoint = event.position;
            var viewportPoint = myDragon.viewport.pointFromPixel(webPoint);
            imagePoint = myDragon.viewport.viewportToImageCoordinates(viewportPoint);
            handleChange();
        }
    });
    myDragon.addHandler('animation', handleChange);
    tracker.setTracking(true);  
});

var createHeader = function(x, y, image, meta) {
    return image == "" ? '(' + x + ', ' + y + ')' : image;
}
var createFooter = function(x, y, image, meta) {
  return meta;
}

var showFullInfo = function(boxWidth, boxHeight) {
    return boxWidth >= 150;
}
var showFooter = function(x, y, image, meta) {
    return (typeof(juxtaMeta) != 'undefined');
}

juxtaCallback = function(x, y, boxX, boxY, boxWidth, boxHeight, validPos, image, meta) {
  var sf = showFooter(x, y, image, meta);
  if (validPos) {
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
};
