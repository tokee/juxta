# Quick hack to visualize non-gridified tSNE placed images

# Adapted from https://github.com/ml4a/ml4a-guides/blob/master/notebooks/image-tsne.ipynb
#
############################################################################################
#
# Important: This script is under the GPL-2.0 licence
#
############################################################################################
# pip3 install matplotlib prime 
# On Ubuntu 19.10 it seems we need this instead: sudo apt-get install python-matplotlib
# pip3 install -U git+https://github.com/bmcfee/RasterFairy/ --user

import json
import matplotlib.pyplot
from PIL import Image
import rasterfairy
import numpy as np
import math
import sys
import argparse
import os

def process_arguments(args):
    parser = argparse.ArgumentParser(description='Plotting points to grid with RasterFairy')
    parser.add_argument('--in', action='store', required=True, help='input JSON file with points and images')
    parser.add_argument('--out_prefix', action='store', required=True, help='prefix for output files')
    parser.add_argument('--raw_image', action='store', default='', help='if defined, create preview image with raw data from in')
    parser.add_argument('--grid_image', action='store', default='', help='if defined, create preview image with gridified images')
    parser.add_argument('--image_width', action='store', default=4000, help='image width for raw- and grid-image')
    parser.add_argument('--image_height', action='store', default=3000, help='image height for raw- and grid-image')
    parser.add_argument('--tile_width', action='store', default=72, help='tile width for raw- and grid-image')
    parser.add_argument('--tile_height', action='store', default=56, help='tile height for raw- and grid-image')
    parser.add_argument('--scale_factor', action='store', default=100000, help='coordinates are multiplied with this before RasterFairy processing (do not change this unless you know what you are doing')
    params = vars(parser.parse_args(args))
    return params
    
def load_points():
    with open(json_file) as json_bytes:
        data = json.load(json_bytes)

    arr_points = []
    arr_all = []
    for tup in data:
        point = tup['point']
        arr_points.append([int(point[0]*scale_factor), int(point[1]*scale_factor)])
        arr_all.append([point[0], point[1], tup['path']])

    image_count = len(arr_points)
    
    ny = int(math.sqrt(image_count/2))
    if (ny == 0):
        ny = 1
    nx = int(image_count / ny)
    if (nx * ny < image_count):
        nx += 1
    #print("The " + str(image_count) + " images will be represented as " + str(nx) + "x" + str(ny) + " grid")

    return (data, arr_points, arr_all, image_count, nx, ny)
    
def create_raw_image():
    if ( raw_image == ''):
        return
    print("Generating raw preview image '" + str(raw_image) + "'")
    
    max_dim = 100
    counter = 0

    full_image = Image.new('RGBA', (image_width, image_height))
    for x, y, img in arr_all:
        counter += 1
        if ( counter % 10 == 0):
          print("Image #" + str(counter) + "/" + str(image_count))
        tile = Image.open(img)
        rs = max(1, tile.width/max_dim, tile.height/max_dim)
        tile = tile.resize((int(tile.width/rs), int(tile.height/rs)), Image.ANTIALIAS)
        full_image.paste(tile, (int((image_width-max_dim)*x), int((image_height-max_dim)*y)), mask=tile.convert('RGBA'))

    full_image.save(raw_image);
    print("Finished generating raw preview image. Result in " + raw_image)

def create_grid_image(grid):
    if ( grid_image == ''):
        return
    print("Generating gridified image " + grid_image)

    full_width = tile_width * nx
    full_height = tile_height * ny
    aspect_ratio = float(tile_width) / tile_height

    grid_bitmap = Image.new('RGB', (full_width, full_height))

    counter = 0
    total = len(arr_all)
    for tuple, grid_pos in zip(arr_all, grid):
        counter += 1
        if ( counter % 10 == 0):
          print("Image #" + str(counter) + "/" + str(image_count))

        idx_x, idx_y = grid_pos
        img_path = tuple[2]
#        print("image-gen: x: " + str(idx_x) + ", y: " + str(idx_y) + ", img: " + img_path)
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
        grid_bitmap.paste(tile, (int(x), int(y)))

    grid_bitmap.save(grid_image);
    print("Finished generating gridified image. Result in " + grid_image)
    
def make_grid():
    tsne = np.array(arr_points)
    print ("Analyzing " + str(len(tsne)) + " coordinates to target " + str(nx) + "x" + str(ny))
#    for x, y in tsne:
#        print ("tSNE: " + str(x) + ", " + str(y))

    gridAssignment = rasterfairy.transformPointCloud2D(tsne, target=(nx, ny))
    grid, gridShape = gridAssignment

#    print ("Got " + str(len(grid)) + " grid entries")
    for entry in grid:
        gridX, gridY = entry
#        print("gx: " + str(gridX) + ", gy: " + str(gridY))

    out_grid = []
    for i, dat in enumerate(data):
        gridX, gridY = grid[i]
#        print("grid_index: " + str(i) + ", gx: " + str(gridX) + ", gy: " + str(gridY))
        out_grid.append({'gx': int(gridX), 'gy': int(gridY), 'path': dat['path']})
 #   print(dat['path'] + " gx:" + str(int(gridX)) + ", gy:" + str(int(gridY)))

    # Column is secondary, row is primary - Python sort is stable; it does not change order on equal keys
    out_grid.sort(key = lambda obj: obj['gx'])
    out_grid.sort(key = lambda obj: obj['gy'])

    imgfile = open(out_image_list, "w")
    for element in out_grid:
        imgfile.write(element['path'] + "\n")
        # print(str(element['gx']) + " " + str(element['gy']) + " " + element['path'])
    imgfile.close()
#    print("Stored gridified image list as " + out_image_list)

    return grid

if __name__ == '__main__':
    params = process_arguments(sys.argv[1:])

    json_file = params['in']
    out_prefix = params['out_prefix']
    raw_image = params['raw_image']
    grid_image = params['grid_image']
    image_width = params['image_width']
    image_height = params['image_height']
    tile_width = params['tile_width']
    tile_height = params['tile_height']
    scale_factor = params['scale_factor']

    out_image_list = out_prefix + ".dat"
    if ( raw_image != '' and os.path.splitext(raw_image)[1] == ".jpg" ):
        sys.exit("Error: raw_image was '" + raw_image + "' but must be png or a similar format that supports transparency")
    
    data, arr_points, arr_all, image_count, nx, ny = load_points()

    create_raw_image()
    grid = make_grid()
    create_grid_image(grid)

    print("Data in " + out_image_list + " with a render-grid of " + str(nx) + "x" + str(ny))
