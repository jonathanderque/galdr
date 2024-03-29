const w4 = @import("wasm4.zig");
const pager = @import("pager.zig");
const sprites = @import("sprites.zig");
const musicode = @import("musicode.zig");
const instruments = @import("instruments.zig");
const tracks = @import("tracks.zig");
const Instrument = musicode.Instrument;
const Musicode = musicode.Musicode;

const rand_a: u64 = 6364136223846793005;
const rand_c: u64 = 1442695040888963407;
var rand_state: u64 = 0;

pub fn rand() u64 {
    rand_state = @addWithOverflow(@mulWithOverflow(rand_state, rand_a)[0], rand_c)[0];
    return (rand_state >> 32) & 0xFFFFFFFF;
}

const Palette = struct {
    bg_color: u32,
    fg_color: u32,
};

const palettes = [_]Palette{
    // 1-bit black and white
    Palette{
        .bg_color = 0x000000,
        .fg_color = 0xcccccc,
    },
    // GB from downwell
    Palette{
        .bg_color = 0x323b28,
        .fg_color = 0x6d7f56,
    },
    // VBOY from downwell
    Palette{
        .bg_color = 0x000000,
        .fg_color = 0xab0000,
    },
    // Pastel from downwell
    Palette{
        .bg_color = 0x1d50c3,
        .fg_color = 0xfe7160,
    },
    // Grandma from downwell
    Palette{
        .bg_color = 0x630e34,
        .fg_color = 0xfeb17e,
    },
    // Purply from downwell
    Palette{
        .bg_color = 0x341a12,
        .fg_color = 0x8964b4,
    },
    // Oldncold from downwell
    Palette{
        .bg_color = 0x041e37,
        .fg_color = 0x69ccef,
    },
    // Dirtsnow from downwell
    Palette{
        .bg_color = 0xa4a4a4,
        .fg_color = 0x4b4b4b,
    },
};

pub fn change_palette(index: usize) void {
    const p = palettes[index];
    w4.PALETTE.* = .{
        p.bg_color,
        p.fg_color,
        p.fg_color,
        p.fg_color,
    };
}

pub fn color_component_transition(from: i32, to: i32, current_step: u16, max_steps: u16) u32 {
    const incr: i32 = @divTrunc((to - from) * current_step, max_steps);
    return @as(u32, @intCast(@as(i16, @intCast(from)) + incr));
}

pub fn rgb_transition(from: u32, to: u32, current_step: u16, max_steps: u16) u32 {
    const from_b = @as(i32, @intCast(from & 0xff));
    const from_g = @as(i32, @intCast((from >> 8) & 0xff));
    const from_r = @as(i32, @intCast((from >> 16) & 0xff));
    const to_b = @as(i32, @intCast(to & 0xff));
    const to_g = @as(i32, @intCast((to >> 8) & 0xff));
    const to_r = @as(i32, @intCast((to >> 16) & 0xff));
    const result_b = color_component_transition(from_b, to_b, current_step, max_steps);
    const result_g = color_component_transition(from_g, to_g, current_step, max_steps);
    const result_r = color_component_transition(from_r, to_r, current_step, max_steps);
    return (result_r & 0xff) << 16 | (result_g & 0xff) << 8 | (result_b & 0xff);
}

const Reward = union(enum(u8)) {
    no_reward: void,
    gold_reward: u16,
    spell_reward: Spell,
    alignment_reward: i8,
    kidnapped_daughter_reward: void,
};

const Effect = union(enum(u8)) {
    no_effect: void,
    toggle_inventory_menu: void,
    damage_to_player: i16,
    damage_to_enemy: i16,
    vampirism_to_player: i16,
    vampirism_to_enemy: i16,
    player_heal: u16,
    player_healing_max: void,
    player_shield: i16,
    enemy_shield: i16,
    gold_payment: u16,
    alignment: i16,
    curse: curse,
};

