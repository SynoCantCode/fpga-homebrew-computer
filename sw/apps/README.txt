APPS: windows made from page files (read by the window manager, WM.BIN)

On the card:
  /APPS/APPS.TXT          the apps to open, one folder name a line (up to 8)
  /APPS/NAME/PAGE.TXT     what the app's window holds (below)
  /APPS/NAME/ICON.PIC     (optional) its desktop icon: 32 x 32, see-through dots = colour 0xFE
  /APPS/NAME/*.PIC        (optional) pictures its page shows
This folder (sw/apps/) is the PC's copy. Put an app on the card:
  sh project/tools/scripts/sendfile.sh sw/apps/welcome/page.txt --to /apps/welcome/page.txt
(make the folders on the computer first: mkdir /apps   mkdir /apps/welcome)

A page: one line each. Positions are CELLS (the window's grid: 8 x 16 dots each), counted from 0.
Lines starting with ; are notes. Numbers are decimal, except colours (hex, like the palette: 38 = colour 3, shade 8).

  title TEXT                  the title bar's text (else the folder's name)
  style NAME                  how the window looks: /SYSTEM/DESIGN/WINDOWS/NAME/STYLE.TXT (else the default)
  size COLUMNS ROWS           its cells: 12-76 across, 2-26 down (else 30 x 6)
  place X Y                   where it starts, in dots (snapped to 8 x 16)
  hidden                      it starts closed (its taskbar button, or another app's button, opens it)
  fullscreen no               no full-screen button (□) for this window (it has one unless this is said)
  colour NN                   the colour of the text lines after it (else 00, black)
  text COLUMN ROW TEXT        a text from that cell, on one row (cut at the window's edge)
  wrap ROW TEXT               a paragraph from that row, wrapped to the window's width
  box COLUMN ROW WIDTH HEIGHT TEXT
                              a paragraph wrapped INSIDE that box of cells (the page editor: drag across the
                              cells, then type). In box and wrap texts, 
 (a backslash, then n) starts a new line
  input COLUMN ROW WIDTH HEIGHT
                              a box you can TYPE into: click it, then type (letters, Enter, Backspace). What's
                              typed is kept only while the window is open: its x or a close button empties it
                              (hiding it with its taskbar button keeps it)
  button COLUMN ROW LABEL ACTION
                              a button (the label is one word); ACTION is:
                                close        this window closes
                                open NAME    the app NAME's window opens, at the front
  image COLUMN ROW FILE.PIC   a picture: from the app's folder, else /SYSTEM/DESIGN/SPRITES/ (0xFE dots are see-through)
  icon FILE.PIC               its desktop icon (from the app's folder or the sprites; else the app's ICON.PIC; a strip
                              of 32 x 32 frames = an animated icon)
  #NAME (after the keyword)   a name for that piece, so the app's program can read and change it: `input #city 0 2
                              20 1`, `text #status 0 4 waiting...` (WM_GET_TEXT, WM_SET_TEXT: app_defs.asm).
                              Enter in a one-row input goes to the app's key handler. sw/apps/greet shows it all
  shell COMMAND               a FULL-SCREEN app (no window): opening it (its icon, its taskbar button, Open on its
                              menu) hands its shell lines to the shell, and the window manager ends; the shell runs
                              them one by one, as if typed. sw/apps/terminal is one. End with `shell run /wm.bin` to
                              come back to the desktop after (the Terminal doesn't: you type desktop)
  animate COLUMN ROW FILE.PIC FRAMEWIDTH FRAMES SPEED
                              an animation: FILE.PIC is a strip, its FRAMES side by side, each FRAMEWIDTH dots wide;
                              SPEED frames a second (up to 10). An ICON.PIC wider than 32 is an animated icon (frames
                              of 32 x 32 side by side): sw/apps/cd/ shows both

Pictures: python project/tools/pictures/make_picture.py star.png --key --to star.pic
(--key: the PNG's transparent dots become 0xFE)
