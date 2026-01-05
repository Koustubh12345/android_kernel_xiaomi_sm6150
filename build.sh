#!/bin/bash

# ================= CONFIG =================
DEVICE="Redmi Note 10 Pro"
CODENAME="sweet"
KERNEL_NAME="TENSEI-KERNEL-BUILD"
DEFCONFIG="sweet_defconfig"
ANYKERNEL_REPO="https://github.com/pure-soul-kk/AnyKernel3.git"
ANYKERNEL_BRANCH="master"
KERNEL_TAG="v1.0"

HOST="sleeping-bag"
USER_NAME="tenseichad"

# Telegram
BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

# ================= TELEGRAM HELPERS =================
tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHATID" \
        -d parse_mode=Markdown \
        --data-binary text="$1"
}

tg_post_build() {
    curl -s -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$CHATID" \
        -F parse_mode=Markdown \
        --data-binary caption="$2"
}

# ================= CLEANUP =================
rm -rf out zip error.log clang

# ================= TOOLCHAIN =================
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
tg_post_msg $'> *Build Triggered*\n'\
$'> Device  : '"$DEVICE"' ('"$CODENAME"$')\n'\
$'> Kernel  : '"$KERNEL_NAME"'\n'\
$'> User    : '"$USER_NAME"

# ================= BUILD =================
Build_Start=$(date +%s)
Start_Date=$(date +"%d %b %Y | %H:%M %Z")

mkdir -p out
make clean && make mrproper
make O=out "$DEFCONFIG"

make -j$(nproc --all) O=out \
    ARCH=arm64 \
    LLVM=1 LLVM_IAS=1 \
    CC=clang \
    AR=llvm-ar NM=llvm-nm LD=ld.lld \
    OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-androideabi- \
    2>&1 | tee error.log

Build_End=$(date +%s)
End_Date=$(date +"%d %b %Y | %H:%M %Z")
Diff=$((Build_End - Build_Start))

# ================= OUTPUT CHECK =================
IMG="$PWD/out/arch/arm64/boot/Image.gz"
DTBO="$PWD/out/arch/arm64/boot/dtbo.img"
DTB="$PWD/out/arch/arm64/boot/dtb.img"

if [[ ! -f "$IMG" ]]; then
    tg_post_msg $'*Kernel Build Failed*\n\n'\
    $'> Device : '"$DEVICE"'\n'\
    $'> Status : FAILED'
    tg_post_build error.log "Build failed log"
    exit 1
fi

# ================= PACKAGING =================
git clone --depth=1 -b "$ANYKERNEL_BRANCH" "$ANYKERNEL_REPO" zip
cp "$IMG" "$DTBO" "$DTB" zip/
cd zip || exit 1

ZIP_NAME="${KERNEL_NAME}-${KERNEL_TAG}-${CODENAME}-$(date +%Y%m%d).zip"
zip -r9 "$ZIP_NAME" . -x .git README.md LICENSE

SHA256=$(sha256sum "$ZIP_NAME" | cut -d' ' -f1)

# =================TELEGRAM OUTPUT =================
CAPTION=$'*Kernel Build Completed*\n\n'\
$'> Device   : '"$DEVICE"' ('"$CODENAME"$')\n'\
$'> Kernel   : '"$KERNEL_NAME"'\n'\
$'> Android  : 11 | 12 | 13 | 14 | 15 | 16\n\n'\
$'> Start    : '"$Start_Date"$'\n'\
$'> End      : '"$End_Date"$'\n'\
$'> Time     : '$((Diff / 60))' minutes\n\n'\
$'> Output   : Image.gz-dtb\n'\
$'> DTBO     : dtbo.img\n\n'\
$'> Status   : SUCCESS\n\n'\
$'> SHA256   : `'"$SHA256"'`'

tg_post_build "$ZIP_NAME" "$CAPTION"