const spell_max_size: usize = 8;
const end_of_spell: u8 = 0;
const Spell = struct {
    name: []const u8 = "",
    input: [spell_max_size]u8 = [_]u8{
        end_of_spell,
        end_of_spell,
        end_of_spell,
        end_of_spell,
        end_of_spell,
        end_of_spell,
        end_of_spell,
        end_of_spell,
    },
    price: u16 = 0,
    alignment: i8 = 0,
    current_progress: usize = 0,
    effect: Effect = Effect.no_effect,
    frame_triggered: i16 = -99, // used for visual feedback

    pub fn zero() Spell {
        var spell = Spell{
            .name = "",
            .input = undefined,
            .current_progress = 0,
            .frame_triggered = -99,
            .effect = Effect.no_effect,
        };
        var i: usize = 0;
        while (i < spell_max_size) : (i += 1) {
            spell.input[i] = end_of_spell;
        }
        return spell;
    }

    pub fn reset(self: *Spell) void {
        self.current_progress = 0;
    }

    pub fn process(self: *Spell, input: u8) void {
        if (input == end_of_spell) {
            return;
        }
        if (input == self.input[self.current_progress]) {
            self.current_progress += 1;
        } else {
            self.reset();
        }
    }

    pub fn is_completed(self: *Spell) bool {
        return (self.input[self.current_progress] == end_of_spell);
    }

    pub fn is_defined(self: *const Spell) bool {
        return (self.input[0] != end_of_spell);
    }

    pub fn set_spell(self: *Spell, input: []const u8) void {
        var i: usize = 0;
        while (i < self.input.len and i < input.len) : (i += 1) {
            self.input[i] = input[i];
        }
        if (i < self.input.len) {
            self.input[i] = end_of_spell;
        }
    }

    //// spell library

    pub fn spell_inventory_menu() Spell {
        var s = Spell{
            .name = "_inventory menu",
            .effect = Effect.toggle_inventory_menu,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_2, w4.BUTTON_2, w4.BUTTON_1, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_title_tutorial() Spell {
        var s = Spell{
            .name = "Tutorial",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{w4.BUTTON_2});
        return s;
    }

    pub fn spell_title_options() Spell {
        var s = Spell{
            .name = "Options",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_title_start_game() Spell {
        var s = Spell{
            .name = "Start Game",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_tutorial_basics_next() Spell {
        var s = Spell{
            .name = "Next",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_tutorial_synergies_heal() Spell {
        var s = Spell{
            .name = "Heal",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_tutorial_synergies_next() Spell {
        var s = Spell{
            .name = "Next",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1, w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_sword() Spell {
        var s = Spell{
            .name = "Sword",
            .price = 9,
            .alignment = -2,
            .effect = Effect{ .damage_to_enemy = 3 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_squawk() Spell {
        var s = Spell{
            .name = "Squawk",
            .price = 11,
            .alignment = 0,
            .effect = Effect{ .damage_to_enemy = 1 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_UP, w4.BUTTON_UP, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_fireball() Spell {
        var s = Spell{
            .name = "Fireball",
            .price = 5,
            .alignment = -2,
            .effect = Effect{ .damage_to_enemy = 6 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_RIGHT,
            w4.BUTTON_LEFT,
            w4.BUTTON_LEFT,
            w4.BUTTON_1,
            w4.BUTTON_DOWN,
            w4.BUTTON_2,
        });
        return s;
    }

    pub fn spell_ash() Spell {
        var s = Spell{
            .name = "Ash",
            .price = 5,
            .alignment = -1,
            .effect = Effect{ .damage_to_enemy = 2 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_LEFT,
            w4.BUTTON_LEFT,
            w4.BUTTON_1,
            w4.BUTTON_DOWN,
        });
        return s;
    }

    pub fn spell_shade() Spell {
        var s = Spell{
            .name = "Shade",
            .price = 12,
            .alignment = 0,
            .effect = Effect{ .player_shield = 4 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_DOWN,
            w4.BUTTON_DOWN,
            w4.BUTTON_RIGHT,
            w4.BUTTON_1,
        });
        return s;
    }

    pub fn spell_lightning() Spell {
        var s = Spell{
            .name = "Lightning",
            .alignment = 3,
            .price = 3,
            .effect = Effect{ .damage_to_enemy = 4 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_UP,
            w4.BUTTON_UP,
            w4.BUTTON_LEFT,
            w4.BUTTON_1,
            w4.BUTTON_RIGHT,
            w4.BUTTON_2,
        });
        return s;
    }

    pub fn spell_bolt() Spell {
        var s = Spell{
            .name = "Bolt",
            .alignment = 2,
            .price = 3,
            .effect = Effect{ .damage_to_enemy = 3 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_UP,
            w4.BUTTON_UP,
            w4.BUTTON_LEFT,
            w4.BUTTON_1,
        });
        return s;
    }

    pub fn spell_shield() Spell {
        var s = Spell{
            .name = "Shield",
            .price = 12,
            .alignment = 2,
            .effect = Effect{ .player_shield = 5 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_DOWN,
            w4.BUTTON_DOWN,
            w4.BUTTON_RIGHT,
            w4.BUTTON_1,
        });
        return s;
    }

    pub fn spell_ice_wall() Spell {
        var s = Spell{
            .name = "Ice Wall",
            .price = 4,
            .alignment = -2,
            .effect = Effect{ .player_shield = 5 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_UP,
            w4.BUTTON_UP,
            w4.BUTTON_2,
            w4.BUTTON_DOWN,
        });
        return s;
    }

    pub fn spell_ice_shard() Spell {
        var s = Spell{
            .name = "Ice Shard",
            .price = 7,
            .alignment = -2,
            .effect = Effect{ .damage_to_enemy = 9 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_DOWN,
            w4.BUTTON_UP,
            w4.BUTTON_UP,
            w4.BUTTON_2,
            w4.BUTTON_DOWN,
        });
        return s;
    }

    pub fn spell_mud_plate() Spell {
        var s = Spell{
            .name = "Mud Plate",
            .price = 3,
            .alignment = 2,
            .effect = Effect{ .player_shield = 4 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_DOWN,
            w4.BUTTON_DOWN,
            w4.BUTTON_2,
            w4.BUTTON_UP,
        });
        return s;
    }

    pub fn spell_earth_ball() Spell {
        var s = Spell{
            .name = "Earth Ball",
            .price = 9,
            .alignment = 4,
            .effect = Effect{ .damage_to_enemy = 11 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_UP,
            w4.BUTTON_DOWN,
            w4.BUTTON_DOWN,
            w4.BUTTON_2,
            w4.BUTTON_UP,
            w4.BUTTON_1,
        });
        return s;
    }

    pub fn spell_root() Spell {
        var s = Spell{
            .name = "Root",
            .price = 14,
            .alignment = 4,
            .effect = Effect{ .vampirism_to_enemy = 5 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_2,
            w4.BUTTON_UP,
            w4.BUTTON_1,
            w4.BUTTON_UP,
            w4.BUTTON_DOWN,
        });
        return s;
    }

    pub fn spell_soul_steal() Spell {
        var s = Spell{
            .name = "Soul Steal",
            .price = 20,
            .alignment = -3,
            .effect = Effect{ .vampirism_to_enemy = 6 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_LEFT,
            w4.BUTTON_RIGHT,
            w4.BUTTON_DOWN,
            w4.BUTTON_LEFT,
            w4.BUTTON_RIGHT,
            w4.BUTTON_1,
        });
        return s;
    }

    pub fn spell_wolf_bite() Spell {
        var wolf_bite = Spell{
            .name = "Wolf Bite",
            .price = 9,
            .alignment = -7,
            .effect = Effect{ .damage_to_enemy = 3 },
        };
        wolf_bite.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return wolf_bite;
    }

    pub fn spell_heal() Spell {
        var s = Spell{
            .name = "Heal",
            .price = 9,
            .alignment = 2,
            .effect = Effect{ .player_heal = 2 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_sun_shiv() Spell {
        var s = Spell{
            .name = "Sun Shiv",
            .price = 11,
            .alignment = 2,
            .effect = Effect{ .damage_to_enemy = 2 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_UP, w4.BUTTON_1, w4.BUTTON_DOWN, w4.BUTTON_2 });
        return s;
    }

    pub fn spell_moon_shiv() Spell {
        var s = Spell{
            .name = "Moon Shiv",
            .price = 11,
            .alignment = -2,
            .effect = Effect{ .damage_to_enemy = 2 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_DOWN, w4.BUTTON_2, w4.BUTTON_UP, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_holy_water() Spell {
        var spell = Spell{
            .name = "Holy Water",
            .price = 9,
            .alignment = 9,
            .effect = Effect{ .damage_to_enemy = 8 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_crissaegrim() Spell {
        var spell = Spell{
            .name = "Crissaegrim",
            .price = 25,
            .alignment = 9,
            .effect = Effect{ .damage_to_enemy = 14 },
        };
        // crissaegrim is a fast but powerful sword, spell input should be short and easy
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_2 });
        return spell;
    }

    pub fn spell_knife() Spell {
        var spell = Spell{
            .name = "Knife",
            .price = 2,
            .alignment = -5,
            .effect = Effect{ .damage_to_enemy = 2 },
            .frame_triggered = 0,
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_2 });
        return spell;
    }

    pub fn spell_cross() Spell {
        var spell = Spell{
            .name = "Cross",
            .price = 10,
            .alignment = 5,
            .effect = Effect{ .damage_to_enemy = 6 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_LEFT, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_whip() Spell {
        var spell = Spell{
            .name = "Whip",
            .price = 13,
            .alignment = 7,
            .effect = Effect{ .damage_to_enemy = 10 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_RIGHT, w4.BUTTON_LEFT, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_fangs() Spell {
        var spell = Spell{
            .name = "Fangs",
            .price = 13,
            .alignment = -9,
            .effect = Effect{ .vampirism_to_enemy = 1 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_LEFT, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_cloak() Spell {
        var spell = Spell{
            .name = "Cloak",
            .price = 9,
            .alignment = -9,
            .effect = Effect{ .player_shield = 10 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_DOWN, w4.BUTTON_UP, w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_buckler() Spell {
        var spell = Spell{
            .name = "Buckler",
            .price = 9,
            .alignment = 8,
            .effect = Effect{ .player_shield = 8 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_DOWN, w4.BUTTON_1, w4.BUTTON_LEFT, w4.BUTTON_LEFT });
        return spell;
    }

    // curses
    pub fn spell_zap() Spell {
        var spell = Spell{
            .name = "Zap",
            .price = 0,
            .alignment = -10,
            .effect = Effect{ .damage_to_player = 3 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_burn() Spell {
        var spell = Spell{
            .name = "Burn",
            .price = 0,
            .alignment = 10,
            .effect = Effect{ .damage_to_player = 3 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_1, w4.BUTTON_DOWN });
        return spell;
    }

    pub fn spell_rooted() Spell {
        var spell = Spell{
            .name = "Rooted",
            .price = 0,
            .alignment = 10,
            .effect = Effect{ .damage_to_player = 3 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_UP, w4.BUTTON_2 });
        return spell;
    }

    pub fn spell_frozen() Spell {
        var spell = Spell{
            .name = "Frozen",
            .price = 0,
            .alignment = 10,
            .effect = Effect{ .damage_to_player = 3 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_2, w4.BUTTON_DOWN });
        return spell;
    }

    pub fn spell_cut() Spell {
        var spell = Spell{
            .name = "Cut",
            .price = 0,
            .alignment = 10,
            .effect = Effect{ .damage_to_player = 3 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_DOWN, w4.BUTTON_2 });
        return spell;
    }
};

const curses = [_]Spell{
    Spell.spell_zap(),
    Spell.spell_burn(),
    Spell.spell_rooted(),
    Spell.spell_frozen(),
    Spell.spell_cut(),
};

const curse = enum(usize) {
    zap = 0,
    burn,
    rooted,
    frozen,
    cut,
};

const GlobalState = enum {
    crossroad,
    event_boss_cutscene,
    event_boss_intro,
    event_boss_intro_2,
    event_boss_outro,
    event_boss,
    event_castle_bat,
    event_castle_candle,
    event_castle_schmoo,
    event_castle_sun_shop,
    event_castle_vampire_shop,
    event_cavern_man,
    event_chest_regular,
    event_chest_mimic, // same as other chest events, different outcome
    event_chest_mimic_fight_intro,
    event_coast_barbarian_invasion,
    event_coast_kidnapped_daughter,
    event_coast_kidnapped_daughter_decline,
    event_coast_merfolk,
    event_coast_seagull,
    event_coast_sea_monster,
    event_coin_muncher,
    event_credits,
    event_dungeon_ambush,
    event_dungeon,
    event_dungeon_1,
    event_dungeon_2,
    event_dungeon_3,
    event_dungeon_4,
    event_dungeon_5,
    event_dungeon_6,
    event_dungeon_7,
    event_hard_swamp_creature,
    event_healer,
    event_healer_decline,
    event_healer_accept,
    event_coastal_shop,
    event_mine_shop,
    event_healing_shop,
    event_forest_wolf,
    event_militia_ambush,
    event_mine_troll,
    event_mine_troll_warrior,
    event_mine_troll_king,
    event_moon_altar,
    event_moon_altar_skip,
    event_moon_altar_pray,
    event_moon_altar_destroy,
    event_moon_fountain,
    event_moon_fountain_skip,
    event_moon_fountain_damage,
    event_moon_fountain_heal,
    event_moon_fountain_refresh,
    event_moon_partisan,
    event_pirate,
    event_pirate_captain,
    event_rat,
    event_snake_pit,
    event_sun_altar,
    event_sun_altar_skip,
    event_sun_altar_pay,
    event_sun_altar_destroy,
    event_swamp_people,
    event_swamp_creature,
    event_swamp_shop,
    event_sun_fountain,
    event_sun_fountain_skip,
    event_sun_fountain_damage,
    event_sun_fountain_heal,
    event_sun_fountain_refresh,
    event_sun_partisan,
    event_training_fight_1,
    event_training_fight_2,
    event_training_bat,
    fight,
    fight_end,
    fight_reward,
    game_over,
    inventory,
    inventory_full,
    inventory_full_2,
    map,
    options,
    new_game_init,
    pick_character,
    pick_character_2,
    pick_random_event,
    shop,
    title,
    title_1,
    tutorial_basics,
    tutorial_synergies,
    tutorial_fights,
    tutorial_fights_1,
    tutorial_pause_menu,
    tutorial_alignment,
    tutorial_end,
};

const Area = struct {
    name: []const u8,
    event_count: usize, // player is expected to play even_count events out of the total pool
    event_pool: []const GlobalState,
};

const training_area = Area{
    .name = "Wizard Camp",
    .event_count = 3,
    .event_pool = &[_]GlobalState{
        GlobalState.event_training_fight_1,
        GlobalState.event_training_fight_2,
        GlobalState.event_training_bat,
    },
};

const road_area = Area{
    .name = "Road",
    .event_count = 3,
    .event_pool = &[_]GlobalState{
        GlobalState.event_chest_regular,
        GlobalState.event_coin_muncher,
        GlobalState.event_snake_pit,
        GlobalState.event_rat,
        GlobalState.event_militia_ambush,
    },
};

const coast_area = Area{
    .name = "Coast",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_coast_seagull,
        GlobalState.event_coast_barbarian_invasion,
        GlobalState.event_coast_kidnapped_daughter,
        GlobalState.event_coast_merfolk,
        GlobalState.event_coast_sea_monster,
        GlobalState.event_coastal_shop,
    },
};

const pirate_area = Area{
    .name = "Pirate Ship",
    .event_count = 3,
    .event_pool = &[_]GlobalState{
        GlobalState.event_chest_regular,
        GlobalState.event_pirate,
        GlobalState.event_pirate_captain,
    },
};

const dungeon_area = Area{
    .name = "???",
    .event_count = 1,
    .event_pool = &[_]GlobalState{
        GlobalState.event_dungeon,
    },
};

const swamp_area = Area{
    .name = "Swamp",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_chest_regular,
        GlobalState.event_swamp_creature,
        GlobalState.event_swamp_people,
        GlobalState.event_moon_altar,
        GlobalState.event_moon_partisan,
    },
};

const hard_swamp_area = Area{
    .name = "Swamp",
    .event_count = 5,
    .event_pool = &[_]GlobalState{
        GlobalState.event_chest_regular,
        GlobalState.event_chest_mimic,
        GlobalState.event_healer,
        GlobalState.event_hard_swamp_creature,
        GlobalState.event_moon_altar,
        GlobalState.event_moon_fountain,
        GlobalState.event_swamp_shop,
    },
};

const forest_area = Area{
    .name = "Forest",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_coin_muncher,
        GlobalState.event_sun_fountain,
        GlobalState.event_forest_wolf,
        GlobalState.event_healing_shop,
        GlobalState.event_cavern_man,
        GlobalState.event_sun_partisan,
    },
};

const medium_forest_area = Area{
    .name = "Forest",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_sun_altar,
        GlobalState.event_chest_regular,
        GlobalState.event_chest_mimic,
        GlobalState.event_sun_fountain,
        GlobalState.event_forest_wolf,
        GlobalState.event_dungeon_ambush,
    },
};

const castle_area = Area{
    .name = "Castle",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_castle_bat,
        GlobalState.event_castle_candle,
        GlobalState.event_castle_schmoo,
        GlobalState.event_castle_sun_shop,
        GlobalState.event_castle_vampire_shop,
    },
};

const mine_area = Area{
    .name = "Mines",
    .event_count = 3,
    .event_pool = &[_]GlobalState{
        GlobalState.event_mine_shop,
        GlobalState.event_mine_troll,
        GlobalState.event_mine_troll_warrior,
        GlobalState.event_mine_troll_king,
    },
};

const boss_area = Area{
    .name = "Eclipse",
    .event_count = 1,
    .event_pool = &[_]GlobalState{
        GlobalState.event_boss,
    },
};

const training_area_pool = [_]Area{
    road_area,
    training_area,
};

// same overall difficulty than the training camp, but has rewards and other quests
const easy_area_pool = [_]Area{
    forest_area,
    swamp_area,
};

const medium_area_pool = [_]Area{
    coast_area,
    medium_forest_area,
    castle_area,
};

const hard_area_pool = [_]Area{
    castle_area,
    hard_swamp_area,
    mine_area,
};

const boss_area_pool = [_]Area{
    boss_area,
};

const EnemyIntent = struct {
    trigger_time: u16,
    effect: Effect,
};

const RandomReward = struct {
    probability: u8, // [0-100]
    reward: Reward,

    pub fn zero() RandomReward {
        return RandomReward{
            .probability = 0,
            .reward = Reward.no_reward,
        };
    }
};

const Enemy = struct {
    hp: i16 = 0,
    max_hp: i16 = 0,
    shield: i16 = 0,
    intent_current_time: u16 = 0,
    intent_index: usize = 0,
    intent: [enemy_intent_max_size]EnemyIntent = undefined,
    guaranteed_reward: Reward = Reward.no_reward,
    random_reward: RandomReward = RandomReward.zero(),
    sprite: [*]const u8 = undefined,

    pub fn zero() Enemy {
        var e = Enemy{};
        var i: usize = 0;
        while (i < e.intent.len) : (i += 1) {
            e.intent[i] = EnemyIntent{
                .trigger_time = 0,
                .effect = Effect.no_effect,
            };
        }
        return e;
    }

    pub fn enemy_barbarian() Enemy {
        var enemy = zero();
        const enemy_max_hp = 25;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{ .damage_to_player = 9 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 5 };
        enemy.sprite = &sprites.enemy_barbarian;
        return enemy;
    }

    pub fn enemy_boss() Enemy {
        var enemy = zero();
        const enemy_max_hp = 99;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 35 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .curse = curse.burn },
        };
        enemy.intent[2] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{ .enemy_shield = 20 },
        };
        enemy.intent[3] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .curse = curse.zap },
        };
        enemy.sprite = &sprites.enemy_boss;
        return enemy;
    }

    pub fn enemy_mimic() Enemy {
        var enemy = zero();
        const enemy_max_hp = 50;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 6 },
        };
        enemy.sprite = &sprites.enemy_mimic;
        enemy.guaranteed_reward = Reward{ .gold_reward = 1 };
        return enemy;
    }

    pub fn enemy_castle_bat() Enemy {
        var enemy = zero();
        const enemy_max_hp = 25;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .vampirism_to_player = 6 },
        };
        enemy.sprite = &sprites.enemy_castle_bat;
        return enemy;
    }

    pub fn enemy_castle_candle() Enemy {
        var enemy = zero();
        const enemy_max_hp = 2;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 1 },
        };
        enemy.sprite = &sprites.enemy_castle_candle;
        enemy.guaranteed_reward = Reward{ .gold_reward = 10 };
        enemy.random_reward = RandomReward{
            .probability = 80,
            .reward = Reward{ .spell_reward = Spell.spell_holy_water() },
        };
        return enemy;
    }

    pub fn enemy_castle_schmoo() Enemy {
        var enemy = zero();
        const enemy_max_hp = 44;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 7 * 60,
            .effect = Effect{ .damage_to_player = 13 },
        };
        enemy.sprite = &sprites.enemy_castle_schmoo;
        enemy.guaranteed_reward = Reward{ .gold_reward = 5 };
        enemy.random_reward = RandomReward{
            .probability = 4,
            .reward = Reward{ .spell_reward = Spell.spell_crissaegrim() },
        };
        return enemy;
    }

    pub fn enemy_coin_muncher() Enemy {
        var enemy = zero();
        const enemy_max_hp = 10;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 1 * 60,
            .effect = Effect{ .gold_payment = 1 },
        };
        enemy.sprite = &sprites.enemy_coin_muncher;
        return enemy;
    }

    pub fn enemy_dungeon_guard() Enemy {
        var enemy = zero();
        const enemy_max_hp = 30;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 8 * 60,
            .effect = Effect{ .damage_to_player = 10 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 12 },
        };
        enemy.guaranteed_reward = Reward.no_reward;
        enemy.sprite = &sprites.enemy_militia;
        return enemy;
    }

    pub fn enemy_forest_wolf() Enemy {
        var enemy = zero();
        const enemy_max_hp = 20;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .damage_to_player = 7 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 9 * 60,
            .effect = Effect{ .damage_to_player = 12 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 1 };
        enemy.random_reward = RandomReward{
            .probability = 33,
            .reward = Reward{ .spell_reward = Spell.spell_wolf_bite() },
        };
        enemy.sprite = &sprites.enemy_wolf;
        return enemy;
    }

    pub fn enemy_merfolk() Enemy {
        var enemy = zero();
        const enemy_max_hp = 30;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{ .damage_to_player = 3 },
        };
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        enemy.sprite = &sprites.enemy_merfolk;
        return enemy;
    }

    pub fn enemy_militia_ambush() Enemy {
        var enemy = zero();
        const enemy_max_hp = 30;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 8 * 60,
            .effect = Effect{ .damage_to_player = 10 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 4 },
        };
        enemy.random_reward = RandomReward{
            .probability = 40,
            .reward = Reward{ .spell_reward = Spell.spell_ice_wall() },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 2 };
        enemy.sprite = &sprites.enemy_militia;
        return enemy;
    }

    pub fn enemy_mine_troll_king() Enemy {
        var enemy = zero();
        const enemy_max_hp = 50;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .damage_to_player = 32 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 18 },
        };
        enemy.intent[2] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .curse = curse.rooted },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 25 };
        enemy.random_reward = RandomReward{
            .probability = 50,
            .reward = Reward{ .spell_reward = Spell.spell_mud_plate() },
        };
        enemy.sprite = &sprites.enemy_mine_troll_king;
        return enemy;
    }

    pub fn enemy_mine_troll_warrior() Enemy {
        var enemy = zero();
        const enemy_max_hp = 30;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 22 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 14 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 7 };
        enemy.random_reward = RandomReward{
            .probability = 50,
            .reward = Reward{ .spell_reward = Spell.spell_mud_plate() },
        };
        enemy.sprite = &sprites.enemy_mine_troll_warrior;
        return enemy;
    }

    pub fn enemy_mine_troll() Enemy {
        var enemy = zero();
        const enemy_max_hp = 20;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .damage_to_player = 15 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 16 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 7 };
        enemy.random_reward = RandomReward{
            .probability = 50,
            .reward = Reward{ .spell_reward = Spell.spell_earth_ball() },
        };
        enemy.sprite = &sprites.enemy_mine_troll;
        return enemy;
    }

    pub fn enemy_partisan() Enemy {
        var enemy = zero();
        const enemy_max_hp = 35;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 8 * 60,
            .effect = Effect{ .damage_to_player = 13 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 7 },
        };
        enemy.random_reward = RandomReward{
            .probability = 10,
            .reward = Reward{ .spell_reward = Spell.spell_buckler() },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 5 };
        enemy.sprite = &sprites.enemy_partisan;
        return enemy;
    }

    pub fn enemy_pirate() Enemy {
        var enemy = zero();
        const enemy_max_hp = 45;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{
                .damage_to_player = 16,
            },
        };
        enemy.guaranteed_reward = Reward.no_reward;
        enemy.sprite = &sprites.enemy_pirate;
        return enemy;
    }

    pub fn enemy_pirate_captain() Enemy {
        var enemy = zero();
        const enemy_max_hp = 65;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{ .damage_to_player = 22 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .enemy_shield = 7 },
        };
        enemy.intent[2] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .curse = curse.cut },
        };
        enemy.guaranteed_reward = Reward.kidnapped_daughter_reward;
        enemy.sprite = &sprites.enemy_pirate_captain;
        return enemy;
    }

    pub fn enemy_seagull() Enemy {
        var enemy = zero();
        const enemy_max_hp = 10;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 1 * 60,
            .effect = Effect{ .damage_to_player = 1 },
        };
        enemy.guaranteed_reward = Reward{ .spell_reward = Spell.spell_squawk() };
        enemy.sprite = &sprites.enemy_seagull;
        return enemy;
    }

    pub fn enemy_sea_monster() Enemy {
        var enemy = zero();
        const enemy_max_hp = 35;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 19 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 15 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 10 };
        enemy.sprite = &sprites.enemy_sea_monster;
        return enemy;
    }

    pub fn enemy_snake_pit() Enemy {
        var enemy = zero();
        const enemy_max_hp = 15;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .damage_to_player = 3 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 2 };
        enemy.sprite = &sprites.enemy_snake;
        return enemy;
    }

    pub fn enemy_rat() Enemy {
        var enemy = zero();
        const enemy_max_hp = 13;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .damage_to_player = 4 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 1 };
        enemy.sprite = &sprites.enemy_rat;
        return enemy;
    }

    pub fn enemy_swamp_people() Enemy {
        var enemy = zero();
        const enemy_max_hp = 20;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .damage_to_player = 8 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .enemy_shield = 1 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 2 };
        enemy.random_reward = RandomReward{
            .probability = 30,
            .reward = Reward{ .spell_reward = Spell.spell_mud_plate() },
        };
        enemy.sprite = &sprites.enemy_swamp_people;
        return enemy;
    }

    pub fn enemy_swamp_creature() Enemy {
        var enemy = zero();
        const enemy_max_hp = 30;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 7 * 60,
            .effect = Effect{ .damage_to_player = 9 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 2 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 4 };
        enemy.random_reward = RandomReward{
            .probability = 40,
            .reward = Reward{ .spell_reward = Spell.spell_moon_shiv() },
        };
        enemy.sprite = &sprites.enemy_swamp_creature;
        return enemy;
    }

    pub fn enemy_hard_swamp_creature() Enemy {
        var enemy = zero();
        const enemy_max_hp = 50;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .damage_to_player = 22 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 20 },
        };
        enemy.intent[2] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .curse = curse.frozen },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 7 };
        enemy.random_reward = RandomReward{
            .probability = 10,
            .reward = Reward{ .spell_reward = Spell.spell_moon_shiv() },
        };
        enemy.sprite = &sprites.enemy_swamp_creature;
        return enemy;
    }

    pub fn enemy_training_soldier_1() Enemy {
        var enemy = zero();
        const enemy_max_hp = 25;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 12 * 60,
            .effect = Effect{ .damage_to_player = 7 },
        };
        enemy.guaranteed_reward = Reward.no_reward;
        enemy.sprite = &sprites.enemy_barbarian;
        return enemy;
    }

    pub fn enemy_training_soldier_2() Enemy {
        var enemy = zero();
        const enemy_max_hp = 25;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 12 * 60,
            .effect = Effect{ .damage_to_player = 7 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 4 },
        };
        enemy.guaranteed_reward = Reward.no_reward;
        enemy.sprite = &sprites.enemy_barbarian;
        return enemy;
    }

    pub fn enemy_training_bat() Enemy {
        var enemy = zero();
        const enemy_max_hp = 15;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 12 * 60,
            .effect = Effect{ .vampirism_to_player = 5 },
        };
        enemy.guaranteed_reward = Reward.no_reward;
        enemy.sprite = &sprites.enemy_castle_bat;
        return enemy;
    }
};

pub fn add_spell_to_list(spell: Spell, spell_list: []Spell) void {
    // find the first undefined spell in spellbook
    var i: usize = 0;
    while (i < spell_list.len and spell_list[i].is_defined()) {
        i += 1;
    }
    if (i < spell_list.len) {
        spell_list[i] = spell;
    }
}

pub fn remove_nth_spell_from_list(n: usize, spell_list: []Spell) void {
    var i: usize = n + 1;
    while (i < spell_list.len) : (i += 1) {
        spell_list[i - 1] = spell_list[i];
    }
    spell_list[spell_list.len - 1] = Spell.zero();
}

pub fn get_spell_list_size(spell_list: []Spell) usize {
    var size: usize = 0;
    for (spell_list) |spell| {
        if (spell.is_defined()) {
            size += 1;
        }
    }
    return size;
}

fn play_sfx_block() void {
    if (options[2] > 0) {
        instruments.instruments[11].play(options[2]);
    }
}

fn play_sfx_hit() void {
    if (options[2] > 0) {
        instruments.instruments[8].play(options[2]);
    }
}

fn play_sfx_death() void {
    if (options[2] > 0) {
        instruments.instruments[7].play(options[2]);
    }
}

fn play_sfx_sweep() void {
    if (options[2] > 0) {
        instruments.instruments[1].play(options[2]);
    }
}

fn play_sfx_menu(volume: u8) void {
    instruments.instruments[2].play(volume);
}

const PauseMenu = enum { Off, InventoryMenu, OptionsMenu };

