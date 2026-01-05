#!/bin/bash
#
# Script For Building Android arm64 Kernel.
#

# Setup colors
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# Cleanup
echo -e "$green << cleanup >> \n $white"
rm -rf out zip error.log

# Device Configuration
DEVICE="Redmi Note 10 Pro (sweet/in)"
KERNEL_NAME="TENSEI-KERNEL-BUILD"
CODENAME="SWEET"
DEFCONFIG_DEVICE="sweet_defconfig"

# Build Environment
AnyKernel="https://github.com/pure-soul-kk/AnyKernel3.git"
AnyKernelbranch="master"
HOSST="Power-Station"
USEER="Kernel-Dev"

# Telegram setup
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
    -d "parse_mode=Markdown" \
    -d text="$1"
}

tg_post_build() {
    SHA256CHECK=$(sha256sum "$1" | cut -d' ' -f1)
    BUILD_DATE=$(date +'%d %b %Y | %H:%M UTC')
    
    # Custom Formatted Caption
    CAPTION="*Kernel Build Completed*

*Device* : $DEVICE
*Kernel* : $KERNEL_NAME-BUILD

*Android support* : 11 | 12 | 13 | 14 | 15 | 16

*Build date* : $BUILD_DATE
*Time Took* : $(($Diff / 60)) minutes and $(($Diff % 60)) seconds

build finished in $(($Diff / 60)):$(($Diff % 60)) | *SHA256 Checksum :*
\`$SHA256CHECK\`"

    curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
    -F chat_id="$CHATID" \
    -F "parse_mode=Markdown" \
    -F caption="$CAPTION"
}

tg_error() {
    curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
    -F chat_id="$CHATID" \
    -F "parse_mode=Markdown" \
    -F caption="❌ *Build Failed for $CODENAME*! Check error.log"
}

# Clang Setup
echo -e "$green << cloning clang >> \n $white"
if [ ! -d "$HOME/clang" ]; then
    git clone --depth=1 -b 15.0 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git "$HOME"/clang
fi
export PATH="$HOME/clang/bin:$PATH"

build_kernel() {
    Start=$(date +"%s")
    make -j$(nproc --all) O=out \
                              ARCH=arm64 \
                              LLVM=1 \
                              LLVM_IAS=1 \
                              AR=llvm-ar \
                              NM=llvm-nm \
                              LD=ld.lld \
                              OBJCOPY=llvm-objcopy \
                              OBJDUMP=llvm-objdump \
                              STRIP=llvm-strip \
                              CC=clang \
                              CLANG_TRIPLE=aarch64-linux-gnu- \
                              CROSS_COMPILE=aarch64-linux-android- \
                              CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee error.log
    End=$(date +"%s")
    Diff=$(($End - $Start))
}

# Start Build Process
echo -e "$green << doing pre-compilation process >> \n $white"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="$HOSST"
export KBUILD_BUILD_USER="$USEER"

mkdir -p out
make clean && make mrproper
make "$DEFCONFIG_DEVICE" O=out

tg_post_msg "🚀 *Successful triggered Compiling kernel for $DEVICE*"

build_kernel || error=true

export IMG="$PWD"/out/arch/arm64/boot/Image.gz
export dtbo="$PWD"/out/arch/arm64/boot/dtbo.img
export dtb="$PWD"/out/arch/arm64/boot/dtb.img

if [ -f "$IMG" ]; then
    echo -e "$green << Build completed >> \n $white"
    echo -e "$green << cloning AnyKernel >> \n $white"
    git clone --depth=1 "$AnyKernel" --single-branch -b "$AnyKernelbranch" zip
    cp "$IMG" zip/
    [ -f "$dtbo" ] && cp "$dtbo" zip/
    [ -f "$dtb" ] && cp "$dtb" zip/
    
    cd zip
    ZIP_NAME="${KERNEL_NAME}-${CODENAME}-$(date '+%Y%m%d-%H%M').zip"
    zip -r9 "$ZIP_NAME" * -x .git README.md LICENSE
    
    tg_post_build "$ZIP_NAME"
    cd ..
    rm -rf out zip error.log
else
    echo -e "$red << Build Failed >> \n $white"
    tg_error "error.log"
    exit 1
fi
