; the pixel screen's colours, change them here
; graphics_init makes the 256 colour palette from it at start-up
; a pixel is one byte, a colour number 0-255
; top 4 bits = colour (0-15)     bottom 4 bits = shade (0-15, dark to light)
; 0x98 = colour 9 shade 8, the colour itself
; colour 0       greys, shade 0 = black, shade 15 = white
; colours 1-14   the 14 colours below, each is shade 8
; shades 0-8 = the colour x (shade + 1) / 9
; shades 9-15 = towards white, 7/8 of the way at shade 15
; colour 15      16 free colours (0xF0 - 0xFF), no shading
; a program can change any of the 256 with SET_COLOUR

; colours 1-14, middle shade (0x00RRGGBB)
palette_colours:
.word 0x005044C8                       ; 1  blue-violet, the shell's background
.word 0x00008080                       ; 2  teal, the Windows 95 desktop
.word 0x00000080                       ; 3  navy, Windows 95 title bars
.word 0x003C8CE6                       ; 4  sky blue
.word 0x0030C8D8                       ;5  aqua
.word 0x0022AA22                       ;6  green
.word 0x0080D040                       ; 7  lime
.word 0x00E8C830                       ;8  yellow
.word 0x00E07020                       ;9  orange
.word 0x00CC2222                       ;10 red
.word 0x00F080B0                       ;11 pink
.word 0x00AA22AA                       ;12 magenta
.word 0x007040A0                       ;13 purple
.word 0x00805030                       ;14 brown

; colour 15, the 16 free colours (0xF0 - 0xFF)
palette_free:
.word 0x00C0C0C0                       ;0xF0 Windows 95 silver
.word 0x00808080                       ; 0xF1 Windows 95 dark grey, bevel shadows
.word 0x00E8E8E8                       ;0xF2 the text screen's white
.word 0x000A246A                       ;0xF3 Windows 98 title bar, dark end
.word 0x00A6CAF0                       ;0xF4 Windows 98 title bar, light end
.word 0x00FFFFE1                       ;0xF5 tooltip yellow
.word 0x0066CCFF                       ;0xF6 Aero glass blue
.word 0x00B9E3FF                       ;0xF7 Aero glass, pale
.word 0x0039B54A                       ;0xF8 Aero grass green
.word 0x00FFD700                       ;0xF9 gold
.word 0x00FF6EC7                       ;0xFA hot pink
.word 0x0000FF00                       ;0xFB pure green
.word 0x000000FF                       ;0xFC pure blue
.word 0x00FF0000                       ;0xFD pure red
.word 0x00FF00FF                       ;0xFE pure magenta
.word 0x00000000                       ;0xFF black

; names for a few (colour x 16 + shade)
.equ COLOUR_BLACK,       0x00
.equ COLOUR_WHITE,       0x0F
.equ COLOUR_SILVER,      0xF0
.equ COLOUR_SHADOW,      0xF1