const choices_max_size: usize = 5;
const spell_book_full_size: usize = 8;
const spell_book_max_size: usize = 2 * spell_book_full_size;
const visited_events_max_size: usize = 32;
const enemy_intent_max_size: usize = 5;
const shop_items_max_size: usize = 5;
const State = struct {
    previous_input: u8 = 0,
    pager: pager.Pager = undefined,
    spell_index: isize = 0, // index keeping track of which spell is hilighted when displaying inventory
    pause_menu: PauseMenu = PauseMenu.Off,
    state_register: GlobalState = GlobalState.title, // generic state holder used for temporary screens (inventory, map, etc...) to hold the next true state
    // global state
    state: GlobalState = GlobalState.title,
    state_has_changed: bool = true,
    area: Area = undefined,
    area_counter: usize = 0,
    area_event_counter: usize = 0,
    crossroad_index_1: usize = 0,
    crossroad_index_2: usize = 0,
    visited_events: [visited_events_max_size]bool = undefined,
    choices: [spell_book_max_size]Spell = undefined,
    frame_counter: u16 = 0,
    text_progress: u16 = 0,
    // cutscene
    moon_x: i32 = 0,
    // sound engine
    musicode: Musicode,
    // player
    player_hp: i16 = 0,
    player_max_hp: i16 = 0,
    player_shield: i16 = 0,
    player_alignment: i16 = 0, // -100, +100
    player_gold: i16 = 0,
    player_curse: Spell = undefined,
    spellbook: [spell_book_max_size]Spell = undefined,
    reward_probability: u8 = 0,
    inventory_menu_spell: Spell = undefined,
    player_animation: u8 = 0,
    // enemy
    enemy: Enemy = Enemy.zero(),
    enemy_animation: u8 = 0,
    // shop
    shop_items: [shop_items_max_size]Spell = undefined,
    shop_list_index: usize = 0, // 0= player_inventory 1= shop_inventory
    shop_gold: i16 = 0,

    pub fn music_tick(self: *State) void {
        if (options[1] > 0) {
            self.musicode.tick();
        }
    }

    fn play_track_fanfare02(self: *State) void {
        if (options[1] > 0) {
            self.musicode.volume = options[1];
            self.musicode.start_track(tracks.fanfare02_track[0..], false);
        }
    }

    fn play_track_fanfare03(self: *State) void {
        if (options[1] > 0) {
            self.musicode.volume = options[1];
            self.musicode.start_track(tracks.fanfare03_track[0..], false);
        }
    }

    fn play_track_title(self: *State) void {
        if (options[1] > 0) {
            self.musicode.volume = options[1];
            self.musicode.start_track(tracks.title_track[0..], true);
        }
    }

    pub fn text_tick(self: *State) void {
        self.pager.set_progressive_display(true);
        self.pager.reset_steps();
        self.text_progress += 1;
        self.pager.set_max_steps(2 * state.text_progress);
        self.pager.animation_step = state.text_progress / 8;
    }

    pub fn apply_reward(self: *State, reward: Reward) void {
        switch (reward) {
            Reward.no_reward => {},
            Reward.gold_reward => |amount| {
                self.player_gold += @as(i16, @intCast(amount));
            },
            Reward.spell_reward => |spell| {
                add_spell_to_list(spell, &self.spellbook);
            },
            Reward.alignment_reward => |alignment| {
                self.change_alignment(alignment);
            },
            Reward.kidnapped_daughter_reward => {
                self.change_alignment(10);
                self.player_gold += 50;
            },
        }
    }

    pub fn apply_effect(self: *State, effect: Effect) void {
        switch (effect) {
            Effect.no_effect => {},
            Effect.toggle_inventory_menu => {
                self.pause_menu = switch (self.pause_menu) {
                    PauseMenu.Off => PauseMenu.InventoryMenu,
                    else => PauseMenu.Off,
                };
            },
            Effect.player_heal => |amount| {
                self.player_hp += @as(i16, @intCast(amount));
                if (self.player_hp >= self.player_max_hp) {
                    self.player_hp = self.player_max_hp;
                }
            },
            Effect.player_healing_max => {
                self.player_hp = self.player_max_hp;
            },
            Effect.damage_to_player => |dmg| {
                if (dmg > self.player_shield) {
                    self.player_hp -= (dmg - self.player_shield);
                    self.player_shield = 0;
                    if (self.player_hp < 0) {
                        self.player_hp = 0;
                    }
                    self.player_animation = 4;
                    play_sfx_hit();
                } else {
                    self.player_shield -= dmg;
                    play_sfx_block();
                }
            },
            Effect.damage_to_enemy => |dmg| {
                if (dmg > self.enemy.shield) {
                    self.enemy.hp -= (dmg - self.enemy.shield);
                    self.enemy.shield = 0;
                    if (self.enemy.hp < 0) {
                        self.enemy.hp = 0;
                    }
                    self.enemy_animation = 4;
                    play_sfx_hit();
                } else {
                    self.enemy.shield -= dmg;
                    play_sfx_block();
                }
            },
            Effect.vampirism_to_player => |dmg| {
                if (dmg > self.player_shield) {
                    const actual_dmg = (dmg - self.player_shield);
                    self.player_hp -= actual_dmg;
                    self.enemy.hp += actual_dmg;
                    self.player_shield = 0;
                    if (self.player_hp < 0) {
                        self.player_hp = 0;
                    }
                    if (self.enemy.hp > self.enemy.max_hp) {
                        self.enemy.hp = self.enemy.max_hp;
                    }
                    self.player_animation = 4;
                    play_sfx_hit();
                } else {
                    self.player_shield -= dmg;
                    play_sfx_block();
                }
            },
            Effect.vampirism_to_enemy => |dmg| {
                if (dmg > self.enemy.shield) {
                    const actual_dmg = (dmg - self.enemy.shield);
                    self.enemy.hp -= actual_dmg;
                    self.player_hp += actual_dmg;
                    self.enemy.shield = 0;
                    if (self.enemy.hp < 0) {
                        self.enemy.hp = 0;
                    }
                    if (self.player_hp >= self.player_max_hp) {
                        self.player_hp = self.player_max_hp;
                    }
                    self.enemy_animation = 4;
                    play_sfx_hit();
                } else {
                    self.enemy.shield -= dmg;
                    play_sfx_block();
                }
            },
            Effect.gold_payment => |amount| {
                // warning the event must check beforehand that there is enough gold
                if (amount <= self.player_gold) {
                    self.player_gold -= @as(i16, @intCast(amount));
                }
            },
            Effect.player_shield => |amount| {
                self.player_shield += @as(i16, @intCast(amount));
            },
            Effect.enemy_shield => |amount| {
                self.enemy.shield += @as(i16, @intCast(amount));
            },
            Effect.alignment => |alignment| {
                self.change_alignment(alignment);
            },
            Effect.curse => |c| {
                self.player_curse = curses[@intFromEnum(c)];
            },
        }
    }

    pub fn change_alignment(self: *State, increment: i16) void {
        self.player_alignment += increment;
        if (self.player_alignment < -100) {
            self.player_alignment = -100;
        }
        if (self.player_alignment > 100) {
            self.player_alignment = 100;
        }
    }

    pub fn reset_spellbook(self: *State) void {
        var i: usize = 0;
        while (i < self.spellbook.len) : (i += 1) {
            self.spellbook[i].reset();
        }
    }

    pub fn reset_shop_items(self: *State) void {
        var i: usize = 0;
        while (i < self.shop_items.len) : (i += 1) {
            self.shop_items[i] = Spell.zero();
        }
    }

    pub fn reset_player_shield(self: *State) void {
        self.player_shield = 0;
    }

    pub fn reset_enemy_shield(self: *State) void {
        self.enemy_shield = 0;
    }

    pub fn reset_enemy_intent(self: *State) void {
        var i: usize = 0;
        while (i < self.enemy.intent.len) : (i += 1) {
            self.enemy.intent[i] = EnemyIntent{
                .trigger_time = 0,
                .effect = Effect.no_effect,
            };
        }
    }

    pub fn reset_visited_events(self: *State) void {
        var i: usize = 0;
        while (i < self.visited_events.len) : (i += 1) {
            self.visited_events[i] = false;
        }
    }

    pub fn reset_choices(self: *State) void {
        var i: usize = 0;
        while (i < self.choices.len) : (i += 1) {
            self.choices[i] = Spell.zero();
        }
    }

    pub fn set_choices_with_labels_1(self: *State, label1: []const u8) void {
        self.reset_choices();
        self.choices[0] = Spell{
            .name = label1,
            .effect = Effect.no_effect,
        };
        state.choices[0].set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_1 });
    }

    pub fn set_choices_back(self: *State) void {
        self.reset_choices();
        self.choices[0] = Spell{
            .name = "Back",
            .effect = Effect.no_effect,
        };
        state.choices[0].set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
    }

    pub fn set_choices_confirm(self: *State) void {
        self.set_choices_with_labels_1("Confirm");
    }

    pub fn set_choices_fight(self: *State) void {
        self.set_choices_with_labels_1("Fight!");
    }

    pub fn set_choices_with_labels_2(self: *State, label1: []const u8, label2: []const u8) void {
        self.reset_choices();
        self.choices[0] = Spell{
            .name = label1,
            .effect = Effect.no_effect,
        };
        state.choices[0].set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
        self.choices[1] = Spell{
            .name = label2,
            .effect = Effect.no_effect,
        };
        state.choices[1].set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_1 });
    }

    pub fn set_choices_accept_decline(self: *State) void {
        self.set_choices_with_labels_2("Decline", "Accept");
    }

    pub fn set_choices_shop(self: *State) void {
        self.set_choices_with_labels_2("Buy/Sell", "Exit");
        state.choices[0].set_spell(&[_]u8{w4.BUTTON_1});
        state.choices[1].set_spell(&[_]u8{w4.BUTTON_2});
    }

    pub fn set_choices_inventory_full(self: *State) void {
        self.set_choices_with_labels_2("Pick/Discard", "Exit");
        state.choices[0].set_spell(&[_]u8{w4.BUTTON_1});
        state.choices[1].set_spell(&[_]u8{w4.BUTTON_2});
    }
};

//// drawing functions

pub fn draw_left_arrow(x: i32, y: i32, fill: bool) void {
    if (fill) {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 0, 9, sprites.arrows_width, w4.BLIT_1BPP);
    } else {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 0, 0, sprites.arrows_width, w4.BLIT_1BPP);
    }
}

pub fn draw_right_arrow(x: i32, y: i32, fill: bool) void {
    if (fill) {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 0, 9, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
    } else {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 0, 0, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
    }
}

pub fn draw_up_arrow(x: i32, y: i32, fill: bool) void {
    if (fill) {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 9, 9, sprites.arrows_width, w4.BLIT_1BPP);
    } else {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 9, 0, sprites.arrows_width, w4.BLIT_1BPP);
    }
}

pub fn draw_down_arrow(x: i32, y: i32, fill: bool) void {
    if (fill) {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 9, 9, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_Y);
    } else {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 9, 0, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_Y);
    }
}

pub fn draw_button_1(x: i32, y: i32, fill: bool) void {
    if (fill) {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 18, 9, sprites.arrows_width, w4.BLIT_1BPP);
    } else {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 18, 0, sprites.arrows_width, w4.BLIT_1BPP);
    }
}

pub fn draw_button_2(x: i32, y: i32, fill: bool) void {
    if (fill) {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 27, 9, sprites.arrows_width, w4.BLIT_1BPP);
    } else {
        w4.blitSub(&sprites.arrows, x, y, 9, 9, 27, 0, sprites.arrows_width, w4.BLIT_1BPP);
    }
}

pub fn draw_spell_input(input: []const u8, current_progress: usize, x: i32, y: i32) void {
    var i: usize = 0;
    var var_x: i32 = x;
    while (i < input.len and input[i] != end_of_spell) : (i += 1) {
        switch (input[i]) {
            w4.BUTTON_1 => draw_button_1(var_x, y, i < current_progress),
            w4.BUTTON_2 => draw_button_2(var_x, y, i < current_progress),
            w4.BUTTON_LEFT => draw_left_arrow(var_x, y, i < current_progress),
            w4.BUTTON_RIGHT => draw_right_arrow(var_x, y, i < current_progress),
            w4.BUTTON_UP => draw_up_arrow(var_x, y, i < current_progress),
            w4.BUTTON_DOWN => draw_down_arrow(var_x, y, i < current_progress),
            else => {},
        }
        var_x += 10;
    }
}

pub fn draw_spell(spell: *Spell, p: *pager.Pager, x: i32, y: i32) void {
    p.set_cursor(x, y + 1);
    pager.fmg_text(&state.pager, spell.name);
    draw_spell_input(&spell.input, spell.current_progress, 10 + (12 * (1 + pager.fmg_letter_width)), y);
}

pub fn set_blink_color(s: *State, y: i32, spell: *Spell) void {
    const blink_on = (options[0] == 1) and @mod(s.frame_counter, 10) < 5;
    if (s.frame_counter > 0 and spell.frame_triggered + 30 > s.frame_counter) {
        if (spell.is_defined() and blink_on) {
            w4.DRAW_COLORS.* = 0x22;
            w4.rect(10, y, 140, 9);
            w4.DRAW_COLORS.* = 0x21;
        }
    } else {
        w4.DRAW_COLORS.* = 0x02;
    }
}

pub fn draw_curse(s: *State, x: i32, y: i32) void {
    if (s.player_curse.is_defined()) {
        draw_exclamation_mark(0, y);
        set_blink_color(s, y, &s.player_curse);
        draw_spell(&s.player_curse, &s.pager, x, y);
        draw_effect(110, y, s, s.player_curse.effect);
    }
}

pub fn draw_spell_list(spells: []Spell, s: *State, x: i32, y: i32) void {
    var i: usize = 0;
    var var_y = y;
    s.pager.set_progressive_display(false);
    while (i < spells.len) : (i += 1) {
        set_blink_color(s, var_y, &spells[i]);
        draw_spell(&spells[i], &s.pager, x, var_y);
        var_y += 10;
    }
    w4.DRAW_COLORS.* = 0x02;
}

pub fn draw_progress_bar(x: i32, y: i32, width: u32, height: u32, v: u32, max: u32) void {
    w4.DRAW_COLORS.* = 0x21;
    w4.rect(x, y, width, height);
    w4.DRAW_COLORS.* = 0x02;
    w4.rect(x, y, width * v / max, height);
}

pub fn draw_progress_bubble(x: i32, y: i32, v: u32, max: u32) void {
    w4.DRAW_COLORS.* = 0x21;
    var sprite_index = 9 * (v * 17 / max);
    if (sprite_index >= sprites.progress_bubble_width) {
        sprite_index = sprites.progress_bubble_width - 9;
    }
    w4.blitSub(&sprites.progress_bubble, x, y, 9, 9, sprite_index, 0, sprites.progress_bubble_width, w4.BLIT_1BPP);
    w4.DRAW_COLORS.* = 0x02;
}

pub fn draw_hero(x: i32, y: i32) void {
    w4.blit(&sprites.hero, x, y, sprites.hero_width, sprites.hero_height, w4.BLIT_1BPP);
}

pub fn draw_logo(x: i32, y: i32) void {
    w4.blit(&sprites.galdr_logo, x, y, sprites.galdr_logo_width, sprites.galdr_logo_height, w4.BLIT_1BPP);
}

pub fn draw_sword(x: i32, y: i32) void {
    w4.blitSub(&sprites.effects, x, y, 9, 9, 0, 0, sprites.effects_width, w4.BLIT_1BPP);
}

pub fn draw_shield(x: i32, y: i32) void {
    w4.blitSub(&sprites.effects, x, y, 9, 9, 9, 0, sprites.effects_width, w4.BLIT_1BPP);
}

pub fn draw_coin(x: i32, y: i32) void {
    w4.blitSub(&sprites.effects, x, y, 9, 9, 27, 0, sprites.effects_width, w4.BLIT_1BPP);
}

pub fn draw_heart(x: i32, y: i32) void {
    w4.blitSub(&sprites.effects, x, y, 9, 9, 36, 0, sprites.effects_width, w4.BLIT_1BPP);
}

pub fn draw_fang(x: i32, y: i32) void {
    w4.blitSub(&sprites.effects, x, y, 9, 9, 45, 0, sprites.effects_width, w4.BLIT_1BPP);
}

pub fn draw_exclamation_mark(x: i32, y: i32) void {
    w4.blitSub(&sprites.effects, x, y, 9, 9, 54, 0, sprites.effects_width, w4.BLIT_1BPP);
}

pub fn draw_moon(x: i32, y: i32) void {
    w4.blitSub(&sprites.alignment, x, y, 9, 9, 0, 0, sprites.alignment_width, w4.BLIT_1BPP);
}

pub fn draw_sun(x: i32, y: i32) void {
    w4.blitSub(&sprites.alignment, x, y, 9, 9, 9, 0, sprites.alignment_width, w4.BLIT_1BPP);
}

pub fn draw_map_location(x: i32, y: i32) void {
    w4.blit(&sprites.map_location, x, y, sprites.map_location_width, sprites.map_location_height, w4.BLIT_1BPP);
}
pub fn draw_map_character(x: i32, y: i32) void {
    w4.blit(&sprites.map_character, x, y, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);
}

