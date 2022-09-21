#!/bin/sh

set -eu

if [ $# -eq 1 ]
then
    BINUTILS_PREFIX="$1"
else
    # check for arm-none-eabi-as in PATH
    if command -v arm-none-eabi-as >/dev/null
    then
        BINUTILS_PREFIX="arm-none-eabi-"
    # check for devkitARM
    elif [ -n "${DEVKITARM:-}" ]
    then
        BINUTILS_PREFIX="$DEVKITARM/bin/arm-none-eabi-"
    # oof
    else
        echo "Please supply a prefix for ARM Binutils (e.g. arm-*-*eabi-), install arm-none-eabi-binutils, or define \$DEVKITARM."
        exit 1
    fi
fi

AS="${AS:-${BINUTILS_PREFIX}as}"
LD="${LD:-${BINUTILS_PREFIX}ld}"
OBJCOPY="${OBJCOPY:-${BINUTILS_PREFIX}objcopy}"
ASFLAGS="${ASFLAGS:- -mcpu=arm7tdmi --no-pad-sections}"
LDFLAGS="${LDFLAGS:- -Ttext=0x08000000 -nostdlib -static}"
OBJCOPY_FLAGS="${OBJCOPY_FLAGS:- -O binary -j .text}"
THUMB_NOP="$(printf '\300\106')"  # c0 46 - Thumb-1 ARMv4 NOP (mov r8, r8)

build()
{
    FILENAME="$1"
    shift
    $AS $ASFLAGS $@ snek.s -o $FILENAME.o
    $LD $LDFLAGS $FILENAME.o -o $FILENAME.elf
    $OBJCOPY $OBJCOPY_FLAGS $FILENAME.elf $FILENAME.gba

    # check for AS putting a NOP to align the file to a multiple of 4 bytes
    if [ "$THUMB_NOP" = $(tail -c 2 $FILENAME.gba) ]
    then
        # kill it with fire
        truncate -s-2 $FILENAME.gba
    fi
    
    printf "%s.gba size: %d bytes\n" $FILENAME $(stat -c%s $FILENAME.gba)
}

get_bytes()
{
    xxd -ps -s $2 -l ${3:-1} $1 | fold -b -w 2
}

checksum()
{
    if command -v xxd >/dev/null
    then
        FILENAME="$1"
        CHECKSUM=0
        BYTES=$(get_bytes $FILENAME 0xA0 0x1D)
        for i in $BYTES
        do
            BYTE="0x$i"
            CHECKSUM=$(( $CHECKSUM - $BYTE ))
        done
        CHECKSUM=$(( ($CHECKSUM - 0x19) & 0xFF ))
        ACTUAL_CHECKSUM=$(( 0x$(get_bytes $FILENAME 0xBD) ))
        if [ $CHECKSUM -ne $ACTUAL_CHECKSUM ]
        then
            printf "checksum validatation failed!\n"
            printf "calculated %#02x, got %#02x\n" $CHECKSUM $ACTUAL_CHECKSUM
        else
            printf "checksum validation succeeded.\n"
        fi
    else
        printf "Skipping checksum validation, can't find xxd\n"
    fi
}

# normal version
build snek
# emulator bios version
build snek-emu --defsym EMULATOR_BIOS=1
# validate checksum
checksum snek.gba
