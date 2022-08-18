// all numbers are bytes (u8)
// .---.--------------------.
// | 0 |                xyz |  wait for xyz beats
// '---'--------------------'
// .---.--------------------.-------------.--------------.
// | 1 | 0 |          instr |  <----u16 note freq -----> | play instrument with a note
// '---'--------------------'-------------'--------------'
// .---.--------------------.
// | 1 | 1 |          instr |  play instrument
// '---'--------------------'
//

const w4 = @import("wasm4.zig");

pub const Instrument = struct {
    freq1: u32 = 0,
    freq2: u32 = 0,
    attack: u32 = 0,
    decay: u32 = 0,
    sustain: u32 = 0,
    release: u32 = 0,
    peak_vol: u32 = 0,
    sustain_vol: u32 = 0,
    channel: u32 = 0,

    pub fn zero() Instrument {
        return Instrument{};
    }

    pub fn play(self: *const Instrument) void {
        w4.tone(toneFrequency(self.freq1, self.freq2), toneDuration(self.attack, self.decay, self.sustain, self.release), toneVolume(self.peak_vol, self.sustain_vol), self.channel);
    }

    pub fn play_with_note(self: *Instrument, note: u32) void {
        w4.tone(toneFrequency(note, self.freq2), toneDuration(self.attack, self.decay, self.sustain, self.release), toneVolume(self.peak_vol, self.sustain_vol), self.channel);
    }
};

fn toneFrequency(freq1: u32, freq2: u32) u32 {
    return freq1 | (freq2 << 16);
}

fn toneDuration(attack: u32, decay: u32, sustain: u32, release: u32) u32 {
    return (attack << 24) | (decay << 16) | sustain | (release << 8);
}

fn toneVolume(peak: u32, volume: u32) u32 {
    return (peak << 8) | volume;
}

fn toneFlags(channel: u32, mode: u32, pan: u32) u32 {
    return channel | (mode << 2) | (pan << 4);
}

pub const Musicode = struct {
    instruments: [8]Instrument,
    bpm_count: u32,
    track_index: usize,
    track: []const u8 = undefined,
    loop: bool = true,

    pub fn new() Musicode {
        var result = Musicode{
            .instruments = undefined,
            .bpm_count = 1,
            .track_index = 0,
        };

        var i: usize = 0;
        while (i < result.instruments.len) : (i += 1) {
            result.instruments[i] = Instrument.zero();
        }

        return result;
    }

    pub fn reset(self: *Musicode) void {
        self.track_index = 0;
    }

    pub fn start_track(self: *Musicode, track: []const u8, loop: bool) void {
        self.bpm_count = 1;
        self.track_index = 0;
        self.track = track;
        self.loop = loop;
    }

    pub fn play(self: *Musicode) void {
        if (self.bpm_count == 0) {
            var is_wait = false;
            while (is_wait == false and self.track_index < self.track.len) {
                const instrument = self.track[self.track_index];
                if (instrument & 0b1100_0000 == 0b1100_0000) {
                    // TODO
                    const i = self.instruments[instrument & 0b0011_1111];
                    i.play();
                } else if (instrument & 0b1000_0000 == 0b1000_0000) { // play with note
                    const i = instrument & 0b0011_1111;
                    var note: u32 = 0;
                    self.track_index += 1;
                    note = (note << 8) | self.track[self.track_index];
                    self.track_index += 1;
                    note = (note << 8) | self.track[self.track_index];
                    self.instruments[i].play_with_note(note);
                } else { // top bit is not set -> wait
                    self.bpm_count = instrument & 0b0011_1111;
                    is_wait = true;
                }
                self.track_index += 1;
                if (self.loop and self.track_index >= self.track.len) {
                    self.track_index = 0;
                }
            }
        } else {
            self.bpm_count -= 1;
        }
    }

    pub fn wait(frames: u8) u8 {
        return frames & 0b0111_1111;
    }

    pub fn instr_with_note(instr_id: usize) u8 {
        return (@intCast(u8, instr_id) & 0b0011_1111) | 0b1000_0000;
    }

    pub fn instr(instr_id: usize) u8 {
        return @intCast(u8, instr_id) | 0b1100_0000;
    }
};