pub fn draw_effect(x: i32, y: i32, s: *State, effect: Effect) void {
    switch (effect) {
        Effect.damage_to_player, Effect.damage_to_enemy => |dmg| {
            draw_sword(x, y);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, @as(i32, @intCast(dmg)));
        },
        Effect.player_shield, Effect.enemy_shield => |amount| {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 9, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, @as(i32, @intCast(amount)));
        },
        Effect.player_heal => |amount| {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 18, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, amount);
        },
        Effect.player_healing_max => {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 18, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_text(&s.pager, "max");
        },
        Effect.gold_payment => |amount| {
            draw_coin(x, y);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, -@as(i32, @intCast(amount)));
        },
        Effect.vampirism_to_player, Effect.vampirism_to_enemy => |dmg| {
            draw_fang(x, y);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, @as(i32, @intCast(dmg)));
        },
        Effect.curse => |_curse| {
            _ = _curse;
            draw_exclamation_mark(x, y);
        },
        else => {},
    }
}

pub fn draw_shop_party(x: i32, y: i23, s: *State, name: []const u8, gold_amount: i16) void {
    s.pager.set_cursor(x, y);
    pager.fmg_text(&s.pager, name);
    pager.fmg_text(&s.pager, "(");
    draw_coin(s.pager.cursor_x, y - 1);
    s.pager.set_cursor(s.pager.cursor_x + 11, y);
    pager.fmg_number(&s.pager, gold_amount);
    pager.fmg_text(&s.pager, ")");
}

pub fn draw_reward(s: *State, reward: Reward) void {
    switch (reward) {
        Reward.kidnapped_daughter_reward => {
            pager.fmg_text(&s.pager, "The parents say:");
            pager.fmg_newline(&s.pager);
            pager.fmg_text(&s.pager, "\"Thank you for saving our daughter!! We don't have much, but it is now yours.\" (");
            draw_coin(s.pager.cursor_x, s.pager.cursor_y - 1);
            s.pager.set_cursor(s.pager.cursor_x + 11, s.pager.cursor_y);
            pager.fmg_text(&s.pager, "50)");
        },
        Reward.gold_reward => |amount| {
            pager.fmg_text(&s.pager, "You gained ");
            pager.fmg_number(&s.pager, amount);
            pager.fmg_text(&s.pager, " gold!");
            pager.fmg_newline(&s.pager);
        },
        Reward.spell_reward => |spell| {
            pager.fmg_text(&s.pager, "You leared the ");
            pager.fmg_text(&s.pager, spell.name);
            pager.fmg_text(&s.pager, " spell!");
            pager.fmg_newline(&s.pager);
        },
        Reward.alignment_reward => |alignment| {
            _ = alignment;
            // alignment reward is never explicit to the player
        },
        else => {},
    }
}

pub fn draw_spell_details(x: i32, y: i32, s: *State, spell: Spell) void {
    s.pager.set_cursor(x, y);
    pager.fmg_text(&s.pager, spell.name);
    if (spell.alignment > 0) {
        draw_sun(s.pager.cursor_x, y - 1);
    } else {
        draw_moon(s.pager.cursor_x, y - 1);
    }
    s.pager.set_cursor(s.pager.cursor_x + 11, y);
    pager.fmg_text(&s.pager, " * ");
    draw_coin(s.pager.cursor_x, y - 1);
    s.pager.set_cursor(s.pager.cursor_x + 11, y);
    pager.fmg_number(&s.pager, spell.price);
    const second_line_y = y + 2 * (pager.fmg_letter_height + 1);
    draw_spell_input(&spell.input, 0, x, second_line_y);
    s.pager.set_cursor(90, s.pager.cursor_y);
    draw_effect(s.pager.cursor_x, second_line_y, s, spell.effect);
}

pub fn draw_right_triangle(x: i32, y: i32) void {
    w4.blitSub(&sprites.arrows, x, y, 5, 9, 0, 9, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
}
// draws a list of spell names + cursor
pub fn draw_spell_inventory_list(x: i32, y: i32, s: *State, list: []Spell, show_cursor: bool) void {
    var i: usize = 0;
    while (i < list.len) : (i += 1) {
        const y_list = y + @as(i32, @intCast(i * (pager.fmg_letter_height + 2)));
        s.pager.set_cursor(x, y_list);
        if (show_cursor and i == s.spell_index) {
            draw_right_triangle(x + 2, y_list - 1);
        }
        s.pager.set_cursor(x + 10, y_list);
        pager.fmg_text(&s.pager, list[i].name);
    }
}

pub fn draw_alignment_hud(s: *State, x: i32, y: i32) void {
    draw_moon(x, y + 1);
    draw_sun(x + 72, y + 1);
    w4.DRAW_COLORS.* = 0x20;
    // aligment bar is 60 wide
    w4.rect(x + 10, y + 2, 60, 7);
    //w4.rect(x + 10 + 30, y + 12, 2, 7);
    w4.DRAW_COLORS.* = 0x22;
    // oval x should be between 10 and 55
    w4.oval(x + 10 + @divTrunc((100 + s.player_alignment) * 55, 200), y + 4, 4, 3);
    w4.DRAW_COLORS.* = 0x02;
}

pub fn draw_player_hud(s: *State) void {
    const x: i32 = 10;
    const y: i32 = 0;
    draw_heart(x, y);

    var i: i32 = 0;
    while (i < 5) : (i += 1) {
        w4.blit(&sprites.progress_bar, x + 10 + (i * sprites.progress_bar_width), y + 1, sprites.progress_bar_width, sprites.progress_bar_height, w4.BLIT_1BPP);
    }
    w4.rect(x + 10, y + 1, @as(u32, @intCast(@divTrunc(5 * sprites.progress_bar_width * s.player_hp, s.player_max_hp))), sprites.progress_bar_height);

    const hp_x = x + 15 + 5 * sprites.progress_bar_width;
    s.pager.set_cursor(hp_x, y + 1);
    pager.fmg_number(&s.pager, s.player_hp);
    pager.fmg_text(&s.pager, "/");
    pager.fmg_number(&s.pager, s.player_max_hp);
    draw_coin(hp_x, y + 11);
    s.pager.set_cursor(hp_x + 11, y + 12);
    pager.fmg_number(&s.pager, s.player_gold);

    draw_alignment_hud(s, 10, 10);
}

pub fn draw_enemy_hud(s: *State) void {
    const x: i32 = 90;
    const y: i32 = 80 - 20;
    draw_heart(x, y + 10);
    var i: i32 = 0;
    while (i < 2) : (i += 1) {
        w4.blit(&sprites.progress_bar, x + 10 + (i * sprites.progress_bar_width), y + 11, sprites.progress_bar_width, sprites.progress_bar_height, w4.BLIT_1BPP);
    }
    w4.rect(x + 10, y + 11, @as(u32, @intCast(@divTrunc(2 * sprites.progress_bar_width * s.enemy.hp, s.enemy.max_hp))), sprites.progress_bar_height);
    const hp_x = x + 15 + 2 * sprites.progress_bar_width;
    s.pager.set_cursor(hp_x, y + 11);
    pager.fmg_number(&s.pager, s.enemy.hp);

    draw_shield(x, y);
    s.pager.set_cursor(x + 10, y + 1);
    pager.fmg_number(&s.pager, s.enemy.shield);
}

////////////////////////////////////////////////////////////////////
/////      EVENTS           ////////////////////////////////////////
////////////////////////////////////////////////////////////////////

const Dialog = union(enum) {
    newline: void,
    text: []const u8,
};

const Outcome = union(enum) {
    area: Area,
    state: GlobalState,
    apply_effect: Effect,
    guaranteed_reward: Reward,
};

pub fn draw_dialog_list(dialog: []const Dialog, s: *State) void {
    for (dialog) |elem| {
        switch (elem) {
            Dialog.newline => {
                pager.fmg_newline(&s.pager);
            },
            Dialog.text => |t| {
                pager.fmg_text(&s.pager, t);
            },
        }
    }
}

pub fn fight_intro(s: *State, released_keys: u8, enemy: Enemy, dialog: []const Dialog) void {
    if (s.state_has_changed) {
        s.set_choices_fight();

        // player reset
        s.reset_player_shield();
        s.reset_spellbook();

        // enemy reset
        s.reset_enemy_intent();
        s.enemy.intent_current_time = 0;
        s.enemy.intent_index = 0;
        s.enemy.guaranteed_reward = Reward.no_reward;
        s.enemy.random_reward = RandomReward.zero();
    }
    s.text_tick();
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.enemy = enemy;
        s.state = GlobalState.fight;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    draw_dialog_list(dialog, s);

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn conditional_fight_intro(s: *State, released_keys: u8, enemy: Enemy, dialog: []const Dialog) void {
    if (s.state_has_changed) {
        s.set_choices_with_labels_2("Decline", "Fight!");

        // player reset
        s.reset_player_shield();
        s.reset_spellbook();

        // enemy reset
        s.reset_enemy_intent();
        s.enemy.intent_current_time = 0;
        s.enemy.intent_index = 0;
        s.enemy.guaranteed_reward = Reward.no_reward;
        s.enemy.random_reward = RandomReward.zero();
    }
    s.text_tick();
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.pick_random_event;
    }
    if (s.choices[1].is_completed()) {
        s.enemy = enemy;
        s.state = GlobalState.fight;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    draw_dialog_list(dialog, s);

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn shop_intro(s: *State, released_keys: u8, dialog: []const Dialog, shop_gold: i16, shop_items: []const Spell) void {
    if (s.state_has_changed) {
        s.set_choices_with_labels_1("To The Shop");

        s.spell_index = 0;
        s.shop_list_index = 0;
        s.reset_shop_items();
        s.shop_gold = shop_gold;
        var i: usize = 0;
        for (shop_items) |item| {
            s.shop_items[i] = item;
            i += 1;
        }
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.set_choices_shop();
        s.state = GlobalState.shop;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    draw_dialog_list(dialog, s);

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_choices_input(s: *State, released_keys: u8) void {
    for (&s.choices) |*spell| {
        spell.process(released_keys);
    }
}

pub fn process_fight(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.frame_counter = 0;
        s.player_animation = 0;
        s.enemy_animation = 0;
        s.musicode.start_track(&empty_track, false);
        for (&s.spellbook) |*spell| {
            spell.reset();
            spell.frame_triggered = -40;
        }
        s.player_curse = Spell.zero();
    } else {
        s.frame_counter += 1;
        if (@mod(s.frame_counter, 3) == 0) {
            if (s.enemy_animation > 0) {
                s.enemy_animation -= 1;
            }
            if (s.player_animation > 0) {
                s.player_animation -= 1;
            }
        }
    }
    s.music_tick();
    s.inventory_menu_spell.process(released_keys);
    if (s.inventory_menu_spell.is_completed()) {
        s.apply_effect(s.inventory_menu_spell.effect);
        s.inventory_menu_spell.reset();
    }
    if (s.pause_menu == PauseMenu.InventoryMenu) {
        s.state_register = GlobalState.fight;
        s.state = GlobalState.inventory;
        return;
    }
    if (s.pause_menu == PauseMenu.OptionsMenu) {
        process_options_helper(s, released_keys, GlobalState.fight);
        return;
    }

    s.player_curse.process(released_keys);
    for (&s.spellbook) |*spell| {
        spell.process(released_keys);
    }

    // we assume process_fight will be called every frame
    if (s.enemy.hp > 0) {
        s.enemy.intent_current_time += 1;
        if (s.enemy.intent_current_time >= s.enemy.intent[s.enemy.intent_index].trigger_time) {
            s.apply_effect(s.enemy.intent[s.enemy.intent_index].effect);
            s.enemy.intent_current_time = 0;
            s.enemy.intent_index += 1;
            if (s.enemy.intent[s.enemy.intent_index].effect == Effect.no_effect) {
                s.enemy.intent_index = 0;
            }
        }
    } else {
        s.state = GlobalState.fight_end;
    }

    if (s.player_hp == 0) {
        s.state = GlobalState.fight_end;
    }

    // drawing
    w4.DRAW_COLORS.* = 2;

    draw_player_hud(s);

    // hero
    draw_shield(10, 22);
    s.pager.set_cursor(20, 22);
    pager.fmg_number(&s.pager, s.player_shield);
    draw_hero(20 - s.player_animation, 34);

    // enemy
    draw_enemy_hud(s);
    w4.blit(state.enemy.sprite, 105 + s.enemy_animation, 42, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);
    s.pager.set_cursor(100, 15);
    draw_progress_bubble(100, 32, s.enemy.intent_current_time, s.enemy.intent[s.enemy.intent_index].trigger_time);
    draw_effect(111, 32, s, s.enemy.intent[s.enemy.intent_index].effect);

    w4.hline(0, 80, 160);
    draw_curse(s, 10, 81);
    draw_spell_list(&s.spellbook, s, 10, 91);

    if (s.player_curse.is_completed()) {
        s.player_curse.frame_triggered = @as(i16, @intCast(s.frame_counter));
        s.apply_effect(s.player_curse.effect);
        s.change_alignment(s.player_curse.alignment);
        s.player_curse.reset();
    }
    for (&s.spellbook) |*spell| {
        if (spell.is_completed()) {
            spell.frame_triggered = @as(i16, @intCast(s.frame_counter));
            s.apply_effect(spell.effect);
            s.change_alignment(spell.alignment);
            spell.reset();
        }
    }
}

pub fn process_fight_end(s: *State, released_keys: u8) void {
    _ = released_keys;
    if (s.state_has_changed) {
        s.frame_counter = 0;
        w4.PALETTE[3] = w4.PALETTE[1];
        play_sfx_death();
        s.player_curse = Spell.zero();
    } else {
        s.frame_counter += 1;
        w4.PALETTE[3] = rgb_transition(w4.PALETTE[1], w4.PALETTE[0], s.frame_counter, 80);
        if (s.frame_counter >= 80) {
            if (s.player_hp == 0) {
                s.state = GlobalState.game_over;
            } else {
                s.state = GlobalState.fight_reward;
            }
        }
    }
    s.music_tick();

    // drawing
    w4.DRAW_COLORS.* = 2;

    draw_player_hud(s);

    if (s.player_hp == 0) {
        w4.DRAW_COLORS.* = 4;
    } else {
        w4.DRAW_COLORS.* = 2;
    }
    // hero
    draw_hero(20, 34);

    // enemy
    if (s.enemy.hp == 0) {
        w4.DRAW_COLORS.* = 4;
    } else {
        w4.DRAW_COLORS.* = 2;
    }
    w4.blit(state.enemy.sprite, 105 + s.enemy_animation, 42, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);
    w4.DRAW_COLORS.* = 2;
    // TODO modify palette
    s.pager.set_cursor(100, 15);
    w4.hline(0, 80, 160);
}
pub fn process_fight_reward(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_confirm();
        s.reward_probability = @as(u8, @intCast(@mod(rand(), 100)));
        s.play_track_fanfare03();
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.apply_reward(s.enemy.guaranteed_reward);
        if (s.reward_probability < s.enemy.random_reward.probability) {
            s.apply_reward(s.enemy.random_reward.reward);
        }
        s.state = GlobalState.pick_random_event;
    }
    s.text_tick();
    s.music_tick();
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    draw_hero(20, 34);
    w4.hline(0, 80, 160);
    s.pager.set_cursor(10, 90);
    draw_reward(s, s.enemy.guaranteed_reward);

    if (s.reward_probability < s.enemy.random_reward.probability) {
        draw_reward(s, s.enemy.random_reward.reward);
    }

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_game_over(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_confirm();
        s.play_track_fanfare02();
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.title;
    }
    s.music_tick();
    w4.DRAW_COLORS.* = 0x02;
    w4.blit(&sprites.skull, 30, 48, sprites.skull_width, sprites.skull_height, w4.BLIT_1BPP);
    w4.blit(&sprites.skull, 102, 48, sprites.skull_width, sprites.skull_height, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
    s.pager.set_cursor(48, 50);
    pager.fmg_text(&s.pager, "GAME OVER");
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_inventory(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_with_labels_2("Back", "Options");
        s.shop_list_index = 0;
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.pause_menu = PauseMenu.Off;
        s.state = s.state_register;
    }
    if (s.choices[1].is_completed()) {
        s.state = s.state_register;
        s.pause_menu = PauseMenu.OptionsMenu;
    }

    process_keys_spell_list(s, released_keys, &s.spellbook);

    const spell = s.spellbook[@as(usize, @intCast(s.spell_index))];

    w4.DRAW_COLORS.* = 0x02;
    draw_spell_details(10, 10, s, spell);
    draw_shop_tabs(s, false);
    draw_shop_party(10, 50, s, "YOU", s.player_gold);
    draw_spell_inventory_list(10, 70, s, &s.spellbook, true);

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_inventory_full(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_confirm();
        s.spell_index = 0;
        s.shop_list_index = 0;
        s.shop_gold = 0;
        s.reset_shop_items();
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.inventory_full_2;
        s.set_choices_inventory_full();
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Your spellbook is full!!");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "You should discard some spells before continuing your adventure.");
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_options(s: *State, released_keys: u8) void {
    process_options_helper(s, released_keys, GlobalState.title_1);
}

pub fn process_options_helper(s: *State, released_keys: u8, exit_state: GlobalState) void {
    // spell_index is reused to keep track of the hilighted options
    if (s.state_has_changed) {
        s.set_choices_with_labels_2("Change", "Exit");
        state.choices[0].set_spell(&[_]u8{w4.BUTTON_1});
        state.choices[1].set_spell(&[_]u8{w4.BUTTON_2});
        s.spell_index = 0;
    }

    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Options:");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    // BLINK
    pager.fmg_text(&s.pager, "  Blink: ");
    if (options[0] == 1) {
        pager.fmg_text(&s.pager, "On");
    } else {
        pager.fmg_text(&s.pager, "Off");
    }
    pager.fmg_newline(&s.pager);

    // Music Volume
    pager.fmg_text(&s.pager, "  Music volume: ");
    if (options[1] == 0) {
        pager.fmg_text(&s.pager, "Off");
    } else {
        pager.fmg_number(&s.pager, options[1]);
    }
    pager.fmg_newline(&s.pager);

    // SFX Volume
    pager.fmg_text(&s.pager, "  SFX volume: ");
    if (options[2] == 0) {
        pager.fmg_text(&s.pager, "Off");
    } else {
        pager.fmg_number(&s.pager, options[2]);
    }
    pager.fmg_newline(&s.pager);

    // Palette
    pager.fmg_text(&s.pager, "  Palette: ");
    pager.fmg_number(&s.pager, options[3]);

    draw_right_triangle(10, 25 + s.spell_index * (pager.fmg_letter_height + 1));
    if (released_keys == w4.BUTTON_UP and s.spell_index > 0) {
        s.spell_index -= 1;
    }
    if (released_keys == w4.BUTTON_DOWN and s.spell_index < 3) {
        s.spell_index += 1;
    }

    s.pager.set_cursor(10, 70);
    switch (s.spell_index) {
        0 => { // Blink
            pager.fmg_text(&s.pager, "Enable/Disable blinking of completed spells.");
        },
        1 => { // Music volume
            pager.fmg_text(&s.pager, "Change the volume used for music playback.");
        },
        2 => { // SFX volume
            pager.fmg_text(&s.pager, "Change the volume used for sound effects playback.");
        },
        3 => { // Palette
            pager.fmg_text(&s.pager, "Change the color palette for the game.");
        },
        else => {},
    }
    const incr = 10;
    if (released_keys == w4.BUTTON_LEFT) {
        if (s.spell_index == 0) { // Blink
            options[0] = 1 - options[0];
        } else if (s.spell_index == 1) { // Music volume
            if (options[1] > incr) {
                options[1] -= incr;
            } else {
                options[1] = 0;
            }
            play_sfx_menu(options[1]);
        } else if (s.spell_index == 2) { // SFX Volume
            if (options[2] > incr) {
                options[2] -= incr;
            } else {
                options[2] = 0;
            }
            play_sfx_menu(options[2]);
        } else if (s.spell_index == 3) { // Palette
            if (options[3] > 0) {
                options[3] -= 1;
            } else {
                options[3] = palettes.len - 1;
            }
            change_palette(options[3]);
        }
    }
    if (released_keys == w4.BUTTON_RIGHT) {
        if (s.spell_index == 0) { // Blink
            options[0] = 1 - options[0];
        } else if (s.spell_index == 1) { // Music volume
            if (options[1] < 100 - incr) {
                options[1] += incr;
            } else {
                options[1] = 100;
            }
            play_sfx_menu(options[1]);
        } else if (s.spell_index == 2) { // SFX Volume
            if (options[2] < 100 - incr) {
                options[2] += incr;
            } else {
                options[2] = 100;
            }
            play_sfx_menu(options[2]);
        } else if (s.spell_index == 3) { // Palette
            if (options[3] < palettes.len - 1) {
                options[3] += 1;
            } else {
                options[3] = 0;
            }
            change_palette(options[3]);
        }
    }
    process_choices_input(s, released_keys);

    if (s.choices[0].is_completed()) {
        s.choices[0].reset();
        switch (s.spell_index) {
            0 => { // BLINK
                options[0] = 1 - options[0];
            },
            1 => { // Music Volume
                options[1] += 10;
                if (options[1] > 100) {
                    options[1] = 0;
                }
                play_sfx_menu(options[1]);
            },
            2 => { // Music Volume
                options[2] += 10;
                if (options[2] > 100) {
                    options[2] = 0;
                }
                play_sfx_menu(options[2]);
            },
            3 => { // Palette
                options[3] += 1;
                if (options[3] >= palettes.len) {
                    options[3] = 0;
                }
                change_palette(options[3]);
            },
            else => {},
        }
    }
    if (s.choices[1].is_completed()) {
        _ = w4.diskw(&options, @sizeOf(@TypeOf(options)));
        s.state = exit_state;
        s.pause_menu = PauseMenu.Off;
    }

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_inventory_full_2(s: *State, released_keys: u8) void {
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        s.shop_list_index = 1 - s.shop_list_index;
    }
    var spell: Spell = undefined;
    if (s.shop_list_index == 0) {
        s.choices[0].name = "Discard";
        process_keys_spell_list(s, released_keys, &s.spellbook);
        spell = s.spellbook[@as(usize, @intCast(s.spell_index))];
    }
    if (s.shop_list_index == 1) {
        s.choices[0].name = "Pick up";
        process_keys_spell_list(s, released_keys, &s.shop_items);
        spell = s.shop_items[@as(usize, @intCast(s.spell_index))];
    }

    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        // dropping a spell
        if (s.shop_list_index == 0) {
            add_spell_to_list(spell, &s.shop_items);
            remove_nth_spell_from_list(@as(usize, @intCast(s.spell_index)), &s.spellbook);
        }
        // picking up a spell
        if (s.shop_list_index == 1) {
            add_spell_to_list(spell, &s.spellbook);
            remove_nth_spell_from_list(@as(usize, @intCast(s.spell_index)), &s.shop_items);
        }
        s.choices[0].reset();
    }
    if (s.choices[1].is_completed()) {
        if (get_spell_list_size(&s.spellbook) < spell_book_full_size) {
            s.reset_shop_items();
            s.state = GlobalState.pick_random_event;
        }
        s.choices[1].reset();
    }

    draw_spell_details(10, 10, s, spell);

    draw_shop_party(10, 50, s, "YOU", s.player_gold);
    if (s.shop_list_index == 0) {
        draw_spell_inventory_list(10, 70, s, &s.spellbook, s.shop_list_index == 0);
    }

    s.pager.set_cursor(90, 50);
    pager.fmg_text(&s.pager, "GROUND");
    if (s.shop_list_index == 1) {
        draw_spell_inventory_list(10, 70, s, &s.shop_items, s.shop_list_index == 1);
    }

    draw_shop_tabs(s, true);

    draw_spell_list(&s.choices, s, 10, 140);

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.pager.set_cursor(20, 38);
        pager.f35_text(&s.pager, "CAN'T LEAVE. SPELLBOOK FULL!");
    }
}

pub fn process_map(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_with_labels_1("Proceed");
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = s.state_register;
        return;
    }

    const name_x = 80 - pager.fmg_letter_width * @as(i32, @intCast(@divTrunc(s.area.name.len, 2)));
    s.pager.set_cursor(name_x, 40);
    pager.fmg_text(&s.pager, s.area.name);
    const counter_x = 80 - pager.fmg_letter_width * (5 / 2);
    s.pager.set_cursor(counter_x, 60);
    pager.fmg_number(&s.pager, @as(i32, @intCast(s.area_counter)));
    pager.fmg_text(&s.pager, " - ");
    pager.fmg_number(&s.pager, @as(i32, @intCast(s.area_event_counter)));

    const map_y = 100;
    var map_x: i32 = 30;
    if (s.area.event_count > 1) {
        draw_map_location(map_x, map_y);

        if (1 == s.area_event_counter) {
            draw_map_character(map_x - 6, map_y - 20);
        }
        const map_x_increment: i32 = @divTrunc(100, @as(i32, @intCast(s.area.event_count)) - 1);
        map_x += map_x_increment;
        var i: usize = 1;
        while (i < s.area.event_count) : (i += 1) {
            w4.hline(map_x - map_x_increment + 8, map_y + 2, @as(u32, @intCast(map_x_increment - 10)));
            if (i + 1 == s.area_event_counter) {
                draw_map_character(map_x - 6, map_y - 20);
            }
            draw_map_location(map_x, map_y);
            map_x += map_x_increment;
        }
    } else {
        map_x = 80;
        draw_map_location(map_x, map_y);

        if (1 == s.area_event_counter) {
            draw_map_character(map_x - 6, map_y - 20);
        }
    }

    draw_player_hud(s);
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_pick_character(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_with_labels_2("Moon", "Sun");
        s.play_track_fanfare02();
    } else {
        s.music_tick();
    }
    s.text_tick();
    process_choices_input(s, released_keys);

    // Moon loadout
    if (s.choices[0].is_completed()) {
        state.spellbook[0] = Spell.spell_fireball();
        state.spellbook[1] = Spell.spell_ash();
        state.spellbook[2] = Spell.spell_shade();
        s.state = GlobalState.pick_character_2;
    }
    // Sun loadout
    if (s.choices[1].is_completed()) {
        state.spellbook[0] = Spell.spell_lightning();
        state.spellbook[1] = Spell.spell_bolt();
        state.spellbook[2] = Spell.spell_shield();
        s.state = GlobalState.pick_character_2;
    }
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Welcome to ");
    s.pager.animate(true);
    pager.fmg_text(&s.pager, "GALDR");
    s.pager.animate(false);
    pager.fmg_text(&s.pager, "!!");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Legend says an eclipse will occur soon and will change our land forever.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "I predict you will have a role to play in this,");
    pager.fmg_text(&s.pager, "but only you can choose where your destiny will lead you.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Which one do you prefer?");

    draw_spell_list(&s.choices, s, 10, 140);
}

const pick_character_2_dialog = [_]Dialog{
    Dialog{ .text = "Very well." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You will now proceed with your quest." },
    Dialog.newline,
    Dialog{ .text = "I'd recommend you training first at the Wizard Camp though." },
};

const pick_character_2_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.crossroad },
};

pub fn process_pick_random_event(s: *State, released_keys: u8) void {
    _ = released_keys;

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.state = GlobalState.inventory_full;
        return;
    }

    if (s.area_counter >= 5) { // last boss
        s.area_event_counter += 1;
        switch (s.area_event_counter) {
            1 => {
                s.state = GlobalState.event_boss_cutscene;
            },
            2 => {
                s.state = GlobalState.event_boss_intro;
            },
            3 => {
                s.state = GlobalState.event_boss_intro_2;
            },
            4 => {
                s.state = GlobalState.event_boss;
            },
            5 => {
                s.state = GlobalState.event_boss_outro;
            },
            6 => {
                s.state = GlobalState.event_credits;
            },
            else => s.state = GlobalState.title,
        }
        return;
    }

    if (s.area_event_counter >= s.area.event_count) {
        s.state = GlobalState.crossroad;
        return;
    }
    s.area_event_counter += 1;

    const max_attempts = 128;
    var attempts: u16 = 0;
    var idx: usize = @as(usize, @intCast(@mod(rand(), s.area.event_pool.len)));
    while (s.visited_events[idx] and attempts < max_attempts) : (attempts += 1) {
        idx = @as(usize, @intCast(@mod(rand(), s.area.event_pool.len)));
    }
    if (attempts == max_attempts) {
        s.state = GlobalState.crossroad;
    } else {
        s.visited_events[idx] = true;
        s.state_register = s.area.event_pool[idx];
        s.state = GlobalState.map;
    }
}

