    @ -*- ARM -*-
    @ Copyright (C) 2022 easyaspi314
    @ MIT License

    .syntax unified
    .arch   armv4t
    .globl  main
    .text

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                 GBA CONSTANTS                                @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ Memory maps
    .equ MAP_BIOS,   0x00000000
    .equ MAP_EWRAM,  0x02000000
    .equ MAP_IWRAM,  0x03000000
    .equ MAP_IO,     0x04000000
    .equ MAP_PAL,    0x05000000
    .equ MAP_VRAM,   0x06000000
    .equ MAP_OAM,    0x07000000
    .equ MAP_ROM,    0x08000000

    @ IO + x
    .equ DISPCNT, 0x00
    .equ VCOUNT, 0x06
    .equ BG0CNT, 0x08

    @ IO_2 + x
.ifndef BASE_2
    .equ BASE_2, 0xE0
.endif
    .equ TM0CNT_L, 0x100 - BASE_2
    .equ TM0CNT_H, 0x102 - BASE_2
    .equ KEYINPUT, 0x130 - BASE_2


    @ Syscalls
    .equ SWI_Div, 0x06
    .equ SWI_RLUnCompVram, 0x15

    .equ SCREEN_WIDTH, 240
    .equ SCREEN_HEIGHT, 160

    .equ U16, 2
    @ 4bpp tile
    .equ TILE_BYTES, 32
    .equ TILE_PIXELS, 8
    .equ BG_WIDTH, 32
    .equ BG_HEIGHT, 32

    .equ U16_LG2, 1
    .equ BG_WD_2, 5 @ log2(BG_WIDTH) for shifts

    .equ SCREEN_BG_WIDTH, SCREEN_WIDTH / TILE_PIXELS
    .equ SCREEN_BG_HEIGHT, SCREEN_HEIGHT / TILE_PIXELS

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                    MY CONSTANTS                              @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ XXX: Would 1D tiles make this shorter? The logic to check tiles would be odd.
    .equ START_POS, BG_WIDTH * (SCREEN_BG_HEIGHT / 2) + (SCREEN_BG_WIDTH / 2)

    @ The game uses the tilemap to both display the game and track game state.
    @ IMPORTANT: It is expected that snek tiles < appel < empty.
    .equ TILE_RIGHT, 0x000              @ snek, green square
    .equ TILE_LEFT,  0x001              @ snek, green square
    .equ TILE_UP,    0x002              @ snek, green square
    .equ TILE_DOWN,  0x003              @ snek, green square
    .equ TILE_APPEL, 0x004              @ red square
    .equ TILE_EMPTY, 0x005              @ black square

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                     MACROS                                   @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ Converts to.RGB5
    .macro rgb r, g, b
        .hword ((\r) << 0) | ((\g) << 5) | ((\b) << 10)
    .endm
    @ Header for GBA run length encoding block
    .macro rl_hdr len
        .word (3 << 4) | ((\len) << 8)
    .endm
    @ Encodes the byte val repeates len times
    .macro rl_rep len, val
        .byte 0x80 | ((\len - 3) & 0x7f)
        .byte \val
    .endm
    @ Encodes the len bytes vals
    .macro rl_lit len, val:vararg
        .byte ((\len - 1) & 0x7f)
        .byte \val
    .endm

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                    REGISTERS                                 @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ Constants
    LUT         .req r3                  @ direction lookup table (volatile)
    IO          .req r3                  @ 0x04000000 (volatile)
    IO_2        .req r4                  @ 0x04000000 + BASE_2
    PAL_RAM     .req r5                  @ 0x05000000 (overwritten)
    VRAM        .req r6                  @ 0x06000000 (tile map 0), must be r6

    @ Variables
    Head        .req r5
    Dir         .req r7
    Tail        .req r8                  @ NOTE: hi register. Can this be improved?

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                   ROM HEADER                                 @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    .globl _start
    .globl main
    .arm
_start:
    b       arm_veneer                  @ I really wish BLX was in v4T.
