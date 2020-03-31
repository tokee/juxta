#!/usr/bin/env python3

# Disable tensorflow warning about missing GPU support
# https://stackoverflow.com/questions/47068709/your-cpu-supports-instructions-that-this-tensorflow-binary-was-not-compiled-to-u
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import argparse
import sys
import glob
import os.path
import math
import rasterfairy

import numpy as np

import keras
from keras.models import Model
from keras.applications.imagenet_utils import decode_predictions, preprocess_input
from keras.preprocessing import image
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE
from PIL import Image as PILImage
from multiprocessing import Pool, Lock

#
# Requirements: keras tensorflow sklearn "numpy<1.17" (to avoid warnings fron tensorflow)
# pip3 install -r Requirements.txt
#
# Or:
#
# python3 -m venv tsne
# source tsne/bin/activat
# pip install --upgrade pip
# pip install -r Requirements.txt
#

# TODO:
# - Add support for other models
# - Skip analysis if it has already been done (load previously generated data)
# - Optionally render a collage with the images after tSNE

def process_arguments(args):
    parser = argparse.ArgumentParser(description='ML network analysis of images')
    parser.add_argument('--images', nargs='+', action='store', required=True, help='images to analyze (image paths, file with list of images or glob')
    parser.add_argument('--perplexity', action='store', default=30, help='perplexity of t-SNE (default 30)')
    parser.add_argument('--learning_rate', action='store', default=150, help='learning rate of t-SNE (default 150)')
    parser.add_argument('--components', action='store', default=300, help='components for PCA fit (default 300)')
    parser.add_argument('--output', action='store', default='ml_out.json', help='output file for vectors and classifications (default ml_out.json)')

    parser.add_argument('--grid_width', action='store', default=0, help='grid width measured in images. If not defined, it will be calculated towards having a 2:1 aspect ratio')
    parser.add_argument('--grid_height', action='store', default=0, help='grid height measured in images. If not defined, it will be calculated towards having a 2:1 aspect ratio')
    parser.add_argument('--scale_factor', action='store', default=100000, help='coordinates are multiplied with this before RasterFairy processing (do not change this unless you know what you are doing')

    parser.add_argument('--render_tsne', action='store', default='', help='if defined, a colleage of the images positioned by their t-SNE calculated coordinates is rendered to the given file')
    parser.add_argument('--render_width', action='store', default=5000, help='the width of the t-SNE render')
    parser.add_argument('--render_height', action='store', default=5000, help='the height of the t-SNE render')
    parser.add_argument('--render_part_width', action='store', default=100, help='the width of a single image on the full t-SNE render')
    parser.add_argument('--render_part_height', action='store', default=100, help='the height of a single image on the full t-SNE render')
    
    params = vars(parser.parse_args(args))
    return params

# https://stackoverflow.com/questions/47555829/preprocess-input-method-in-keras
def load_image(path, input_shape):
    img = image.load_img(path, target_size=input_shape)
    x = image.img_to_array(img)
    x = np.expand_dims(x, axis=0)
    x = preprocess_input(x)
    return x

# https://towardsdatascience.com/visualising-high-dimensional-datasets-using-pca-and-t-sne-in-python-8ef87e7915b
def analyze(image_paths, output, penultimate_layer):
    model = keras.applications.VGG16(weights='imagenet', include_top=True)
    penultimate = model.get_layer(penultimate_layer).output
    predictions = model.get_layer("predictions").output
    feat_extractor = Model(inputs=model.input, outputs=[penultimate, predictions])
    input_shape = model.input_shape[1:3] # 224, 224?

    acceptable_image_paths = []
    penultimate_features = []
    prediction_features = []
    predictionss = []
    for index, path in enumerate(image_paths):
        img = load_image(path, input_shape);
        if img is not None:
            print(" - Analyzing %d/%d: %s " % ((index+1),len(image_paths), path))
            features = feat_extractor.predict(img)
            penultimate_features.append(features[0][0]) # 4096 dimensional
            prediction_features.append(features[1][0]) # 1000 dimensional
            acceptable_image_paths.append(path)
            predictions = decode_predictions(features[1], top=10)[0]
            predictionss.append(predictions)
        else:
            print(" - Image not available %d/%d: %s" % ((index+1),len(image_paths), path))

    return acceptable_image_paths, penultimate_features, prediction_features, predictionss

