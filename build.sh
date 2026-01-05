#!/bin/bash

# --- Config ---
DEVICE="Redmi Note 10 Pro"
CODENAME="sweet"
KERNEL_NAME="TENSEI-KERNEL-BUILD"
DEFCONFIG="sweet_defconfig"
ANYKERNEL_REPO="https://github.com/pure-soul-kk/AnyKernel3.git"
ANYKERNEL_BRANCH="master"
HOSST="sleeping-bag"
USEER="tenseichad"

# --- Telegram Setup ---
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

# Professional Formatting helper
tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" -d chat_id="$CHATID" \
    -d "parse_mode=Markdown" \
    -d text="$1"
}

tg_post_build() {
    local file="$1"
    local caption="$2"
    curl -s -F document=@"$file" "$BOT_BUILD_URL" \
    -F chat_id="$CHATID" \
    -F "parse_mode=Markdown" \
    -F caption="$caption"
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
    Build_Start=$(date +"%s")
    Start_Date=$(date +"%d %b %Y | %H:%M %Z")
    
    make -j$(nproc --all) O=out \
        ARCH=arm64 \
        LLVM=1 LLVM_IAS=1 \
        AR=llvm-ar NM=llvm-nm LD=ld.lld \
        OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
        CC=clang CLANG_TRIPLE=aarch64-linux-gnu- \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-androideabi- 2>&1 | tee error.log

    Build_End=$(date +"%s")
    End_Date=$(date +"%d %b %Y | %H:%M %Z")
    Diff=$(($Build_End - $Build_Start))
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
tg_post_msg "*Build Triggered*%0A%0ADevice: $DEVICE ($CODENAME)%0AVersion: $KERNEL_TAG%0AUser: $USEER"

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
    ZIP_NAME="${KERNEL_NAME}-${KERNEL_TAG}-${CODENAME}-$(date '+%Y%m%d').zip"
    zip -r9 "$ZIP_NAME" * -x .git README.md LICENSE *placeholder
    
    # Clean Reference Output Format
    CAPTION="*Kernel Build Completed*%0A%0A*Device*: $DEVICE ($CODENAME)%0A*Kernel*: $KERNEL_NAME%0A%0A*Android*: 11 | 12 | 13 | 14 | 15%0A%0A*Start*: $Start_Date%0A*End*: $End_Date%0A*Time Took*: $(($Diff / 60)) minutes%0A%0A*Output*: Image.gz-dtb%0A*DTBO*: dtbo.img%0A%0A*Status*: SUCCESS%0A%0A*SHA256*: \`$(sha256sum "$ZIP_NAME" | cut -d' ' -f1)\`"
    
    tg_post_build "$ZIP_NAME" "$CAPTION"
    cd ..
else
    echo "Build Failed"
    tg_post_msg "*Kernel Build Failed*%0A%0ADevice: $DEVICE%0AStatus: FAILED%0A%0ACheck the error log below."
    tg_post_build "error.log" "Error log for $DEVICE build"
    exit 1
fi
