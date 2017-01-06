# juxta
Generates large collages of images using OpenSeadragon

Demo at https://tokee.github.io/juxta/

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

## Limitations and bugs
 * Only the generation of base tiles is currently threadable
 * There are some missing tiles at the bottom of the virtual image, resulting in some visual artefacts

