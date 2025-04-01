# Terminal color picker

This is a terminal based color picker. It is a little tool to help you choose
pick colors and translate them from / to different formats. It is linux only but
a macos version could happen as it really similar to linux. It is highly
inspired by [this website](https://htmlcolorcodes.com/).

<https://github.com/user-attachments/assets/063aa337-312d-4ef6-986d-950d8a76b35e>

The TUI draws a big square for color selection. This square could not appear
completely square depending on your font. For better looking squares, I
recommend using a font which has a 1:2 ratio such as
[FiraCode](https://github.com/tonsky/FiraCode).

It is mainly a way to learn Zig and do a nice TUI. I don't use any
libraries or external dependencies so all you need to compile it is Zig.

## Installation

I don't do packaging or releases. If you want to use it, you will need to build
it from source.

You need to have `zig` installed on your system. Then clone this repo, `cd` into
it and run `zig build` which will compile the program. You can find the output
in `./zig-out/bin/color-picker-tui`. Then move it to your path or use it as you
wish.

## Usage

Just drag your mouse over the gradients to select a color. You can also give the
colors in the input fields on the right. To validate the input, just press `enter`.
You can also paste in the input fields with `Ctrl + Shift + V` or `p`. To copy the
color, click on the relevant format at the top. 

To quit the program, you can do `Ctrl + C`, `escape` or `q`. 

> [!WARNING]
> The clipboard features only work in Wayland. X11 sucks and I don't
> want to support it.

## Note

This is a project I did to learn and explore many things at once. The codebase
is really messy and for some parts a disaster. I most likely won't fix it as
it is not the purpose. If you are interested, the things I explored are:
- Terminal UI
- Zig general concepts
- Zig comptime (really powerful)
- Buffers
- OOP composition (I now know that I don't like OOP)

I tried to make as little heap allocations as possible which isn't always the best
solution. But the allocators concept in Zig is really strong and I should probably
explore it more. I also don't use any other dependencies than zig's standard library. 

