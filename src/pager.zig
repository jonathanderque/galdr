const w4 = @import("wasm4.zig");

// font 4 wide 7 tall

pub const f47_letter_width = 4;
pub const f47_letter_height = f47_height;
pub const f47_width = 104;
pub const f47_height = 7;
pub const f47_flags = 0; // BLIT_1BPP

// upper case letters (A - Z)
const f47_uppercase_letters = [91]u8{ 0x91, 0x91, 0x00, 0x96, 0x10, 0x67, 0x66, 0x91, 0x91, 0x81, 0x66, 0x66, 0x50, 0x66, 0x66, 0x77, 0x66, 0xbe, 0x57, 0x06, 0x66, 0x66, 0x7b, 0x66, 0x66, 0x5e, 0x66, 0x76, 0x77, 0x76, 0xbe, 0x37, 0x02, 0x66, 0x66, 0x7b, 0x66, 0x66, 0x5d, 0x61, 0x76, 0x11, 0x40, 0xbe, 0x77, 0x64, 0x61, 0x61, 0x9b, 0x66, 0x69, 0xbb, 0x06, 0x76, 0x77, 0x66, 0xbe, 0x37, 0x66, 0x67, 0x65, 0xeb, 0x66, 0x06, 0xb7, 0x66, 0x66, 0x77, 0x66, 0xb6, 0x57, 0x66, 0x67, 0x56, 0xeb, 0x6a, 0x06, 0xb7, 0x61, 0x91, 0x07, 0x96, 0x19, 0x60, 0x66, 0x97, 0xa6, 0x1b, 0x9c, 0x66, 0xb0 };

// lower case letters (a - z)
const f47_lowercase_letters = [91]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xf7, 0xfe, 0xf8, 0xf7, 0xbf, 0x77, 0xff, 0xff, 0xff, 0xf7, 0xff, 0xff, 0xff, 0x97, 0x9e, 0x97, 0x97, 0xf8, 0x67, 0x65, 0x99, 0x95, 0x81, 0x66, 0x66, 0x60, 0x61, 0x68, 0x01, 0x01, 0x3e, 0x67, 0x02, 0x66, 0x62, 0x37, 0x66, 0x66, 0x0d, 0x06, 0x76, 0x77, 0xe5, 0xbe, 0x17, 0x66, 0x61, 0x87, 0xc7, 0x65, 0x09, 0xeb, 0x61, 0x98, 0x97, 0x95, 0x11, 0x68, 0x66, 0x97, 0xe7, 0x18, 0x8b, 0x66, 0x80 };

// numbers (0 - 9)
const f47_numbers_width = 40;
const f47_numbers = [35]u8{ 0x9b, 0x99, 0xc0, 0x90, 0x99, 0x63, 0x66, 0xa7, 0x6e, 0x66, 0x6b, 0xee, 0x67, 0x7d, 0x66, 0x6b, 0xd9, 0x01, 0x1b, 0x98, 0x6b, 0xbe, 0xee, 0x6b, 0x6e, 0x6b, 0x76, 0xee, 0x6b, 0x66, 0x91, 0x09, 0xe1, 0x9b, 0x99 };

// symbols1: !"#$%&'()*+,-./
const f47_symbols1_width = 64;
const f47_symbols1 = [56]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x35, 0x9f, 0xfb, 0x7b, 0x7f, 0xff, 0xff, 0xff, 0x35, 0x0f, 0x65, 0x77, 0xb5, 0xbf, 0xff, 0xef, 0x3f, 0x9f, 0xd0, 0xf7, 0xbb, 0x1f, 0x1f, 0xdf, 0xff, 0x0f, 0xb5, 0xf7, 0xb5, 0xbb, 0xff, 0xbf, 0x3f, 0x9f, 0x61, 0xfb, 0x7f, 0xf7, 0xf7, 0x7f };

// symbols2: :;<=>?
const f47_symbols2_width = 24;
const f47_symbols2 = [21]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xdf, 0x71, 0xfb, 0xb0, 0xbe, 0x7f, 0x7f, 0xd9, 0xfb, 0xb0, 0xbf, 0x77, 0xdf, 0x79 };

