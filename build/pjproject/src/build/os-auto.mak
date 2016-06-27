# build/os-auto.mak.  Generated from os-auto.mak.in by configure.

export OS_CFLAGS   := $(CC_DEF)PJ_AUTOCONF=1 -O2 -m32 -mios-simulator-version-min=7.0 -I/Users/tak/Tak/Dev/Projects/beachside/pjsip/build/openssl/include -DPJ_SDK_NAME="\"iPhoneSimulator9.3.sdk\"" -arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator9.3.sdk -DPJ_IS_BIG_ENDIAN=0 -DPJ_IS_LITTLE_ENDIAN=1 -I/Users/tak/Tak/Dev/Projects/beachside/pjsip/build/openssl/include

export OS_CXXFLAGS := $(CC_DEF)PJ_AUTOCONF=1 -O2 -m32 -mios-simulator-version-min=7.0 -I/Users/tak/Tak/Dev/Projects/beachside/pjsip/build/openssl/include -DPJ_SDK_NAME="\"iPhoneSimulator9.3.sdk\"" -arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator9.3.sdk 

export OS_LDFLAGS  := -O2 -m32 -mios-simulator-version-min=7.0 -L/Users/tak/Tak/Dev/Projects/beachside/pjsip/build/openssl/lib -lstdc++ -arch x86_64 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator9.3.sdk -framework AudioToolbox -framework Foundation -L/Users/tak/Tak/Dev/Projects/beachside/pjsip/build/openssl/lib -lm -lpthread  -framework CoreAudio -framework CoreFoundation -framework AudioToolbox -framework CFNetwork -framework UIKit -framework UIKit -framework OpenGLES -framework AVFoundation -framework CoreGraphics -framework QuartzCore -framework CoreVideo -framework CoreMedia -lcrypto -lssl

export OS_SOURCES  := 


