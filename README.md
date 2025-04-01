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

This is a project I did to learn and explore many things at once. The codebase
is really messy and for some parts a disaster. I most likely won't fix it as
it is not the purpose. If you are interested, the things I explored are:
- Terminal UI
- Zig general concepts
- Zig comptime (really powerful)
- Buffers
- OOP composition (I now know that I don't like OOP)

I tried to make as little allocations as possible which isn't a viable solution
in production code. But the allocators concept in Zig is really strong and I
should probably explore it more. I also don't use any other dependencies than zig's
standard library. 