// font 3 wide 5 tall
const f35_width = 80;
const f35_height = 5;
const f35_flags = 0; // BLIT_1BPP
const f35_letter_width = 3;
const f35_letter_height = f35_height;
// 3-wide 5-tall font
// upper case letters (A - Z)
const f35_letters_uppercase = [50]u8{ 0xa6, 0x10, 0x22, 0x01, 0x34, 0x49, 0x06, 0x04, 0x92, 0x43, 0x49, 0xa6, 0xda, 0xb8, 0xb0, 0x92, 0x49, 0xd4, 0x92, 0x5b, 0x05, 0xa2, 0x50, 0xb8, 0xb4, 0x90, 0x46, 0xd4, 0x95, 0xb7, 0x49, 0xa6, 0xd2, 0xb9, 0x34, 0x93, 0x2b, 0x54, 0x82, 0xaf, 0x46, 0x10, 0xe2, 0x05, 0x04, 0x83, 0xc8, 0xd1, 0x52, 0xa3 };

// lower case letters (a - z)
const f35_letters_lowercase = [50]u8{ 0xef, 0xef, 0x7b, 0xbd, 0xbf, 0xff, 0xff, 0xbf, 0xff, 0xff, 0x8e, 0x60, 0x83, 0xe1, 0xb0, 0xe8, 0x08, 0x14, 0x92, 0x43, 0xcd, 0xe0, 0xc1, 0x39, 0x30, 0x10, 0x04, 0xb4, 0x95, 0x53, 0x01, 0x86, 0x72, 0xb8, 0xb4, 0x93, 0xce, 0x34, 0x85, 0xa7, 0x00, 0x02, 0xca, 0x05, 0x44, 0xab, 0xcc, 0x49, 0x42, 0xa3 };

// numbers (0 - 9)
const f35_numbers_width = 32;
const f35_numbers = [20]u8{ 0xb4, 0x04, 0x00, 0x03, 0x47, 0x64, 0xde, 0x4b, 0x54, 0x40, 0x06, 0x03, 0x55, 0xed, 0x96, 0x5b, 0xa0, 0x0c, 0x46, 0x03 };

// symbols1: !"#$%&'()*+,-./
const f35_symbols1_width = 48;
const f35_symbols1 = [30]u8{ 0xab, 0xf5, 0xdd, 0x7f, 0xff, 0xff, 0xab, 0xfd, 0x5b, 0xaa, 0xff, 0xf7, 0xbf, 0xfa, 0x3b, 0xb4, 0x71, 0xef, 0xff, 0xf6, 0x7b, 0xaa, 0xdf, 0xdf, 0xbf, 0xf4, 0x3d, 0x7f, 0xbe, 0xff };

// symbols2: :;<=>?
const f35_symbols2_width = 24;
const f35_symbols2 = [15]u8{ 0xff, 0x76, 0x3f, 0x76, 0x8b, 0xbf, 0xfd, 0xfd, 0x7f, 0x76, 0x8b, 0xff, 0xef, 0x77, 0x7f };

// TODO: do not modify pager.cursor_x directly here
// this works because we are passing consistant values to
// maybe_warp and cursor_x increment
fn f47_letter(pager: *Pager, letter: u8) void {
    pager.maybe_warp(f47_letter_width, f47_letter_height + 1);

    if (pager.progressive_display and !pager.should_display()) {
        return;
    }

    if (letter >= 'A' and letter <= 'Z') {
        var letter_x: u32 = (letter - 'A') * f47_letter_width;
        w4.blitSub(&f47_uppercase_letters, pager.cursor_x, pager.get_y(), f47_letter_width, f47_letter_height, letter_x, 0, f47_width, w4.BLIT_1BPP);
        pager.cursor_x += f47_letter_width + 1;
    } else if (letter >= 'a' and letter <= 'z') {
        var letter_x: u32 = (letter - 'a') * f47_letter_width;
        w4.blitSub(&f47_lowercase_letters, pager.cursor_x, pager.get_y(), f47_letter_width, f47_letter_height, letter_x, 0, f47_width, w4.BLIT_1BPP);
        pager.cursor_x += f47_letter_width + 1;
    } else if (letter >= '0' and letter <= '9') {
        var letter_x: u32 = (letter - '0') * f47_letter_width;
        w4.blitSub(&f47_numbers, pager.cursor_x, pager.get_y(), f47_letter_width, f47_letter_height, letter_x, 0, f47_numbers_width, w4.BLIT_1BPP);
        pager.cursor_x += f47_letter_width + 1;
    } else if (letter >= '!' and letter <= '/') {
        var letter_x: u32 = (letter - '!') * f47_letter_width;
        w4.blitSub(&f47_symbols1, pager.cursor_x, pager.get_y(), f47_letter_width, f47_letter_height, letter_x, 0, f47_symbols1_width, w4.BLIT_1BPP);
        pager.cursor_x += f47_letter_width + 1;
    } else if (letter >= ':' and letter <= '?') {
        var letter_x: u32 = (letter - ':') * f47_letter_width;
        w4.blitSub(&f47_symbols2, pager.cursor_x, pager.get_y(), f47_letter_width, f47_letter_height, letter_x, 0, f47_symbols2_width, w4.BLIT_1BPP);
        pager.cursor_x += f47_letter_width + 1;
    } else if (letter == ' ') {
        pager.cursor_x += f47_letter_width;
    } else if (letter == '\n') {
        pager.warp(f47_letter_height + 1);
    }
    pager.incr_step();
}

