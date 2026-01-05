#!/bin/bash
#
# Script For Building Android arm64 Kernel (Optimized for SWEET)
# Copyright (C) 2021-2023 itsshashanksp <9945shashank@gmail.com>
#

# Setup colors
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# 1. Cleanup
echo -e "$green << cleanup >> \n $white"
rm -rf out zip error.log

# 2. Hardcoded Sweet Configuration
DEVICE="REDMI NOTE 10 PRO (OSS)"
KERNEL_NAME="TENSEI_KERNEL-MIUI-HYPER"
CODENAME="SWEET"
DEFCONFIG_DEVICE="sweet_defconfig"
AnyKernel="https://github.com/pure-soul-kk/AnyKernel3.git"
AnyKernelbranch="master"
HOSST="sleeping-bag"
USEER="puresoulkk"

# 3. Export Build Details
export KBUILD_BUILD_USER=$USEER
export KBUILD_BUILD_HOST=$HOSST
export ARCH=arm64
export SUBARCH=arm64

# 4. Telegram setup
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHAT_ID" \
    -d "parse_mode=Markdown" \
    -d text="$1"
}

# 5. Start Build Process
echo -e "$yellow >> Starting build for $DEVICE ($CODENAME)... $white"

# Create output directory
mkdir -p out

# Build Command
make -j$(nproc --all) O=out ARCH=arm64 $DEFCONFIG_DEVICE

echo -e "$yellow >> Compiling Kernel... $white"
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                      2>&1 | tee error.log

# 6. Check if build succeeded
if ! [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    echo -e "$red << Build Failed! >> $white"
    tg_post_msg "❌ Build failed for $CODENAME"
    exit 1
fi

# 7. Zipping with AnyKernel
echo -e "$green << Zipping Kernel >> $white"
git clone --depth=1 "$AnyKernel" -b "$AnyKernelbranch" zip
cp out/arch/arm64/boot/Image.gz-dtb zip/
cd zip
zip -r9 "../${KERNEL_NAME}-${CODENAME}.zip" * -x .git README.md
cd ..

echo -e "$green << Build Completed Successfully! >> $white"
