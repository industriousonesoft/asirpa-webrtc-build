#!/bin/bash

echo "$#"

if [ $# -lt 1 ]; then
	echo "$0 <webrtc source dir>"
	exit 1
fi

#webrtc source dir
SOURCE_DIR=$1

echo  "$SOURCE_DIR/webrtc"

if [ ! -d "$SOURCE_DIR/webrtc" ];then 
	echo "webrtc source dir not found"
	exit 1
fi

set -ex

cd $(dirname $0)

SCRIPT_DIR=$(pwd)
PLATFORM_NAME=macos
BUILD_DIR="${SCRIPT_DIR}/_build/${PLATFORM_NAME}"

#read wevrtc versions
source $SCRIPT_DIR/VERSION

pushd $SOURCE_DIR/webrtc/src

	#rtc_use_h264=false：webrtc不内建h264编解码器（软解码）, 在macos可基于video_toolbox自行创建硬编解码器，在通过参数传入
	#use_rtti=true：build with C++ RTTI enabled. For more detail: /src/build/config/compiler/BUILD.gn
	gn gen $BUILD_DIR/webrtc --args='target_os="mac" is_debug=false rtc_include_tests=false rtc_build_examples=false rtc_use_h264=false is_component_build=false use_rtti=true libcxx_abi_unstable=false' 

	#Target to build all the WebRTC production code, for more detail: /src/BUILD.gn: rtc_static_library("webrtc")
	ninja -C $BUILD_DIR/webrtc
	#编译指定的tartgets（以及它们所依赖的targets）
	#native_api & default_codec_factory_objc: macos native api, for more detail: /src/sdk/BUILD.gn
	ninja -C $BUILD_DIR/webrtc \
		native_api \
		default_codec_factory_objc \
		opus_audio_encoder_factory \
		opus_audio_decoder_factory \
		builtin_audio_encoder_factory \
		builtin_audio_decoder_factory \
		builtin_video_encoder_factory \
		builtin_video_decoder_factory 

	python tools_webrtc/libs/generate_licenses.py --target :webrtc $BUILD_DIR/webrtc $BUILD_DIR/webrtc
popd

pushd $BUILD_DIR/webrtc/obj
	#将构建的对象文件打包成一个静态库
	#-r: Replace or add the specified files to the archive
	#-c: creates the archive silently
	/usr/bin/ar -rc $BUILD_DIR/webrtc/libwebrtc.a `find . -name '*.o'`
popd

./scripts/package_webrtc.sh $PLATFORM_NAME $SOURCE_DIR $BUILD_DIR $SCRIPT_DIR/VERSION





