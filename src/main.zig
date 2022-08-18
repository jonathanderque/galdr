const w4 = @import("wasm4.zig");
const pager = @import("pager.zig");
const sprites = @import("sprites.zig");
const notes = @import("notes.zig");
const musicode = @import("musicode.zig");
const Instrument = musicode.Instrument;
const Musicode = musicode.Musicode;

const rand_a: u64 = 6364136223846793005;
const rand_c: u64 = 1442695040888963407;
var rand_state: u64 = 0;

pub fn rand() u64 {
    rand_state = rand_state * rand_a + rand_c;
    return (rand_state >> 32) & 0xFFFFFFFF;
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
    frame_triggered: i16 = 0, // used for visual feedback

    pub fn zero() Spell {
        var spell = Spell{
            .name = "",
            .input = undefined,
            .current_progress = 0,
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
        s.set_spell(&[_]u8{w4.BUTTON_1});
        return s;
    }

    pub fn spell_title_start_game() Spell {
        var s = Spell{
            .name = "Start Game",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_2 });
        return s;
    }

    pub fn spell_tutorial_basics_next() Spell {
        var s = Spell{
            .name = "NEXT",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_tutorial_synergies_heal() Spell {
        var s = Spell{
            .name = "HEAL",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_tutorial_synergies_next() Spell {
        var s = Spell{
            .name = "NEXT",
            .effect = Effect.no_effect,
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1, w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_sword() Spell {
        var s = Spell{
            .name = "SWORD",
            .price = 9,
            .alignment = -2,
            .effect = Effect{ .damage_to_enemy = 3 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_RIGHT, w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_squawk() Spell {
        var s = Spell{
            .name = "SQUAWK",
            .price = 11,
            .alignment = 0,
            .effect = Effect{ .damage_to_enemy = 1 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_UP, w4.BUTTON_UP, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_fireball() Spell {
        var s = Spell{
            .name = "FIREBALL",
            .price = 5,
            .alignment = -2,
            .effect = Effect{ .damage_to_enemy = 4 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_lightning() Spell {
        var s = Spell{
            .name = "LIGHTNING",
            .alignment = 10,
            .price = 9,
            .effect = Effect{ .damage_to_enemy = 7 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_RIGHT,
            w4.BUTTON_RIGHT,
            w4.BUTTON_LEFT,
            w4.BUTTON_1,
            w4.BUTTON_RIGHT,
            w4.BUTTON_2,
        });
        return s;
    }

    pub fn spell_shield() Spell {
        var s = Spell{
            .name = "SHIELD",
            .price = 12,
            .alignment = 2,
            .effect = Effect{ .player_shield = 2 },
        };
        s.set_spell(&[_]u8{
            w4.BUTTON_DOWN,
            w4.BUTTON_DOWN,
            w4.BUTTON_RIGHT,
            w4.BUTTON_1,
        });
        return s;
    }

    pub fn spell_wolf_bite() Spell {
        var wolf_bite = Spell{
            .name = "WOLF BITE",
            .price = 9,
            .alignment = -7,
            .effect = Effect{ .damage_to_enemy = 5 },
        };
        wolf_bite.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return wolf_bite;
    }

    pub fn spell_heal() Spell {
        var s = Spell{
            .name = "HEAL",
            .price = 5,
            .alignment = 2,
            .effect = Effect{ .player_heal = 2 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_heal_plus() Spell {
        var s = Spell{
            .name = "HEAL+",
            .price = 12,
            .alignment = 5,
            .effect = Effect{ .player_heal = 5 },
        };
        s.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return s;
    }

    pub fn spell_holy_water() Spell {
        var spell = Spell{
            .name = "HOLY WATER",
            .price = 9,
            .alignment = 9,
            .effect = Effect{ .damage_to_enemy = 8 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_LEFT, w4.BUTTON_UP, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_crissaegrim() Spell {
        var spell = Spell{
            .name = "CRISSAEGRIM",
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
            .name = "KNIFE",
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
            .name = "CROSS",
            .price = 10,
            .alignment = 5,
            .effect = Effect{ .damage_to_enemy = 6 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_LEFT, w4.BUTTON_DOWN, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_whip() Spell {
        var spell = Spell{
            .name = "WHIP",
            .price = 13,
            .alignment = 7,
            .effect = Effect{ .damage_to_enemy = 10 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_RIGHT, w4.BUTTON_LEFT, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_fangs() Spell {
        var spell = Spell{
            .name = "FANGS",
            .price = 13,
            .alignment = -9,
            .effect = Effect{ .vampirism_to_enemy = 3 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_UP, w4.BUTTON_DOWN, w4.BUTTON_LEFT, w4.BUTTON_1 });
        return spell;
    }

    pub fn spell_cloak() Spell {
        var spell = Spell{
            .name = "CLOAK",
            .price = 9,
            .alignment = -9,
            .effect = Effect{ .player_shield = 10 },
        };
        spell.set_spell(&[_]u8{ w4.BUTTON_DOWN, w4.BUTTON_UP, w4.BUTTON_RIGHT, w4.BUTTON_1 });
        return spell;
    }
};

const GlobalState = enum {
    crossroad,
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
    event_healer,
    event_healer_decline,
    event_healer_accept,
    event_healing_shop,
    event_forest_wolf,
    event_militia_ambush,
    event_moon_altar,
    event_moon_altar_skip,
    event_moon_altar_pray,
    event_moon_altar_destroy,
    event_pirate,
    event_pirate_captain,
    event_snake_pit,
    event_sun_altar,
    event_sun_altar_skip,
    event_sun_altar_pay,
    event_sun_altar_destroy,
    event_swamp_people,
    event_swamp_creature,
    event_sun_fountain,
    event_sun_fountain_skip,
    event_sun_fountain_damage,
    event_sun_fountain_heal,
    event_sun_fountain_refresh,
    fight,
    fight_end,
    fight_reward,
    game_over,
    inventory,
    inventory_full,
    inventory_full_2,
    map,
    new_game_init,
    pick_random_event,
    shop,
    title,
    tutorial_basics,
    tutorial_synergies,
    tutorial_pause_menu,
    tutorial_alignment,
    tutorial_end,
};

const Area = struct {
    name: []const u8,
    event_count: usize, // player is expected to play even_count events out of the total pool
    event_pool: []const GlobalState,
};

const coast_area = Area{
    .name = "COAST",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_coast_seagull,
        GlobalState.event_coast_barbarian_invasion,
        GlobalState.event_coast_kidnapped_daughter,
        GlobalState.event_coast_merfolk,
        GlobalState.event_coast_sea_monster,
    },
};

const pirate_area = Area{
    .name = "PIRATE SHIP",
    .event_count = 3,
    .event_pool = &[_]GlobalState{
        GlobalState.event_chest_regular,
        GlobalState.event_pirate,
        GlobalState.event_pirate_captain,
    },
};

const swamp_area = Area{
    .name = "SWAMP",
    .event_count = 3,
    .event_pool = &[_]GlobalState{
        GlobalState.event_swamp_creature,
        GlobalState.event_swamp_people,
        GlobalState.event_snake_pit,
        GlobalState.event_healer,
        GlobalState.event_moon_altar,
    },
};

const forest_area = Area{
    .name = "FOREST",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_chest_regular,
        GlobalState.event_chest_mimic,
        GlobalState.event_coin_muncher,
        GlobalState.event_sun_fountain,
        GlobalState.event_forest_wolf,
        GlobalState.event_cavern_man,
        GlobalState.event_militia_ambush,
        GlobalState.event_healing_shop,
        GlobalState.event_sun_altar,
    },
};

const castle_area = Area{
    .name = "CASTLE",
    .event_count = 4,
    .event_pool = &[_]GlobalState{
        GlobalState.event_castle_bat,
        GlobalState.event_castle_candle,
        GlobalState.event_castle_schmoo,
        GlobalState.event_castle_sun_shop,
        GlobalState.event_castle_vampire_shop,
    },
};

const boss_area = Area{
    .name = "ECLIPSE",
    .event_count = 1,
    .event_pool = &[_]GlobalState{
        GlobalState.event_boss,
    },
};

const easy_area_pool = [_]Area{
    coast_area,
    swamp_area,
};

const medium_area_pool = [_]Area{
    forest_area,
    castle_area,
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
        return Enemy{};
    }

    pub fn enemy_barbarian() Enemy {
        var enemy = zero();
        const enemy_max_hp = 15;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 5 };
        enemy.sprite = &sprites.enemy_barbarian;
        return enemy;
    }

    pub fn enemy_boss() Enemy {
        var enemy = zero();
        const enemy_max_hp = 100;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .damage_to_player = 14 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 7 * 60,
            .effect = Effect{ .enemy_shield = 10 },
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
        const enemy_max_hp = 20;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 2 * 60,
            .effect = Effect{ .vampirism_to_player = 2 },
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
        const enemy_max_hp = 14;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        enemy.sprite = &sprites.enemy_castle_schmoo;
        enemy.guaranteed_reward = Reward{ .gold_reward = 5 };
        enemy.random_reward = RandomReward{
            .probability = 10,
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

    pub fn enemy_forest_wolf() Enemy {
        var enemy = zero();
        const enemy_max_hp = 20;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 3 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 7 * 60,
            .effect = Effect{ .damage_to_player = 7 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 10 };
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
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 3 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 50 };
        enemy.sprite = &sprites.enemy_militia;
        return enemy;
    }

    pub fn enemy_pirate() Enemy {
        var enemy = zero();
        const enemy_max_hp = 15;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 3 },
        };
        enemy.guaranteed_reward = Reward.no_reward;
        enemy.sprite = &sprites.enemy_pirate;
        return enemy;
    }

    pub fn enemy_pirate_captain() Enemy {
        var enemy = zero();
        const enemy_max_hp = 30;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 6 * 60,
            .effect = Effect{ .damage_to_player = 7 },
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
            .effect = Effect{ .damage_to_player = 7 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 3 },
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
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 3 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 2 };
        enemy.sprite = &sprites.enemy_snake;
        return enemy;
    }

    pub fn enemy_swamp_people() Enemy {
        var enemy = zero();
        const enemy_max_hp = 15;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 1 * 60,
            .effect = Effect{ .enemy_shield = 1 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 2 };
        enemy.sprite = &sprites.enemy_swamp_people;
        return enemy;
    }

    pub fn enemy_swamp_creature() Enemy {
        var enemy = zero();
        const enemy_max_hp = 15;
        enemy.hp = enemy_max_hp;
        enemy.max_hp = enemy_max_hp;
        enemy.intent[0] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .damage_to_player = 9 },
        };
        enemy.intent[1] = EnemyIntent{
            .trigger_time = 3 * 60,
            .effect = Effect{ .enemy_shield = 11 },
        };
        enemy.guaranteed_reward = Reward{ .gold_reward = 20 };
        enemy.sprite = &sprites.enemy_swamp_creature;
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
    inventory_menu_flag: bool = false,
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
    // sound engine
    musicode: Musicode,
    // player
    player_hp: i16 = 0,
    player_max_hp: i16 = 0,
    player_shield: i16 = 0,
    player_alignment: i16 = 0, // -100, +100
    player_gold: i16 = 0,
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

    pub fn apply_reward(self: *State, reward: Reward) void {
        switch (reward) {
            Reward.no_reward => {},
            Reward.gold_reward => |amount| {
                self.player_gold += @intCast(i16, amount);
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
                self.inventory_menu_flag = !self.inventory_menu_flag;
            },
            Effect.player_heal => |amount| {
                self.player_hp += @intCast(i16, amount);
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
                    self.musicode.start_track(&damage_track, false);
                } else {
                    self.player_shield -= dmg;
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
                    self.musicode.start_track(&damage_track, false);
                } else {
                    self.enemy.shield -= dmg;
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
                    self.musicode.start_track(&damage_track, false);
                } else {
                    self.player_shield -= dmg;
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
                    self.musicode.start_track(&damage_track, false);
                } else {
                    self.enemy.shield -= dmg;
                }
            },
            Effect.gold_payment => |amount| {
                // warning the event must check beforehand that there is enough gold
                if (amount <= self.player_gold) {
                    self.player_gold -= @intCast(i16, amount);
                }
            },
            Effect.player_shield => |amount| {
                self.player_shield += @intCast(i16, amount);
            },
            Effect.enemy_shield => |amount| {
                self.enemy.shield += @intCast(i16, amount);
            },
            Effect.alignment => |alignment| {
                self.change_alignment(alignment);
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
    while (i < input.len or input[i] == end_of_spell) : (i += 1) {
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

pub fn draw_spell_list(spells: []Spell, s: *State, x: i32, y: i32) void {
    var i: usize = 0;
    var var_y = y;
    while (i < spells.len) : (i += 1) {
        const blink_on = @mod(s.frame_counter, 10) < 5;
        if (s.frame_counter > 0 and spells[i].frame_triggered + 30 > s.frame_counter) {
            if (spells[i].is_defined() and blink_on) {
                w4.DRAW_COLORS.* = 0x22;
                w4.rect(10, var_y, 140, 9);
                w4.DRAW_COLORS.* = 0x21;
            }
        } else {
            w4.DRAW_COLORS.* = 0x02;
        }
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
            w4.blitSub(&sprites.effects, x, y, 9, 9, 0, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, @intCast(i32, dmg));
        },
        Effect.player_shield, Effect.enemy_shield => |amount| {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 9, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, @intCast(i32, amount));
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
            pager.fmg_number(&s.pager, -@intCast(i32, amount));
        },
        Effect.vampirism_to_player, Effect.vampirism_to_enemy => |dmg| {
            draw_fang(x, y);
            s.pager.set_cursor(x + 12, y + 1);
            pager.fmg_number(&s.pager, @intCast(i32, dmg));
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

// draws a list of spell names + cursor
pub fn draw_spell_inventory_list(x: i32, y: i32, s: *State, list: []Spell, show_cursor: bool) void {
    var i: usize = 0;
    while (i < list.len) : (i += 1) {
        const y_list = y + @intCast(i32, i * (pager.fmg_letter_height + 2));
        s.pager.set_cursor(x, y_list);
        if (show_cursor and i == s.spell_index) {
            w4.blitSub(&sprites.arrows, x + 2, y_list - 1, 5, 9, 0, 9, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
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
    w4.rect(x + 10, y + 1, @intCast(u32, @divTrunc(5 * sprites.progress_bar_width * s.player_hp, s.player_max_hp)), sprites.progress_bar_height);

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
    _ = s;
    draw_heart(x, y + 10);
    var i: i32 = 0;
    while (i < 2) : (i += 1) {
        w4.blit(&sprites.progress_bar, x + 10 + (i * sprites.progress_bar_width), y + 11, sprites.progress_bar_width, sprites.progress_bar_height, w4.BLIT_1BPP);
    }
    w4.rect(x + 10, y + 11, @intCast(u32, @divTrunc(2 * sprites.progress_bar_width * s.enemy.hp, s.enemy.max_hp)), sprites.progress_bar_height);
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
        s.set_choices_with_labels_1("TO THE SHOP");

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
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
}

pub fn process_fight(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.frame_counter = 0;
        s.player_animation = 0;
        s.enemy_animation = 0;
        s.musicode.start_track(&empty_track, false);
        for (s.spellbook) |*spell| {
            spell.frame_triggered = -40;
        }
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
    s.musicode.play();
    s.inventory_menu_spell.process(released_keys);
    if (s.inventory_menu_spell.is_completed()) {
        s.apply_effect(s.inventory_menu_spell.effect);
        s.inventory_menu_spell.reset();
    }
    if (s.inventory_menu_flag) {
        s.state_register = GlobalState.fight;
        s.state = GlobalState.inventory;
        return;
    }

    for (s.spellbook) |*spell| {
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
    draw_spell_list(&s.spellbook, s, 10, 90);

    for (s.spellbook) |*spell| {
        if (spell.is_completed()) {
            spell.frame_triggered = @intCast(i16, s.frame_counter);
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
        w4.PALETTE[3] = 0xffffff;
        s.musicode.start_track(&fight_death_sfx_track, false);
    } else {
        s.frame_counter += 1;
        w4.PALETTE[3] -= 0x030303;
        if (s.frame_counter >= 80) {
            if (s.player_hp == 0) {
                s.state = GlobalState.game_over;
            } else {
                s.state = GlobalState.fight_reward;
            }
        }
    }
    s.musicode.play();

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
        s.reward_probability = @intCast(u8, @mod(rand(), 100));
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.apply_reward(s.enemy.guaranteed_reward);
        if (s.reward_probability < s.enemy.random_reward.probability) {
            s.apply_reward(s.enemy.random_reward.reward);
        }
        s.state = GlobalState.pick_random_event;
    }
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
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.title;
    }
    w4.DRAW_COLORS.* = 0x02;
    w4.blit(&sprites.skull, 30, 48, sprites.skull_width, sprites.skull_height, w4.BLIT_1BPP);
    w4.blit(&sprites.skull, 102, 48, sprites.skull_width, sprites.skull_height, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
    s.pager.set_cursor(48, 50);
    pager.fmg_text(&s.pager, "GAME OVER");
    draw_spell_list(&s.choices, s, 10, 140);
}

pub fn process_inventory(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        s.set_choices_back();
        s.shop_list_index = 0;
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.inventory_menu_flag = false;
        s.state = s.state_register;
    }

    process_keys_spell_list(s, released_keys, &s.spellbook);

    const spell = s.spellbook[@intCast(usize, s.spell_index)];

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

pub fn process_inventory_full_2(s: *State, released_keys: u8) void {
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        s.shop_list_index = 1 - s.shop_list_index;
    }
    var spell: Spell = undefined;
    if (s.shop_list_index == 0) {
        s.choices[0].name = "Discard";
        process_keys_spell_list(s, released_keys, &s.spellbook);
        spell = s.spellbook[@intCast(usize, s.spell_index)];
    }
    if (s.shop_list_index == 1) {
        s.choices[0].name = "Pick up";
        process_keys_spell_list(s, released_keys, &s.shop_items);
        spell = s.shop_items[@intCast(usize, s.spell_index)];
    }

    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        // dropping a spell
        if (s.shop_list_index == 0) {
            add_spell_to_list(spell, &s.shop_items);
            remove_nth_spell_from_list(@intCast(usize, s.spell_index), &s.spellbook);
        }
        // picking up a spell
        if (s.shop_list_index == 1) {
            add_spell_to_list(spell, &s.spellbook);
            remove_nth_spell_from_list(@intCast(usize, s.spell_index), &s.shop_items);
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
        s.set_choices_with_labels_1("PROCEED");
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = s.state_register;
        return;
    }

    const name_x = 80 - pager.fmg_letter_width * @intCast(i32, @divTrunc(s.area.name.len, 2));
    s.pager.set_cursor(name_x, 40);
    pager.fmg_text(&s.pager, s.area.name);
    const counter_x = 80 - pager.fmg_letter_width * (5 / 2);
    s.pager.set_cursor(counter_x, 60);
    pager.fmg_number(&s.pager, @intCast(i32, s.area_counter));
    pager.fmg_text(&s.pager, " - ");
    pager.fmg_number(&s.pager, @intCast(i32, s.area_event_counter));

    const map_y = 100;
    var map_x: i32 = 30;
    if (s.area.event_count > 1) {
        draw_map_location(map_x, map_y);

        if (1 == s.area_event_counter) {
            draw_map_character(map_x - 6, map_y - 20);
        }
        const map_x_increment: i32 = @divTrunc(100, @intCast(i32, s.area.event_count) - 1);
        map_x += map_x_increment;
        var i: usize = 1;
        while (i < s.area.event_count) : (i += 1) {
            w4.hline(map_x - map_x_increment + 8, map_y + 2, @intCast(u32, map_x_increment - 10));
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

pub fn process_pick_random_event(s: *State, released_keys: u8) void {
    _ = released_keys;

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.state = GlobalState.inventory_full;
        return;
    }

    if (s.area_event_counter >= s.area.event_count) {
        s.state = GlobalState.crossroad;
        return;
    }
    s.area_event_counter += 1;

    const max_attempts = 128;
    var attempts: u16 = 0;
    var idx: usize = @intCast(usize, @mod(rand(), s.area.event_pool.len));
    while (s.visited_events[idx] and attempts < max_attempts) : (attempts += 1) {
        idx = @intCast(usize, @mod(rand(), s.area.event_pool.len));
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
        s.reset_choices();
        s.choices[0] = Spell.spell_title_tutorial();
        s.choices[1] = Spell.spell_title_start_game();
    }
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
        s.state = GlobalState.tutorial_basics;
    } else if (s.choices[1].is_completed()) {
        s.state = GlobalState.new_game_init;
    }

    // generate randomness
    _ = rand();

    w4.DRAW_COLORS.* = 0x02;
    w4.blit(&sprites.galdr_logo, 16, 50, sprites.galdr_logo_width, sprites.galdr_logo_height, w4.BLIT_1BPP);
    draw_spell_list(&s.choices, s, 10, 140);
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
        s.reset_choices();
        s.choices[0] = Spell.spell_tutorial_basics_next();
        s.state = GlobalState.tutorial_pause_menu;
    }
    s.pager.set_cursor(10, 10);
    pager.fmg_text(&s.pager, "Look carefully at the spells below; you'll notice similarities between the input needed for these two spells.");
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

pub fn process_tutorial_pause_menu(s: *State, released_keys: u8) void {
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
    pager.fmg_text(&s.pager, " will get you in the Trance of the Pause Menu.");
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
        .musicode = Musicode.new(),
        // global state
        .state = GlobalState.crossroad,
        .choices = undefined,
        .area = swamp_area,
        .visited_events = undefined,
        // player
        .player_hp = player_max_hp,
        .player_max_hp = player_max_hp,
        .spellbook = undefined,
        .player_gold = 19,
        .inventory_menu_spell = Spell.spell_inventory_menu(),

        // enemy
        .enemy = Enemy.zero(),
    };

    initialize_instruments(&state);

    var i: usize = 0;
    while (i < state.spellbook.len) : (i += 1) {
        state.spellbook[i] = Spell.zero();
    }

    state.spellbook[0] = Spell.spell_fireball();
    state.spellbook[1] = Spell.spell_lightning();
    state.spellbook[2] = Spell.spell_shield();
}

pub fn current_area_pool(s: *State) []const Area {
    return switch (s.area_counter) {
        0 => &easy_area_pool,
        1 => &medium_area_pool,
        2 => &boss_area_pool,
        else => unreachable,
    };
}

pub fn process_crossroad(s: *State, released_keys: u8) void {
    if (s.state_has_changed) {
        if (s.area_counter == 3) {
            s.state = GlobalState.title;
            return;
        }

        // pick two areas / setup choices
        const area_pool = current_area_pool(s);
        s.crossroad_index_1 = @intCast(usize, @mod(rand(), area_pool.len));
        if (area_pool.len > 1) {
            s.crossroad_index_2 = @intCast(usize, @mod(rand(), area_pool.len));
            while (s.crossroad_index_2 == s.crossroad_index_1) {
                s.crossroad_index_2 = @intCast(usize, @mod(rand(), area_pool.len));
            }
        } else {
            s.crossroad_index_2 = s.crossroad_index_1;
        }
        s.set_choices_with_labels_2(area_pool[s.crossroad_index_1].name, area_pool[s.crossroad_index_2].name);
        s.enemy.sprite = &sprites.crossroad;
    }
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

const boss_dialog = [_]Dialog{
    Dialog{ .text = "Be prepared, this is it!" },
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
        s.reset_choices();
        if (choice1 != null) {
            s.set_choices_with_labels_2(choice0, choice1.?);
        } else {
            s.set_choices_with_labels_1(choice0);
        }
        s.enemy.random_reward = RandomReward.zero();
        s.enemy.guaranteed_reward = Reward.no_reward;
    }
    process_choices_input(s, released_keys);
    _ = s;
    _ = released_keys;
    _ = dialog;
    _ = outcome0;
    _ = outcome1;
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

const healing_shop_gold = 50;
const healing_shop_items = [_]Spell{
    Spell.spell_heal(),
    Spell.spell_heal_plus(),
};
const healing_shop_dialog = [_]Dialog{
    Dialog{ .text = "The merchant greets you:" },
    Dialog.newline,
    Dialog.newline,
    Dialog{ .text = "\"Welcome to Hildan's Heap of Heals!\"" },
};

pub fn process_keys_spell_list(s: *State, released_keys: u8, spell_list: []Spell) void {
    if (released_keys == w4.BUTTON_DOWN) {
        s.spell_index += 1;
        while (!spell_list[@intCast(usize, s.spell_index)].is_defined() and s.spell_index < spell_list.len) {
            s.spell_index += 1;
        }
        if (s.spell_index >= spell_list.len) {
            s.spell_index = 0;
        }
    }
    // switch from one list to the other -> make sure we are within bounds of the new list
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        while (!spell_list[@intCast(usize, s.spell_index)].is_defined() and s.spell_index >= 0) {
            s.spell_index -= 1;
        }
        if (s.spell_index <= 0) { // should not happen unless empty spell list
            s.spell_index = 0;
        }
    }
    if (released_keys == w4.BUTTON_UP) {
        s.spell_index -= 1;
        if (s.spell_index < 0) {
            s.spell_index = @intCast(isize, spell_list.len - 1);
            while (!spell_list[@intCast(usize, s.spell_index)].is_defined() and s.spell_index >= 0) {
                s.spell_index -= 1;
            }
            if (s.spell_index <= 0) { // should not happen unless empty spell list
                s.spell_index = 0;
            }
        }
    }
}

pub fn draw_shop_tabs(s: *State, draw_second_tab: bool) void {
    _ = s;
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
        spell = s.spellbook[@intCast(usize, s.spell_index)];
    }
    if (s.shop_list_index == 1) {
        s.choices[0].name = "Buy";
        process_keys_spell_list(s, released_keys, &s.shop_items);
        spell = s.shop_items[@intCast(usize, s.spell_index)];
    }

    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        // selling a spell
        if (s.shop_list_index == 0) {
            s.player_gold += @intCast(i16, spell.price);
            s.shop_gold -= @intCast(i16, spell.price);
            add_spell_to_list(spell, &s.shop_items);
            remove_nth_spell_from_list(@intCast(usize, s.spell_index), &s.spellbook);
        }
        // buying a spell
        if (s.shop_list_index == 1) {
            s.player_gold -= @intCast(i16, spell.price);
            s.shop_gold += @intCast(i16, spell.price);
            add_spell_to_list(spell, &s.spellbook);
            remove_nth_spell_from_list(@intCast(usize, s.spell_index), &s.shop_items);
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
        s.pager.set_cursor(85, 140);
        pager.fmg_text(&s.pager, "Can't leave. ");
        s.pager.set_cursor(85, 150);
        pager.fmg_text(&s.pager, "Spellbook full");
    }
    if (s.player_gold < 0 or s.shop_gold < 0) {
        s.pager.set_cursor(85, 140);
        pager.fmg_text(&s.pager, "Can't leave. ");
        s.pager.set_cursor(85, 150);
        pager.fmg_text(&s.pager, "Not enough");
        draw_coin(s.pager.cursor_x + 3, 150 - 1);
    }
}

const forest_wolf_dialog = [_]Dialog{
    Dialog{ .text = "As you pass through the dark woods, you hear a frightening growl behind you." },
    Dialog.newline,
    Dialog{ .text = "A giant lone wolf is snarling at you. You have no choice other than to fight for your life!" },
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

const empty_track = [_]u8{
    Musicode.wait(1),
};
const damage_track = [_]u8{
    Musicode.instr(4), // 1
};
const fight_death_sfx_track = [_]u8{
    Musicode.instr(6), // 1
};
const title_track = [_]u8{
    Musicode.instr(4), // 1
    Musicode.instr(3),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(4), // 3
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr_with_note(1), // 1
    0,                 98, // G2
    // TODO add note
    Musicode.instr(3), Musicode.wait(15),
    Musicode.instr(5), Musicode.wait(15),
    Musicode.instr(3), Musicode.wait(15),
    Musicode.instr(5), Musicode.wait(15),
    Musicode.instr(4), // 3
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
    Musicode.instr(5),
    Musicode.wait(15),
};

var state: State = undefined;

pub fn initialize_instruments(s: *State) void {
    //state.musicode.instruments[0] = Instrument{ .freq1 = 500, .sustain = 5, .sustain_vol = 80, .channel = w4.TONE_NOISE };
    s.musicode.instruments[0] = Instrument{
        .freq1 = 440,
        .decay = 2,
        .sustain = 5,
        .release = 1,
        .sustain_vol = 4,
        .channel = w4.TONE_PULSE1,
    };
    // sweep
    s.musicode.instruments[1] = Instrument{
        .freq1 = notes.A3,
        .attack = 26,
        .decay = 45,
        .sustain = 1,
        .release = 44,
        .sustain_vol = 4,
        .channel = w4.TONE_TRIANGLE,
    };
    // lead
    s.musicode.instruments[2] = Instrument{
        .freq1 = notes.A3,
        .sustain = 10,
        .sustain_vol = 80,
        .channel = w4.TONE_PULSE1,
    };
    // kick
    s.musicode.instruments[3] = Instrument{ .freq1 = 150, .sustain = 5, .sustain_vol = 80, .channel = w4.TONE_NOISE };
    // snare
    s.musicode.instruments[4] = Instrument{ .freq1 = 500, .sustain = 5, .sustain_vol = 80, .channel = w4.TONE_NOISE };
    // hi hats
    s.musicode.instruments[5] = Instrument{ .freq1 = 700, .sustain = 3, .sustain_vol = 80, .channel = w4.TONE_NOISE };
    // death sfx
    s.musicode.instruments[6] = Instrument{ .freq1 = 330, .freq2 = 190, .release = 100, .sustain_vol = 80, .channel = w4.TONE_NOISE };
}

export fn start() void {
    w4.PALETTE.* = .{
        0x000000,
        0xcccccc,
        0x55cc55,
        0xcc5555,
    };

    state = State{
        .musicode = Musicode.new(),
    };
    initialize_instruments(&state);
}

export fn update() void {
    // input processing
    const gamepad = w4.GAMEPAD1.*;
    const released_keys = state.previous_input & ~gamepad;
    state.previous_input = gamepad;

    const previous_state = state.state;

    switch (state.state) {
        GlobalState.crossroad => process_crossroad(&state, released_keys),
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
        GlobalState.event_healer => process_event_healer(&state, released_keys),
        GlobalState.event_healer_decline => text_event_confirm(&state, released_keys, &event_healer_decline_dialog),
        GlobalState.event_healer_accept => text_event_confirm(&state, released_keys, &event_healer_accept_dialog),
        GlobalState.event_healing_shop => shop_intro(&state, released_keys, &healing_shop_dialog, healing_shop_gold, &healing_shop_items),
        GlobalState.event_forest_wolf => fight_intro(&state, released_keys, Enemy.enemy_forest_wolf(), &forest_wolf_dialog),
        GlobalState.event_moon_altar => process_event_moon_altar(&state, released_keys),
        GlobalState.event_moon_altar_skip => text_event_confirm(&state, released_keys, &event_moon_altar_skip_1_dialog),
        GlobalState.event_moon_altar_pray => text_event_confirm(&state, released_keys, &event_moon_altar_pray_1_dialog),
        GlobalState.event_moon_altar_destroy => text_event_confirm(&state, released_keys, &event_moon_altar_destroy_1_dialog),
        GlobalState.event_militia_ambush => fight_intro(&state, released_keys, Enemy.enemy_militia_ambush(), &militia_ambush_dialog),
        GlobalState.event_pirate => fight_intro(&state, released_keys, Enemy.enemy_pirate(), &pirate_dialog),
        GlobalState.event_pirate_captain => fight_intro(&state, released_keys, Enemy.enemy_pirate_captain(), &pirate_captain_dialog),
        GlobalState.event_snake_pit => fight_intro(&state, released_keys, Enemy.enemy_snake_pit(), &snake_pit_dialog),
        GlobalState.event_sun_altar => process_event_sun_altar(&state, released_keys),
        GlobalState.event_sun_altar_skip => text_event_confirm(&state, released_keys, &event_sun_altar_skip_1_dialog),
        GlobalState.event_sun_altar_pay => text_event_confirm(&state, released_keys, &event_sun_altar_pay_1_dialog),
        GlobalState.event_sun_altar_destroy => text_event_confirm(&state, released_keys, &event_sun_altar_destroy_1_dialog),
        GlobalState.event_swamp_people => fight_intro(&state, released_keys, Enemy.enemy_swamp_people(), &swamp_people_dialog),
        GlobalState.event_swamp_creature => fight_intro(&state, released_keys, Enemy.enemy_swamp_creature(), &swamp_creature_dialog),
        GlobalState.event_sun_fountain => process_event_sun_fountain(&state, released_keys),
        GlobalState.event_sun_fountain_skip => text_event_confirm(&state, released_keys, &event_sun_fountain_skip_dialog),
        GlobalState.event_sun_fountain_damage => text_event_confirm(&state, released_keys, &event_sun_fountain_damage_dialog),
        GlobalState.event_sun_fountain_heal => text_event_confirm(&state, released_keys, &event_sun_fountain_heal_dialog),
        GlobalState.event_sun_fountain_refresh => text_event_confirm(&state, released_keys, &event_sun_fountain_refresh_dialog),
        GlobalState.fight => process_fight(&state, released_keys),
        GlobalState.fight_end => process_fight_end(&state, released_keys),
        GlobalState.fight_reward => process_fight_reward(&state, released_keys),
        GlobalState.game_over => process_game_over(&state, released_keys),
        GlobalState.inventory => process_inventory(&state, released_keys),
        GlobalState.inventory_full => process_inventory_full(&state, released_keys),
        GlobalState.inventory_full_2 => process_inventory_full_2(&state, released_keys),
        GlobalState.map => process_map(&state, released_keys),
        GlobalState.new_game_init => process_new_game_init(),
        GlobalState.pick_random_event => process_pick_random_event(&state, released_keys),
        GlobalState.shop => process_shop(&state, released_keys),
        GlobalState.title => process_title(&state, released_keys),
        GlobalState.tutorial_basics => process_tutorial_basics(&state, released_keys),
        GlobalState.tutorial_synergies => process_tutorial_synergies(&state, released_keys),
        GlobalState.tutorial_pause_menu => process_tutorial_pause_menu(&state, released_keys),
        GlobalState.tutorial_alignment => process_tutorial_alignment(&state, released_keys),
        GlobalState.tutorial_end => process_tutorial_end(&state, released_keys),
    }

    state.state_has_changed = (previous_state != state.state);
}