# Defined inside analyze_parallel to inherits all shared structures
def analyze_single(path):
    img = load_image(path, input_shape);
    if img is not None:
        #print(" - Analyzing %d/%d: %s " % ((index+1),len(image_paths), path))
        print(" - Analyzing %s " % (path))
        image_lock.acquire()
        try:
            print("Inside")
 #       features = feat_extractor.predict(img)
#        predictions = decode_predictions(features[1], top=10)[0]
   #         penultimate_features.append(features[0][0]) # 4096 dimensional
    #        prediction_features.append(features[1][0]) # 1000 dimensional
     #       acceptable_image_paths.append(path)
      #      predictionss.append(predictions)
        finally:
            image_lock.release()
    else:
        print(" - Image not available: %s" % (path))
        #print(" - Image not available %d/%d: %s" % ((index+1),len(image_paths), path))

# https://towardsdatascience.com/visualising-high-dimensional-datasets-using-pca-and-t-sne-in-python-8ef87e7915b
def analyze_parallel(image_paths, output, penultimate_layer):

    # Real ugly to globalize all these, but how to neatly pack them to the analyze_single call?
    global feat_extractor
    global input_shape
    global acceptable_image_paths
    global penultimate_features
    global prediction_features
    global predictionss
    global image_lock

    model = keras.applications.VGG16(weights='imagenet', include_top=True)
    penultimate = model.get_layer(penultimate_layer).output
    predictions = model.get_layer("predictions").output
    feat_extractor = Model(inputs=model.input, outputs=[penultimate, predictions])
    input_shape = model.input_shape[1:3] # 224, 224?

    acceptable_image_paths = []
    penultimate_features = []
    prediction_features = []
    predictionss = []

    # TODO: Thread count should be an option
    image_lock = Lock()
    with Pool(6) as pool:
        pool.map(analyze_single, image_paths)

    return acceptable_image_paths, penultimate_features, prediction_features, predictionss

def reduce(penultimate_features, perplexity, learning_rate, pca_components, scale_factor):
    # Reduce dimensions
    
    # t-SNE is too costly to run on 4096-dimensional space, so we reduce with PCA first
    image_count = len(penultimate_features)
    # TODO: Shouldn't we just skip the PCA-step if there are less images than pca_components?
    components = min(pca_components, image_count)
    print("Running PCA on %d images with %d components..." % (image_count, components))
    features = np.array(penultimate_features)
    pca = PCA(n_components=components)
    pca_result = pca.fit_transform(features)

    tsne = TSNE(n_components=2, verbose=1, perplexity=perplexity, learning_rate=learning_rate, n_iter=300)
    tsne_raws = tsne.fit_transform(np.array(pca_result))

    #print(tsne_raws)
#    [[ -6.464286 -77.81506 ]
#     [-11.039936  35.283787]
#     [-78.37078  -20.521582]
#     [ 73.822014  50.5032  ]
#     [ 74.64323  -41.658306]]

    tsne_min = [ np.min(tsne_raws[:,d]) for d in range(2) ]
    tsne_span = [ np.max(tsne_raws[:,d]) - tsne_min[d] for d in range(2) ]

    tsne_norm = []
    tsne_norm_int = []
    for raw_point in tsne_raws:
        norm = [float((raw_point[d] - tsne_min[d])/tsne_span[d]) for d in range(2) ]
        tsne_norm.append(norm)
        norm_int = [int(norm[d] * scale_factor) for d in range(2) ]
        tsne_norm_int.append(norm_int)
        
    return tsne_norm, tsne_norm_int
        
def calculate_grid(image_count, grid_width, grid_height):
    if (grid_width == 0 and grid_height == 0):
        print(" - Neither grid_width nor grid_height is specified. Calculating with intended aspect ration 2:1")
        grid_height = int(math.sqrt(image_count/2))
        if (grid_height == 0):
            grid_height = 1
        grid_width = int(image_count / grid_height)
        if (grid_width * grid_height < image_count):
            grid_width += 1
    elif( grid_width != 0 and grid_height != 0):
        if (grid_width * grid_height < image_count):
            sys.exit("Error: grid_width==" + str(grid_width) + " * grid_height==" + str(grid_height) + " == " + str(grid_width*grid_height) + " does not hold image_count==" + str(image_count))
        if (grid_width * (grid_height-1) >= image_count):
            sys.exit("Error: grid_width==" + str(grid_width) + " * grid_height==" + str(grid_height) + " == " + str(grid_width*grid_height) + " is too large for image_count==" + str(image_count) + " images (rows can be skipped and rasterfair hangs on mismatched grid capacity)")
        if ((grid_width-1) * grid_height >= image_count):
            sys.exit("Error: grid_width==" + str(grid_width) + " * grid_height==" + str(grid_height) + " == " + str(grid_width*grid_height) + " is too large for image_count==" + str(image_count) + " images (columns can be skipped and rasterfair hangs on mismatched grid capacity)")
        print(" - grid_height==" + str(grid_height) + ", grid_width==" + str(grid_width))
    elif (grid_width != 0):
        grid_height = int(image_count/grid_width)
        if (grid_height*grid_width < image_count):
            grid_height += 1
        print(" - grid_width==" + str(grid_width) + ", calculated grid_height==" + str(grid_height))
    else: # grid_height != 0
        grid_width = int(image_count/grid_height)
        if (grid_width*grid_height < image_count):
            grid_width += 1
        print(" - grid_height==" + str(grid_height) + ", calculated grid_width==" + str(grid_width))
    print(" - The " + str(image_count) + " images will be represented on a " + str(grid_width) + "x" + str(grid_height) + " grid")

    return grid_width, grid_height

    
