#!/bin/bash

rm -rf ffmpeg
mkdir -p ./ffmpeg

cd ../../ffmpeg
make clean

echo $(pwd)
emconfigure ./configure --cc="emcc" --cxx="em++" --ar="emar" --nm="emnm" --prefix=$(pwd)/../wasm-test/decoder/ffmpeg \
                        --enable-cross-compile --target-os=none --arch=x86_32 --cpu=generic \
                        --disable-avformat --disable-avdevice --disable-swresample --disable-avfilter \
                        --disable-programs --disable-debug --disable-doc \
                        --disable-everything --disable-asm --disable-postproc \
                        --enable-decoder=hevc --enable-parser=hevc \
                        --enable-decoder=h264 --enable-parser=h264 \
                        --enable-gpl --enable-version3 --disable-x86asm --disable-postproc

make
make install