nintendo_logo:
    @ Nintendo logo
    .byte 0x24, 0xff, 0xae, 0x51, 0x69, 0x9a, 0xa2, 0x21, 0x3d, 0x84, 0x82, 0x0a
    .byte 0x84, 0xe4, 0x09, 0xad, 0x11, 0x24, 0x8b, 0x98, 0xc0, 0x81, 0x7f, 0x21
    .byte 0xa3, 0x52, 0xbe, 0x19, 0x93, 0x09, 0xce, 0x20, 0x10, 0x46, 0x4a, 0x4a
    .byte 0xf8, 0x27, 0x31, 0xec, 0x58, 0xc7, 0xe8, 0x33, 0x82, 0xe3, 0xce, 0xbf
    .byte 0x85, 0xf4, 0xdf, 0x94, 0xce, 0x4b, 0x09, 0xc1, 0x94, 0x56, 0x8a, 0xc0
    .byte 0x13, 0x72, 0xa7, 0xfc, 0x9f, 0x84, 0x4d, 0x73, 0xa3, 0xca, 0x9a, 0x61
    .byte 0x58, 0x97, 0xa3, 0x27, 0xfc, 0x03, 0x98, 0x76, 0x23, 0x1d, 0xc7, 0x61
    .byte 0x03, 0x04, 0xae, 0x56, 0xbf, 0x38, 0x84, 0x00, 0x40, 0xa7, 0x0e, 0xfd
    .byte 0xff, 0x52, 0xfe, 0x03, 0x6f, 0x95, 0x30, 0xf1, 0x97, 0xfb, 0xc0, 0x85
    .byte 0x60, 0xd6, 0x80, 0x25, 0xa9, 0x63, 0xbe, 0x03, 0x01, 0x4e, 0x38, 0xe2
    .byte 0xf9, 0xa2, 0x34, 0xff, 0xbb, 0x3e, 0x03, 0x44, 0x78, 0x00, 0x90, 0xcb
    .byte 0x88, 0x11, 0x3a, 0x94, 0x65, 0xc0, 0x7c, 0x63, 0x87, 0xf0, 0x3c, 0xaf
    .byte 0xd6, 0x25, 0xe4, 0x8b, 0x38, 0x0a, 0xac, 0x72, 0x21, 0xd4, 0xf8, 0x07

    @ We do a little header tomfoolery
    @ The GBA doesn't check most of these fields, it only cares about the logo,
    @ the checksum, and the fixed value.
    @
    @ IMPORTANT: These next few instructions are sensitive: changing a single byte
    @ will require recalculating the whole thing. These were brute forced.

    @ You may notice that I don't manually set up the stack pointer.
    @ This is only required for multiboot ROMs and I don't care about that.

    @@@@@@@@@@@@@@@@@@@@@@@@@ BEGIN SENSITIVE INSTRUCTIONS @@@@@@@@@@@@@@@@@@@@@@@@@
arm_veneer:                             @ Jump to thumb mode
    @ Game title
    adr     r6, main + 1                @ Get address of main + thumb bit
    bx      r6                          @ BX out of this dummy thicc ARM mode
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                  GAME CODE                                   @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ Still in the ROM header but these are the instructions that are useful
    .thumb_func
