#!/bin/sh

# see http://stackoverflow.com/a/3915420/318790
function realpath { echo $(cd $(dirname "$1"); pwd)/$(basename "$1"); }
__FILE__=`realpath "$0"`
__DIR__=`dirname "${__FILE__}"`

# download
function download() {
    "${__DIR__}/download.sh" "$1" "$2" #--no-cache
}

BASE_DIR="$1"
PJSIP_URL="http://www.pjsip.org/release/2.5.1/pjproject-2.5.1.tar.bz2"
PJSIP_DIR="$1/src"
PJSIP_CONFIG_PATH="${PJSIP_DIR}/pjlib/include/pj/config_site.h"

LIB_PATHS=("pjlib/lib" \
           "pjlib-util/lib" \
           "pjmedia/lib" \
           "pjnath/lib" \
           "pjsip/lib" \
           "third_party/lib")

OPENSSL_PREFIX=
OPENH264_PREFIX=
while [ "$#" -gt 0 ]; do
    case $1 in
        --with-openssl)
            if [ "$#" -gt 1 ]; then
                OPENSSL_PREFIX=$2
                shift 2
                continue
            else
                echo 'ERROR: Must specify a non-empty "--with-openssl PREFIX" argument.' >&2
                exit 1
            fi
            ;;
        --with-openh264)
            if [ "$#" -gt 1 ]; then
                OPENH264_PREFIX=$2
                shift 2
                continue
            else
                echo 'ERROR: Must specify a non-empty "--with-openh264 PREFIX" argument.' >&2
                exit 1
            fi
            ;;
    esac

    shift
done

function remove_config_site () {
    if [ -f "${PJSIP_CONFIG_PATH}" ]; then
        rm "${PJSIP_CONFIG_PATH}"
    fi
}

function config_site() {
    #SOURCE_DIR=$1
    #PJSIP_CONFIG_PATH="${SOURCE_DIR}/pjlib/include/pj/config_site.h"
    HAS_VIDEO=

    echo "Creating config.h..."

    remove_config_site
#    if [ -f "${PJSIP_CONFIG_PATH}" ]; then
#        rm "${PJSIP_CONFIG_PATH}"
#    fi

    echo "#define PJ_CONFIG_IPHONE 1" >> "${PJSIP_CONFIG_PATH}"
    if [[ ${OPENH264_PREFIX} ]]; then
        echo "#define PJMEDIA_HAS_OPENH264_CODEC 1" >> "${PJSIP_CONFIG_PATH}"
        HAS_VIDEO=1
    fi
    if [[ ${HAS_VIDEO} ]]; then
        echo "#define PJMEDIA_HAS_VIDEO 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#define PJMEDIA_VIDEO_DEV_HAS_OPENGL_ES 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#define PJMEDIA_VIDEO_DEV_HAS_IOS_OPENGL 1" >> "${PJSIP_CONFIG_PATH}"
        echo "#include <OpenGLES/ES3/glext.h>" >> "${PJSIP_CONFIG_PATH}"
    fi
    echo "#include <pj/config_site_sample.h>" >> "${PJSIP_CONFIG_PATH}"
}

function copy_libs () {
    ARCH=${1}

    for SRC_DIR in ${LIB_PATHS[*]}; do
        SRC_DIR="${PJSIP_DIR}/${SRC_DIR}"
        DST_DIR="${SRC_DIR}-${ARCH}"
        if [ -d "${DST_DIR}" ]; then
            rm -rf "${DST_DIR}"
        fi
        #echo "${SRC_DIR}" "${DST_DIR}"
        cp -R "${SRC_DIR}" "${DST_DIR}"

    done
}

function remove_libs () {
    ARCH=${1}

    for LIB_DIR in ${LIB_PATHS[*]}; do
        LIB_DIR="${PJSIP_DIR}/${LIB_DIR}"
        LIB_ARCH_DIR="${LIB_DIR}-${ARCH}"
        if [ -d "${LIB_ARCH_DIR}" ]; then
            rm -rf "${LIB_ARCH_DIR}"
        fi
    done    
}

