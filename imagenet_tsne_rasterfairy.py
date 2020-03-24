#!/usr/bin/env python3

# Disable tensorflow warning about missing GPU support
# https://stackoverflow.com/questions/47068709/your-cpu-supports-instructions-that-this-tensorflow-binary-was-not-compiled-to-u
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import argparse
import sys
import glob
import os.path

import numpy as np

import keras
from keras.models import Model
from keras.applications.imagenet_utils import decode_predictions, preprocess_input
from keras.preprocessing import image
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE


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
# - Skip analysis if it has already been done (load previously generated data)
# - Optionally render a collage with the images after tSNE
# - Run rasterfairy

def process_arguments(args):
    parser = argparse.ArgumentParser(description='ML network analysis of images')
    parser.add_argument('--images', nargs='+', action='store', required=True, help='images to analyze')
    parser.add_argument('--perplexity', action='store', default=30, help='perplexity of t-SNE (default 30)')
    parser.add_argument('--learning_rate', action='store', default=150, help='learning rate of t-SNE (default 150)')
    parser.add_argument('--components', action='store', default=300, help='components for PCA fit (default 300)')
    parser.add_argument('--output', action='store', default='ml_out.json', help='output file for vectors and classifications (default ml_out.json)')
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
def analyze(image_paths, perplexity, learning_rate, pca_components, output):
    out = open(output, "w")
    # TODO: Try other models
    model = keras.applications.VGG16(weights='imagenet', include_top=True)
    fc2 = model.get_layer("fc2").output
    predictions = model.get_layer("predictions").output
    feat_extractor = Model(inputs=model.input, outputs=[fc2, predictions])
    input_shape = model.input_shape[1:3] # 224, 224?

    acceptable_image_paths = []
    fc2_features = []
    prediction_features = []
    for index, path in enumerate(image_paths):
        img = load_image(path, input_shape);
        if img is not None:
            print(" - Analyzing %d/%d: %s " % ((index+1),len(image_paths), path))
            features = feat_extractor.predict(img)
            fc2_features.append(features[0][0]) # 4096 dimensional
            prediction_features.append(features[1][0]) # 1000 dimensional
            acceptable_image_paths.append(path)
#            print("Decoded: " + str(decode_predictions(features[1], top=10)))
            predictions = decode_predictions(features[1], top=10)[0]
#            print("****".join(('\n{"designation":"' + str(c[1]) + '", "internalID":"' + str(c[0]) + '", "probability":' + str(c[2]) + '}') for c in predictions))

            out.write('\n{ "path":"' + path + '", ')
            # TODO: Remember to make this a variable when the script is extended to custom networks
            out.write('"network": "imagenet", ')

            out.write('"predictions": [')
            out.write(','.join((' {"designation":"' + str(c[1])  + '", "probability":' + str(c[2]) + ', "internalID":"' + str(c[0])+ '"}') for c in predictions))
            out.write("], ")
           
            # TODO: Remember to make this a variable when the script is extended to custom networks
            out.write('"vector_layer":"fc2", ')
            out.write('"vector": [' + ','.join(str(f) for f in features[0][0]) + "]")
            out.write("}")
        else:
            print(" - Image not available %d/%d: %s" % ((index+1),len(image_paths), path))
            
    out.write("\n")
    out.close()

    # Reduce dimensions
    
    # t-SNE is too costly to run on 4096-dimensional space, so we reduce with PCA first
    num_images = len(acceptable_image_paths)
    # TODO: Shouldn't we just skip the PCA-step if there are less images than pca_components?
    components = min(pca_components, num_images)
    print("Running PCA on %d images with %d components..." % (num_images, components))
    features = np.array(fc2_features)
    pca = PCA(n_components=components)
    pca_result = pca.fit_transform(features)

    tsne = TSNE(n_components=2, verbose=1, perplexity=perplexity, learning_rate=learning_rate, n_iter=300)
    tsne_results = tsne.fit_transform(np.array(pca_result))

    # TODO: Write dimensional data and generate preview image
    
    data = []
    for i,f in enumerate(images):
        # TODO: Can we skip the normalising? Will rasterfairy work with negative numbers and/or large numbers?
        point = [float((tsne[i,k] - np.min(tsne[:,k]))/(np.max(tsne[:,k]) - np.min(tsne[:,k]))) for k in range(tsne_dimensions) ]

    # TODO: Run rasterfairy

    # TODO: Store final output
        
    print("Stored output to '" + output + "'")
            
if __name__ == '__main__':
    params = process_arguments(sys.argv[1:])
    image_paths = params['images']
    # If the images-argument is a string instead of an existing file, try globbing it
    if len(image_paths) == 1 and not os.path.isfile(image_paths[0]):
        print("Globbing '" + image_paths[0] + "'")
        image_paths = glob.glob(os.path.expanduser(image_paths[0]))
    if len(image_paths) == 0:
        print("Error: 0 images resolved")
        sys.exit()

    perplexity = int(params['perplexity'])
    learning_rate = int(params['learning_rate'])
    pca_components = int(params['components'])
    output = params['output']

    analyze(image_paths, perplexity, learning_rate, pca_components, output)

