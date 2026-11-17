STYLES: how windows look (read by the window manager, WM.BIN)

On the card: /SYSTEM/DESIGN/WINDOWS/NAME/STYLE.TXT, plus any pictures it uses. This folder is the PC's copy.
A page picks a style with the line   style NAME   (no such style: the default, the grey Windows 95 look).
Up to 11 styles can be in use at once (besides the default).
STYLES.TXT (in this folder, on the card /SYSTEM/DESIGN/WINDOWS/STYLES.TXT) lists the styles, one name a line: Studio's
Style button goes through them in that order (then back to the default). Add a new style's name there.

A style file: one line each, any order; a line it leaves out keeps the default's value. Places are in DOTS,
counted from the window's top-left; a number below 0 counts back from the right / bottom edge (-21 = 21 dots in
from the right). Colours are in hex, like the palette (38 = colour 3, shade 8). Lines starting with ; are notes.

  content LEFT TOP RIGHT BOTTOM     the margins around the cells. The window's size = the cells + these
                                    (default 8 28 8 6). TOP must leave room for the header
  frame FILL LIGHT DARK             the frame's colour, its top/left edge, its bottom/right edge (F0 0F F1)
  panel LEFT TOP RIGHT BOTTOM COLOUR EDGE
                                    the panel behind the cells: its margins, its colour, the line above it
                                    (3 24 3 3 0F F1)
  header LEFT TOP RIGHT HEIGHT FROM TO BACKFROM BACKTO
                                    the title bar: its margins, its top, its height, then its colours from left to
                                    right (8 strips blending FROM -> TO) when the window is at the front, and
                                    BACKFROM -> BACKTO when it's behind (3 3 3 18 38 3F 06 0D). A TOP below 0 puts
                                    it at the bottom. Dragging the header moves the window
  title X Y FRONT BACK              the title's place IN THE HEADER and its colour at the front / behind
                                    (3 1 0F F0)
  close X Y [DRAW]                  the close box (16 x 16): its place in the window (-21 4); a 3rd number 0 = don't
                                    draw the box (the picture has its own x): it still closes the window there
  full X Y [DRAW]                   the full-screen button (16 x 16): its place in the window (-38 4); 0 = don't
                                    draw it (the picture has its own). Clicking it: the window fills the screen
                                    above the taskbar; again: back to how it was
  picture FILE.PIC LEFT TOP RIGHT BOTTOM
                                    a DRAWN style: the window is your picture, fitted to its size (9-slice). The 4
                                    numbers are the slice lines (dots in from each edge): the corners stay as drawn,
                                    the strips between them repeat across / down, the middle repeats both ways.
                                    Colour 0xFE in it is see-through (round corners). With a picture, frame, panel
                                    and the header's colours aren't drawn (the header's place still says where to
                                    drag the window and where the title goes). Paint one in the editor's Draw mode;
                                    every style here was made from a pixel design with make_window_style.py
  decoration FILE.PIC X Y           a picture drawn on top, see-through (0xFE dots skipped), up to 2. Its place
                                    can be over the window's edge (e.g. -10 0). Make one with
                                    python project/tools/pictures/make_picture.py star.png --key

Put a style on the card (make the folders first on the computer: mkdir /system/design/windows, then
mkdir /system/design/windows/classic):
  sh project/tools/scripts/sendfile.sh sw/graphics/designs/windows/classic/style.txt --to /system/design/windows/classic/style.txt
  sh project/tools/scripts/sendfile.sh sw/graphics/designs/windows/classic/frame.pic --to /system/design/windows/classic/frame.pic
A new style from a drawing (a filled PNG + the same with its text area cut out in magenta):
  python project/tools/pictures/make_window_style.py window.png window-open-center.png NAME
Or design it in the page editor's Style mode and press Send.