pub fn process_title(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.frame_counter = 0;
        s.set_choices_with_labels_1("Skip");
        s.pager.set_progressive_display(false);
        s.moon_x = 20;
        w4.PALETTE[3] = w4.PALETTE[0];
        play_sfx_sweep();
    } else {
        s.frame_counter += 1;
    }
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.title_1;
    }
    process_choices_input(s, released_keys);

    if (@mod(s.frame_counter, 5) == 0) {
        s.moon_x += 1;
    }
    if (s.frame_counter < 120) {
        w4.PALETTE[3] = rgb_transition(w4.PALETTE[0], w4.PALETTE[1], s.frame_counter, 120);
    }

    if (@mod(s.frame_counter, 3) == 0 and s.frame_counter > 200) {
        w4.PALETTE[3] = rgb_transition(w4.PALETTE[1], w4.PALETTE[0], s.frame_counter - 200, 320 - 200);
    }
    if (s.frame_counter >= 320) {
        s.state = GlobalState.title_1;
    }

    const size = 60;
    w4.DRAW_COLORS.* = 0x04;
    w4.oval(s.moon_x, 50, size, size);
    w4.DRAW_COLORS.* = 0x11; // 0x11
    w4.oval(s.moon_x + 18 - @divTrunc(s.moon_x, 3), 51, size - 1, size - 1);
}

pub fn process_title_1(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.reset_choices();
        s.choices[0] = Spell.spell_title_tutorial();
        s.choices[1] = Spell.spell_title_start_game();
        s.choices[2] = Spell.spell_title_options();
        // prevent blinking for the menu :-(
        s.choices[0].frame_triggered = -99;
        s.choices[1].frame_triggered = -99;
        s.choices[2].frame_triggered = -99;
        s.play_track_title();
        w4.PALETTE[3] = 0x000000;
        s.frame_counter = 0;
    } else {
        s.music_tick();
        s.frame_counter += 1;
    }
    if (s.frame_counter < 120) {
        w4.PALETTE[3] = rgb_transition(w4.PALETTE[0], w4.PALETTE[1], s.frame_counter, 120);
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
        s.state = GlobalState.tutorial_basics;
    } else if (s.choices[1].is_completed()) {
        s.state = GlobalState.new_game_init;
    } else if (s.choices[2].is_completed()) {
        s.state = GlobalState.options;
    }

    // generate randomness
    _ = rand();

    w4.DRAW_COLORS.* = 0x04;
    draw_logo(16, 50);
    w4.DRAW_COLORS.* = 0x02;
    draw_spell_list(&s.choices, s, 10, 130);
}

