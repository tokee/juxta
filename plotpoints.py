# Quick hack to visualize non-gridified tSNE placed images

# Adapted from https://github.com/ml4a/ml4a-guides/blob/master/notebooks/image-tsne.ipynb
# pip3 install matplotlib
# pip3 install -U git+https://github.com/bmcfee/RasterFairy/ --user

import json
import matplotlib.pyplot
from PIL import Image

import rasterfairy
import numpy as np
import math

jsonfile = "points.json"
previewimage = "preview.png"
outimages = "gridified.dat"
# Grid image
gridimage = "grid.png"
tile_width = 72
tile_height = 56

# Load points
with open(jsonfile) as json_file:
    data = json.load(json_file)

arr = []
arrall = []
arrMimick = []
for tup in data:
    point = tup['point']
    arr.append([point[0], point[1]])
    arrall.append([point[0], point[1], tup['path']])
    arrMimick.append([tup['path'], [point[0], point[1]] ])

imagecount = len(arr)
    
ny = int(math.sqrt(imagecount/2))
if (ny == 0):
    ny = 1
nx = int(imagecount / ny)
if (nx * ny < imagecount):
    nx += 1
print("The " + str(imagecount) + " images will be represented as " + str(nx) + "×" + str(ny) + " grid")

    
def makepreview():    
    width = 4000
    height = 3000
    max_dim = 100
    counter = 0

    print("Generating non-gridified preview image")
    full_image = Image.new('RGBA', (width, height))
    for x, y, img in arrall:
        counter += 1
        if ( counter % 10 == 0):
          print("Image #" + str(counter) + "/" + str(imagecount))
        tile = Image.open(img)
        rs = max(1, tile.width/max_dim, tile.height/max_dim)
        tile = tile.resize((int(tile.width/rs), int(tile.height/rs)), Image.ANTIALIAS)
        full_image.paste(tile, (int((width-max_dim)*x), int((height-max_dim)*y)), mask=tile.convert('RGBA'))

    full_image.save(previewimage);
    print("Finished generating non-gridified preview image. Result in " + previewimage)

def makegridimage(grid):
    print("Generating gridified image")

    full_width = tile_width * nx
    full_height = tile_height * ny
    aspect_ratio = float(tile_width) / tile_height

    grid_image = Image.new('RGB', (full_width, full_height))

    counter = 0
    total = len(arrall)
    for tuple, grid_pos in zip(arrall, grid):
        counter += 1
        if ( counter % 10 == 0):
          print("Image #" + str(counter) + "/" + str(imagecount))

        idx_x, idx_y = grid_pos
        img_path = tuple[2]
        #print("x: " + str(idx_x) + ", y: " + str(idx_y) + ", img: " + img_path)
        x, y = tile_width * idx_x, tile_height * idx_y
        tile = Image.open(img_path)
        tile_ar = float(tile.width) / tile.height  # center-crop the tile to match aspect_ratio
        if (tile_ar > aspect_ratio):
            margin = 0.5 * (tile.width - aspect_ratio * tile.height)
            tile = tile.crop((margin, 0, margin + aspect_ratio * tile.height, tile.height))
        else:
            margin = 0.5 * (tile.height - float(tile.width) / aspect_ratio)
            tile = tile.crop((0, margin, tile.width, margin + float(tile.width) / aspect_ratio))
            tile = tile.resize((tile_width, tile_height), Image.ANTIALIAS)
            grid_image.paste(tile, (int(x), int(y)))

    grid_image.save(gridimage);
    print("Finished generating gridified image. Result in " + gridimage)
    
def makegrid():
    tsne = np.array(arr)
    gridAssignment = rasterfairy.transformPointCloud2D(tsne, target=(nx, ny))
    grid, gridShape = gridAssignment

    for entry in grid:
        gridX, gridY = entry
        print("gx: " + str(gridX) + ", gy: " + str(gridY))
    return

    out_grid = []
    for i, dat in enumerate(data):
        gridX, gridY = grid[i]
        print("gx: " + str(gridX) + ", gy: " + str(gridY))
        out_grid.append({'gx': int(gridX), 'gy': int(gridY), 'path': dat['path']})
    #    print(dat['path'] + " gx:" + str(int(gridX)) + ", gy:" + str(int(gridY)))
    return

    # We sort by secondary first - Python sort is stable; it does not change order on equal keys
    out_grid.sort(key = lambda obj: obj['gy'])
    out_grid.sort(key = lambda obj: obj['gx'])

    imgfile = open(outimages, "w")
    for element in out_grid:
        imgfile.write(element['path'] + "\n")
    #print(str(element['gx']) + " " + str(element['gy']) + " " + element['path'])
    imgfile.close()
    print("Stored gridified image list as " + outimages)

    return grid


    
makepreview()
grid = makegrid()
makegridimage(grid)
