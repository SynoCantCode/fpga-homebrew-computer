# FPGA Computer

A computer I built from scratch on a Tang Nano 20K FPGA. The CPU, the graphics card and the operating system are all mine. The hardware is Verilog and the software is written in my own assembly language for my own CPU.

Still in progress.

## What it has

Hardware

- 32-bit CPU with my own instruction set, over 120 instructions
- 8 MB of SDRAM with an instruction cache
- HDMI graphics card with text, 256 colour pixels, a mouse pointer and a blitter
- PS/2 keyboard and mouse, SD card, ethernet, a clock chip

Software

- kernel and shell
- FAT32 file system on the SD card
- network stack with DHCP, ping and a small browser
- window manager with a desktop, taskbar, icons and wallpapers
- apps: files, settings, clock, pong, browser, terminal
- Studio, for making app windows on the computer itself

## Folders

- hardware: the Verilog, split into cpu, graphics, memory, io, bus and top
- sw/os: boot ROM, kernel, shell, file system, network
- sw/apps: the desktop apps
- sw/graphics: window manager, drawing code, sprites and window designs
- sw/programs: the editor and some example programs

## Notes

AI helped with some of the assembly code.

The assembler, test benches and build scripts are not in this repo, so it will not build straight from here.
