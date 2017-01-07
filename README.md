# juxta
Generates large collages of images using OpenSeadragon

Demo at https://tokee.github.io/juxta/

## Technical notes
juxta generates tiles for use with OpenSeadragon. One tile = one 256x256 pixel image file. The tile generation is threaded and localized to the individual source images. This means that memory overhead is independent of the total collage size. The difference between generating a collage of 10 vs. 10 million images is only CPU time.

One downside to storing tiles as individual files is that the folder holding the tiles for the deepest zoom level will contain a lot of tiles: At least one per source image. This is a performance problem for some file systems, as well as some backup systems.

The script is restart-friendly as it skips already generated tiles.

## Requirements
 * bash, curl
 * ImageMagic

## Usage
1. Create a list of images
   `ls myimages/*.jpg > images.dat`

2. Generate collage tiles
  `./juxta.sh images.dat mycollage`
Due to problems with downloading directly from GitHub, OpenSeadragon might have to be downloaded manually. Don't worry, the script will tell you what to do.

3. View the collage in a browser
 `firefox mycollage.html`

## Advanced
Processing can be controlled by setting environment variables. Most important options are

 * RAW_W / RAW_H: The size of the fully zoomed source images, measured in tiles. RAW_W=4 and RAW_H=3 means (4**256)x(3**256) = 1024x768 pixels. Default is 4 and 3.
 * THREADS: The number of threads to use when generating the tiles at full zoom level. Default is 1.
 * TILE_FORMAT: png or jpg. Default is jpg.

Processing a bunch of photos on a modern desktop machine could be done with
```
ls myimages/*.jpg > sources.dat
RAW_W=3 RAW_H=2 THREADS=4 TILE_FORMAT=jpg ./juxta.sh sources.dat mycollage
```
