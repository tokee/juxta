# juxta
Generates a collage of a given set of images, for display on a webpage using the deep zoom tool OpenSeadragon.
Each source image can have associated meta-data, which is displayed on mouse-over. Some samples:

 * http://labs.statsbiblioteket.dk/juxta/subject3795/ (1,000 * 1 MPixel historical postcards - 1 GigaPixel)
 * http://labs.statsbiblioteket.dk/juxta/subject208/ (5,000 * 28 MPixel historical maps - 136 GigaPixel)
 * https://ruebot.net/visualizations/wm/ (6,104,790 * 0.5 MPixel twitter images - 3 TeraPixel)
 * https://ruebot.net/45-images/ (17,525,913 * 0.25 MPixel twitter images - 4 TeraPixel)

## Requirements
 * bash and friends (unzip, sed, tr...)
 * ImageMagic
 * wget optional (OpenSeadragon must be downloaded manually if it is not there)

Developed and tested under Ubuntu 16.04. As of 2017-02-03 it worked under OS X, with some glitches in meta-data.

OpenSeadragon and the mouse-over code has been tested with IE10, Firefox, Chrome & Safari on desktop machines, as well as Safari on iPhone &iPad and whatever build-in browser CyanogenMOD has.


## Basic usage
1. Create a list of images
   `find myimages -iname "*.jpg" > images.dat`

2. Generate collage tiles
  `./juxta.sh images.dat mycollage`

3. View the collage in a browser
 `firefox mycollage/index.html`

But! This will produce something with poor choice in colors, clumsy layout and no links to the full images. You probably want to tweak all that: `juxta.sh` is the core script, intended to be called with options geared towards different use cases. If you want to use it as gallery creator, check the "Recursive image gallery" section below.


## Keyboard shortcuts
It is possible to navigate using the keyboard instead of mouse or touch:

- `Arrow key` pans
- `CTRL+arrow key` pans a full screen (in a hackish way - this should be improved)
- `Number key (1-9)` ensures that that number of images is visible and optimally zoomed
- `CTRL+number key` ensures that 2^number of images (1-512) is visible and optimally zoomed
- `m` marks an image visually (same as right click with mouse)
- `c` clears all marks
- `e` exports a list of marked images to the browser console

## Advanced
Processing can be controlled by setting environment variables. Most important options are

 * RAW_W / RAW_H: The size of the fully zoomed individual images, measured in tiles. RAW_W=4 and RAW_H=3 means `(4*256)x(3*256)` = 1024x768 pixels. Default is 4 and 3.
 * BACKGROUND: 6-digit hex for the color to use as background. Default is cccccc.
 * THREADS: The number of threads to use when generating the tiles at full zoom level. Default is 3.
 * TILE_FORMAT: png or jpg. Default is jpg.

Processing a bunch of photos of file size 500KB or more could be done with
```shell
find myimages -iname "*.jpg" -a -size +500k  > photos.dat
BACKGROUND=000000 RAW_W=3 RAW_H=2 THREADS=4 TILE_FORMAT=jpg ./juxta.sh photos.dat mycollage
```

A collection of small clip art images could be
```shell
find myimages -iname "*.png" -o -iname "*.gif" > clipart.dat
BACKGROUND=ffffff RAW_W=1 RAW_H=1 THREADS=2 TILE_FORMAT=png ./juxta.sh clipart.dat mycollage
```

There are a lot of secondary options, which are all documented in the `juxta.sh`-script.


## Image similarity sort
juxta supports image similarity sort using Python3 with keras and imagenet. This is a rather heavy
process and not entirely hardened yet, so no promises.

