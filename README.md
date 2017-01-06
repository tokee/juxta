# juxta
Generates large collages of images using OpenSeadragon

## Principle
1. A list of images is provided.
2. Each image is scaled and padded to WxH tiles of 256 pixels.
3. The tiles are positioned on a virtual canvas, using path and file names as required by OpenSeadragon.
4. OpenSeadragon-compatible tiles for different zoom-levels are created.
5. A HTML page with the zoomable collage is created.
