/*
  Simple ping service for tracking if the display is being used interactively

  Use by including this script and calling
  <script>activatePing(Ping-image-URL, delay, message);</script>
  where 
  - Ping-image-URL is a (preferably 1x1 pixel gif) image where access is logged.
  - delay is the minimum delay between pings in milliseconds
  - message if an (optional) custom message to be send to the logger, for example
    with the name of the collection
*/
var pingActivated = false;
var pingDelay = 30000;
var pingMessage = "None";
var urlPrefix = null;
var dummyImage = document.createElement("img");
dummyImage.width = 1;
dummyImage.height = 1;

function ping() {
    if (pingActivated) {
        return;
    }
    pingActivated = true;
    now = new Date();
    strNow = now.getUTCFullYear().toString() + "-" +
        (now.getUTCMonth() + 1).toString() +
        "-" + now.getUTCDate() + "T" + now.getUTCHours() +
        ":" + now.getUTCMinutes() + ":" + now.getUTCSeconds();
    url = urlPrefix + "?message=" + pingMessage + "&time=" + strNow;
    setTimeout(function() {
        pingActivated = false;
        dummyImage.src=url;
    }, pingDelay);
}

var activatePing = function(url, delay = pingDelay, message = pingMessage) {
    urlPrefix = url;
    pingDelay = delay;
    pingMessage = message;
    
    document.addEventListener("click", ping);
    document.addEventListener("touchstart", ping);
}
    
