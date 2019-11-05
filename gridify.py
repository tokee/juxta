import rasterfairy
import json
import numpy as np
import math

# Expects output from tSNE-images.py and runs rasterfairy on the input,
# writing the image paths layed out to a grid as the output

with open('/home/te/projects/ml4a-ofx/points.json') as json_file:
    data = json.load(json_file)

arr = []
for tup in data:
    point = tup['point']
    arr.append([point[0], point[1]])
#    arr.append([math.floor(point[0]*100000000), math.floor(point[1]*100000000)])

#full_data = np.asarray( data )
#  {'path': '/home/te/projects/ml4a-ofx/images/20190902-0853_4.jpg', 'point': [0.1758463829755783, 0.3165808618068695]}
#for entry in full_data:
#    print (entry)


#print(full_data)

#arr = np.asarray( [[1000, 2000], [2, 30], [8, 100], [300, 2]])
#print(arr)
tsne = np.asarray(arr)
#print(tsne)

nx = 15
ny = 21

# 16x20 hangs forever!?
#nx = 16
#ny = 20

#grid = rasterfairy.transformPointCloud2D(tsne)
print("Calling rasterfairy on " + str(len(arr)) + " coordinates")
gridAssignment = rasterfairy.transformPointCloud2D(tsne, target=(nx, ny))
grid, gridShape = gridAssignment

out_grid = []
for i, dat in enumerate(data):
    gridX, gridY = grid[i]
    out_grid.append({'gx': int(gridX), 'gy': int(gridY), 'path': dat['path']})
#    print(dat['path'] + " gx:" + str(int(gridX)) + ", gy:" + str(int(gridY)))

#out_grid = out_grid.sort(key = lambda obj: obj['gx'], obj['gy'])

# We sort by secondary first - Python sort is stable; it does not change order on equal keys
out_grid.sort(key = lambda obj: obj['gy'])
out_grid.sort(key = lambda obj: obj['gx'])

for element in out_grid:
    print(element['path'])

#print(out_grid)


