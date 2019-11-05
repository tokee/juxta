import rasterfairy
import json
import numpy as np

with open('/home/te/projects/ml4a-ofx/points.json') as json_file:
    data = json.load(json_file)

for j in data:
    print(j['point'])

    print("**************************************")
    
full_data = np.asarray( data )
#  {'path': '/home/te/projects/ml4a-ofx/images/20190902-0853_4.jpg', 'point': [0.1758463829755783, 0.3165808618068695]}
#for entry in full_data:
#    print (entry)


#print(full_data)

arr = np.asarray( [[1000, 2000], [2, 30], [8, 100], [300, 2]])
print(arr)
tsne = np.asarray(arr)
print(tsne)

# nx * ny = 1000, the number of images
nx = 2
ny = 2

# assign to grid
#grid = rasterfairy.transformPointCloud2D(tsne)
grid = rasterfairy.transformPointCloud2D(tsne, target=(nx, ny))
print(grid)


