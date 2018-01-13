#!/bin/sh

#
# Locally deploy the play executable to the dist directory.
#
# Prerequisites. Distribution package built in target/universal folder. See package.sh.
#
# The distribution is deployed to dist/scala-server-1.0
#

# TODO. Input parameter for deployDir.
deployDir=dist
projectDir=`pwd`
outDir=${projectDir}/target/universal

echo "deploying board game scala server from ${outDir} to ${deployDir}"
mkdir -p $deployDir
cd $deployDir
rm -rf scala-server-1.0/
unzip $outDir/scala-server-1.0.zip
cd scala-server-1.0
mkdir dict
cp ${projectDir}/dict/en-words.txt dict/en-words.txt

echo "deployed"
