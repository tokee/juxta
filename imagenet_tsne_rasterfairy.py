#!/usr/bin/env python3

# Disable tensorflow warning about missing GPU support
# https://stackoverflow.com/questions/47068709/your-cpu-supports-instructions-that-this-tensorflow-binary-was-not-compiled-to-u
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

import argparse
import sys

import numpy

import keras
from keras.models import Model
from keras.applications.imagenet_utils import decode_predictions, preprocess_input
from keras.preprocessing import image
from sklearn.decomposition import PCA

#
# Requirements: keras tensorflow sklearn "numpy<1.17" (to avoid warnings fron tensorflow)
#

def process_arguments(args):
    parser = argparse.ArgumentParser(description='ML network analysis of images')
    parser.add_argument('--images', nargs='+', action='store', help='images to analyze')
    parser.add_argument('--perplexity', action='store', default=30, help='perplexity of t-SNE (default 30)')
    parser.add_argument('--learning_rate', action='store', default=150, help='learning rate of t-SNE (default 150)')
    parser.add_argument('--components', action='store', default=300, help='components for PCA fit (default 300)')
    params = vars(parser.parse_args(args))
    return params

# https://stackoverflow.com/questions/47555829/preprocess-input-method-in-keras
def load_image(path, input_shape):
    img = image.load_img(path, target_size=input_shape)
    x = image.img_to_array(img)
    x = numpy.expand_dims(x, axis=0)
    x = preprocess_input(x)
    return x

#https://towardsdatascience.com/visualising-high-dimensional-datasets-using-pca-and-t-sne-in-python-8ef87e7915b
def analyze(image_paths, perplexity, learning_rate, pca_components):
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
            print(" - Analyzing %s %d/%d" % (path, (index+1),len(image_paths)))
            features = feat_extractor.predict(img)
            fc2_features.append(features[0]) # 4096 dimensional
            prediction_features.append(features[1]) # 1000 dimensional
            acceptable_image_paths.append(path)
            # print("Decoded: " + str(decode_predictions(acts, top=10)))
        else:
            print(" - Image not available %s %d/%d" % (path, (index+1),len(image_paths)))

    # t-SNE is too costly to run on 4096-dimensional space, so we reduce with PCA first
    num_images = len(acceptable_image_paths)
    # Why do we need this? Shouldn't components relate to fc2-dimensions?
    components = min(pca_components, num_images)
    print("Running PCA on %d images with %d components..." % (num_images, components))
    features = numpy.array(fc2_features)
    pca = PCA(n_components=components)
    pca_result = pca.fit_transform(features)


            
if __name__ == '__main__':
    params = process_arguments(sys.argv[1:])
    image_paths = params['images']
    perplexity = int(params['perplexity'])
    learning_rate = int(params['learning_rate'])
    pca_components = int(params['components'])

    analyze(image_paths, perplexity, learning_rate, pca_components)

