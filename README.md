# gbasnek

a smol snek game for the gba

it is 352 bytes smol and wishes to become smoller

### how 2 play

if u dont know how 2 play snek u need 2 get out more

u use the dpad 2 move green snek and eat red appel, when u eat red appel u get longer

u dont want 2 eat urself or wall, that is bad

dont try 2 move backwards btw that is a skill issue and u die

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

The output will be snek.gba, as well as some intermediate files.

### Notes

This uses a *barely legal* ROM header which puts code in the header fields, in a way similar
to ["A Whirlwind Tutorial on Creating Really Teensy ELF Executables for Linux](https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html).

The `push` instruction is used to encode *and* correct the checksum (as well as push `r0` to
the stack so it can be used for the `CpuSet` call).

If you modify the code in the header, you must modify the list of registers. The build script
will mention it. In the future I will make the build script automatically update or calculate
the required register list.

### Contributing

Because this is a golfed project, unless there is a severe bug, **I will reject anything that**
**makes the outputted ROM larger in size.**

The spec that I am following:
 - Basic snek gameplay rules
 - Sneks, appels, and the background are all different colors. Yes, the game could be playable
   in monochrome, but I want it to be colored. It only costs two bytes and makes things look nicer.
 - All tiles are solid 8x8 colors.
 - The game advances at 12 FPS
 - The RNG is based on the timer. This will have a different result depending on the BIOS.
 - The snek spawns at (10, 14), roughly in the center.
 - BIOS functions are allowed.

The intentional bugs/oversights:
 - Pressing the opposite direction will kill you.
 - The appel generation algorithm only has to find a tile **in theory**. Due to how the timing
   works, there may be tiles that it won't spawn on, or it can lag/softlock if it can't find an
   empty tile.
 - There is no win condition, you just play until you die or the previous thing happens
 - vBlank is a busy spin loop
 - The ROM header is not to spec (Oh no! Anyways...)

Make sure that the code boots on, at the very least, mGBA with the official GBA bios.