def gridify(tsne_norm_int, grid_width, grid_height):
    tsne = np.array(tsne_norm_int)
    grid, gridShape = rasterfairy.transformPointCloud2D(tsne, target=(grid_width, grid_height))
    return grid
    
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

# Merges & sorts all structures according to the grid layout
def merge(grid, tsne_norm, acceptable_image_paths, penultimate_features, prediction_features, predictions):
    merged = []
    for i, path in enumerate(acceptable_image_paths):
        merged.append({
            'path': path,
            'position_norm': tsne_norm[i],
            'position_grid': grid[i],
            'penultimate': penultimate_features[i],
            'prediction_features': prediction_features[i],
            'predictions': predictions[i]
            })

    # Column is secondary, row is primary - Python sort is stable; it does not change order on equal keys
    merged.sort(key = lambda obj: obj['position_grid'][0])
    merged.sort(key = lambda obj: obj['position_grid'][1])

    return merged

def store(merged, penultimate_layer, grid_width, grid_height, output):
    out = open(output, "w")
    for i, element in enumerate(merged):
        if (i != 0):
            out.write('\n')
        out.write('{ "path":"' + element['path'] + '", ')
        # TODO: Remember to make this a variable when the script is extended to custom networks
        out.write('"network": "imagenet", ')

        out.write('"norm_x": ' + str(element['position_norm'][0]) + ', ')
        out.write('"norm_y": ' + str(element['position_norm'][1]) + ', ')
        
        out.write('"grid_x": ' + str(int(element['position_grid'][0])) + ', ')
        out.write('"grid_y": ' + str(int(element['position_grid'][1])) + ', ')

        predictions = element['predictions']
        out.write('"predictions": [')
        out.write(','.join((' {"designation":"' + str(c[1])  + '", "probability":' + str(c[2]) + ', "internalID":"' + str(c[0])+ '"}') for c in predictions))
        out.write("], ")

        prediction_features = element['prediction_features']
        out.write('"prediction_vector": [' + ','.join(str(f) for f in prediction_features) + "], ")

        penultimate = element['penultimate']
        out.write('"penultimate_vector_layer": "' + penultimate_layer + '", ')
        out.write('"penultimate_vector": [' + ','.join(str(f) for f in penultimate) + "]")

        out.write("}")

    out.write("\n")
    out.close()

    print("Stored result in '" + output + "', generate collage with grid dimensions " + str(grid_width) + "x" + str(grid_height))

def render(merged, render_tsne, render_width, render_height, render_part_width, render_part_height):
    if (render_tsne == ''):
        return

    print(" - Generating collage from raw t-SNE coordinates to " + render_tsne)
    tsne_image = PILImage.new('RGBA', (render_width, render_height))
    for element in merged:
        path = element['path']
        norm = element['position_norm']
        
        print("   - " + path)
        img = PILImage.open(path)
        divisor = max(img.width/render_part_width, img.height/render_part_height)
        img = img.resize( (int(img.width/divisor), int(img.height/divisor)), PILImage.LANCZOS)
        tsne_image.paste(img, (int(norm[0]*(render_width-render_part_width)), int(norm[1]*(render_height-render_part_height))), mask=img.convert('RGBA'))

    tsne_image.save(render_tsne);
    print(" - Collage generated from raw t-SNE coordinates and stored as " + render_tsne)