function _build() {
    pushd . > /dev/null
    cd ${PJSIP_DIR}

    ARCH=$1
    LOG=${BASE_DIR}/${ARCH}.log

    # configure
    CONFIGURE="./configure-iphone"
    if [[ ${OPENSSL_PREFIX} ]]; then
        CONFIGURE="${CONFIGURE} --with-ssl=${OPENSSL_PREFIX}"
    fi
    if [[ ${OPENH264_PREFIX} ]]; then
        CONFIGURE="${CONFIGURE} --with-openh264=${OPENH264_PREFIX}"
    fi

    # flags
    if [[ ! ${CFLAGS} ]]; then
        export CFLAGS=
    fi
    if [[ ! ${LDFLAGS} ]]; then
        export LDFLAGS=
    fi
    if [[ ${OPENSSL_PREFIX} ]]; then
        export CFLAGS="${CFLAGS} -I${OPENSSL_PREFIX}/include"
        export LDFLAGS="${LDFLAGS} -L${OPENSSL_PREFIX}/lib"
    fi
    if [[ ${OPENH264_PREFIX} ]]; then
        export CFLAGS="${CFLAGS} -I${OPENH264_PREFIX}/include"
        export LDFLAGS="${LDFLAGS} -L${OPENH264_PREFIX}/lib"
    fi
    export LDFLAGS="${LDFLAGS} -lstdc++"

    echo "Building for ${ARCH}..."

    make distclean > ${LOG} 2>&1
    ARCH="-arch ${ARCH}" ${CONFIGURE} >> ${LOG} 2>&1
    make dep >> ${LOG} 2>&1
    make clean >> ${LOG}
    make >> ${LOG} 2>&1

    copy_libs ${ARCH}
}

function armv7() {
    export CFLAGS=
    export LDFLAGS=
    _build "armv7"
}
function armv7s() {
    export CFLAGS=
    export LDFLAGS=
    _build "armv7s"
}
function arm64() {
    export CFLAGS=
    export LDFLAGS=
    _build "arm64"
}
function i386() {
    export DEVPATH="`xcrun -sdk iphonesimulator --show-sdk-platform-path`/Developer"
    export CFLAGS="-O2 -m32 -mios-simulator-version-min=7.0"
    export LDFLAGS="-O2 -m32 -mios-simulator-version-min=7.0"
    _build "i386"
}
function x86_64() {
    export DEVPATH="`xcrun -sdk iphonesimulator --show-sdk-platform-path`/Developer"
    export CFLAGS="-O2 -m32 -mios-simulator-version-min=7.0"
    export LDFLAGS="-O2 -m32 -mios-simulator-version-min=7.0"
    _build "x86_64"
}

