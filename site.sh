#!/bin/sh -ex

rm -rf site-out

mkdir -p site-out

rsync -avz src/site/resources/ site-out/
