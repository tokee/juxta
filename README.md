# juxta
Generates a collage of a given set of images, for display on a webpage using the deep zoom tool OpenSeadragon.
Each source image can have associated meta-data, which is displayed on mouse-over.

Demo at http://labs.statsbiblioteket.dk/juxta/subject3795/

## Technical notes
juxta generates tiles for use with OpenSeadragon. One tile = one 256x256 pixel image file. The tile generation is threaded and localized to the individual source images. This means that memory overhead is independent of the total collage size. The difference between generating a collage of 10 vs. 10 million images is only CPU time. Associated meta-data are stored in chunks and only requested on mouse-over, keeping browser page-open time and memory requirements independent of collage size.

As each tile on zoom level `n` is created from 4 tiles on zoom level `n+1`, this means `JPEG → scale(¼) → JPEG`, if `jpg` is used as tile format. The artefacts from the JPEG compression compounds, although the effect is mitigated by down scaling.

The `4 tiles → join → scale(¼) → 1 tile` processing means that tile-edge-artefacts compounds, potentially resulting in visible horizontal and vertical lines at some zoom levels. This is most visible when using images that fits the tiles well, as it brings the edges of the images closer together.

The script is restart-friendly as it skips already generated tiles.

Processing 24,000 ~1MPixel images on a laptop using 2 threads took 2½ hour and resulted in ~390,000 tiles for a total of 6.4GB with a 19GPixel canvas size (138240x138240 pixel). As scaling is practically linear `O(n+log2(sqrt(n)))`, a collage from 1 million such images would take ~4 days.

The theoretical limits for collage size / source image count are dictated by bash & JavaScripts max integers. The bash-limit depends on system, but should be 2⁶³ on most modern systems. For JavaScript it is 2⁵³. Think yotta-pixels.

The practical limit is determined primarily by the number of inodes on the file system. Check with `df -i` under *nix. With the default raw image size if `RAW_W=4 RAW_H=3` (1024x768 pixels), each source image will result in ~17 files, so a system with 100M free inodes can hold a collage with 5M images. Rule of thumb: Do check if there are enough free inodes when creating collages of millions of images. There is a gradual performance degradation when moving beyond hundreds of millions of images (see issue #5); but that is solvable, should the case arise.

Depending on browser, mouse-over meta-data will not be shown when opening the collage from the local file system. This is a security decision (CORS). It should work when accessing the collage through a webserver.


## Requirements
 * bash and friends (unzip, sed, tr...)
 * ImageMagic
 * wget optional (OpenSeadragon must be downloaded manually if it is not there)

Developed and tested under Ubuntu 16.04. As of 2017-02-03 it worked under OS X, with some glitches in meta-data.

## Usage
1. Create a list of images
   `find myimages -iname "*.jpg" > images.dat`

2. Generate collage tiles
  `./juxta.sh images.dat mycollage`

3. View the collage in a browser
 `firefox mycollage.html`

## Advanced
Processing can be controlled by setting environment variables. Most important options are

 * RAW_W / RAW_H: The size of the fully zoomed individual images, measured in tiles. RAW_W=4 and RAW_H=3 means `(4*256)x(3*256)` = 1024x768 pixels. Default is 4 and 3.
 * BACKGROUND: 6-digit hex for the color to use as background. Default is cccccc.
 * THREADS: The number of threads to use when generating the tiles at full zoom level. Default is 1.
 * TILE_FORMAT: png or jpg. Default is jpg.

Processing a bunch of photos of file size 500KB or more could be done with
```
find myimages -iname "*.jpg" -a -size +500k  > photos.dat
BACKGROUND=000000 RAW_W=3 RAW_H=2 THREADS=4 TILE_FORMAT=jpg ./juxta.sh photos.dat mycollage
```

A collection of small clip art images could be
```
find myimages -iname "*.png" -o -iname "*.gif" > clipart.dat
BACKGROUND=ffffff RAW_W=1 RAW_H=1 THREADS=2 TILE_FORMAT=png ./juxta.sh clipart.dat mycollage
```

## Demos
The script ./demo_kb.sh fetches openly available images from kb.dk and generates a collage
with linkback to the image pages at kb.dk. Sample run of the script:
```
MAX_IMAGES=200 ./demo_kb.sh create subject2210
```

Scale testing can be done with ./demo_scale.sh. Sample runs:
```
./demo_scale.sh 100
RAW_W=1 RAW_H=1 ./demo_scale.sh 1000
```

## Custom collage with links
1. Download the images to a local folder
2. Create a file `myimages.dat` with the images listed in the wanted order.

   Each line in the file holds one image and optional meta-data divided by `|`. In this example, the meta-data are links to the original image. Example line: `myimages/someimage_25232.png|http://example.com/someimage_23232.png`  
3. Create a template `mytemplate.html` with a JavaScript snippet for generating a link.

   The template `demo_kb.template.html` can be used as a starting point. Override either of `createHeader` and `createFooter`. In this example, it could be  
   
   ```
createHeader = function(x, y, image, meta) {
  imageId = image.substring(image.lastIndexOf('/')+1).replace(/\.[^/.]+$/, "");
  return '<a href="' + meta + '">' + imageID + '</a>';
}
showFooter(x, y, image, meta) {
  return false;
}
```
4. Determine the aspect ratio and implicitly the size of the images making up the collage using `RAW_W` and `RAW_H`
5. Start juxta: `RAW_W=2 RAW_H=2 TEMPLATE=mytemplate.html ./juxta.sh myimages.dat mycollage`

   It is of course advisable to start with a few hundred images to see that everything works as intended.  

## Performance
The script `demo_scale.sh` creates a few sample images and a collage of arbitrary size by repeating those images.

### Old-ish Xeon server machine `RAW_W=1 RAW_H=1` (smallest possible images)

|images|seconds|img/s|MPixels|files|  MB|
|  ---:|   ---:| ---:|   ---:| ---:|---:|
|    50|      3|   16|      3|  140|   2|
|   500|     20|   25|     33|  753|   7|
|  5000|    195|   25|    330|   7K|  63|
| 50000|   2002|   25|   3288|  67K| 618|
|500000|  19652|   25|  32804| 669K|6158|

This was measured after issue #5 (limit the number of files/folder) was completed. As can be seen, performance is linear with the number of images.

Before the completion of issue #5, the folder for the lowest zoom-level contained 500K files in this test, which caused a severe performance degradation. The i5 desktop used for this test had the results below, which can be simulated by specifying `FOLDER_LAYOUT=dzi`.

|images|seconds|img/s|MPixels|files|  MB|
|  ---:|   ---:| ---:|   ---:| ---:|---:|
|    50|      1|   50|      3|  146|   5|
|   500|     12|   41|     33|  759|  10|
|  5000|    115|   43|    330|   7K|  66|
| 50000|   1384|   36|   3288|  67K| 621|
|500000|  43064|   11|  32804| 668K|6166|

As can be seen, performance drops markedly when the number of images rises and the folder-layout is forced to `dzi`.
