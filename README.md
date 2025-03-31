# Terminal color picker

This is a terminal based color picker. It is a little tool to help you choose
pick colors and translate them from / to different formats. It is linux only but
a macos version could happen as it really similar to linux. It is highly
inspired by [this](https://htmlcolorcodes.com/).

The TUI draws a big square for color selection. This square could not appear
completely square depending on your font. For better looking squares, I
recommend using a font which has a 1:2 ratio such as
[FiraCode](https://github.com/tonsky/FiraCode).

It is mainly a way to learn `zig` and do a nice TUI. I won't use any
dependencies at all so all you need to compile it is `zig`.

> [!WARNING]
> The clipboard features only work in Wayland. X11 sucks and I don't
> want to support it.

## Usage

You need to have `zig` installed on your system. Then clone this repo, `cd` into
it and run `zig build` which will compile the program. You can find the output
in `./zig-out/bin/color-picker-tui`. Then move it to your path or use it as you
wish.

## Note

This project doesn't use any dependencies. So if you want to learn how to do a
TUI (in zig), you can just read the code. My implementation is far from perfect
and is in no way a reference, but it works. If you want to learn more about
terminals, [this blogpost](https://poor.dev/blog/terminal-anatomy/) is amazing.