function lipo() {
    echo "Lipo libs..."

    TMP=`mktemp -t lipo`
    while [ $# -gt 0 ]; do
        ARCH=$1
        for LIB_DIR in ${LIB_PATHS[*]}; do
            ARGS=""
            DST_DIR="${PJSIP_DIR}/${LIB_DIR}"
            SRC_DIR="${DST_DIR}-${ARCH}"

            for FILE in `ls -l1 "${SRC_DIR}"`; do
                OPTIONS="-arch ${ARCH} ${SRC_DIR}/${FILE}"
                EXISTS=`cat "${TMP}" | grep "${FILE}"`
                if [[ ${EXISTS} ]]; then
                    SED_SRC="${FILE}$"
                    SED_SRC="${SED_SRC//\//\\/}"
                    SED_DST="${FILE} ${OPTIONS}"
                    SED_DST="${SED_DST//\//\\/}"
                    echo "${SED_SRC}/${SED_DST}"
                    sed -i.bak "s/${SED_SRC}/${SED_DST}/" "${TMP}"
                    rm "${TMP}.bak"

                else
                    echo "${OPTIONS}" >> "${TMP}"
                fi
            done
        done
        shift
    done

    cat ${TMP}
    while read LINE; do
        COMPONENTS=($LINE)
        LAST=${COMPONENTS[@]:(-1)}
        PREFIX=$(dirname $(dirname "${LAST}"))
        OUTPUT="${PREFIX}/lib/`basename ${LAST}`"
        xcrun -sdk iphoneos lipo ${LINE} -create -output ${OUTPUT}
    done < "${TMP}"
}

function build_all() {
    armv7 && armv7s && arm64 && i386 && x86_64
}

function remove_all_libs {
    remove_libs armv7
    remove_libs armv7s
    remove_libs arm64
    remove_libs i386
    remove_libs x86_64

    for LIB_DIR in ${LIB_PATHS[*]}; do
        LIB_DIR="${PJSIP_DIR}/${LIB_DIR}"
        if [ -d "${LIB_DIR}" ]; then
            rm -rf "${LIB_DIR}"
        fi
    done
}

function lipo_libs() {

    echo "Lipo libs..."

    if [ -d ${BASE_DIR}/lib/ ]; then
        rm -rf ${BASE_DIR}/lib/
    fi
    if [ ! -d ${BASE_DIR}/lib/ ]; then
        mkdir ${BASE_DIR}/lib/
    fi

    # pjlib
    PJLIB_OUTPUT_DIR="${BASE_DIR}/lib/pjlib/lib"

    if [ ! -d ${PJLIB_OUTPUT_DIR} ]; then
        mkdir -p ${PJLIB_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjlib/lib-armv7/libpj-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjlib/lib-armv7s/libpj-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjlib/lib-arm64/libpj-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjlib/lib-i386/libpj-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjlib/lib-x86_64/libpj-x86_64-apple-darwin_ios.a \
                             -create -output ${PJLIB_OUTPUT_DIR}/libpj-apple-darwin_ios.a

    # pjlib-util
    PJLIB_UTIL_OUTPUT_DIR="${BASE_DIR}/lib/pjlib-util/lib"

    if [ ! -d ${PJLIB_UTIL_OUTPUT_DIR} ]; then
        mkdir -p ${PJLIB_UTIL_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjlib-util/lib-armv7/libpjlib-util-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjlib-util/lib-armv7s/libpjlib-util-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjlib-util/lib-arm64/libpjlib-util-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjlib-util/lib-i386/libpjlib-util-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjlib-util/lib-x86_64/libpjlib-util-x86_64-apple-darwin_ios.a \
                             -create -output ${PJLIB_UTIL_OUTPUT_DIR}/libpjlib-util-apple-darwin_ios.a

    # pjnath
    PJNATH_OUTPUT_DIR="${BASE_DIR}/lib/pjnath/lib"

    if [ ! -d ${PJNATH_OUTPUT_DIR} ]; then
        mkdir -p ${PJNATH_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjnath/lib-armv7/libpjnath-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjnath/lib-armv7s/libpjnath-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjnath/lib-arm64/libpjnath-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjnath/lib-i386/libpjnath-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjnath/lib-x86_64/libpjnath-x86_64-apple-darwin_ios.a \
                             -create -output ${PJNATH_OUTPUT_DIR}/libpjnath-apple-darwin_ios.a

    # pjsip
    PJSIP_OUTPUT_DIR="${BASE_DIR}/lib/pjsip/lib"

    if [ ! -d ${PJSIP_OUTPUT_DIR} ]; then
        mkdir -p ${PJSIP_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjsip/lib-armv7/libpjsip-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjsip/lib-armv7s/libpjsip-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjsip/lib-arm64/libpjsip-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjsip/lib-i386/libpjsip-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjsip/lib-x86_64/libpjsip-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_OUTPUT_DIR}/libpjsip-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjsip/lib-armv7/libpjsip-simple-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjsip/lib-armv7s/libpjsip-simple-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjsip/lib-arm64/libpjsip-simple-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjsip/lib-i386/libpjsip-simple-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjsip/lib-x86_64/libpjsip-simple-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_OUTPUT_DIR}/libpjsip-simple-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjsip/lib-armv7/libpjsip-ua-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjsip/lib-armv7s/libpjsip-ua-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjsip/lib-arm64/libpjsip-ua-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjsip/lib-i386/libpjsip-ua-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjsip/lib-x86_64/libpjsip-ua-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_OUTPUT_DIR}/libpjsip-ua-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjsip/lib-armv7/libpjsua-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjsip/lib-armv7s/libpjsua-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjsip/lib-arm64/libpjsua-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjsip/lib-i386/libpjsua-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjsip/lib-x86_64/libpjsua-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_OUTPUT_DIR}/libpjsua-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjsip/lib-armv7/libpjsua2-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjsip/lib-armv7s/libpjsua2-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjsip/lib-arm64/libpjsua2-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjsip/lib-i386/libpjsua2-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjsip/lib-x86_64/libpjsua2-x86_64-apple-darwin_ios.a \
                             -create -output ${PJSIP_OUTPUT_DIR}/libpjsua2-apple-darwin_ios.a


    # pjmedia
    PJMEDIA_OUTPUT_DIR="${BASE_DIR}/lib/pjmedia/lib"

    if [ ! -d ${PJMEDIA_OUTPUT_DIR} ]; then
        mkdir -p ${PJMEDIA_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjmedia/lib-armv7/libpjmedia-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjmedia/lib-armv7s/libpjmedia-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjmedia/lib-arm64/libpjmedia-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjmedia/lib-i386/libpjmedia-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjmedia/lib-x86_64/libpjmedia-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_OUTPUT_DIR}/libpjmedia-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjmedia/lib-armv7/libpjmedia-audiodev-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjmedia/lib-armv7s/libpjmedia-audiodev-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjmedia/lib-arm64/libpjmedia-audiodev-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjmedia/lib-i386/libpjmedia-audiodev-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjmedia/lib-x86_64/libpjmedia-audiodev-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_OUTPUT_DIR}/libpjmedia-audiodev-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjmedia/lib-armv7/libpjmedia-codec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjmedia/lib-armv7s/libpjmedia-codec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjmedia/lib-arm64/libpjmedia-codec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjmedia/lib-i386/libpjmedia-codec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjmedia/lib-x86_64/libpjmedia-codec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_OUTPUT_DIR}/libpjmedia-codec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjmedia/lib-armv7/libpjmedia-videodev-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjmedia/lib-armv7s/libpjmedia-videodev-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjmedia/lib-arm64/libpjmedia-videodev-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjmedia/lib-i386/libpjmedia-videodev-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjmedia/lib-x86_64/libpjmedia-videodev-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_OUTPUT_DIR}/libpjmedia-videodev-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/pjmedia/lib-armv7/libpjsdp-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/pjmedia/lib-armv7s/libpjsdp-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/pjmedia/lib-arm64/libpjsdp-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/pjmedia/lib-i386/libpjsdp-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/pjmedia/lib-x86_64/libpjsdp-x86_64-apple-darwin_ios.a \
                             -create -output ${PJMEDIA_OUTPUT_DIR}/libpjsdp-apple-darwin_ios.a

    # pj_third_party
    PJ_THIRD_PARTY_OUTPUT_DIR="${BASE_DIR}/lib/third_party/lib"

    if [ ! -d ${PJ_THIRD_PARTY_OUTPUT_DIR} ]; then
        mkdir -p ${PJ_THIRD_PARTY_OUTPUT_DIR}
    fi

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/third_party/lib-armv7/libg7221codec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/third_party/lib-armv7s/libg7221codec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/third_party/lib-arm64/libg7221codec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/third_party/lib-i386/libg7221codec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/third_party/lib-x86_64/libg7221codec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_OUTPUT_DIR}/libg7221codec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/third_party/lib-armv7/libgsmcodec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/third_party/lib-armv7s/libgsmcodec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/third_party/lib-arm64/libgsmcodec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/third_party/lib-i386/libgsmcodec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/third_party/lib-x86_64/libgsmcodec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_OUTPUT_DIR}/libgsmcodec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/third_party/lib-armv7/libilbccodec-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/third_party/lib-armv7s/libilbccodec-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/third_party/lib-arm64/libilbccodec-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/third_party/lib-i386/libilbccodec-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/third_party/lib-x86_64/libilbccodec-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_OUTPUT_DIR}/libilbccodec-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/third_party/lib-armv7/libresample-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/third_party/lib-armv7s/libresample-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/third_party/lib-arm64/libresample-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/third_party/lib-i386/libresample-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/third_party/lib-x86_64/libresample-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_OUTPUT_DIR}/libresample-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/third_party/lib-armv7/libspeex-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/third_party/lib-armv7s/libspeex-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/third_party/lib-arm64/libspeex-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/third_party/lib-i386/libspeex-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/third_party/lib-x86_64/libspeex-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_OUTPUT_DIR}/libspeex-apple-darwin_ios.a

    xcrun -sdk iphoneos lipo -arch armv7  ${PJSIP_DIR}/third_party/lib-armv7/libsrtp-armv7-apple-darwin_ios.a \
                             -arch armv7s ${PJSIP_DIR}/third_party/lib-armv7s/libsrtp-armv7s-apple-darwin_ios.a \
                             -arch arm64  ${PJSIP_DIR}/third_party/lib-arm64/libsrtp-arm64-apple-darwin_ios.a \
                             -arch i386   ${PJSIP_DIR}/third_party/lib-i386/libsrtp-i386-apple-darwin_ios.a \
                             -arch x86_64 ${PJSIP_DIR}/third_party/lib-x86_64/libsrtp-x86_64-apple-darwin_ios.a \
                             -create -output ${PJ_THIRD_PARTY_OUTPUT_DIR}/libsrtp-apple-darwin_ios.a

}

