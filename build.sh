#!/bin/bash

# ================= CONFIG =================
DEVICE="Redmi Note 10 Pro"
CODENAME="sweet"
REGION="in"
KERNEL_NAME="TENSEI-KERNEL-BUILD"
DEFCONFIG="sweet_defconfig"

ANYKERNEL_REPO="https://github.com/pure-soul-kk/AnyKernel3.git"
ANYKERNEL_BRANCH="master"

HOST="sleeping-bag"
USER="puresoulkk"

ANDROID_SUPPORT="11 | 12 | 13 | 14 | 15 | 16"

# Telegram
BOT_MSG_URL="https://api.telegram.org/bot${API_BOT}/sendMessage"
BOT_FILE_URL="https://api.telegram.org/bot${API_BOT}/sendDocument"

# ================= FUNCTIONS =================
tg_msg() {
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHATID" \
        -d parse_mode="Markdown" \
        --data-urlencode text="$1"
}

tg_file() {
    local file="$1"
    local caption="$2"
    curl -s -F document=@"$file" \
        -F chat_id="$CHATID" \
        -F parse_mode="Markdown" \
        --data-urlencode caption="$caption" \
        "$BOT_FILE_URL"
}

human_time() {
    local T=$1
    printf "%d minutes and %d seconds" $((T/60)) $((T%60))
}

# ================= CLEAN =================
rm -rf out zip error.log

# ================= TOOLCHAIN =================
git clone --depth=1 -b 15.0 \
https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git \
"$HOME/clang"

export PATH="$HOME/clang/bin:$PATH"

# ================= ENV =================
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="$HOST"
export KBUILD_BUILD_USER="$USER"

# ================= START =================
BUILD_START_EPOCH=$(date +%s)
BUILD_START_DATE=$(date +"%d %b %Y | %H:%M %Z")

tg_msg "*Kernel Build Started*

Device : $DEVICE ($CODENAME/$REGION)
Kernel : $KERNEL_NAME
Build  : $BUILD_START_DATE"

mkdir -p out
make clean && make mrproper
make "$DEFCONFIG" O=out

make -j$(nproc --all) \
O=out ARCH=arm64 \
LLVM=1 LLVM_IAS=1 \
CC=clang \
CROSS_COMPILE=aarch64-linux-android- \
CROSS_COMPILE_ARM32=arm-linux-androideabi- \
2>&1 | tee error.log

# ================= END =================
BUILD_END_EPOCH=$(date +%s)
BUILD_END_DATE=$(date +"%d %b %Y | %H:%M %Z")
BUILD_DIFF=$((BUILD_END_EPOCH - BUILD_START_EPOCH))
BUILD_TIME=$(human_time "$BUILD_DIFF")

IMG="out/arch/arm64/boot/Image.gz"
DTBO="out/arch/arm64/boot/dtbo.img"
DTB="out/arch/arm64/boot/dtb.img"

if [[ ! -f "$IMG" ]]; then
    tg_msg "*Kernel Build Failed*

Device : $DEVICE
Check error.log"
    tg_file "error.log" "Build log"
    exit 1
fi

# ================= PACKAGE =================
git clone --depth=1 -b "$ANYKERNEL_BRANCH" "$ANYKERNEL_REPO" zip
cp "$IMG" "$DTBO" "$DTB" zip/
cd zip

ZIP_NAME="${KERNEL_NAME}-${CODENAME}-$(date '+%Y%m%d-%H%M').zip"
zip -r9 "$ZIP_NAME" . -x .git README.md LICENSE "*placeholder*"

SHA256=$(sha256sum "$ZIP_NAME" | awk '{print $1}')

cd ..

# ================= FINAL MESSAGE =================
CAPTION="*Kernel Build Completed*

Device    : $DEVICE ($CODENAME/$REGION)
Kernel    : $KERNEL_NAME

Android support : $ANDROID_SUPPORT

Build date : $BUILD_START_DATE
Time Took : $BUILD_TIME

build finished in $(printf "%02d:%02d" $((BUILD_DIFF/60)) $((BUILD_DIFF%60))) | SHA256 Checksum : \`$SHA256\`"

tg_file "zip/$ZIP_NAME" "$CAPTION"