pub fn process_tutorial_basics(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.choices[0] = Spell.spell_tutorial_synergies_heal();
        s.choices[1] = Spell.spell_tutorial_synergies_next();
        s.state = GlobalState.tutorial_synergies;
    }
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Welcome to GALDR!");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "We will explain you first how to cast spells");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Look at the bottom of the screen, ");
    pager.fmg_text(&s.pager, "to cast the NEXT spell:");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, " 1. press and release ");
    draw_right_arrow(s.pager.cursor_x, s.pager.cursor_y, false);
    s.pager.set_cursor(s.pager.cursor_x + 11, s.pager.cursor_y);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, " 2. then press and release ");
    draw_button_1(s.pager.cursor_x, s.pager.cursor_y, false);

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_tutorial_synergies(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[1].is_completed()) {
        s.state = GlobalState.tutorial_fights;
    }
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Now, look at the spells below; you'll notice similarities between the input needed for these two spells.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Because your input applies for all spells, casting NEXT will also cast HEAL!");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Building a spellbook with such synergies is key to become a great wizard!");

    if (s.choices[0].is_completed()) {
        draw_heart(110, 140);
        s.pager.set_cursor(120, 140);
        pager.fmg_text(&s.pager, "+1");
    }
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_tutorial_fights(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
        s.frame_counter = 0;
    } else {
        s.frame_counter += 1;
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.tutorial_fights_1;
    }

    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "When in a battle, you have the ability to know what your enemy is going to do.");
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Intent will be signfied as follows:");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    draw_sword(s.pager.cursor_x, s.pager.cursor_y);
    pager.fmg_text(&s.pager, "    when attacking");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    draw_shield(s.pager.cursor_x, s.pager.cursor_y);
    pager.fmg_text(&s.pager, "    when blocking");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    draw_fang(s.pager.cursor_x, s.pager.cursor_y);
    pager.fmg_text(&s.pager, "    when using vampirism");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    draw_exclamation_mark(s.pager.cursor_x, s.pager.cursor_y);
    pager.fmg_text(&s.pager, "    when casting a curse");

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_tutorial_fights_1(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
        s.frame_counter = 0;
    } else {
        s.frame_counter += 1;
        if (s.frame_counter > 100) {
            s.frame_counter = 0;
        }
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.tutorial_pause_menu;
    }

    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Curses are like regular spells in your spellbook, but will inflict damage when synergising with your other spells.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Curses are lifted at the end of the fight.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "You'll also know when your enemy will act with this progress \"bubble\": ");
    draw_progress_bubble(s.pager.cursor_x, s.pager.cursor_y, s.frame_counter, 100);
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_tutorial_pause_menu(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
        s.state = GlobalState.tutorial_alignment;
    }
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "When fighting in battles, it can be difficult to remember the details of each spell.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Dont worry!");
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Casting ");
    draw_button_2(s.pager.cursor_x, s.pager.cursor_y - 1, false);
    draw_button_2(s.pager.cursor_x + 11, s.pager.cursor_y - 1, false);
    draw_button_1(s.pager.cursor_x + 22, s.pager.cursor_y - 1, false);
    draw_button_1(s.pager.cursor_x + 33, s.pager.cursor_y - 1, false);
    s.pager.set_cursor(s.pager.cursor_x + 44, s.pager.cursor_y);
    pager.fmg_text(&s.pager, " will put you in the Trance of the Pause Menu.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "The Pause Menu stops time and lets you inspect your spellbook.");

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_tutorial_alignment(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.reset_choices();
        s.state = GlobalState.tutorial_end;
    }
    draw_alignment_hud(s, 10, 0);
    s.pager.set_cursor(10, 20);
    pager.fmg_text(&s.pager, "Casting spells will modify your alignment.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Alignment is shown at the top of the screen in the bar between ");
    draw_moon(s.pager.cursor_x, s.pager.cursor_y);
    s.pager.set_cursor(s.pager.cursor_x + 11, s.pager.cursor_y);
    pager.fmg_text(&s.pager, " and ");
    draw_sun(s.pager.cursor_x, s.pager.cursor_y);
    s.pager.set_cursor(s.pager.cursor_x + 11, s.pager.cursor_y);
    pager.fmg_text(&s.pager, ".");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Alignment will affect the outcome of events, or even prevent you from picking certain options, so be mindful of your alignment.");

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_tutorial_end(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.reset_choices();
        s.state = GlobalState.title;
    }
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Whether you choose to follow the moon or the sun,");
    pager.fmg_text(&s.pager, "your initiation is now finished.");
    pager.fmg_newline(&s.pager);
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Good luck!");

    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_new_game_init() void {
    const player_max_hp = 40;

    state = State{
        .previous_input = 0,
        .pager = pager.Pager.new(),
        .musicode = Musicode.new(&instruments.instruments),
        // global state
        .state = GlobalState.pick_character,
        .choices = undefined,
        .area = swamp_area,
        .visited_events = undefined,
        // player
        .player_hp = player_max_hp,
        .player_max_hp = player_max_hp,
        .spellbook = undefined,
        .player_gold = 5,
        .inventory_menu_spell = Spell.spell_inventory_menu(),

        // enemy
        .enemy = Enemy.zero(),
    };

    var i: usize = 0;
    while (i < state.spellbook.len) : (i += 1) {
        state.spellbook[i] = Spell.zero();
    }
}

pub fn current_area_pool(s: *State) []const Area {
    return switch (s.area_counter) {
        0 => &training_area_pool,
        1 => &easy_area_pool,
        2 => &medium_area_pool,
        3 => &hard_area_pool,
        4 => &boss_area_pool,
        else => unreachable,
    };
}

pub fn process_crossroad(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        if (s.area_counter >= 5) {
            s.state = GlobalState.title;
            return;
        }

        if (s.area_counter == 4) { // last boss
            s.area = boss_area;
            s.area_counter += 1;
            s.area_event_counter = 0;
            s.reset_visited_events();
            s.state = GlobalState.pick_random_event;
            return;
        }

        // pick two areas / setup choices
        const area_pool = current_area_pool(s);
        s.crossroad_index_1 = @as(usize, @intCast(@mod(rand(), area_pool.len)));
        if (area_pool.len > 1) {
            s.crossroad_index_2 = @as(usize, @intCast(@mod(rand(), area_pool.len)));
            while (s.crossroad_index_2 == s.crossroad_index_1) {
                s.crossroad_index_2 = @as(usize, @intCast(@mod(rand(), area_pool.len)));
            }
        } else {
            s.crossroad_index_2 = s.crossroad_index_1;
        }
        s.set_choices_with_labels_2(area_pool[s.crossroad_index_1].name, area_pool[s.crossroad_index_2].name);
        s.enemy.sprite = &sprites.crossroad;
    }
    s.text_tick();
    process_choices_input(s, released_keys);
    // display choices / manage user input
    w4.DRAW_COLORS.* = 2;
    draw_player_hud(s);
    draw_hero(20, 34);
    w4.blit(state.enemy.sprite, 105, 42, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);
    w4.hline(0, 80, 160);
    s.pager.set_cursor(10, 90);
    pager.fmg_text(&s.pager, "You arrive at a crossroad.");
    pager.fmg_newline(&s.pager);
    pager.fmg_text(&s.pager, "Please pick your path carefully.");
    pager.fmg_newline(&s.pager);
    draw_spell_list(&s.choices, s, 10, 140);
    const area_pool = current_area_pool(s);
    if (s.choices[0].is_completed()) {
        s.area = area_pool[s.crossroad_index_1];
        s.area_counter += 1;
        s.area_event_counter = 0;
        s.reset_visited_events();
        s.state = GlobalState.pick_random_event;
    } else if (s.choices[1].is_completed()) {
        s.area = area_pool[s.crossroad_index_2];
        s.area_event_counter = 0;
        s.area_counter += 1;
        s.reset_visited_events();
        s.state = GlobalState.pick_random_event;
    }
}

pub fn process_event_boss_cutscene(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.frame_counter = 0;
        s.set_choices_with_labels_1("Skip");
        s.pager.set_progressive_display(false);
        s.moon_x = 70;
        w4.PALETTE[3] = 0x000000;
        play_sfx_sweep();
    } else {
        s.frame_counter += 1;
    }
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.pick_random_event;
    }
    process_choices_input(s, released_keys);

    if (@mod(s.frame_counter, 10) == 0 and s.moon_x > 51) {
        s.moon_x -= 1;
    }
    if (s.frame_counter < 120) {
        w4.PALETTE[3] = rgb_transition(w4.PALETTE[0], w4.PALETTE[1], s.frame_counter, 120);
    }

    if (s.frame_counter > 180) {
        w4.PALETTE[3] = rgb_transition(w4.PALETTE[1], w4.PALETTE[0], s.frame_counter - 180, 300 - 180);
    }
    if (s.frame_counter >= 300) {
        s.state = GlobalState.pick_random_event;
    }

    const size = 60;
    w4.DRAW_COLORS.* = 0x04;
    w4.oval(50, 50, size, size);
    w4.DRAW_COLORS.* = 0x11;
    w4.oval(s.moon_x, 51, size - 1, size - 1);
}

const event_boss_intro_dialog = [_]Dialog{
    Dialog{ .text = "The eclipse is at its peak and the temperature is noticeably colder." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You arrive at what seems to be a sacrificial site. " },
    Dialog{ .text = "A group of wizards you don't recognize are all working together on a casting an invocation spell." },
};

const event_boss_intro_dialog_2 = [_]Dialog{
    Dialog{ .text = "After a flash of light, a giant silver dragon appears!" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "With one swift movement, the dragon kills most of the wizards that helped him come back to life. The rest of them tries to flee, but in vain." },
};

const boss_dialog = [_]Dialog{
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "With the dragon's roar piercing your ears, you understand there is no turning back!!" },
};

const event_boss_outro_dialog = [_]Dialog{
    Dialog{ .text = "After one last spell, the dragon finally collapses." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You too fall on the ground, not so much due to your injuries, but because of exhaustion." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "As the eclipse fades out, you close your eyes knowing that you saved the world..." },
};

const castle_bat_dialog = [_]Dialog{
    Dialog{ .text = "This neglected castle is full of annoying bats!!" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "In fact one of them really wants to take a bite out of you..." },
};

const castle_candle_dialog = [_]Dialog{
    Dialog{ .text = "Candles here seem to be items cache..." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Maybe you should try to break one of them?" },
};

const castle_schmoo_dialog = [_]Dialog{
    Dialog{ .text = "The air around you becomes colder..." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "A severed head suddenly appears out of nowhere and is flying in your direction." },
};

const castle_sun_shop_dialog = [_]Dialog{
    Dialog{ .text = "The merchant seems surprised:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"A customer?? It's been long since I've seen anyone around here...\"" },
};

const castle_sun_shop_gold = 50;
const castle_sun_shop_items = [_]Spell{
    Spell.spell_knife(),
    Spell.spell_cross(),
    Spell.spell_whip(),
};

const castle_vampire_shop_dialog = [_]Dialog{
    Dialog{ .text = "A vampire seems to have set up shop here." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"You're not a vampire, but a customer is a customer...\"" },
};

const castle_vampire_shop_gold = 50;
const castle_vampire_shop_items = [_]Spell{
    Spell.spell_fangs(),
    Spell.spell_cloak(),
};

pub fn process_credits(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_with_labels_1("Done");
        s.play_track_fanfare02();
    }

    if (s.choices[0].is_completed()) {
        s.state = GlobalState.title;
    }
    process_choices_input(s, released_keys);
    s.music_tick();
    s.text_tick();

    draw_logo(16, 10);

    s.pager.set_cursor(28, 60);
    pager.f35_text(&s.pager, "A GAME BY JONATHAN DERQUE");

    s.pager.set_cursor(10, 80);
    pager.f35_text(&s.pager, "THIS GAME COULD NOT HAVE BEEN MADE WITHOUT:");
    pager.f35_newline(&s.pager);
    pager.f35_text(&s.pager, " - ART FROM THE SCROLL-O-SPRITES");
    pager.f35_newline(&s.pager);
    pager.f35_text(&s.pager, "   BY QUALE");
    pager.f35_newline(&s.pager);
    pager.f35_text(&s.pager, " - MONOGRAM FONT BY DATAGOBLIN");
    pager.f35_newline(&s.pager);
    pager.f35_text(&s.pager, " - THE WASM-4 FANTASY CONSOLE BY");
    pager.f35_newline(&s.pager);
    pager.f35_text(&s.pager, "   ADUROS, AND ITS COMMUNITY");

    s.pager.set_cursor(20, 135);

    s.pager.animate(true);
    pager.f35_text(&s.pager, "THANK YOU FOR PLAYING GALDR");
    s.pager.animate(false);

    draw_spell_list(&s.choices, s, 10, 150);
}

pub fn apply_outcome_list(s: *State, outcome: []const Outcome) void {
    for (outcome) |o| {
        switch (o) {
            Outcome.area => |area| {
                s.area = area;
                s.area_event_counter = 0;
                s.reset_visited_events();
                s.state = GlobalState.pick_random_event;
            },
            Outcome.state => |st| {
                s.state = st;
            },
            Outcome.guaranteed_reward => |reward| {
                s.enemy.guaranteed_reward = reward;
            },
            Outcome.apply_effect => |effect| {
                s.apply_effect(effect);
            },
        }
    }
}

pub fn text_event_choice_2(s: *State, released_keys: u8, dialog: []const Dialog, choice0: []const u8, outcome0: []const Outcome, choice1: ?[]const u8, outcome1: []const Outcome) void {
    if (s.state_has_changed) {
        s.pager.reset_steps();
        s.reset_choices();
        if (choice1 != null) {
            s.set_choices_with_labels_2(choice0, choice1.?);
        } else {
            s.set_choices_with_labels_1(choice0);
        }
        s.enemy.random_reward = RandomReward.zero();
        s.enemy.guaranteed_reward = Reward.no_reward;
    }
    s.text_tick();
    process_choices_input(s, released_keys);
    if (s.choices[0].is_defined() and s.choices[0].is_completed()) {
        apply_outcome_list(s, outcome0);
        return;
    } else if (s.choices[1].is_defined() and s.choices[1].is_completed()) {
        apply_outcome_list(s, outcome1);
        return;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    draw_dialog_list(dialog, s);
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn text_event_choice_1(s: *State, released_keys: u8, dialog: []const Dialog, choice0: []const u8, outcome0: []const Outcome) void {
    text_event_choice_2(s, released_keys, dialog, choice0, outcome0, null, undefined);
}

pub fn text_event_confirm(s: *State, released_keys: u8, dialog: []const Dialog) void {
    const outcome = [_]Outcome{
        Outcome{ .state = GlobalState.pick_random_event },
    };
    text_event_choice_1(s, released_keys, dialog, "Confirm", &outcome);
}

const event_barbarian_invasion_dialog = [_]Dialog{
    Dialog{ .text = "A villager pleas for help:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Barbarians are about to land on our shores, please help us fight them!\"" },
};

const event_kidnapped_daughter_dialog = [_]Dialog{
    Dialog{ .text = "\"Pirates have kidnapped our beloved daughter!\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Can you please try to save her from the pirates?\"" },
};

const event_kidnapped_daughter_decline_dialog = [_]Dialog{
    Dialog{ .text = "Despite their distress, you answer that you have a more important quest to fulfill.." },
};

const event_kidnapped_daughter_skip_outcome = [_]Outcome{
    Outcome{
        .state = GlobalState.event_coast_kidnapped_daughter_decline,
    },
};

const event_kidnapped_daughter_accept_outcome = [_]Outcome{
    Outcome{
        .area = pirate_area,
    },
};

const event_merfolk_dialog = [_]Dialog{
    Dialog{ .text = "A sudden tide sees you abruptly surrounded with water." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "A half-fish half-man being menacingly appears in front of you" },
};

const event_cavern_man_outcome = [_]Outcome{
    Outcome{ .guaranteed_reward = Reward{ .spell_reward = Spell.spell_sword() } },
    Outcome{ .state = GlobalState.fight_reward },
};
const event_cavern_man_dialog = [_]Dialog{
    Dialog{ .text = "You meet an old man living in a cavern. He says:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"It's dangerous to go alone! Take this.\"" },
};

const event_chest_dialog = [_]Dialog{
    Dialog{ .text = "There is a chest here. It probably contains some valuables." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Open the chest?" },
};

const event_mimic_dialog = [_]Dialog{
    Dialog{ .text = "This chest appears to be a mimic!... and it does not like you fiddling with it." },
};

const event_chest_skip_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.pick_random_event },
};

const event_chest_regular_gold_outcome = [_]Outcome{
    Outcome{ .guaranteed_reward = Reward{ .gold_reward = 10 } },
    Outcome{ .state = GlobalState.fight_reward },
};

const event_chest_mimic_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_chest_mimic_fight_intro },
};

const event_seagull_dialog = [_]Dialog{
    Dialog{ .text = "As you were quietly enjoying your meal on the beach, a seagull is trying to steal your food!!!" },
};

const event_sea_monster_dialog = [_]Dialog{
    Dialog{ .text = "Fishermen are approaching you, they say:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"With the upcoming eclipse, attacks from the sea monster are more frequent..\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Can you help us get rid of it?\"" },
};

const coin_muncher_dialog = [_]Dialog{
    Dialog{ .text = "You suddenly wake up with something brushing against your leg!" },
    Dialog.newline,
    Dialog{ .text = "You discover a Coin Muncher feeding on the content of your purse!!" },
};

const event_healer_dialog = [_]Dialog{
    Dialog{ .text = "You stumble upon an old man wearing druid clothes. He says:" },
    Dialog.newline,
    Dialog{ .text = "\"I can heal your wounds for 10 gold. Are you interested?\"" },
};
const event_healer_decline_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_healer_decline },
};
const event_healer_accept_outcome = [_]Outcome{
    Outcome{ .apply_effect = Effect{ .gold_payment = 10 } },
    Outcome{ .apply_effect = Effect.player_healing_max },
    Outcome{ .state = GlobalState.event_healer_accept },
};

pub fn process_event_healer(s: *State, released_keys: u8) void {
    if (s.player_gold >= 10) {
        text_event_choice_2(s, released_keys, &event_healer_dialog, "Decline", &event_healer_decline_outcome, "Accept", &event_healer_accept_outcome);
    } else {
        text_event_choice_1(s, released_keys, &event_healer_dialog, "You're broke", &event_healer_decline_outcome);
    }
}

const event_healer_decline_dialog = [_]Dialog{
    Dialog{ .text = "The druid says:" },
    Dialog.newline,
    Dialog{ .text = "\"As you wish. May you be successful in your endeavours.\"" },
};

const event_healer_accept_dialog = [_]Dialog{
    Dialog{ .text = "The druid utters weird sounds that only him can understand, but you already feels better." },
};

const coastal_shop_gold = 50;
const coastal_shop_items = [_]Spell{
    Spell.spell_ice_shard(),
    Spell.spell_moon_shiv(),
    Spell.spell_fireball(),
    Spell.spell_buckler(),
};
const coastal_shop_dialog = [_]Dialog{
    Dialog{ .text = "The merchant says:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"I used to be a wizard like you. Then I took a wand in the knee.\"" },
};

const event_dungeon_ambush_sun_dialog = [_]Dialog{
    Dialog{ .text = "As you make your way through the forest, you encounter a faction of sun soldiers." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You share your quest objectives with them but they cannot help you at the moment." },
};

const event_dungeon_ambush_moon_dialog = [_]Dialog{
    Dialog{ .text = "As you make your way through the forest, a faction of sun soldiers attacks you." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Before you can defend yourself, you fall to the ground and lose conciousness...." },
};

const event_dungeon_ambush_moon_outcome = [_]Outcome{
    Outcome{
        .area = dungeon_area,
    },
};

pub fn process_dungeon_ambush(s: *State, released_keys: u8) void {
    if (s.player_alignment <= -10) {
        text_event_choice_1(&state, released_keys, &event_dungeon_ambush_moon_dialog, "Confirm", &event_dungeon_ambush_moon_outcome);
    } else {
        text_event_confirm(&state, released_keys, &event_dungeon_ambush_sun_dialog);
    }
}

pub fn process_dungeon(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.pager.reset_steps();
        s.set_choices_confirm();
        s.spellbook[0] = Spell.spell_soul_steal();
        var i: usize = 1;
        while (i < s.spellbook.len) : (i += 1) {
            s.spellbook[i] = Spell.zero();
        }
        s.player_hp = 1;
        s.player_gold = 0;
    }
    s.text_tick();
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.event_dungeon_1;
    }

    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    draw_dialog_list(&event_dungeon_dialog, s);
    draw_spell_list(&s.choices, s, 10, 140);
}

const event_dungeon_dialog = [_]Dialog{
    Dialog{ .text = "\"Hey!\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You slowly open your eyes... Your whole body hurts." },
};

const event_dungeon_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_1 },
};

const event_dungeon_dialog_1 = [_]Dialog{
    Dialog{ .text = "\"Ah, nice to see you're finally coming to.\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Looking around you, you seem to be in jail. The person talking to you is a guard outside of your cell." },
};

