#!/bin/bash

# ================= CONFIG =================
DEVICE="Redmi Note 10 Pro"
CODENAME="sweet"
KERNEL_NAME="TENSEI-KERNEL"
DEFCONFIG="sweet_defconfig"
ANYKERNEL_REPO="https://github.com/pure-soul-kk/AnyKernel3.git"
ANYKERNEL_BRANCH="master"
KERNEL_TAG="v1.0"

HOST="sleeping-bag"
USER_NAME="tenseichad"

# Telegram URLs
BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

# ================= TELEGRAM HELPERS =================
tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHATID" \
        -d parse_mode=Markdown \
        -d text="$1"
}

tg_post_build() {
    curl -s -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$CHATID" \
        -F parse_mode=Markdown \
        -F caption="$2"
}

# ================= CLEANUP =================
rm -rf out zip error.log clang

# ================= TOOLCHAIN =================
echo "Cloning Clang..."
git clone --depth=1 -b 15.0 \
https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git \
"$HOME/clang"

export PATH="$HOME/clang/bin:$PATH"

# ================= ENV =================
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="$HOST"
export KBUILD_BUILD_USER="$USER_NAME"

# ================= BUILD TRIGGER =================
START_DATE=$(date +"%d %b %Y | %H:%M %Z")
BUILD_START=$(date +%s)

tg_post_msg "🔨 *Build Triggered*
*Device:* $DEVICE ($CODENAME)
*Kernel:* $KERNEL_NAME
*User:* $USER_NAME"

# ================= BUILD =================
mkdir -p out
make clean && make mrproper
make O=out "$DEFCONFIG"

# FIX: Added CLANG_TRIPLE to resolve your error log
make -j$(nproc --all) O=out \
    ARCH=arm64 \
    LLVM=1 LLVM_IAS=1 \
    CC=clang \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    AR=llvm-ar NM=llvm-nm LD=ld.lld \
    OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    2>&1 | tee error.log

BUILD_END=$(date +%s)
END_DATE=$(date +"%d %b %Y | %H:%M %Z")
DIFF=$((BUILD_END - BUILD_START))

# ================= OUTPUT CHECK =================
IMG="$PWD/out/arch/arm64/boot/Image.gz"
DTBO="$PWD/out/arch/arm64/boot/dtbo.img"
DTB="$PWD/out/arch/arm64/boot/dtb.img"

if [[ ! -f "$IMG" ]]; then
    tg_post_msg "❌ *Kernel Build Failed*
*Device:* $DEVICE
*Status:* FAILED"
    tg_post_build "error.log" "Build failed log"
    exit 1
fi

# ================= PACKAGING =================
git clone --depth=1 -b "$ANYKERNEL_BRANCH" "$ANYKERNEL_REPO" zip
cp "$IMG" "$DTBO" "$DTB" zip/
cd zip || exit 1

ZIP_NAME="${KERNEL_NAME}-${KERNEL_TAG}-${CODENAME}-$(date +%Y%m%d).zip"
zip -r9 "$ZIP_NAME" . -x .git README.md LICENSE

SHA256=$(sha256sum "$ZIP_NAME" | cut -d' ' -f1)

# ================= TELEGRAM OUTPUT =================
CAPTION="✅ *Kernel Build Completed*

*Device:* $DEVICE ($CODENAME)
*Kernel:* $KERNEL_NAME

*Android Support:* 11 | 12 | 13 | 14 | 15 | 16

*Start:* $START_DATE
*End:* $END_DATE
*Duration:* $((DIFF / 60)) minutes

*Output:* Image.gz-dtb
*DTBO:* dtbo.img

*Status:* SUCCESS

*SHA256:* \`$SHA256\`"

tg_post_build "$ZIP_NAME" "$CAPTION"