main:                                   @ Set up registers, tiles, and such
    movs    r1, #0x80                   @ TIMER_ENABLE, also used for constants
    lsls    IO_2, r1, #19               @ => 0x04000000
    @ Game code
    adds    IO_2, #BASE_2               @ => 0x040000xx
    strh    r1, [IO_2, #TM0CNT_H]       @ TM0CNT_H = TIMER_ENABLE
    @ Maker code
    movs    r2, #MAP_VRAM >> 22         @ => 0x18

    @ This instruction encodes the mandatory value 0x96 at offset 0x080000b2.
    @ |  15 - 11  |  10 - 6   | 5 - 3 | 0 - 2 |
    @ | 0 0 0 0 0 |   imm5    |  Rm   |  Rd   |   lsls   Rd, Rm, #imm5
    @ | 0 0 0 0 0 | 1 0 1 1 0 | 0 1 0 | 1 1 0 |   lsls   r6, r2, #22
    @ '------- 0x05 -----'------- 0x96 -------'   .byte  0x96, 0x05
    @ Fixed value 0x96, main unit code
    lsls    VRAM, r2, #22               @ => 0x06000000
    @ Device type, 7 reserved bytes
    lsls    r3, r1, #7                  @ => 0x00004000
    adds    r1, VRAM, r3                @ => 0x06004000 = tileset map 1
    adr     r0, rle_tiles               @ note: PC-relative, this will change if the literal pool is moved
    swi     SWI_RLUnCompVram            @ RLUnCompVram(rle_tiles, 0x06004000)
.Lplay_again:                           @ Reset the state of the game (mostly)
    @ Software version, checksum (0x20) @ Set the palette. Redundant but I need 5 in a register below.
    movs    r0, #MAP_PAL >> 24          @ => 5. Both TILE_EMPTY and literal for palette address
    @@@@@@@@@@@@@@@@@@@@@@@@@@ END SENSITIVE INSTRUCTIONS @@@@@@@@@@@@@@@@@@@@@@@@@@
    lsls    PAL_RAM, r0, #24            @ => 0x05000000
    ldr     r1, palette
    str     r1, [PAL_RAM, #4]           @ Set palette: pal[2] = GREEN, pal[3] = RED
.Lclear_tiles:                          @ Clear the tile memory to reset the board
    idx     .req Dir                    @ Ensure this loop clears Dir

    lsls    idx, r0, #8                 @ => 0x500 = BG_WIDTH * SCREEN_BG_HEIGHT * U16
.Lclear_loop:                           @ simple memset loop
    subs    idx, #2
    strh    r0, [VRAM, idx]
    bne     .Lclear_loop
.Lclear_loop.end:
.Lset_head:                             @ Set the initial head and tail state.
    movs    Head, #START_POS >> 1       @ start in the middle, roughly
    lsls    Head, #1 + 1                @ => START_POS * U16
    strh    Dir, [VRAM, Head]           @ note: due to the clear loop, Dir == 0 == TILE_RIGHT
    mov     Tail, Head                  @ start with head==tail

.Lgenerate_appel:                       @ Generate a new appel.
    ldrh    r0, [IO_2, #TM0CNT_L]       @ Use TM0CNT_L for rng
    movs    r1, #SCREEN_BG_HEIGHT       @ => 20
    swi     SWI_Div                     @ row = TM0CNT_L % 20, tmp = TM0CNT_L / 20
    lsls    r2, r1, #BG_WD_2 + 1        @ row *= BG_WIDTH * U16 (Div preserves r2)
    movs    r1, #SCREEN_BG_WIDTH        @ => 30
    swi     SWI_Div                     @ col = (TM0CNT_L / 20) % 30
    lsls    r1, #1                      @ col *= U16
    adds    r1, r2                      @ col + (row * BG_WIDTH)
    ldrh    r0, [VRAM, r1]              @ check if we are on a clear tile
    cmp     r0, #TILE_EMPTY
    bne     .Lgenerate_appel            @ not available, try again
.Lgenerate_appel.end:
    movs    r0, #TILE_APPEL             @ Store an appel
    strh    r0, [VRAM, r1]

.Lgame_loop:                            @ Main loop
    movs    r1, #MAP_IO >> 24           @ => 0x04, number of keys, pointer address
    lsls    IO, r1, #24                 @ => 0x04000000
    strh    r1, [IO, #BG0CNT]           @ set BG0 mode
    lsls    r2, r1, #8 - 2              @ => 0x100 == BG0_ENABLE, loop counter times 64
    strh    r2, [IO, #DISPCNT]          @ set display mode

.Ldelay_frames:                         @ Delay 5 frames for 12 FPS.
.Lvblank_pre_loop:                      @ loop until out of vblank
    ldrh    r0, [IO, #VCOUNT]           @ read current line
    cmp     r0, #SCREEN_HEIGHT
    bhs     .Lvblank_pre_loop
.Lvblank_pre_loop.end:
.Lvblank_loop:                          @ loop until the next vblank
    ldrh    r0, [IO, #VCOUNT]           @ read current line
    cmp     r0, #SCREEN_HEIGHT
    blo     .Lvblank_loop
.Lvblank_loop.end:
    subs    r2, #0x100 / 4              @ Subtract from our loop counter times 64
    bpl     .Ldelay_frames              @ Jump if not negative (after 5 iterations)
.Ldelay_frames.end:

    @ input testing
    @ KEYINPUT layout
    @ Bit = 1: released, Bit = 0: pressed, which is backwards
    @   9     8      7     6    5       4        3      2      1   0
    @   L  |  R  | Down | Up | Left | Right | Start | Select | B | A
.Ltest_inputs:                          @ note: r1 is still 4.
    ldr     r2, [IO_2, #KEYINPUT]       @ read KEYINPUT (technically KEYCNT too but idc, I need range)
    lsls    r2, #24                     @ shift left so the d-pad bits are on top
.Linput_loop:
    lsls    r2, #1                      @ Test next bit into carry flag
    bcs     .Lnot_pressed               @ CS = bit set = not pressed
.Lpressed:                              @ Pressed, set the direction
    subs    Dir, r1, #1                 @ The decrement is below, so we still need to sub 1
.Lnot_pressed:
    subs    r1, #1                      @ repeat for all directions
    bne     .Linput_loop
.Linput_loop.end:
    strh    Dir, [VRAM, Head]           @ save snek tile with next direction
    adr     LUT, direction_lut          @ Get LUT
    ldrsb   r0, [LUT, Dir]              @ Load pointer offset from the LUT
    adds    Head, r0                    @ Move pointer, sets condition codes
.Lcheck_tile:                           @ Check the tile (condition codes set above)
    bmi     .Lplay_again                @ if < 0, we are too high
    lsrs    r0, Head, #BG_WD_2 + 1      @ (head / U16) / BG_WIDTH
    cmp     r0, #SCREEN_BG_HEIGHT       @ Check if too low
    bge     .Lplay_again
    lsls    r0, Head, #32 - BG_WD_2 - 1 @ (head / U16) % BG_WIDTH
    lsrs    r0, #32 - BG_WD_2
    cmp     r0, #SCREEN_BG_WIDTH        @ Check if too far left/right (will wrap)
    bge     .Lplay_again
    ldrh    r0, [VRAM, Head]            @ Load the new tile
    strh    Dir, [VRAM, Head]           @ Store new direction
    cmp     r0, #TILE_APPEL             @ Check the new tile
    blt     .Lplay_again                @ snek < appel, we ate ourselves
    beq     .Lgenerate_appel            @ appel, grow (a.k.a. don't erase tail) and make appel
.Ldont_eat_appel:                       @ otherwise empty tile
    mov     r2, Tail                    @ mov out of hi register
    ldrh    r1, [VRAM, r2]              @ load tail direction
    strh    r0, [VRAM, r2]              @ move tail to the next tile (r1 == TILE_EMPTY)
    ldrsb   r3, [LUT, r1]               @ move tail pointer
    add     Tail, r3
    b       .Lgame_loop                 @ loop again

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                                 LITERAL.POOL                                 @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @ This must be aligned at a 4 byte boundary. The assembler will zero pad to fit
    @ this, which is why sizes will be in multiples of 4. However, code that would
    @ decrease the binary size if the alignment was not required is still accepted
    @ as it leads to further code size reductions.
    @
    @ If you see `literal_pool_alignment` in `objdump`'s output, you have an alignment
    @ (this works because it merges adjacent labels).
literal_pool_alignment:
    .p2align 2,0
    @ Lookup table for how far to move the pointer
direction_lut:
    .byte   U16                         @ TILE_RIGHT
    .byte   -U16                        @ TILE_LEFT
    .byte   -(BG_WIDTH * U16)           @ TILE_UP
    .byte   BG_WIDTH * U16              @ TILE_DOWN

    @ GBA RLE encoded tile data
rle_tiles:
    rl_hdr  160                         @ header
    rl_rep  4 * TILE_BYTES, 0x22        @ 4 green tiles for snek
    rl_rep  1 * TILE_BYTES, 0x33        @ 1 red tile for appel
palette:
    rgb     0,  31,  0                  @ green
    rgb     31,  0,  0                  @ red
    .pool                               @ any ldr =x or veneers go here
