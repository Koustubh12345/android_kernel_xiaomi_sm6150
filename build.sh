#!/bin/bash

# --- Config ---
DEVICE="REDMI NOTE 10 PRO"
CODENAME="SWEET"
KERNEL_NAME="VANTOM_KERNEL-OSS-TENSEI-BUILD"
DEFCONFIG="sweet_defconfig"
ANYKERNEL_REPO="https://github.com/pure-soul-kk/AnyKernel3.git"
ANYKERNEL_BRANCH="master"
HOSST="sleeping-bag"
USEER="puresoulkk"

# --- Telegram Setup ---
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
    -d "parse_mode=Markdown" \
    -d text="$1"
}

tg_post_build() {
    local file="$1"
    local caption="$2"
    sha=$(sha256sum "$file" | cut -d' ' -f1)
    curl -s -F document=@"$file" "$BOT_BUILD_URL" \
    -F chat_id="$CHATID" \
    -F "parse_mode=Markdown" \
    -F caption="$caption%0A%0ASHA256: \`$sha\`"
}

# --- Cleanup ---
rm -rf out zip error.log

# --- Toolchain ---
echo "Cloning Clang..."
git clone --depth=1 -b 15.0 https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git "$HOME"/clang
export PATH="$HOME/clang/bin:$PATH"
KBUILD_COMPILER_STRING=$("$HOME"/clang/bin/clang --version | head -n 1)

# --- Build Logic ---
build_kernel() {
    Start=$(date +"%s")
    
    make -j$(nproc --all) O=out \
        ARCH=arm64 \
        LLVM=1 LLVM_IAS=1 \
        AR=llvm-ar NM=llvm-nm LD=ld.lld \
        OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
        CC=clang CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee error.log

    End=$(date +"%s")
    Diff=$(($End - $Start))
}

# --- Preparation ---
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST="$HOSST"
export KBUILD_BUILD_USER="$USEER"

mkdir -p out
make clean && make mrproper
make "$DEFCONFIG" O=out

# --- Execution ---
tg_post_msg "BUILD STARTED%0ADevice: $DEVICE%0ACodename: $CODENAME%0ATag: $KERNEL_TAG"

build_kernel

# --- Verification & Packaging ---
IMG="$PWD"/out/arch/arm64/boot/Image.gz
DTBO="$PWD"/out/arch/arm64/boot/dtbo.img
DTB="$PWD"/out/arch/arm64/boot/dtb.img

if [ -f "$IMG" ]; then
    echo "Build Success"
    git clone --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" zip
    cp "$IMG" "$DTBO" "$DTB" zip/
    cd zip
    ZIP_NAME="${KERNEL_NAME}-${KERNEL_TAG}-${CODENAME}-$(date '+%Y%m%d-%H%M').zip"
    zip -r9 "$ZIP_NAME" * -x .git README.md LICENSE *placeholder
    
    CAPTION="BUILD SUCCESS%0ADevice: $DEVICE%0ATime: $(($Diff / 60))m $(($Diff % 60))s"
    tg_post_build "$ZIP_NAME" "$CAPTION"
    cd ..
else
    echo "Build Failed"
    tg_post_msg "BUILD FAILED%0ADevice: $DEVICE%0ACheck error.log below."
    tg_post_build "error.log" "Build Log: $DEVICE"
    exit 1
fi
