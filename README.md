# gbasnek

a smol snek game for the gba

it is 366 bytes smol and wishes to become smoller

### how 2 play

if u dont know how 2 play snek u need 2 get out more

u use the dpad 2 move green snek and eat red appel, when u eat red appel u get longer

u dont want 2 eat urself or wall, that is bad

dont try 2 move backwards btw that is a skill issue and u die

btw if u play on flash cart or use gba bios, use snek.gba, if u use emulator without bios use snek-emu.gba

### Building

Enough with the meme talk.

To build this project, you must have
 - A POSIX shell and coreutils
 - ARM ELF Binutils. The easiest way is to install `arm-none-eabi` binutils or [devkitARM](https://devkitpro.org/wiki/Getting_Started).
 - xxd to validate the ROM checksum (optional)

In the project directory, run
```sh
./build.sh (binutils prefix)
```
If you have a devkitARM environment set up or have `arm-none-eabi-as` in your
`$PATH`, you can leave out the second argument. However, for example, if you have the
Linux armhf toolchain installed, you can run this:
```sh
./build.sh arm-linux-gnueabihf-
```

The output will be snek.gba and snek-emu.gba, as well as some intermediate files.

### Notes

This uses a "barely legal" ROM header which puts code in the header fields, and also
relies on the register state from the official BIOS.

However, without the official BIOS, the current (as of writing) versions of mGBA and
VBA-M will **not** have the correct registers and will crash. Therefore, there is also
snek-emu.gba which will run on emulator bios. I have opened a PR on mGBA and will open
one for VBA-M as well. This will **not** run on official BIOS or hardware because the
checksum is wrong.

The weird instruction choices are brute forced to cause the checksum to be `0xDF`, which
is the opcode for `swi`, meaning I don't have to jump over the checksum field. However,
this also means that any changes to the code must ensure the checksum is correct. The checksum
will be calculated if you have xxd installed.

### Contributing

Because this is a golfed project, unless there is a severe bug, **I will reject anything that**
**makes the outputted ROM larger in size.**

The spec that I am following:
 - Basic Snek gameplay rules
 - Sneks and apples are different colors. Yes, the game could be playable in monochrome, but
   I want it to be colored. It only costs two bytes and makes things look nicer.
 - The game advances at 12 FPS
 - The RNG is based on the timer. This will have a different result depending on the BIOS.
 - The snake spawns at (10, 14), roughly in the center.
 - BIOS functions are allowed.

The intentional bugs/oversights:
 - Pressing the opposite direction will kill you.
 - The apple generation algorithm only has to find a tile **in theory**. Due to how the timing
   works, there may be tiles that it won't spawn on, or it can lag/softlock if it can't find an
   empty tile.
 - There is no win condition, you just play until you die or the previous thing happens
 - vBlank is a busy spin loops
 - The ROM header is not to spec (Oh no! Anyways...)

Make sure that the code boots on, at the very least, mGBA with the official GBA bios.
