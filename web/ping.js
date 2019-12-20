/*
  Simple ping service for tracking if the display is being used interactively

  Use by including this script and calling
  <script>activatePing(Ping-image-URL);</script>
  where Ping-image-URL is a (preferably 1x1 pixel gif) image where access is logged.
*/
var pingActivated = false;
var pingDelay = 30000;
var dummyImage = document.createElement("img");
dummyImage.width = 1;
dummyImage.height = 1;

var activatePing = function(urlPrefix, delay = pingDelay) {
    pingDelay = delay;
    document.addEventListener("click", function() {
        if (pingActivated) {
            console.log("Already queued");
            return;
        }
        pingActivated = true;
        now = new Date();
        strNow = now.getUTCFullYear().toString() + "-" +
            (now.getUTCMonth() + 1).toString() +
            "-" + now.getUTCDate() + "T" + now.getUTCHours() +
            ":" + now.getUTCMinutes() + ":" + now.getUTCSeconds();
        url = urlPrefix + "?" + strNow;
        setTimeout(function() {
            pingActivated = false;
            dummyImage.src=url;
        }, delay);
    })
}
    
