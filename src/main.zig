const w4 = @import("wasm4.zig");
const pager = @import("pager.zig");
const sprites = @import("sprites.zig");

const rand_a: u64 = 6364136223846793005;
const rand_c: u64 = 1442695040888963407;
var rand_state: u64 = 0;

pub fn rand() u64 {
    rand_state = rand_state * rand_a + rand_c;
    return (rand_state >> 32) & 0xFFFFFFFF;
}

const Effect = union(enum(u8)) {
    no_effect: void,
    damage_to_player: i16,
    damage_to_enemy: i16,
    player_healing_max: void,
    player_shield: i16,
    gold_reward: u16,
    gold_payment: u16,
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
    current_progress: usize = 0,
    effect: Effect = Effect.no_effect,

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

    pub fn set_spell(self: *Spell, input: []const u8) void {
        var i: usize = 0;
        while (i < self.input.len and i < input.len) : (i += 1) {
            self.input[i] = input[i];
        }
        if (i < self.input.len) {
            self.input[i] = end_of_spell;
        }
    }
};

const GlobalState = enum {
    end,
    event_healer,
    event_healer_1,
    event_healer_decline,
    event_healer_accept,
    event_forest_wolf,
    event_forest_wolf_1,
    fight,
    fight_reward,
    game_over,
    pick_random_event,
};

const event_pool = [_]GlobalState{
    GlobalState.event_healer,
    GlobalState.event_forest_wolf,
};

const EnemyIntent = struct {
    trigger_time: u16,
    effect: Effect,
};