function copy_pj_include () {
    PJ_HEADER_DST_BASE_DIR=$1
    PJ_LIB=$2

    PJ_HEADER_SRC_DIR="${PJSIP_DIR}/${PJ_LIB}/include"
    PJ_HEADER_DST_DIR="${PJ_HEADER_DST_BASE_DIR}/${PJ_LIB}"

    if [ ! -d ${PJ_HEADER_DST_DIR} ]; then
        mkdir -p ${PJ_HEADER_DST_DIR}
    fi

    # echo "${PJ_HEADER_SRC_DIR}" "${PJ_HEADER_DST_DIR}"
    cp -R "${PJ_HEADER_SRC_DIR}" "${PJ_HEADER_DST_DIR}"

}

function copy_headers () {

    echo "Copy headers..."

    PJ_HEADER_BASE_DIR="${BASE_DIR}/include"

    if [ -d ${PJ_HEADER_BASE_DIR} ]; then
        rm -rf ${PJ_HEADER_BASE_DIR}
    fi
    if [ ! -d ${PJ_HEADER_BASE_DIR} ]; then
        mkdir ${PJ_HEADER_BASE_DIR}
    fi

    copy_pj_include "${PJ_HEADER_BASE_DIR}" pjsip
    copy_pj_include "${PJ_HEADER_BASE_DIR}" pjlib
    copy_pj_include "${PJ_HEADER_BASE_DIR}" pjlib-util
    copy_pj_include "${PJ_HEADER_BASE_DIR}" pjnath
    copy_pj_include "${PJ_HEADER_BASE_DIR}" pjmedia
}


download "${PJSIP_URL}" "${PJSIP_DIR}"
#config_site "${PJSIP_DIR}"
config_site
build_all
lipo_libs
copy_headers

echo "cleaning up..."
remove_all_libs
remove_config_site
#armv7 && armv7s && arm64 && i386 && x86_64
#armv7 && armv7s
#lipo armv7 armv7s
#lipo armv7 armv7s arm64 i386 x86_64