def render_single(element):
    path = element['path']
    norm = element['position_norm']
        
    print("   - " + path)
    img = PILImage.open(path)
    divisor = max(img.width/render_part_width, img.height/render_part_height, 1)
    img = img.resize( (int(img.width/divisor), int(img.height/divisor)), PILImage.LANCZOS)
    image_lock.acquire()
    try:
        tsne_image.paste(img, (int(norm[0]*(render_width-render_part_width)), int(norm[1]*(render_height-render_part_height))), mask=img.convert('RGBA'))
    finally:
        image_lock.release()

def render_parallel(merged, render_tsne, render_width, render_height, render_part_width, render_part_height):
    if (render_tsne == ''):
        return

    # Ugly hack but how to get it inside render_single?
    global tsne_image
    global image_lock

    print(" - Generating collage from raw t-SNE coordinates to " + render_tsne)
    tsne_image = PILImage.new('RGBA', (render_width, render_height))
    
    image_lock = Lock()
    # TODO: Make #threads configurable
    with Pool(6) as pool:
        pool.map(render_single, merged)

    tsne_image.save(render_tsne);
    print(" - Collage generated from raw t-SNE coordinates and stored as " + render_tsne)

def test_render_single(path):
        
    print("   - " + path)
    img = PILImage.open(path)
    img = img.resize((200, 200), PILImage.LANCZOS)
    image_lock.acquire()
    try:
        tsne_image.paste(img, (500, 500), mask=img.convert('RGBA'))
   finally:
       image_lock.release()

def test_render_parallel(paths):

    global tsne_image
    global image_lock
    tsne_image = PILImage.new('RGBA', (1000, 1000))
    image_lock = Lock()

    for path in paths:
        image_lock.acquire()
        try:
            test_render_single(path)
        finally:
            image_lock.release()
            # TODO: Make #threads configurable
#    with Pool(1) as pool:
#        pool.map(test_render_single, paths)

    tsne_image.save(render_tsne);
    print(" - Collage generated from raw t-SNE coordinates and stored as " + render_tsne)

def test_render(paths):
    tsne_image = PILImage.new('RGBA', (1000, 1000))
    image_lock = Lock()
    for path in paths:
        img = PILImage.open(path)
        img = img.resize((200, 200), PILImage.LANCZOS)
        tsne_image.paste(img, (500, 500), mask=img.convert('RGBA'))

    tsne_image.save(render_tsne);
    print(" - Collage generated from raw t-SNE coordinates and stored as " + render_tsne)

    
if __name__ == '__main__':
    params = process_arguments(sys.argv[1:])
    image_paths = params['images']
    # If the images-argument is a string instead of an existing file, try globbing it
    if len(image_paths) == 1:
        if os.path.isfile(image_paths[0]):
            print("Using images listed in " + image_paths[0] + " as input")
            file = open(image_paths[0], 'r')
            image_paths = [line.strip() for line in file.readlines()]
        else:
            print("Globbing '" + image_paths[0] + "'")
            image_paths = glob.glob(os.path.expanduser(image_paths[0]))
    
    if len(image_paths) == 0:
        print("Error: 0 images resolved")
        sys.exit()

    perplexity = int(params['perplexity'])
    learning_rate = int(params['learning_rate'])
    pca_components = int(params['components'])
    output = params['output']
    penultimate_layer = "fc2"

    # RasterFairy arguments
    grid_width = params['grid_width']
    grid_width = int(grid_width)
    grid_height = params['grid_height']
    grid_height = int(grid_height)
    scale_factor = params['scale_factor']

    render_tsne = params['render_tsne']
    render_width = int(params['render_width'])
    render_height = int(params['render_height'])
    render_part_width = int(params['render_part_width'])
    render_part_height = int(params['render_part_height'])

#    test_render(image_paths)
    test_render_parallel(image_paths)
    
#    acceptable_image_paths, penultimate_features, prediction_features, predictions = analyze(image_paths, output, penultimate_layer)
 #   tsne_norm, tsne_norm_int = reduce(penultimate_features, perplexity, learning_rate, pca_components, scale_factor)
  #  grid_width, grid_height = calculate_grid(len(tsne_norm_int), grid_width, grid_height)
   # grid = gridify(tsne_norm_int, grid_width, grid_height)
#    merged = merge(grid, tsne_norm, acceptable_image_paths, penultimate_features, prediction_features, predictions)
 #   render_parallel(merged, render_tsne, render_width, render_height, render_part_width, render_part_height)
  #  store(merged, penultimate_layer, grid_width, grid_height, output)
#3:43
#2:15 (6 threads, tsne_preview)
