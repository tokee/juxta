# Specific documentation of demo_twitter.sh

## Introduction

`demo_twitter.sh` was created explicitly for handling a use-case for
@ruebot: https://twitter.com/ruebot/status/825819358228254720

In short: Display millions of images from tweets in a collage, providing links
back to the original tweets.

juxta itself takes care of the collage generation, but it needs to be fed with
a list of image-paths and metadata. This documents is about ways to make
that happen.

## Things to consider

juxta creates one big collage. At maximum zoom, the size of the images (and their aspect ratio) is defined by `RAW_WxRAW_H`, where each block is 256x256 pixels, so setting `RAW_W=3 RAW_H=2` means `768x512 pixels`. If there are 1 millions of images, that means a final collage of ~400 gigapixel. An obvious precaution is to create a test-collage of 1000 images or so, to get an idea of how it looks, before running a big job.

Also note that the number of inodes used will be a little more than `RAW_WxRAW_H`. With the example above, be sure to check that there at at least 10 million free inodes on the file system (call `df -i` under Linux/OS-X).

## Tweet-IDs as source

**Important:** This requires [twarc](https://github.com/docnow/twarc), a (free) API-key from
Twitter and an understanding of Twitters [Developer Agreement & Policy](https://dev.twitter.com/overview/terms/agreement-and-policy).

The base usage of the script is to have a file with a list of tweet-IDs,
such as
```
786532479343599620
619403274597363712
599186643854204928
```

Feeding the list to `demo_twitter.sh` with the command
```Shell
MAX_IMAGES=10 ./demo_twitter.sh mytweets.dat tweet_collage
```
will result in the following actions

 1. The tweets are resolved from their IDs using [twarc](https://github.com/docnow/twarc) hydrate
 2. A list of tuples with `[timestamp, tweet-ID, image-URL]` is extracted from the hydrated tweets
 3. The images from the tuples are downloaded and a new list of entries `imagePath|tweet-ID timestamp` is created
 4. juxta is called with the list of entries, using the template `demo_twitter.template.html` to provide custom snippets of JavaScript to resolve `tweet-ID timestamp` into tweet-links

If the script is stopped, restarting will cause it to skip the parts that are already completed. Images are stored in `destination_downloads` in sub-folders containing at most 20,000 images to avoid performance problems with many files/folder.

## Tweets as source

If the tweets are already available in the format used by twarc hydrate, step 1 in _Tweet-IDs as source_ is not needed. `demo_tritter.sh` auto.guesses if the input is already hydrated and for safety it can be stated as an argument.

```Shell
ALREADY_HYDRATED=true ./demo_twitter.sh mytweets.json tweet_collage
```

## Tweets + images both available

It is highly doubtful that an existing collection of tweets and images will follow the folder layout and file name normalisation used by `demo_twitter.sh`. In this case, the script should be skipped altogether and a list of entries of the format `imagePath|tweet-ID timestamp` should be created by other means. An example list is
```
te-images/pbs.twimg.com_media_CupTGBlWcAA-yzz.jpg|786532479343599620 2016-10-13T13:42:10
te-images/pbs.twimg.com_media_CFC9E7bVEAAa62-.png|599186643854204928 2015-05-15T14:16:42
te-images/pbs.twimg.com_media_CJiP_t_XAAApWE6.jpg|619403274597363712 2015-07-10T09:10:23
```

With this list, juxta should be called with
```Shell
TEMPLATE=demo_twitter.template.html RAW_W=2 RAW_H=2 THREADS=3 INCLUDE_ORIGIN=false ./juxta.sh mylist.dat twitter_collage
```