const MusiscoreTag = enum {
    zero,
    instr,
    instr_with_note,
};

pub const MusiscoreInstrument = union(MusiscoreTag) {
    zero: void,
    instr: usize,
    instr_with_note: _MusiscoreInstrWithNote,

    pub fn instr_with_note(instr: usize, note: u16) MusiscoreInstrument {
        return MusiscoreInstrument{ .instr_with_note = _MusiscoreInstrWithNote{
            .instr = instr,
            .note = note,
        } };
    }
};

const _MusiscoreInstrWithNote = struct {
    instr: usize,
    note: u16,
};

pub const Musiscore = struct {
    instruments: [8]Instrument,
    bpm_count: u32,
    track_index: usize,

    pub fn new() Musiscore {
        var result = Musiscore{
            .instruments = undefined,
            .bpm_count = 1,
            .track_index = 0,
        };

        var i: usize = 0;
        while (i < result.instruments.len) : (i += 1) {
            result.instruments[i] = Instrument.zero();
        }

        return result;
    }

    fn play_instr(self: *Musiscore, instrr: MusiscoreInstrument) void {
        switch (instrr) {
            MusiscoreTag.zero => {},
            MusiscoreTag.instr => |instr_index| {
                self.instruments[instr_index].play();
            },
            MusiscoreTag.instr_with_note => |instr_with_note| {
                self.instruments[instr_with_note.instr].play_with_note(instr_with_note.note);
            },
        }
    }

    pub fn play(self: *Musiscore, track: []const MusiscoreInstrument) void {
        if (self.bpm_count == 0) {
            const i_chan1 = track[self.track_index];
            self.track_index += 1;
            const i_chan2 = track[self.track_index];
            self.track_index += 1;
            const i_chan3 = track[self.track_index];
            self.track_index += 1;
            const i_chan4 = track[self.track_index];
            self.track_index += 1;

            self.play_instr(i_chan1);
            self.play_instr(i_chan2);
            self.play_instr(i_chan3);
            self.play_instr(i_chan4);

            if (self.track_index >= track.len) {
                self.track_index = 0;
            }
            self.bpm_count = 15;
        } else {
            self.bpm_count -= 1;
        }
    }

    fn get_compiled_size_for_instr(instr: MusiscoreInstrument) usize {
        switch (instr) {
            MusiscoreTag.zero => {
                return 0;
            },
            MusiscoreTag.instr => |_instr_index| {
                _ = _instr_index;
                return 1; // instr(instr_index)
            },
            MusiscoreTag.instr_with_note => |_instr_with_note| {
                _ = _instr_with_note;
                return 3; // instr_with_note(instr), note_hi, note_low
            },
        }
    }

    pub fn get_compiled_size(track: []const MusiscoreInstrument) usize {
        var track_index: usize = 0;
        var result: usize = 0;
        while (track_index < track.len) : (track_index += 1) {
            result += get_compiled_size_for_instr(track[track_index]);
            if (track_index > 0 and @mod(track_index, 4) == 0) {
                result += 1;
            }
        }
        return result;
    }

    pub fn compile(track: []const MusiscoreInstrument, output: []u8) void {
        var track_index: usize = 0;
        var output_index: usize = 0;
        while (track_index < track.len) : (track_index += 1) {
            switch (track[track_index]) {
                MusiscoreTag.zero => {},
                MusiscoreTag.instr => |instr_index| {
                    output[output_index] = Musicode.instr(instr_index);
                    output_index += 1;
                },
                MusiscoreTag.instr_with_note => |instr_with_note| {
                    output[output_index] = Musicode.instr_with_note(instr_with_note.instr);
                    output_index += 1;
                    output[output_index] = @intCast(u8, instr_with_note.note >> 8 & 0xff);
                    output_index += 1;
                    output[output_index] = @intCast(u8, instr_with_note.note & 0xff);
                    output_index += 1;
                },
            }
            if (track_index > 0 and @mod(track_index, 4) == 0) {
                output[output_index] = Musicode.wait(15);
                output_index += 1;
            }
        }
        if (track_index > 0 and @mod(track_index, 4) == 0) {
            output[output_index] = Musicode.wait(15);
            output_index += 1;
        }
    }
};