const event_dungeon_outcome_1 = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_2 },
};

const event_dungeon_dialog_2 = [_]Dialog{
    Dialog{ .text = "\"Looks like the soldiers got you beaten up pretty bad.\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Don't be afraid, I'm here to help you.\"" },
};

const event_dungeon_outcome_2 = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_3 },
};

const event_dungeon_dialog_3 = [_]Dialog{
    Dialog{ .text = "\"I'd advise you to take some rest, but we have to act now if you want to get out of here.\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "The \"guard\" opens the door of your cell and helps you getting up." },
};

const event_dungeon_outcome_3 = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_4 },
};

const event_dungeon_dialog_4 = [_]Dialog{
    Dialog{ .text = "\"Come on, let's get you out.\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You struggle to walk as the pain races through your body, but your mind is already focusing a little." },
};

const event_dungeon_outcome_4 = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_5 },
};

const event_dungeon_dialog_5 = [_]Dialog{
    Dialog{ .text = "\"Your spellbook?? I'm afraid it is gone for good.\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"But I stole this spell on my way here. I guess you can have it.\"" },
};

const event_dungeon_outcome_5 = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_6 },
};

const event_dungeon_dialog_6 = [_]Dialog{
    Dialog{ .text = "\"I can't go beyond that point or they'll suspect I was the one helping you. Good luck!!\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{
        .text = "Before you can thank him, your savior disappears in a dark corridor.",
    },
};

const event_dungeon_outcome_6 = [_]Outcome{
    Outcome{ .state = GlobalState.event_dungeon_7 },
};

const event_dungeon_dialog_7 = [_]Dialog{
    Dialog{ .text = "On your way out of the dungeon, you stumble upon a guard at the entrance." },
};

const mine_shop_gold = 50;
const mine_shop_items = [_]Spell{
    Spell.spell_root(),
    Spell.spell_mud_plate(),
    Spell.spell_earth_ball(),
};
const mine_shop_dialog = [_]Dialog{
    Dialog{ .text = "The sign at the entrance reads" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"This shop in an abandonned mine tunnel is bought to you by HildinVPN!\"" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You do not like this trend of seeing ads everywhere..." },
};

const healing_shop_gold = 50;
const healing_shop_items = [_]Spell{
    Spell.spell_heal(),
    Spell.spell_sun_shiv(),
};
const healing_shop_dialog = [_]Dialog{
    Dialog{ .text = "The merchant greets you:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Welcome to Hildin's Heap of Heals!\"" },
};

const swamp_shop_gold = 50;
const swamp_shop_items = [_]Spell{
    Spell.spell_ice_shard(),
    Spell.spell_sun_shiv(),
    Spell.spell_heal(),
};
// SHOP
const swamp_shop_dialog = [_]Dialog{
    Dialog{ .text = "\"Hildin is always up to do business, even in the slimiest places!\"" },
};

pub fn process_keys_spell_list(s: *State, released_keys: u8, spell_list: []Spell) void {
    if (released_keys == w4.BUTTON_DOWN) {
        s.spell_index += 1;
        while (!spell_list[@as(usize, @intCast(s.spell_index))].is_defined() and s.spell_index < spell_list.len) {
            s.spell_index += 1;
        }
        if (s.spell_index >= spell_list.len) {
            s.spell_index = 0;
        }
    }
    // switch from one list to the other -> make sure we are within bounds of the new list
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        while (!spell_list[@as(usize, @intCast(s.spell_index))].is_defined() and s.spell_index >= 0) {
            s.spell_index -= 1;
        }
        if (s.spell_index <= 0) { // should not happen unless empty spell list
            s.spell_index = 0;
        }
    }
    if (released_keys == w4.BUTTON_UP) {
        s.spell_index -= 1;
        if (s.spell_index < 0) {
            s.spell_index = @as(isize, @intCast(spell_list.len - 1));
            while (!spell_list[@as(usize, @intCast(s.spell_index))].is_defined() and s.spell_index >= 0) {
                s.spell_index -= 1;
            }
            if (s.spell_index <= 0) { // should not happen unless empty spell list
                s.spell_index = 0;
            }
        }
    }
}

pub fn draw_shop_tabs(s: *State, draw_second_tab: bool) void {
    const y = 46;
    const tab_width = 69;
    const tab_height = 13;
    const left_tab_x = 6;
    const right_tab_x = 86;
    w4.hline(left_tab_x, y, tab_width);
    w4.vline(left_tab_x - 1, y + 1, tab_height);
    w4.vline(left_tab_x + tab_width, y + 1, tab_height);

    if (draw_second_tab) {
        w4.hline(right_tab_x, y, tab_width);
        w4.vline(right_tab_x - 1, y + 1, tab_height);
        w4.vline(right_tab_x + tab_width, y + 1, tab_height);
    }

    w4.hline(0, y + tab_height, left_tab_x);
    w4.hline(left_tab_x + tab_width, y + tab_height, 11);
    w4.hline(right_tab_x + tab_width, y + tab_height, 10);

    if (s.shop_list_index == 0) {
        w4.hline(right_tab_x, y + tab_height, tab_width);
    }
    if (s.shop_list_index == 1) {
        w4.hline(left_tab_x, y + tab_height, tab_width);
    }
}

pub fn process_shop(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.shop_list_index = 1; // start on the "Buy" tab
    }
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        s.shop_list_index = 1 - s.shop_list_index;
    }
    var spell: Spell = undefined;
    if (s.shop_list_index == 0) {
        s.choices[0].name = "Sell";
        process_keys_spell_list(s, released_keys, &s.spellbook);
        spell = s.spellbook[@as(usize, @intCast(s.spell_index))];
    }
    if (s.shop_list_index == 1) {
        s.choices[0].name = "Buy";
        process_keys_spell_list(s, released_keys, &s.shop_items);
        spell = s.shop_items[@as(usize, @intCast(s.spell_index))];
    }

    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        // selling a spell
        if (s.shop_list_index == 0) {
            s.player_gold += @as(i16, @intCast(spell.price));
            s.shop_gold -= @as(i16, @intCast(spell.price));
            add_spell_to_list(spell, &s.shop_items);
            remove_nth_spell_from_list(@as(usize, @intCast(s.spell_index)), &s.spellbook);
        }
        // buying a spell
        if (s.shop_list_index == 1) {
            s.player_gold -= @as(i16, @intCast(spell.price));
            s.shop_gold += @as(i16, @intCast(spell.price));
            add_spell_to_list(spell, &s.spellbook);
            remove_nth_spell_from_list(@as(usize, @intCast(s.spell_index)), &s.shop_items);
        }
        s.choices[0].reset();
    }
    if (s.choices[1].is_completed()) {
        if (s.player_gold >= 0 and s.shop_gold >= 0 and get_spell_list_size(&s.spellbook) < spell_book_full_size) {
            s.state = GlobalState.pick_random_event;
        }
        s.choices[1].reset();
    }

    w4.DRAW_COLORS.* = 0x02;
    draw_spell_details(10, 10, s, spell);

    draw_shop_party(10, 50, s, "YOU", s.player_gold);
    if (s.shop_list_index == 0) {
        draw_spell_inventory_list(10, 70, s, &s.spellbook, s.shop_list_index == 0);
    }

    draw_shop_party(90, 50, s, "SHOP", s.shop_gold);
    if (s.shop_list_index == 1) {
        draw_spell_inventory_list(10, 70, s, &s.shop_items, s.shop_list_index == 1);
    }

    draw_shop_tabs(s, true);

    draw_spell_list(&s.choices, s, 10, 140);

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.pager.set_cursor(20, 38);
        pager.f35_text(&s.pager, "CAN'T LEAVE. SPELLBOOK FULL!");
    }
    if (s.player_gold < 0 or s.shop_gold < 0) {
        s.pager.set_cursor(18, 38);
        pager.f35_text(&s.pager, "CAN'T LEAVE. NOT ENOUGH MONEY!");
    }
}

const forest_wolf_dialog = [_]Dialog{
    Dialog{ .text = "As you pass through the dark woods, you hear a frightening growl behind you." },
    Dialog.newline,
    Dialog{ .text = "A giant lone wolf is snarling at you. You have no choice other than to fight for your life!" },
};

const mine_troll_dialog = [_]Dialog{
    Dialog{ .text = "As you exit a narrow gallery in the mines, you are being chased by a troll." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "They certainly know their way in these dark places!" },
};

const mine_troll_warrior_dialog = [_]Dialog{
    Dialog{ .text = "A troll warrior screems when seeing you wandering in the mines." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "You should prevent him from rallying his friends!!" },
    Dialog{ .text = "Using your spellbook is the only way to shut him down.." },
};

const mine_troll_king_dialog = [_]Dialog{
    Dialog{ .text = "You arrive at a wide chamber carved deep in the mountain." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Amongst skeletons and chests the troll king is mumbling to himself" },
    Dialog{ .text = "This unpleasant sound turns into a terrifying scream as soon as he notices you.." },
};

const event_moon_altar_skip_dialog = [_]Dialog{
    Dialog{ .text = "There is a moon altar here." },
    Dialog.newline,
    Dialog{ .text = "However, you have no use of such a thing." },
};

const event_moon_altar_skip_1_dialog = [_]Dialog{
    Dialog{ .text = "You move on, leaving the altar behind you." },
};

const event_moon_altar_pray_dialog = [_]Dialog{
    Dialog{ .text = "There is a moon altar here." },
    Dialog.newline,
    Dialog{ .text = "Some respite for your mind if you wish..." },
};

const event_moon_altar_pray_1_dialog = [_]Dialog{
    Dialog{ .text = "After praying for some time, you feel comforted in your allegiance to the moon." },
};

const event_moon_altar_destroy_dialog = [_]Dialog{
    Dialog{ .text = "There is a moon altar here." },
    Dialog.newline,
    Dialog{ .text = "Such an altar is an insult to your allegiance. Destroy it?" },
};

const event_moon_altar_destroy_1_dialog = [_]Dialog{
    Dialog{ .text = "You move on after turning the altar into a pile of rubble." },
};

const event_moon_altar_skip_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_moon_altar_skip },
};

const event_moon_altar_pray_outcome = [_]Outcome{
    Outcome{ .apply_effect = Effect{ .alignment = -15 } },
    Outcome{ .state = GlobalState.event_moon_altar_pray },
};

const event_moon_altar_destroy_outcome = [_]Outcome{
    Outcome{ .apply_effect = Effect{ .alignment = 10 } },
    Outcome{ .state = GlobalState.event_moon_altar_destroy },
};

pub fn process_event_moon_altar(s: *State, released_keys: u8) void {
    if (s.player_alignment <= -20) {
        text_event_choice_2(s, released_keys, &event_moon_altar_pray_dialog, "Skip", &event_moon_altar_skip_outcome, "Pray", &event_moon_altar_pray_outcome);
    } else if (s.player_alignment >= 20) {
        text_event_choice_2(s, released_keys, &event_moon_altar_destroy_dialog, "Skip", &event_moon_altar_skip_outcome, "Destroy", &event_moon_altar_destroy_outcome);
    } else {
        text_event_choice_1(s, released_keys, &event_moon_altar_skip_dialog, "Skip", &event_moon_altar_skip_outcome);
    }
}

const moon_partisan_skip_dialog = [_]Dialog{
    Dialog{ .text = "You run into a group of moon partisans." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Happy to see one of them, they greet you and wish you good luck." },
};

const moon_partisan_fight_dialog = [_]Dialog{
    Dialog{ .text = "You run into a group of moon partisans:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Hey you, stop right there where you are!\"" },
};
pub fn process_event_moon_partisan(s: *State, released_keys: u8) void {
    if (s.player_alignment <= -20) {
        text_event_confirm(&state, released_keys, &moon_partisan_skip_dialog);
    } else {
        fight_intro(&state, released_keys, Enemy.enemy_partisan(), &moon_partisan_fight_dialog);
    }
}

const sun_partisan_skip_dialog = [_]Dialog{
    Dialog{ .text = "You run into a group of sun partisans." },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "Happy to see one of them, they greet you and wish you good luck." },
};

const sun_partisan_fight_dialog = [_]Dialog{
    Dialog{ .text = "You run into a group of sun partisans:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"A Moon Wizard! We don't like your kind around here..\"" },
};
pub fn process_event_sun_partisan(s: *State, released_keys: u8) void {
    if (s.player_alignment >= 20) {
        text_event_confirm(&state, released_keys, &sun_partisan_skip_dialog);
    } else {
        fight_intro(&state, released_keys, Enemy.enemy_partisan(), &sun_partisan_fight_dialog);
    }
}

const militia_ambush_dialog = [_]Dialog{
    Dialog{ .text = "You spot a lone militia soldier coming your way." },
    Dialog.newline,
    Dialog{ .text = "He does not seem aware that you're here." },
};

const pirate_dialog = [_]Dialog{
    Dialog{ .text = "A pirate appears and draws his sword!!" },
};

const pirate_captain_dialog = [_]Dialog{
    Dialog{ .text = "You confront the pirate captain, he laughs:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"The girl?? She's mine!!!\"" },
};

const event_rat_dialog = [_]Dialog{
    Dialog{ .text = "There are so many rats here... You try to kill those that come a bit too close." },
};

const snake_pit_dialog = [_]Dialog{
    Dialog{ .text = "You fall into a large man-made pit that someone filled with snakes!" },
    Dialog.newline,
    Dialog{ .text = "You can't get out safely without dealing with your slithery foes first." },
};

const event_sun_altar_skip_dialog = [_]Dialog{
    Dialog{ .text = "There is a sun altar here." },
    Dialog.newline,
    Dialog{ .text = "However, you have no use of such a thing." },
};

const event_sun_altar_skip_1_dialog = [_]Dialog{
    Dialog{ .text = "You move on, leaving the altar behind you." },
};

const event_sun_altar_pay_dialog = [_]Dialog{
    Dialog{ .text = "There is a sun altar here." },
    Dialog.newline,
    Dialog{ .text = "Some respite for your mind in exchange of some gold." },
};

const event_sun_altar_no_pay_dialog = [_]Dialog{
    Dialog{ .text = "There is a sun altar here." },
    Dialog.newline,
    Dialog{ .text = "This would be a welcome tribute, however you do not have enough gold." },
};

const event_sun_altar_pay_1_dialog = [_]Dialog{
    Dialog{ .text = "After leaving a tribute, you feel comforted in your allegiance to the sun." },
};

const event_sun_altar_destroy_dialog = [_]Dialog{
    Dialog{ .text = "There is a sun altar here." },
    Dialog.newline,
    Dialog{ .text = "Such an altar is an insult to your allegiance. Destroy it?" },
};

const event_sun_altar_destroy_1_dialog = [_]Dialog{
    Dialog{ .text = "You move on after turning the altar into a pile of rubble." },
};

const event_sun_altar_skip_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_sun_altar_skip },
};

const event_sun_altar_pay_outcome = [_]Outcome{
    Outcome{ .apply_effect = Effect{ .gold_payment = 20 } },
    Outcome{ .apply_effect = Effect{ .alignment = 15 } },
    Outcome{ .state = GlobalState.event_sun_altar_pay },
};

const event_sun_altar_destroy_outcome = [_]Outcome{
    Outcome{ .apply_effect = Effect{ .alignment = -10 } },
    Outcome{ .state = GlobalState.event_sun_altar_destroy },
};

pub fn process_event_sun_altar(s: *State, released_keys: u8) void {
    if (s.player_alignment >= 20) {
        if (s.player_gold >= 20) {
            text_event_choice_2(s, released_keys, &event_sun_altar_pay_dialog, "Skip", &event_sun_altar_skip_outcome, "Pay", &event_sun_altar_pay_outcome);
        } else {
            text_event_choice_1(s, released_keys, &event_sun_altar_no_pay_dialog, "Skip", &event_sun_altar_skip_outcome);
        }
    } else if (s.player_alignment <= -20) {
        text_event_choice_2(s, released_keys, &event_sun_altar_destroy_dialog, "Skip", &event_sun_altar_skip_outcome, "Destroy", &event_sun_altar_destroy_outcome);
    } else {
        text_event_choice_1(s, released_keys, &event_sun_altar_skip_dialog, "Skip", &event_sun_altar_skip_outcome);
    }
}

const swamp_people_dialog = [_]Dialog{
    Dialog{ .text = "Swamp people do not have a reputation of being friendly" },
    Dialog.newline,
    Dialog{ .text = "You are about to confirm this as you ran into one of them unexpectedly." },
};

const swamp_creature_dialog = [_]Dialog{
    Dialog{ .text = "You observe a large creature moving in the swamp." },
    Dialog.newline,
    Dialog{ .text = "It seems to move towards your direction!" },
    Dialog.newline,
    Dialog{ .text = "Before you can even flee, the large creature is onto you." },
};

const event_sun_fountain_dialog = [_]Dialog{
    Dialog{ .text = "You come across a white fountain basking in a pillar of light." },
    Dialog.newline,
    Dialog{ .text = "You feel thirsty. Do you want to drink from the fountain?" },
};
const event_sun_fountain_skip_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_sun_fountain_skip },
};
const event_sun_fountain_moon_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_sun_fountain_damage },
    Outcome{ .apply_effect = Effect{ .damage_to_player = 5 } },
};
const event_sun_fountain_sun_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_sun_fountain_heal },
    Outcome{ .apply_effect = Effect{ .player_heal = 10 } },
};
const event_sun_fountain_refresh_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_sun_fountain_refresh },
};

