/*
Demo mode auto panner & zoomer for OpenSeadragon.

Original Author: Jesper Lauridsen
Further hacking: Toke Eskildsen - te@ekot.dk

Use by including the script on the HTML page:

  <script src="resources/slideScript.js"></script>

and activating it after the OpenSeadragon has been created:

  <script>
  setupDemoMode(myDragon, 5000, 50000, 45);
  </script>

*/

// Defaults
var iTimeout = 180000; // ms
var iAnimateInterval = 20000; // ms
var iAnimateDuration = 10; // Seconds

/* Define these for poor-person's callback */
function transitionFired() {
}

function setupDemoMode(dragon, timeout = iTimeout, animateInterval = iAnimateInterval, animateDuration = iAnimateDuration) {
  iTimeout = timeout;
  iAnimateInterval = animateInterval;
  iAnimateDuration = animateDuration;  
    
  let autoMoves = 0;  
  let transition;
  let myDragon = dragon;
  let initialized = new Date().getTime();
  let doSteps = new Date().getTime() + iTimeout;
  let interval;
  let intervalSet = false;
  console.log("Activating slideScript", myDragon.viewport);

  // Calling this function will move us to the next transition animation in our
  // list of transitions.
  var animate = function() {
    let ratio = myDragon.viewport.viewer.viewport._contentSize.y / myDragon.viewport.viewer.viewport._contentSize.x;
    let width, height;
    let zoomLevel;
    if (autoMoves % 2) {
      //console.log("Zoom out");
      zoomLevel = (Math.random() * 2 + 4) / 100;
    } else {
      //console.log("Zoom in");
      zoomLevel = (Math.random() * 2 + 1) / 100;
    }
    let spot = {
      x: (Math.random() * 80) / 100 + 0.1,
      y: Math.random() * (ratio - zoomLevel),
      w: zoomLevel,
      h: zoomLevel
    };
    let box = new OpenSeadragon.Rect(spot.x, spot.y, spot.w, spot.h);
    transition = function() {
      myDragon.viewport.zoomSpring.animationTime = animateDuration;
      myDragon.viewport.zoomSpring.springStiffness = 5;
      myDragon.viewport.centerSpringX.animationTime = animateDuration;
      myDragon.viewport.centerSpringX.springStiffness = 5;
      myDragon.viewport.centerSpringY.animationTime = animateDuration;
      myDragon.viewport.centerSpringY.springStiffness = 5;
      myDragon.viewport.zoomSpring.exponential = true;
      myDragon.viewport.centerSpringX.exponential = false;
      myDragon.viewport.centerSpringY.exponential = false;
      myDragon.viewport.fitBounds(box);
      transitionFired();  
    };
    transition();
    autoMoves++;  
  };

    var stopDemoMode = function() {
      if (intervalSet) { // Only make a hard stop if in demo mode
        myDragon.viewport.fitBounds(myDragon.viewport.getBounds(true), true);
      }
      myDragon.viewport.zoomSpring.animationTime = 1.2;
      myDragon.viewport.zoomSpring.springStiffness = 6.5;
      myDragon.viewport.centerSpringX.animationTime = 1.2;
      myDragon.viewport.centerSpringX.springStiffness = 6.5;
      myDragon.viewport.centerSpringY.animationTime = 1.2;
      myDragon.viewport.centerSpringY.springStiffness = 6.5;
      myDragon.viewport.zoomSpring.exponential = undefined;
      myDragon.viewport.centerSpringX.exponential = undefined;
      myDragon.viewport.centerSpringY.exponential = undefined;
      initialized = new Date().getTime();
      doSteps = new Date().getTime() + iTimeout;
      clearInterval(interval);
      intervalSet = false;
      setTimeout(checkIdleStatus, 1000);
    }
    
  // setTimeout to check idle status.
  // it continues indefinitely.
  setTimeout(checkIdleStatus, 1000);
  myDragon.addHandler("canvas-click", stopDemoMode);
  myDragon.addHandler("canvas-drag", stopDemoMode);
  myDragon.addHandler("canvas-enter", stopDemoMode);

  function checkIdleStatus() {
    // Checking time
    if (doSteps < initialized && intervalSet === false) {
      intervalSet = true;
      //Time to start
      animate();
      interval = setInterval(() => {
        animate();
      }, iAnimateInterval);
    } else {
      setTimeout(checkIdleStatus, 1000);
    }
    initialized = new Date().getTime();
  }
}
