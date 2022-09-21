    @ Copyright (C) 2022 easyaspi314
    @ MIT License

    .syntax unified
    .arch   armv4t
    .globl  main
    .text

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                   GBA CONSTANTS                  @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ REG_BASE + x
    .equ DISPCNT, 0x00
    .equ VCOUNT, 0x06
    .equ BG0CNT, 0x08

    @ TIMER_BASE + x
    .equ TM0CNT_L, 0x00
    .equ TM0CNT_H, 0x02
    .equ KEYINPUT, 0x30

    @ Syscalls
    .equ SWI_Div, 0x06
    .equ SWI_RLUnCompVram, 0x15
    .equ SWI_CpuSet, 0x0b

    .equ CPU_FILL, (1 << 24)
    .equ SCREEN_HEIGHT, 160

    @ 4bpp tile
    .equ TILE_BYTES, 32

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                    MY CONSTANTS                  @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    @ XXX: Would 1D tiles make this shorter? The logic to check tiles would be odd.
    .equ SCREEN_WIDTH_TILES, 30
    .equ TILES_WIDTH, 32
    .equ SCREEN_HEIGHT_TILES, 20
    .equ TILES_HEIGHT, 32
    .equ START_POS, (TILES_WIDTH * (SCREEN_HEIGHT_TILES / 2) + (SCREEN_WIDTH_TILES / 2))

    @ The game uses the tilemap to both display the game and
    @ track game state.
    @ IMPORTANT: It is expected that snek tiles < apple < empty.
    .equ TILE_RIGHT, 0x000              @ snek, green square
    .equ TILE_LEFT,  0x001              @ snek, green square
    .equ TILE_UP,    0x002              @ snek, green square
    .equ TILE_DOWN,  0x003              @ snek, green square
    .equ TILE_APPLE, 0x004              @ red square
    .equ TILE_EMPTY, 0x005              @ black square

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                       MACROS                     @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    
    .macro rgb r, g, b
        .hword ((\r) << 0) | ((\g) << 5) | ((\b) << 10)
    .endm
    .macro rl_hdr len
        .word (3 << 4) | ((\len) << 8)
    .endm
    .macro rl_rep len, val
        .byte 0x80 | ((\len - 3) & 0x7f)
        .byte \val
    .endm
    .macro rl_lit len, val:vararg
        .byte ((\len - 1) & 0x7f)
        .byte \val
    .endm


    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                      REGISTERS                   @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    REG_BASE    .req r3                  @ 0x04000000 (volatile)
    TILES       .req r4                  @ 0x06000000 (tile map 0)
    TIMER_BASE  .req r7                  @ 0x04000100
    PAL_RAM     .req r6                  @ 0x05000000 (overwritten)

    Head        .req r6
    Direction   .req r5
    Tail        .req r9                  @ NOTE: hi register

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                     ROM HEADER                   @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .globl _start
    .arm
_start:
    b       .Lentry

.Lgba_header:
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
    @ will require recalculating the whole thing, but this just means changing the
    @ push instruction register list.

    @ You may notice that I don't manually set up the stack pointer.
    @ This is only required for multiboot ROMs and I don't care about that.

    @@@@@@@@@@@@@@@@@@@@@@@@@ BEGIN SENSITIVE INSTRUCTIONS @@@@@@@@@@@@@@@@@@@@@@@@@
.Lentry:
    @ (game title)
    adr     r0, main + 1                @ same effect but doesn't match checksum
    bx      r0                          @ Get out of this dummy thicc ARM mode

    .thumb
    .thumb_func