pub fn process_event_sun_fountain(s: *State, released_keys: u8) void {
    if (s.player_alignment < -20) {
        text_event_choice_2(s, released_keys, &event_sun_fountain_dialog, "Skip", &event_sun_fountain_skip_outcome, "Drink", &event_sun_fountain_moon_outcome);
    } else if (s.player_alignment > 20) {
        text_event_choice_2(s, released_keys, &event_sun_fountain_dialog, "Skip", &event_sun_fountain_skip_outcome, "Drink", &event_sun_fountain_sun_outcome);
    } else {
        text_event_choice_2(s, released_keys, &event_sun_fountain_dialog, "Skip", &event_sun_fountain_skip_outcome, "Drink", &event_sun_fountain_refresh_outcome);
    }
}

const event_sun_fountain_skip_dialog = [_]Dialog{
    Dialog{ .text = "Such a fountain in the middle of nowhere seems strange. You continue your journey without drinking from it." },
};

const event_sun_fountain_damage_dialog = [_]Dialog{
    Dialog{ .text = "The water has a foul taste and your belly immediately hurts." },
    Dialog.newline,
    Dialog{ .text = "You cast a spell to improve your condition but do not fully recover." },
};

const event_sun_fountain_heal_dialog = [_]Dialog{
    Dialog{ .text = "The water is cool and you feel calm and relaxed." },
    Dialog.newline,
    Dialog{ .text = "After resting for a bit, you move on to your next adventure." },
};

const event_sun_fountain_refresh_dialog = [_]Dialog{
    Dialog{ .text = "The water is tepid and tasteless." },
    Dialog.newline,
    Dialog{ .text = "After resting for a bit, you move on to your next adventure." },
};

const event_moon_fountain_dialog = [_]Dialog{
    Dialog{ .text = "You come across a grey fountain in the shade of a large tree." },
    Dialog.newline,
    Dialog{ .text = "You feel thirsty. Do you want to drink from the fountain?" },
};
const event_moon_fountain_skip_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_moon_fountain_skip },
};
const event_moon_fountain_sun_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_moon_fountain_damage },
    Outcome{ .apply_effect = Effect{ .damage_to_player = 5 } },
};
const event_moon_fountain_moon_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_moon_fountain_heal },
    Outcome{ .apply_effect = Effect{ .player_heal = 15 } },
};
const event_moon_fountain_refresh_outcome = [_]Outcome{
    Outcome{ .state = GlobalState.event_moon_fountain_refresh },
};

pub fn process_event_moon_fountain(s: *State, released_keys: u8) void {
    if (s.player_alignment < -20) {
        text_event_choice_2(s, released_keys, &event_moon_fountain_dialog, "Skip", &event_moon_fountain_skip_outcome, "Drink", &event_moon_fountain_moon_outcome);
    } else if (s.player_alignment > 20) {
        text_event_choice_2(s, released_keys, &event_moon_fountain_dialog, "Skip", &event_moon_fountain_skip_outcome, "Drink", &event_moon_fountain_sun_outcome);
    } else {
        text_event_choice_2(s, released_keys, &event_moon_fountain_dialog, "Skip", &event_moon_fountain_skip_outcome, "Drink", &event_moon_fountain_refresh_outcome);
    }
}

const event_moon_fountain_skip_dialog = [_]Dialog{
    Dialog{ .text = "You continue your journey without drinking from suspicious fountain." },
};

const event_moon_fountain_damage_dialog = [_]Dialog{
    Dialog{ .text = "The water has a foul taste and your belly immediately hurts." },
    Dialog.newline,
    Dialog{ .text = "You cast a spell to improve your condition but do not fully recover." },
};

const event_moon_fountain_heal_dialog = [_]Dialog{
    Dialog{ .text = "The water is cool and you feel calm and relaxed." },
    Dialog.newline,
    Dialog{ .text = "After resting for a bit, you move on to your next adventure." },
};

const event_moon_fountain_refresh_dialog = [_]Dialog{
    Dialog{ .text = "The water is tepid and tasteless." },
    Dialog.newline,
    Dialog{ .text = "After resting for a bit, you move on to your next adventure." },
};

const training_fight_dialog_1 = [_]Dialog{
    Dialog{ .text = "Your mentor says:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Let's pratice your fighting skills against this soldier. Try to avoid taking any damage.\"" },
};

const training_fight_dialog_2 = [_]Dialog{
    Dialog{ .text = "Your mentor says:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"You'll have to cast more spells here to go through your enemy shield!\"" },
};

const training_bat_dialog = [_]Dialog{
    Dialog{ .text = "Your mentor says:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"This bat will drain your blood to heal herself. Use your shield to prevent this!" },
};

const empty_track = [_]u8{
    Musicode.wait(1),
};

var options = [_]u8{
    1, // 0-BLINK
    50, // 1-MUSIC VOLUME
    50, // 2-SFX VOLUME
    0, // 3-PALETTE
};
var state: State = undefined;

export fn start() void {
    _ = w4.diskr(&options, @sizeOf(@TypeOf(options)));
    change_palette(options[3]);
    state = State{
        .musicode = Musicode.new(&instruments.instruments),
    };
}

export fn update() void {
    // input processing
    const gamepad = w4.GAMEPAD1.*;
    const released_keys = state.previous_input & ~gamepad;
    state.previous_input = gamepad;

    const previous_state = state.state;

    if (state.state_has_changed) {
        state.text_progress = 0;
    }

    switch (state.state) {
        GlobalState.crossroad => process_crossroad(&state, released_keys),
        GlobalState.event_boss_cutscene => process_event_boss_cutscene(&state, released_keys),
        GlobalState.event_boss_intro => text_event_confirm(&state, released_keys, &event_boss_intro_dialog),
        GlobalState.event_boss_intro_2 => text_event_confirm(&state, released_keys, &event_boss_intro_dialog_2),
        GlobalState.event_boss_outro => text_event_confirm(&state, released_keys, &event_boss_outro_dialog),
        GlobalState.event_boss => fight_intro(&state, released_keys, Enemy.enemy_boss(), &boss_dialog),
        GlobalState.event_castle_bat => fight_intro(&state, released_keys, Enemy.enemy_castle_bat(), &castle_bat_dialog),
        GlobalState.event_castle_candle => fight_intro(&state, released_keys, Enemy.enemy_castle_candle(), &castle_candle_dialog),
        GlobalState.event_castle_schmoo => fight_intro(&state, released_keys, Enemy.enemy_castle_schmoo(), &castle_schmoo_dialog),
        GlobalState.event_castle_sun_shop => shop_intro(&state, released_keys, &castle_sun_shop_dialog, castle_sun_shop_gold, &castle_sun_shop_items),
        GlobalState.event_castle_vampire_shop => shop_intro(&state, released_keys, &castle_vampire_shop_dialog, castle_vampire_shop_gold, &castle_vampire_shop_items),
        GlobalState.event_cavern_man => text_event_choice_1(&state, released_keys, &event_cavern_man_dialog, "Confirm", &event_cavern_man_outcome),
        GlobalState.event_chest_regular => text_event_choice_2(&state, released_keys, &event_chest_dialog, "Skip", &event_chest_skip_outcome, "Open it", &event_chest_regular_gold_outcome),
        GlobalState.event_chest_mimic => text_event_choice_2(&state, released_keys, &event_chest_dialog, "Skip", &event_chest_skip_outcome, "Open it", &event_chest_mimic_outcome),
        GlobalState.event_chest_mimic_fight_intro => fight_intro(&state, released_keys, Enemy.enemy_mimic(), &event_mimic_dialog),
        GlobalState.event_coast_barbarian_invasion => conditional_fight_intro(&state, released_keys, Enemy.enemy_barbarian(), &event_barbarian_invasion_dialog),
        GlobalState.event_coast_kidnapped_daughter => text_event_choice_2(&state, released_keys, &event_kidnapped_daughter_dialog, "Skip", &event_kidnapped_daughter_skip_outcome, "Save her", &event_kidnapped_daughter_accept_outcome),
        GlobalState.event_coast_kidnapped_daughter_decline => text_event_confirm(&state, released_keys, &event_kidnapped_daughter_decline_dialog),
        GlobalState.event_coast_merfolk => fight_intro(&state, released_keys, Enemy.enemy_merfolk(), &event_merfolk_dialog),
        GlobalState.event_coast_seagull => fight_intro(&state, released_keys, Enemy.enemy_seagull(), &event_seagull_dialog),
        GlobalState.event_coast_sea_monster => conditional_fight_intro(&state, released_keys, Enemy.enemy_sea_monster(), &event_sea_monster_dialog),
        GlobalState.event_coin_muncher => fight_intro(&state, released_keys, Enemy.enemy_coin_muncher(), &coin_muncher_dialog),
        GlobalState.event_dungeon_ambush => process_dungeon_ambush(&state, released_keys),
        GlobalState.event_dungeon => process_dungeon(&state, released_keys),
        GlobalState.event_dungeon_1 => text_event_choice_1(&state, released_keys, &event_dungeon_dialog_1, "Confirm", &event_dungeon_outcome_1),
        GlobalState.event_dungeon_2 => text_event_choice_1(&state, released_keys, &event_dungeon_dialog_2, "Confirm", &event_dungeon_outcome_2),
        GlobalState.event_dungeon_3 => text_event_choice_1(&state, released_keys, &event_dungeon_dialog_3, "Confirm", &event_dungeon_outcome_3),
        GlobalState.event_dungeon_4 => text_event_choice_1(&state, released_keys, &event_dungeon_dialog_4, "Confirm", &event_dungeon_outcome_4),
        GlobalState.event_dungeon_5 => text_event_choice_1(&state, released_keys, &event_dungeon_dialog_5, "Confirm", &event_dungeon_outcome_5),
        GlobalState.event_dungeon_6 => text_event_choice_1(&state, released_keys, &event_dungeon_dialog_6, "Confirm", &event_dungeon_outcome_6),
        GlobalState.event_dungeon_7 => fight_intro(&state, released_keys, Enemy.enemy_dungeon_guard(), &event_dungeon_dialog_7),
        GlobalState.event_credits => process_credits(&state, released_keys),
        GlobalState.event_hard_swamp_creature => fight_intro(&state, released_keys, Enemy.enemy_hard_swamp_creature(), &swamp_creature_dialog),
        GlobalState.event_healer => process_event_healer(&state, released_keys),
        GlobalState.event_healer_decline => text_event_confirm(&state, released_keys, &event_healer_decline_dialog),
        GlobalState.event_healer_accept => text_event_confirm(&state, released_keys, &event_healer_accept_dialog),
        GlobalState.event_coastal_shop => shop_intro(&state, released_keys, &coastal_shop_dialog, coastal_shop_gold, &coastal_shop_items),
        GlobalState.event_mine_shop => shop_intro(&state, released_keys, &mine_shop_dialog, mine_shop_gold, &mine_shop_items),
        GlobalState.event_healing_shop => shop_intro(&state, released_keys, &healing_shop_dialog, healing_shop_gold, &healing_shop_items),
        GlobalState.event_forest_wolf => fight_intro(&state, released_keys, Enemy.enemy_forest_wolf(), &forest_wolf_dialog),
        GlobalState.event_mine_troll_warrior => fight_intro(&state, released_keys, Enemy.enemy_mine_troll_warrior(), &mine_troll_warrior_dialog),
        GlobalState.event_mine_troll_king => fight_intro(&state, released_keys, Enemy.enemy_mine_troll_king(), &mine_troll_king_dialog),
        GlobalState.event_mine_troll => fight_intro(&state, released_keys, Enemy.enemy_mine_troll(), &mine_troll_dialog),
        GlobalState.event_moon_altar => process_event_moon_altar(&state, released_keys),
        GlobalState.event_moon_altar_skip => text_event_confirm(&state, released_keys, &event_moon_altar_skip_1_dialog),
        GlobalState.event_moon_altar_pray => text_event_confirm(&state, released_keys, &event_moon_altar_pray_1_dialog),
        GlobalState.event_moon_altar_destroy => text_event_confirm(&state, released_keys, &event_moon_altar_destroy_1_dialog),
        GlobalState.event_moon_partisan => process_event_moon_partisan(&state, released_keys),
        GlobalState.event_militia_ambush => fight_intro(&state, released_keys, Enemy.enemy_militia_ambush(), &militia_ambush_dialog),
        GlobalState.event_pirate => fight_intro(&state, released_keys, Enemy.enemy_pirate(), &pirate_dialog),
        GlobalState.event_pirate_captain => fight_intro(&state, released_keys, Enemy.enemy_pirate_captain(), &pirate_captain_dialog),
        GlobalState.event_rat => fight_intro(&state, released_keys, Enemy.enemy_rat(), &event_rat_dialog),
        GlobalState.event_snake_pit => fight_intro(&state, released_keys, Enemy.enemy_snake_pit(), &snake_pit_dialog),
        GlobalState.event_sun_altar => process_event_sun_altar(&state, released_keys),
        GlobalState.event_sun_altar_skip => text_event_confirm(&state, released_keys, &event_sun_altar_skip_1_dialog),
        GlobalState.event_sun_altar_pay => text_event_confirm(&state, released_keys, &event_sun_altar_pay_1_dialog),
        GlobalState.event_sun_altar_destroy => text_event_confirm(&state, released_keys, &event_sun_altar_destroy_1_dialog),
        GlobalState.event_swamp_people => fight_intro(&state, released_keys, Enemy.enemy_swamp_people(), &swamp_people_dialog),
        GlobalState.event_swamp_creature => fight_intro(&state, released_keys, Enemy.enemy_swamp_creature(), &swamp_creature_dialog),
        GlobalState.event_moon_fountain => process_event_moon_fountain(&state, released_keys),
        GlobalState.event_moon_fountain_skip => text_event_confirm(&state, released_keys, &event_moon_fountain_skip_dialog),
        GlobalState.event_moon_fountain_damage => text_event_confirm(&state, released_keys, &event_moon_fountain_damage_dialog),
        GlobalState.event_moon_fountain_heal => text_event_confirm(&state, released_keys, &event_moon_fountain_heal_dialog),
        GlobalState.event_moon_fountain_refresh => text_event_confirm(&state, released_keys, &event_moon_fountain_refresh_dialog),
        GlobalState.event_sun_fountain => process_event_sun_fountain(&state, released_keys),
        GlobalState.event_sun_fountain_skip => text_event_confirm(&state, released_keys, &event_sun_fountain_skip_dialog),
        GlobalState.event_sun_fountain_damage => text_event_confirm(&state, released_keys, &event_sun_fountain_damage_dialog),
        GlobalState.event_sun_fountain_heal => text_event_confirm(&state, released_keys, &event_sun_fountain_heal_dialog),
        GlobalState.event_sun_fountain_refresh => text_event_confirm(&state, released_keys, &event_sun_fountain_refresh_dialog),
        GlobalState.event_sun_partisan => process_event_sun_partisan(&state, released_keys),
        GlobalState.event_swamp_shop => shop_intro(&state, released_keys, &swamp_shop_dialog, swamp_shop_gold, &swamp_shop_items),
        GlobalState.event_training_fight_1 => fight_intro(&state, released_keys, Enemy.enemy_training_soldier_1(), &training_fight_dialog_1),
        GlobalState.event_training_fight_2 => fight_intro(&state, released_keys, Enemy.enemy_training_soldier_2(), &training_fight_dialog_2),
        GlobalState.event_training_bat => fight_intro(&state, released_keys, Enemy.enemy_training_bat(), &training_bat_dialog),
        GlobalState.fight => process_fight(&state, released_keys),
        GlobalState.fight_end => process_fight_end(&state, released_keys),
        GlobalState.fight_reward => process_fight_reward(&state, released_keys),
        GlobalState.game_over => process_game_over(&state, released_keys),
        GlobalState.inventory => process_inventory(&state, released_keys),
        GlobalState.inventory_full => process_inventory_full(&state, released_keys),
        GlobalState.inventory_full_2 => process_inventory_full_2(&state, released_keys),
        GlobalState.map => process_map(&state, released_keys),
        GlobalState.options => process_options(&state, released_keys),
        GlobalState.new_game_init => process_new_game_init(),
        GlobalState.pick_random_event => process_pick_random_event(&state, released_keys),
        GlobalState.pick_character => process_pick_character(&state, released_keys),
        GlobalState.pick_character_2 => text_event_choice_1(&state, released_keys, &pick_character_2_dialog, "Confirm", &pick_character_2_outcome),
        GlobalState.shop => process_shop(&state, released_keys),
        GlobalState.title => process_title_1(&state, released_keys),
        GlobalState.title_1 => process_title_1(&state, released_keys),
        GlobalState.tutorial_basics => process_tutorial_basics(&state, released_keys),
        GlobalState.tutorial_synergies => process_tutorial_synergies(&state, released_keys),
        GlobalState.tutorial_fights => process_tutorial_fights(&state, released_keys),
        GlobalState.tutorial_fights_1 => process_tutorial_fights_1(&state, released_keys),
        GlobalState.tutorial_pause_menu => process_tutorial_pause_menu(&state, released_keys),
        GlobalState.tutorial_alignment => process_tutorial_alignment(&state, released_keys),
        GlobalState.tutorial_end => process_tutorial_end(&state, released_keys),
    }

    state.state_has_changed = (previous_state != state.state);
}
