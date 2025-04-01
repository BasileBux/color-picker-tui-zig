pub const Vec2 = struct {
    x: u32,
    y: u32,
};

pub fn sum_buff(buffer: []usize) usize {
    var sum: usize = 0;
    for (buffer) |value| {
        sum += value;
    }
    return sum;
}

pub fn shift_right(buffer: []u8, start: usize, end: usize, shift: usize) void {
    if (start >= end or shift == 0) return;

    var i: usize = end;
    while (i > start) {
        i -= 1;
        if (i + shift < buffer.len) {
            buffer[i + shift] = buffer[i];
        }
    }
}

pub fn shift_left(buffer: []u8, start: usize, end: usize, shift: usize) void {
    if (start >= end or shift == 0) return;

    var i: usize = start;
    while (i < end) {
        if (i + shift < buffer.len) {
            buffer[i] = buffer[i + shift];
        }
        i += 1;
    }
}

pub fn hex_string_to_int(hex_str: []u8) u24 {
    var result: u24 = 0;
    for (hex_str) |c| {
        const digit: u24 = switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => unreachable,
        };
        result = result * 16 + digit;
    }
    return result;
}

pub fn string_to_int(value: []u8) u32 {
    var result: u16 = 0;
    for (value) |char| {
        if (char < '0' or char > '9') {
            continue;
        }
        const digit = char - '0';
        result = result * 10 + digit;
    }
    return result;
}