const choices_max_size: usize = 5;
const spell_book_max_size: usize = 10;
const visited_events_max_size: usize = 32;
const enemy_intent_max_size: usize = 5;
const State = struct {
    previous_input: u8,
    pager: pager.Pager,
    // global state
    state: GlobalState,
    visited_events: [visited_events_max_size]bool,
    choices: [spell_book_max_size]Spell,
    // player
    player_hp: i16,
    player_max_hp: i16,
    player_shield: i16 = 0,
    player_gold: i16,
    spellbook: [spell_book_max_size]Spell,
    // enemy
    enemy_hp: i16,
    enemy_max_hp: i16,
    enemy_intent_current_time: u16,
    enemy_intent_index: usize,
    enemy_intent: [enemy_intent_max_size]EnemyIntent = undefined,
    enemy_reward: Effect,

    pub fn apply_effect(self: *State, effect: Effect) void {
        switch (effect) {
            Effect.no_effect => {},
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
                } else {
                    self.player_shield -= dmg;
                }
            },
            Effect.damage_to_enemy => |dmg| {
                self.enemy_hp -= dmg;
                if (self.enemy_hp < 0) {
                    self.enemy_hp = 0;
                }
            },
            Effect.gold_reward => |amount| {
                self.player_gold += @intCast(i16, amount);
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
        }
    }

    pub fn reset_player_shield(self: *State) void {
        self.player_shield = 0;
    }

    pub fn reset_enemy_intent(self: *State) void {
        var i: usize = 0;
        while (i < self.enemy_intent.len) : (i += 1) {
            self.enemy_intent[i] = EnemyIntent{
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

pub fn draw_spell(spell: *Spell, p: *pager.Pager, x: i32, y: i32) void {
    var i: usize = 0;
    var var_x: i32 = x;
    p.set_cursor(x, y + 1);
    pager.f47_text(&state.pager, spell.name);
    var_x = 10 + (12 * (1 + pager.f47_letter_width));
    while (i < spell.input.len or spell.input[i] == end_of_spell) : (i += 1) {
        switch (spell.input[i]) {
            w4.BUTTON_1 => draw_button_1(var_x, y, i < spell.current_progress),
            w4.BUTTON_2 => draw_button_2(var_x, y, i < spell.current_progress),
            w4.BUTTON_LEFT => draw_left_arrow(var_x, y, i < spell.current_progress),
            w4.BUTTON_RIGHT => draw_right_arrow(var_x, y, i < spell.current_progress),
            w4.BUTTON_UP => draw_up_arrow(var_x, y, i < spell.current_progress),
            w4.BUTTON_DOWN => draw_down_arrow(var_x, y, i < spell.current_progress),
            else => {},
        }
        var_x += 10;
    }
}

pub fn draw_spell_list(spells: []Spell, p: *pager.Pager, x: i32, y: i32) void {
    var i: usize = 0;
    var var_y = y;
    while (i < spells.len) : (i += 1) {
        draw_spell(&spells[i], p, x, var_y);
        var_y += 10;
    }
}

pub fn draw_progress_bar(x: i32, y: i32, width: u32, height: u32, v: u32, max: u32) void {
    w4.DRAW_COLORS.* = 0x21;
    w4.rect(x, y, width, height);
    w4.DRAW_COLORS.* = 0x02;
    w4.rect(x, y, width * v / max, height);
}

pub fn process_fight(s: *State, released_keys: u8) void {
    for (s.spellbook) |*spell| {
        spell.process(released_keys);
    }

    // we assume process_fight will be called every frame
    if (s.enemy_hp > 0) {
        s.enemy_intent_current_time += 1;
        if (s.enemy_intent_current_time >= s.enemy_intent[s.enemy_intent_index].trigger_time) {
            s.apply_effect(s.enemy_intent[s.enemy_intent_index].effect);
            s.enemy_intent_current_time = 0;
            s.enemy_intent_index += 1;
            if (s.enemy_intent[s.enemy_intent_index].effect == Effect.no_effect) {
                s.enemy_intent_index = 0;
            }
        }
    } else {
        s.set_choices_confirm();
        s.state = GlobalState.fight_reward;
    }

    if (s.player_hp == 0) {
        s.set_choices_confirm();
        s.state = GlobalState.game_over;
    }

    // drawing
    w4.DRAW_COLORS.* = 2;

    // hero
    s.pager.set_cursor(25, 15);
    pager.f35_text(&s.pager, "HP: ");
    pager.f35_number(&s.pager, s.player_hp);
    pager.f35_text(&s.pager, "/");
    pager.f35_number(&s.pager, s.player_max_hp);
    pager.f35_newline(&s.pager);
    pager.f35_text(&s.pager, "SHIELD: ");
    pager.f35_number(&s.pager, s.player_shield);
    w4.blit(&sprites.hero, 20, 32, sprites.hero_width, sprites.hero_height, w4.BLIT_1BPP);

    // enemy
    s.pager.set_cursor(100, 25);
    pager.f35_text(&s.pager, "HP: ");
    pager.f35_number(&s.pager, s.enemy_hp);
    pager.f35_text(&s.pager, "/");
    pager.f35_number(&s.pager, s.enemy_max_hp);
    s.pager.set_cursor(110, 50);
    switch (s.enemy_intent[s.enemy_intent_index].effect) {
        Effect.damage_to_player => |dmg| {
            _ = dmg;
            // TODO display sword icon
            pager.f47_number(&s.pager, @intCast(i32, dmg));
        },
        else => {},
    }
    draw_progress_bar(110, 60, 16, 5, s.enemy_intent_current_time, s.enemy_intent[s.enemy_intent_index].trigger_time);
    w4.blit(&sprites.enemy_00, 110, 32, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);

    w4.hline(0, 80, 160);
    draw_spell_list(s.spellbook[0..], &s.pager, 10, 90);

    for (s.spellbook) |*spell| {
        if (spell.is_completed()) {
            s.apply_effect(spell.effect);
            spell.reset();
        }
    }
}

pub fn process_fight_reward(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
    if (s.choices[0].is_completed()) {
        s.apply_effect(s.enemy_reward);
        s.state = GlobalState.pick_random_event;
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "Victory!!");
    pager.f47_newline(&s.pager);
    pager.f47_newline(&s.pager);
    switch (s.enemy_reward) {
        Effect.gold_reward => |amount| {
            pager.f47_text(&s.pager, "You gained ");
            pager.f47_number(&s.pager, amount);
            pager.f47_text(&s.pager, " gold!");
        },
        else => {},
    }

    w4.blit(&sprites.enemy_00, 10, 50, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_game_over(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
    if (s.choices[0].is_completed()) {
        s.apply_effect(s.enemy_reward);
        s.state = GlobalState.end;
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(58, 50);
    pager.f47_text(&s.pager, "GAME OVER");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_pick_random_event(s: *State, released_keys: u8) void {
    _ = released_keys;

    const max_attempts = 128;
    var attempts: u16 = 0;
    var idx: usize = @intCast(usize, @mod(rand(), event_pool.len));
    while (s.visited_events[idx] and attempts < max_attempts) : (attempts += 1) {
        idx = @intCast(usize, @mod(rand(), event_pool.len));
    }
    if (attempts == max_attempts) {
        s.state = GlobalState.end;
    } else {
        s.visited_events[idx] = true;
        s.state = event_pool[idx];
    }
}

pub fn process_event_healer(s: *State, released_keys: u8) void {
    _ = released_keys;
    if (s.player_gold >= 10) {
        s.set_choices_accept_decline();
    } else {
        s.set_choices_with_labels_1("You're broke");
    }
    s.state = GlobalState.event_healer_1;
}

pub fn process_event_healer_1(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
    if (s.choices[0].is_completed()) {
        s.set_choices_confirm();
        s.state = GlobalState.event_healer_decline;
    } else if (s.player_gold >= 10 and s.choices[1].is_completed()) {
        s.apply_effect(Effect{ .gold_payment = 10 });
        s.apply_effect(Effect.player_healing_max);
        s.set_choices_confirm();
        s.state = GlobalState.event_healer_accept;
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "You stumble upon an old man wearing druid clothes. He says:");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "\"I can heal your wounds for 10 gold. Are you interested?\"");

    draw_spell_list(&s.choices, &s.pager, 10, 130);
}

pub fn process_event_healer_decline(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
    if (s.choices[0].is_completed()) {
        s.set_choices_confirm();
        s.state = GlobalState.pick_random_event;
    }

    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "The druid says:");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "\"As you wish. May you be successful in your endeavours.\"");

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_healer_accept(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
    if (s.choices[0].is_completed()) {
        s.set_choices_confirm();
        s.state = GlobalState.pick_random_event;
    }

    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "The druid utters weird sounds that only him can understand, but you already feels better.");
    pager.f47_newline(&s.pager);

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_forest_wolf(s: *State, released_keys: u8) void {
    _ = released_keys;
    s.set_choices_fight();
    s.state = GlobalState.event_forest_wolf_1;
}

pub fn process_event_forest_wolf_1(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
    if (s.choices[0].is_completed()) {
        s.reset_player_shield();
        s.reset_enemy_intent();
        const enemy_max_hp = 20;
        s.enemy_hp = enemy_max_hp;
        s.enemy_max_hp = enemy_max_hp;
        s.enemy_intent_current_time = 0;
        s.enemy_intent_index = 0;
        s.enemy_intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 3 },
        };
        s.enemy_intent[1] = EnemyIntent{
            .trigger_time = 7 * 60,
            .effect = Effect{ .damage_to_player = 7 },
        };
        s.enemy_reward = Effect{ .gold_reward = 10 };
        s.state = GlobalState.fight;
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "As you pass through the dark woods, you hear a frightening growl behind you.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "A giant lone wolf is snarling at you. You have no choice other than to fight for your life!");

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

// TODO techical screen/state to debug things, should not be left in the game by the end of the jam
pub fn process_end(s: *State, released_keys: u8) void {
    _ = released_keys;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "(You will have to reset the cart now)");
    pager.f47_newline(&s.pager);
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "Gold: ");
    pager.f47_number(&s.pager, s.player_gold);
}

var state: State = undefined;

export fn start() void {
    _ = rand();

    w4.PALETTE.* = .{
        0x000000,
        0xcccccc,
        0x55cc55,
        0xcc5555,
    };

    const player_max_hp = 40;
    const enemy_max_hp = 20;

    state = State{
        .previous_input = 0,
        .pager = pager.Pager.new(),
        // global state
        .state = GlobalState.pick_random_event,
        .choices = undefined,
        .visited_events = undefined,
        // player
        .player_hp = player_max_hp,
        .player_max_hp = player_max_hp,
        .spellbook = undefined,
        .player_gold = 19,
        // enemy
        .enemy_hp = enemy_max_hp,
        .enemy_max_hp = enemy_max_hp,
        .enemy_intent_current_time = 0,
        .enemy_intent_index = 0,
        .enemy_reward = Effect{ .gold_reward = 10 },
    };

    var i: usize = 0;
    while (i < state.spellbook.len) : (i += 1) {
        state.spellbook[i] = Spell.zero();
    }

    state.reset_visited_events();

    state.spellbook[0] = Spell{
        .name = "FIREBALL",
        .effect = Effect{ .damage_to_enemy = 4 },
    };
    state.spellbook[0].set_spell(&[_]u8{ w4.BUTTON_LEFT, w4.BUTTON_1 });

    state.spellbook[1] = Spell{
        .name = "LIGHTNING",
        .effect = Effect{ .damage_to_enemy = 7 },
    };
    state.spellbook[1].set_spell(&[_]u8{
        w4.BUTTON_RIGHT,
        w4.BUTTON_RIGHT,
        w4.BUTTON_LEFT,
        w4.BUTTON_1,
        w4.BUTTON_RIGHT,
        w4.BUTTON_2,
    });

    state.spellbook[2] = Spell{
        .name = "SHIELD",
        .effect = Effect{ .player_shield = 2 },
    };

    state.spellbook[2].set_spell(&[_]u8{
        w4.BUTTON_DOWN,
        w4.BUTTON_DOWN,
        w4.BUTTON_RIGHT,
        w4.BUTTON_1,
    });
}

export fn update() void {
    // input processing
    const gamepad = w4.GAMEPAD1.*;
    const released_keys = state.previous_input & ~gamepad;
    state.previous_input = gamepad;

    switch (state.state) {
        GlobalState.end => process_end(&state, released_keys),
        GlobalState.event_healer => process_event_healer(&state, released_keys),
        GlobalState.event_healer_1 => process_event_healer_1(&state, released_keys),
        GlobalState.event_healer_decline => process_event_healer_decline(&state, released_keys),
        GlobalState.event_healer_accept => process_event_healer_accept(&state, released_keys),
        GlobalState.event_forest_wolf => process_event_forest_wolf(&state, released_keys),
        GlobalState.event_forest_wolf_1 => process_event_forest_wolf_1(&state, released_keys),
        GlobalState.fight => process_fight(&state, released_keys),
        GlobalState.fight_reward => process_fight_reward(&state, released_keys),
        GlobalState.game_over => process_game_over(&state, released_keys),
        GlobalState.pick_random_event => process_pick_random_event(&state, released_keys),
    }
}