See [9951 map images](http://labs.statsbiblioteket.dk/juxta/subject208/) for an example of image 
similarity sort.

Image similarity sorting works best for 300+ images: Less than this and it gets hard to see
why the images are similar. Using it with 10.000+ images works very well, but is fairly heavy
on CPU & menory during processing.

The argument `IMAGE_SORT=similarity` activates image similarity sorting, which uses the
Python3 script `imagenet_tsne_rasterfairy.py` under the hood.

The script has a bunch of requirements, which can either be installed beforehand with 
`pip3 install --prefer-binary -r Requirements.txt` or automatically handled using virtualenv.
If the former option is used, `USE_VIRTUALEV=false` should be added as option, if the latter 
option is used nothing special has to be done, but first run will be heavy as a lot has to be
fetched.

Specifying `GENERATE_TSNE_PREVIEW_IMAGE=true` makes juxta generate an extra image with
all the input images plotted with overlap, using the raw coordinates from the similarity sorting.
This preview is usable for checking the distance between the image clusters - something which is
not possible with the fixed grid layout of a juxta collage.

Sample call:
```shell
find myimagefolder -iname "*.jpg" > someimages.dat
IMAGE_SORT=similarity GENERATE_TSNE_PREVIEW_IMAGE=true ./juxta.sh someimages similarity
```

## Image search support
The base template includes support for simple search and marking of matching images, based on
image name and metadata. This does not work well for large (100.000+) collages as the search
data is held in browser memory and the search is primitive (iterative scan). It will likely
crash the browser with millions of images.

In order to ensure that all relevant search data is cached, it is necessary to add the parameter
`FORCE_SEARCH` when calling juxta.

Sample call:
```shell
find myimagefolder -iname "*.jpg" > someimages.dat
FORCE_SEARCH=true ./juxta.sh someimages searchable
```

In order to enable search for previously generated collages, the script `adjust_meta.js` has
been provided. Simply execute it with the path of the collage and it will perform most of the
necessary adjustments and documentation on how to add the input field.

Sample call:
```shell
./adjust_meta.js myoldcollage
```

## Demos

### Recursive image gallery
The script `demo_gallery.sh` performs a recursive descend from a starting folder, creating
a collage in each folder that contains images, as well as links to sub-folders with images.
The files are stored in sub-folders named `.juxta` and an `index.html` file is created in
each folder. Sample run of the script:
```shell
./demo_gallery.sh my_picture_folder
```

### Covers
The script `demo_coverbrowser.sh` fetches images from coverbrowser.com and generates a collage
with linkback to the image pages at coverbrowser. *Important note:* The covers are not released
in the public domain or under a CC-license. If a collage of the covers is to be exposed to the
public, be sure to check that it is legal under local copyright laws. Sample run of the script:
```shell
./demo_coverbrowser.sh tintin
```
The cover-collections can be browsed at http://coverbrowser.com/

### Image collection at rijksmuseum.nl
The script `demo_rijksmuseum.sh` fetches openly available images from rijksmuseum.nl and generates a collage
with linkback to the image pages at the museum. In order to run the script, a *free key* must be requested
from the museum. Details at http://rijksmuseum.github.io/ - with that key a sample run is
```shell
MAX_IMAGES=200 KEY=mykey ./demo_rijksmuseum.sh "https://www.rijksmuseum.nl/en/search?f.principalMakers.name.sort=Rembrandt+Harmensz.+van+Rijn&st=OBJECTS" "rembrandt"
```
where the URL is copy-pasted from a search at the Rijksmuseum.


### Historical image collection at kb.dk
The script `demo_kb.sh` fetches openly available images from kb.dk and generates a collage
with linkback to the image pages at kb.dk. Sample run of the script:
```shell
MAX_IMAGES=200 ./demo_kb.sh create subject2210
```

The script `demo_kb_kort.sh` provides overrides to use the Kort & Atlas (Maps & Atlases) from kb.dk. Most of those images are quite high-resolution (~50MPixel), so `RAW_W` and `RAW_H` are set to take advantage of that. Consequently, it might be a good idea to check with a few images before going for thousands.
```shell
MAX_IMAGES=20 ./demo_kb_kort.sh create subject208
```

### Paired images at kb.dk
Some of the images at [kb.dk](https://www.kb.dk/) comes in pairs, notably postcards where both the front and the back are scanned.
The script `demo_kb_dual.sh` fetches such image pairs and creates to collages that are displayed using a loupe effect. Sample run of the script:
```shell
MAX_IMAGES=200 ./demo_kb_dual.sh create subject3795
```

### Flora Danica
[Statens Naturhistoriske Museum](http://www.daim.snm.ku.dk/flora-danica-dk) has a nicely scanned [Flora Danica](https://en.wikipedia.org/wiki/Flora_Danica) with 3,240 images of plants local to Denmark.
The script `demo_flora.sh` fetches these images, sorts them by the latin name of the plants and creates a collage. Sample run of the script:
```shell
MAX_IMAGES=20 ./demo_flora.sh
```

### Scaling

Scale testing can be done with ./demo_scale.sh. See more in the "Performance & Scaling section in this document.  Sample runs:
```shell
./demo_scale.sh 100
RAW_W=1 RAW_H=1 ./demo_scale.sh 1000
```

### Twitter images
The script `demo_twitter.sh` takes a list of tweet-IDs, locates all images from the tweets and
creates a collage with links back to the original tweets. The script downloads all the images
before using juxta to create the collage and is restart-friendly.

**Important:** This requires [twarc](https://github.com/docnow/twarc), a (free) API-key from
Twitter and an understanding of Twitters [Developer Agreement & Policy](https://dev.twitter.com/overview/terms/agreement-and-policy).

Given a list of tweet-IDs (just the numbers), call the script with
```shell
MAX_IMAGES=10 ./demo_twitter.sh mytweets.dat tweet_collage
```

If the tweets and their images are already available, the template from `demo_twitter.sh` can re-used by creating a list of the images of the form `imagepath|tweet-ID timestamp`, for example
```shell
images/0/pbs.twimg.com_media_CupTGBlWcAA-yzz.jpg|786532479343599620 2016-10-13T13:42:10
images/0/pbs.twimg.com_media_CYwJ7LDWwAIA011.jpg|687935756539686912 2016-01-15T10:54:00
```
and juxta can be called with
```shell
TEMPLATE=demo_twitter.template.html RAW_W=1 RAW_H=1 INCLUDE_ORIGIN=false ./juxta.sh tweet_images.dat tweet_collage
```


## Custom collage with links
1. Download the images to a local folder
2. Create a file `myimages.dat` with the images listed in the wanted order.

   Each line in the file holds one image and optional meta-data divided by `|`. In this example, the meta-data are links to the original image. Example line: `myimages/someimage_25232.png|http://example.com/someimage_23232.png`  
3. Create a template `mytemplate.html` with a JavaScript snippet for generating a link.

   The template `demo_kb.template.html` can be used as a starting point. Override either of `createHeader` and `createFooter`. In this example, it could be  
   
```javascript
overlays.createHeader = function(x, y, image, meta) {
  imageId = image.substring(image.lastIndexOf('/')+1).replace(/\.[^/.]+$/, "");
  return '<a href="' + meta + '">' + imageId + '</a>';
}
overlays.createFooter = function(x, y, image, meta) {
  return false;
}
```
4. Determine the aspect ratio and implicitly the size of the images making up the collage using `RAW_W` and `RAW_H`
5. Start juxta: `RAW_W=2 RAW_H=2 TEMPLATE=mytemplate.html ./juxta.sh myimages.dat mycollage`

   It is of course advisable to start with a few hundred images to see that everything works as intended.  

## Technical notes
juxta generates tiles for use with OpenSeadragon. One tile = one 256x256 pixel image file. The tile generation is threaded and localized to the individual source images. This means that memory overhead is independent of the total collage size. The difference between generating a collage of 10 vs. 10 million images is only CPU time. Associated meta-data are stored in chunks and only requested on mouse-over, keeping browser page-open time and memory requirements independent of collage size.

As each tile on zoom level `n` is created from 4 tiles on zoom level `n+1`, this means `JPEG → scale(¼) → JPEG`, if `jpg` is used as tile format. The artefacts from the JPEG compression compounds, although the effect is mitigated by down scaling.

The repeated `4 tiles → join → scale(¼) → 1 tile` processing means that tile-edge-artefacts compounds, potentially resulting in visible horizontal and vertical lines at some zoom levels. This is most visible when using images that fits the tiles well, as it brings the edges of the images closer together.

The script is restart-friendly as it skips already generated tiles.

Processing 24,000 ~1MPixel images on a laptop using 2 threads took 2½ hour and resulted in ~390,000 tiles for a total of 6.4GB with a 19GPixel canvas size (138240x138240 pixel). As scaling is practically linear `O(n+log2(sqrt(n)))`, a collage from 1 million such images would take ~4 days.

The theoretical limits for collage size / source image count are dictated by bash & JavaScripts max integers. The bash-limit depends on system, but should be 2⁶³ on most modern systems. For JavaScript it is 2⁵³. Think yotta-pixels.

The practical limit is determined primarily by the number of inodes on the file system. Check with `df -i` under *nix. With the default raw image size of `RAW_W=4 RAW_H=3` (1024x768 pixels), each source image will result in ~17 files, so a system with 100M free inodes can hold a collage with 5M images. Rule of thumb: Do check if there are enough free inodes when creating collages of millions of images. There is a gradual performance degradation when moving beyond hundreds of millions of images (see [issue #5](https://github.com/tokee/juxta/issues/5)); but that is solvable, should the case arise.

Depending on browser, mouse-over meta-data will only work for the upper left images of the collage, when opening the collage from the local file system. This is by design (see CORS). It should work for all browsers when accessing the collage through a webserver.

## Performance and scaling
The script `demo_scale.sh` creates a few sample images and a collage of arbitrary size by repeating those images. Except for the source images being disk cached, this should should be quite representative of a real-data collage.

### Old-ish Xeon server machine `RAW_W=1 RAW_H=1 ./demo_scale.sh <images>` (smallest possible image representation)

|images|seconds|img/s|MPixels|files|  MB|
|  ---:|   ---:| ---:|   ---:| ---:|---:|
|    50|      3|   16|      3|  140|   2|
|   500|     20|   25|     33|  753|   7|
|  5000|    195|   25|    330|   7K|  63|
| 50000|   2002|   25|   3288|  67K| 618|
|500000|  19652|   25|  32804| 669K|6158|

This was measured after [issue #5](https://github.com/tokee/juxta/issues/5) (limit the number of files/folder) was completed. As can be seen, performance is linear with the number of images.

### Upper limit
As stated in the technical notes section, the practical limit to juxta scale is dictated by the file system. To sanity-check this, a sample collage with 5 million images was generated with `RAW_W=1 RAW_H=1 ./demo_scale.sh 5000000` (using the default 3 threads). On an i5 desktop this took 31 hours @ 45 images/second. The resulting collage displayed without problems, including meta-data for the individual images.

### Scale vs. compatibility

When the number of tiles for any given folder gets high, performance drops for a lot of file systems (ext4 being one of them). juxta handles this by switching to a custom tile-layout instead of the standard [Deep Zoom](https://en.wikipedia.org/wiki/Deep_Zoom) (dzi) layout. The downside is lack of portability of the tiles, if another viewer than OpenSeadragon is to be used.

The Deep Zoom layout can be forced by specifying `FOLDER_LAYOUT=dzi`. Doing so on an i5 desktop machine resulted in

|images|seconds|img/s|MPixels|files|  MB|
|  ---:|   ---:| ---:|   ---:| ---:|---:|
|    50|      1|   50|      3|  146|   5|
|   500|     12|   41|     33|  759|  10|
|  5000|    115|   43|    330|   7K|  66|
| 50000|   1384|   36|   3288|  67K| 621|
|500000|  43064|   11|  32804| 668K|6166|

As can be seen, performance drops markedly when the number of images rises and the folder-layout is forced to `dzi`.


## Upgrading

juxta is very much "hope you hit a stable version at git clone" at the moment, so chances are that the HTML and supporting files should be upgraded at some point. As large collages can take days to create, a special upgrade-mode has been added:
```shell
/juxta.sh -r mycollage
```
Running with `-r` ensures that the tile files are not touched by juxta. However, for this to work properly, it is essential that all tile-related parameters, such as `RAW_W` and `RAW_H`, are set to the same as the original call to juxta. The only safe parameters to tweak on an upgrade are `TEMPLATE`, `ASYNC_META_SIDE`, `ASYNC_META_CACHE`, `OSD_VERSION`, `OSD_ZIP` & `OSD_URL`.

