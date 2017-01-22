# juxta
Generates a large collage of a given set of images, for display on a webpage using the deep zoom tool OpenSeadragon.

Demo at https://tokee.github.io/juxta/

## Technical notes
juxta generates tiles for use with OpenSeadragon. One tile = one 256x256 pixel image file. The tile generation is threaded and localized to the individual source images. This means that memory overhead is independent of the total collage size. The difference between generating a collage of 10 vs. 10 million images is only CPU time.

One downside to storing tiles as individual files is that the folder holding the tiles for the deepest zoom level will contain a lot of tiles: At least one per source image. This is a performance problem for some file systems, as well as some backup systems.

Another downside happens if `jpg` is used as the output format. As each tile on zoom level `n` is created from 4 tiles on zoom level `n+1`, this means `JPEG → scale(¼) → JPEG`. The artefacts from the JPEG compression compounds, but the effect is mitigated by down scaling.

The script is restart-friendly as it skips already generated tiles.

Processing 24,000 ~1MPixel images on a laptop using 2 threads took 2½ hour and resulted in ~390,000 tiles for a total of 6.4GB with a 19GPixel canvas size (138240x138240 pixel). As scaling is practically linear `O(n+log2(sqrt(n)))`, a collage from 1 million such images would take ~4 days.

## Requirements
 * bash and friends (unzip, sed, tr...)
 * ImageMagic
 * wget optional (OpenSeadragon must be downloaded manually if it is not there)

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