main:
    movs    r1, #0x80                   @ TIMER_ENABLE, also used for constants
    movs    TILES, #0x06
    @ (game code)
    lsls    TILES, #24                  @ TILES = 0x06000000
    lsls    TIMER_BASE, r1, #19
    @ (maker code)
    adds    TIMER_BASE, #0x100 - 0x96   @ We are going to need two adds instructions since we need to add 256,
    @ (Fixed value 0x96)                @ so we use this opportunity to encode the required 0x96 byte here
    adds    TIMER_BASE, #0x96           @ TIMER_BASE = 0x04000100   (encodes to 0x96 0x35 satisfying the header)
    @ device type, 7 reserved bytes        
    strh    r1, [TIMER_BASE, #TM0CNT_H] @ TM0CNT_H = TIMER_ENABLE
    lsls    r1, r1, #7                  @ r1 = 0x00004000
    movs    r0, #0x05                   @ Both TILE_EMPTY and literal for palette memory
    lsls    PAL_RAM, r0, #24            @ PAL_RAM = 0x05000000

    @ This push instruction is encoded as (note: little endian so reglist comes first)
    @           15-9        8         7    6    5    4    3    2    1    0
    @    | 1 0 1 1 0 1 0 | lr |    | r7 | r6 | r5 | r4 | r3 | r2 | r1 | r0 |
    @ By changing the registers we push, we can always make the checksum either 0xB4 (push w/o lr) or
    @ 0xB5 (push with lr), as long as we push r0 to get the top value to the stack.
    @ version (reglist), checksum (opcode)
.Lversion_and_checksum:
    push    {r0,r1,r2,r4,r5,r6,lr}      @ Encodes and corrects the checksum, pushes r0 (plus junk) to the stack for CpuSet
    @@@@@@@@@@@@@@@@@@@@@@@@@ END SENSITIVE INSTRUCTIONS @@@@@@@@@@@@@@@@@@@@@@@@@

    @ (reserved 2 bytes)
    ldr     r0, palette
    @ End header
    str     r0, [PAL_RAM, #4]           @ pal[2] = GREEN, pal[3] = RED
    adds    r1, TILES                   @ r1 = 0x06004000 = tileset 1
    adr     r0, rle_tiles               @ note: PC-relative, this will change if the literal pool is removed
    @ software version, checksum
    swi     SWI_RLUnCompVram            @ RLUnCompVram(rle_tiles, 0x06004000) (encodes to version 0x15, checksum 0xDF)

.Lplay_again:
    @ clear tile ram
    @ CpuSet(TILES, 0x0005, TILES_HEIGHT * TILES_WIDTH | CPU_FILL)
    mov     r0, sp                      @ Grab the TILE_EMPTY I pushed to the stack
    movs    r1, TILES
    ldr     r2, =(TILES_HEIGHT * TILES_WIDTH * 2 / 2) | CPU_FILL
    swi     SWI_CpuSet
    movs    Head, #START_POS >> 1       @ start in the middle, roughly
    lsls    Head, #2
    strh    Direction, [TILES, Head]
    mov     Tail, Head                  @ start with head==tail
.Lgenerate_apple:
    ldrh    r0, [TIMER_BASE, #TM0CNT_L] @ Use TM0CNT_L for rng
    movs    r1, #SCREEN_HEIGHT_TILES
    swi     SWI_Div                     @ TM0CNT_L % 20
    lsls    r2, r1, #6                  @ save as row (Div doesn't overwrite r2)
    movs    r1, #SCREEN_WIDTH_TILES
    swi     SWI_Div                     @ (TM0CNT_L / 20) % 30
    lsls    r0, r1, #1
    adds    r0, r2                      @ get address
    ldrh    r1, [TILES, r0]             @ check if we are on a clear tile
    cmp     r1, #TILE_EMPTY
    bne     .Lgenerate_apple            @ whoops, try again
    movs    r1, #TILE_APPLE             @ Store an apple
    strh    r1, [TILES, r0]
.Lgame_loop:
    movs    r1, #0x04                   @ 4 + 1 frame skip, and for pointer address
    lsls    REG_BASE, r1, #24           @ 0x04000000
    @ delay 5 frames for 12 fps
.Ldelay_frames:
.Lvblank_pre_loop:                      @ loop until out of vblank
    ldrh    r0, [REG_BASE, #VCOUNT]     @ VCOUNT
    cmp     r0, #SCREEN_HEIGHT
    bhs     .Lvblank_pre_loop
.Lvblank_loop:                          @ loop until the next vblank
    ldrh    r0, [REG_BASE, #VCOUNT]     @ VCOUNT
    cmp     r0, #SCREEN_HEIGHT
    blo     .Lvblank_loop
    subs    r1, #1
    bge     .Ldelay_frames
.Ldelay_frames.end:
    movs    r1, #(1 << 2)               @ set tiles to block 1
    strh    r1, [REG_BASE, #BG0CNT]     @ REG_BG0CNT
    lsls    r1, #8-2                    @ 0x100 == BG0_ENABLE
    strh    r1, [REG_BASE, #DISPCNT]    @ REG_DISPCNT
.Ltest_inputs:
    ldrh    r2, [TIMER_BASE, #KEYINPUT] @ read REG_KEYINPUT
    lsrs    r2, #5                      @ test RIGHT bit by shifting out
    bcs     .Lnot_right                 @ CS = not pressed
    movs    Direction, #TILE_RIGHT
.Lnot_right:
    lsrs    r2, #1                      @ test LEFT                  
    bcs     .Lnot_left
    movs    Direction, #TILE_LEFT
.Lnot_left:
    lsrs    r2, #1                      @ test UP
    bcs     .Lnot_up
    movs    Direction, #TILE_UP
.Lnot_up:
    lsrs    r2, #1                      @ test DOWN
    bcs     .Lnot_down
    movs    Direction, #TILE_DOWN
.Lnot_down:
    strh    Direction, [TILES, Head]    @ save snek tile with next direction
    adr     r3, direction_lut           @ Move head pointer
    ldrsb   r0, [r3, Direction]
    adds    Head, r0                    @ note: sets flags
    blt     .Lplay_again                @ too high
    lsrs    r0, Head, #5 + 1            @ (head / 32) / 2
    cmp     r0, #SCREEN_HEIGHT_TILES    @ Check if too low    
    bge     .Lplay_again
    lsls    r0, Head, #32 - 5 - 1       @ (head / 2) % 32
    lsrs    r0, #32 - 5
    cmp     r0, #SCREEN_WIDTH_TILES     @ Check if too far left/right (will wrap)
    bge     .Lplay_again 
    ldrh    r0, [TILES, Head]           @ Load the new tile
    strh    Direction, [TILES, Head]    @ Store new direction
    cmp     r0, #TILE_APPLE             @ Check the new tile
    blt     .Lplay_again                @ snek < apple, we ate ourselves
    beq     .Lgenerate_apple            @ apple, grow (a.k.a. don't erase tail) and make apple
.Ldont_eat_apple:                       @ otherwise empty tile
    mov     r0, Tail                    @ annoying hi registers
    ldrh    r1, [TILES, r0]             @ load tail direction
    movs    r2, #TILE_EMPTY             @ erase
    strh    r2, [TILES, r0]             @ move tail to the next tile
    ldrsb   r3, [r3, r1]                @ move tail pointer
    add     Tail, r3
    b       .Lgame_loop

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @                  LITERAL POOL                    @
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    @ This must be at an aligned address, hence why it is
    @ in the middle of the code instead of at the end of
    @ the file or function like most people do.
    @ Because I didn't manually align palette, this will
    @ error out the assembler if this literal pool is
    @ not aligned instead of it silently adding padding.
palette:
    rgb     0,  31,  0                  @ green
    rgb     31,  0,  0                  @ red
    @ Tell the assembler to put the automatically generated
    @ literal pool here
    .pool
    @ GBA RLE encoded tile data
rle_tiles:
    rl_hdr  160                         @ header
    rl_rep  4 * TILE_BYTES, 0x22        @ 4 green tiles for snek
    rl_rep  1 * TILE_BYTES, 0x33        @ 1 red tile for apple

    @ Lookup table for how far to move the pointer
direction_lut:
    .byte   2                           @ TILE_RIGHT
    .byte   -2                          @ TILE_LEFT
    .byte   -(TILES_WIDTH * 2)          @ TILE_UP
    .byte   TILES_WIDTH * 2             @ TILE_DOWN
