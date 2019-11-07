# Quick hack to visualize non-gridified tSNE placed images

# Adapted from https://github.com/ml4a/ml4a-guides/blob/master/notebooks/image-tsne.ipynb

import json
import matplotlib.pyplot
from PIL import Image

with open('points.json') as json_file:
    data = json.load(json_file)

arr = []
for tup in data:
    point = tup['point']
    arr.append([point[0], point[1], tup['path']])

width = 4000
height = 3000
max_dim = 100

full_image = Image.new('RGBA', (width, height))
for x, y, img in arr:
    tile = Image.open(img)
    rs = max(1, tile.width/max_dim, tile.height/max_dim)
    tile = tile.resize((int(tile.width/rs), int(tile.height/rs)), Image.ANTIALIAS)
    full_image.paste(tile, (int((width-max_dim)*x), int((height-max_dim)*y)), mask=tile.convert('RGBA'))

full_image.save("preview.png");
               
