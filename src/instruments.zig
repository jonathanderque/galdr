const w4 = @import("wasm4.zig");
const n = @import("notes.zig");
const Instrument = @import("musicode.zig").Instrument;
const musicode = @import("musicode.zig");
const MusiscoreInstrument = musicode.MusiscoreInstrument;

pub const z = MusiscoreInstrument.zero;
pub const sweep = MusiscoreInstrument{ .instr = 1 };
pub const kick = MusiscoreInstrument{ .instr = 3 };
pub const snare = MusiscoreInstrument{ .instr = 4 };
pub const hh = MusiscoreInstrument{ .instr = 5 };
pub fn sweepn(note: u16) MusiscoreInstrument {
    return MusiscoreInstrument.instr_with_note(1, note);
}
pub fn bassn(note: u16) MusiscoreInstrument {
    return MusiscoreInstrument.instr_with_note(6, note);
}
pub fn basslongn(note: u16) MusiscoreInstrument {
    return MusiscoreInstrument.instr_with_note(9, note);
}
pub fn leadn(note: u16) MusiscoreInstrument {
    return MusiscoreInstrument.instr_with_note(2, note);
}
pub fn leadlongn(note: u16) MusiscoreInstrument {
    return MusiscoreInstrument.instr_with_note(10, note);
}

pub const instruments = [_]Instrument{
    Instrument{
        .freq1 = 440,
        .decay = 2,
        .sustain = 5,
        .release = 1,
        .sustain_vol = 4,
        .channel = w4.TONE_PULSE1,
    },
    // sweep
    Instrument{
        .freq1 = n.A3,
        .attack = 26,
        .decay = 45,
        .sustain = 1,
        .release = 44,
        .peak_vol = 20,
        .sustain_vol = 1,
        .channel = w4.TONE_PULSE1,
    },
    // lead
    Instrument{
        .freq1 = n.A3,
        .sustain = 10,
        .sustain_vol = 30,
        .channel = w4.TONE_PULSE2,
    },
    // kick
    Instrument{ .freq1 = 150, .sustain = 5, .sustain_vol = 10, .channel = w4.TONE_NOISE },
    // snare
    Instrument{ .freq1 = 500, .sustain = 5, .sustain_vol = 10, .channel = w4.TONE_NOISE },
    // hi hats
    Instrument{ .freq1 = 700, .sustain = 3, .sustain_vol = 10, .channel = w4.TONE_NOISE },
    // bass
    Instrument{ .freq1 = 100, .attack = 1, .sustain = 20, .sustain_vol = 80, .channel = w4.TONE_TRIANGLE },
    // hit SFX
    Instrument{ .freq1 = 330, .freq2 = 190, .release = 100, .sustain_vol = 80, .channel = w4.TONE_NOISE },
    // death SFX
    Instrument{ .freq1 = 500, .sustain = 5, .sustain_vol = 80, .channel = w4.TONE_NOISE },
    // bass long
    Instrument{ .freq1 = 100, .attack = 1, .sustain = 40, .sustain_vol = 80, .channel = w4.TONE_TRIANGLE },
    // lead long
    Instrument{ .freq1 = 100, .attack = 1, .sustain = 40, .sustain_vol = 20, .channel = w4.TONE_PULSE1 },
    // block SFX
    Instrument{ .freq1 = 150, .sustain = 5, .sustain_vol = 60, .channel = w4.TONE_NOISE },
};