// caller should guarantee there is no white space ([ \r\n\t]) in slice
fn f47_word(pager: *Pager, str: []const u8, start_idx: usize, end_idx: usize) void {
    pager.maybe_warp(@intCast(i32, end_idx - start_idx) * f47_letter_width, f47_letter_height + 1);
    var i: usize = start_idx;
    while (i < end_idx) : (i += 1) {
        f47_letter(pager, str[i]);
    }
}

fn find_next_whitespace(str: []const u8, from: usize) usize {
    var idx: usize = from;
    while (idx < str.len) : (idx += 1) {
        if (str[idx] == ' ') {
            return idx + 1;
        }
    }
    return idx;
}

pub fn f47_text(pager: *Pager, str: []const u8) void {
    var idx: usize = 0;
    while (idx < str.len) {
        const new_idx = find_next_whitespace(str, idx);
        f47_word(pager, str, idx, new_idx);
        _ = pager;
        idx = new_idx;
    }
}

pub fn f47_newline(pager: *Pager) void {
    pager.warp(f47_letter_height + 1);
}

// n should be strictly > 0 !
fn f47_number_positive(pager: *Pager, n: i32) void {
    const buffer_size = 32;
    var buffer: [buffer_size]u8 = undefined;
    var i: usize = 0;
    var x: i32 = n;
    while (i < buffer_size and x > 0) : (i += 1) {
        const digit = @mod(x, 10);
        buffer[i] = @intCast(u8, digit);
        x = @divFloor(x, 10);
    }
    i -= 1;
    while (i > 0) : (i -= 1) {
        f47_letter(pager, buffer[i] + '0');
    }
    f47_letter(pager, buffer[0] + '0');
}

pub fn f47_number(pager: *Pager, n: i32) void {
    if (n > 0) {
        f47_number_positive(pager, n);
    } else if (n < 0) {
        f47_letter(pager, '-');
        f47_number_positive(pager, -n);
    } else {
        f47_letter(pager, '0');
    }
}

// TODO: do not modify pager.cursor_x directly here
// this works because we are passing consistant values to
// maybe_warp and cursor_x increment
fn f35_letter(pager: *Pager, letter: u8) void {
    pager.maybe_warp(f35_letter_width, f35_letter_height + 1);

    if (pager.progressive_display and !pager.should_display()) {
        return;
    }

    if (letter >= 'A' and letter <= 'Z') {
        var letter_x: u32 = (letter - 'A') * f35_letter_width;
        w4.blitSub(&f35_letters_uppercase, pager.cursor_x, pager.get_y(), f35_letter_width, f35_letter_height, letter_x, 0, f35_width, w4.BLIT_1BPP);
        pager.cursor_x += f35_letter_width + 1;
    } else if (letter >= 'a' and letter <= 'z') {
        var letter_x: u32 = (letter - 'a') * f35_letter_width;
        w4.blitSub(&f35_letters_lowercase, pager.cursor_x, pager.get_y(), f35_letter_width, f35_letter_height, letter_x, 0, f35_width, w4.BLIT_1BPP);
        pager.cursor_x += f35_letter_width + 1;
    } else if (letter >= '0' and letter <= '9') {
        var letter_x: u32 = (letter - '0') * f35_letter_width;
        w4.blitSub(&f35_numbers, pager.cursor_x, pager.get_y(), f35_letter_width, f35_letter_height, letter_x, 0, f35_numbers_width, w4.BLIT_1BPP);
        pager.cursor_x += f35_letter_width + 1;
    } else if (letter >= '!' and letter <= '/') {
        var letter_x: u32 = (letter - '!') * f35_letter_width;
        w4.blitSub(&f35_symbols1, pager.cursor_x, pager.get_y(), f35_letter_width, f35_letter_height, letter_x, 0, f35_symbols1_width, w4.BLIT_1BPP);
        pager.cursor_x += f35_letter_width + 1;
    } else if (letter >= ':' and letter <= '?') {
        var letter_x: u32 = (letter - ':') * f35_letter_width;
        w4.blitSub(&f35_symbols2, pager.cursor_x, pager.get_y(), f35_letter_width, f35_letter_height, letter_x, 0, f35_symbols2_width, w4.BLIT_1BPP);
        pager.cursor_x += f35_letter_width + 1;
    } else if (letter == ' ') {
        pager.cursor_x += f35_letter_width + 1;
    } else if (letter == '\n') {
        pager.warp(f35_letter_height + 1);
    }
    pager.incr_step();
}

// caller should guarantee there is no white space ([ \r\n\t]) in slice
fn f35_word(pager: *Pager, str: []const u8, start_idx: usize, end_idx: usize) void {
    pager.maybe_warp(@intCast(i32, end_idx - start_idx) * f35_letter_width, f35_letter_height + 1);
    var i: usize = start_idx;
    while (i < end_idx) : (i += 1) {
        f35_letter(pager, str[i]);
    }
}

pub fn f35_text(pager: *Pager, str: []const u8) void {
    var idx: usize = 0;
    while (idx < str.len) {
        const new_idx = find_next_whitespace(str, idx);
        f35_word(pager, str, idx, new_idx);
        _ = pager;
        idx = new_idx;
    }
}

pub fn f35_newline(pager: *Pager) void {
    pager.warp(f35_letter_height + 1);
}

// n should be strictly > 0 !
fn f35_number_positive(pager: *Pager, n: i32) void {
    const buffer_size = 32;
    var buffer: [buffer_size]u8 = undefined;
    var i: usize = 0;
    var x: i32 = n;
    while (i < buffer_size and x > 0) : (i += 1) {
        const digit = @mod(x, 10);
        buffer[i] = @intCast(u8, digit);
        x = @divFloor(x, 10);
    }
    i -= 1;
    while (i > 0) : (i -= 1) {
        f35_letter(pager, buffer[i] + '0');
    }
    f35_letter(pager, buffer[0] + '0');
}

pub fn f35_number(pager: *Pager, n: i32) void {
    if (n > 0) {
        f35_number_positive(pager, n);
    } else if (n < 0) {
        f35_letter(pager, '-');
        f35_number_positive(pager, -n);
    } else {
        f35_letter(pager, '0');
    }
}

const screen_width = 160;
const margin_left = 10;
const margin_right = 10;
pub const Pager = struct {
    cursor_x: i32,
    cursor_y: i32,
    progressive_display: bool, // if we should display text progressively
    steps: usize, // how many glyphs we've displayed in this frame
    max_steps: usize, // how many glyphs we should display this frame
    // animations attributes
    animation_flag: bool, // maybe an enum of different animation types?
    animation_step: usize,

    pub fn new() Pager {
        return Pager{
            .cursor_x = margin_left,
            .cursor_y = 10,
            .steps = 0,
            .max_steps = 999,
            .progressive_display = false,
            .animation_flag = false,
            .animation_step = 0,
        };
    }

    fn get_y(self: *Pager) i32 {
        if (self.animation_flag) {
            //var animated_y: i32 = @intCast(i32, @mod(self.steps + self.animation_step, 3)) - 2;
            var animated_y: i32 = @intCast(i32, @mod(self.steps + self.animation_step, 2)) - 1;

            return self.cursor_y + animated_y;
        } else {
            return self.cursor_y;
        }
    }

    pub fn set_cursor(self: *Pager, x: i32, y: i32) void {
        self.cursor_x = x;
        if (self.cursor_x < margin_left) {
            self.cursor_x = margin_left;
        }
        self.cursor_y = y;
    }

    pub fn warp(self: *Pager, y_increment: i32) void {
        self.cursor_x = margin_left;
        self.cursor_y += y_increment;
    }

    fn maybe_warp(self: *Pager, x_increment: i32, y_increment: i32) void {
        if (self.cursor_x + x_increment > screen_width - margin_right) {
            self.warp(y_increment);
        }
    }

    pub fn incr_step(self: *Pager) void {
        self.steps += 1;
    }

    pub fn reset_steps(self: *Pager) void {
        self.steps = 0;
    }

    pub fn set_max_steps(self: *Pager, s: usize) void {
        self.max_steps = s;
    }

    fn should_display(self: *Pager) bool {
        return self.steps < self.max_steps;
    }

    pub fn animate(self: *Pager, flag: bool) void {
        self.animation_flag = flag;
    }

    pub fn set_progressive_display(self: *Pager, flag: bool) void {
        self.progressive_display = flag;
    }
};
