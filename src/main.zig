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

const Reward = union(enum(u8)) {
    no_reward: void,
    gold_reward: u16,
    spell_reward: Spell,
};

const Effect = union(enum(u8)) {
    no_effect: void,
    toggle_inventory_menu: void,
    damage_to_player: i16,
    damage_to_enemy: i16,
    player_heal: u16,
    player_healing_max: void,
    player_shield: i16,
    enemy_shield: i16,
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
    price: u16 = 0,
    alignment: i8 = 0,
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
};

const GlobalState = enum {
    end,
    event_healer,
    event_healer_1,
    event_healer_decline,
    event_healer_accept,
    event_healing_shop,
    event_healing_shop_1,
    event_forest_wolf,
    event_forest_wolf_1,
    event_militia_ambush,
    event_militia_ambush_1,
    event_sun_fountain,
    event_sun_fountain_1,
    event_sun_fountain_skip,
    event_sun_fountain_damage,
    event_sun_fountain_heal,
    event_sun_fountain_refresh,
    fight,
    fight_reward,
    game_over,
    inventory,
    inventory_1,
    inventory_full,
    inventory_full_1,
    inventory_full_2,
    new_game_init,
    pick_random_event,
    shop,
    title,
    title_1,
};

const event_pool = [_]GlobalState{
    GlobalState.event_healer,
    GlobalState.event_healing_shop,
    GlobalState.event_forest_wolf,
    GlobalState.event_militia_ambush,
    GlobalState.event_sun_fountain,
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
    inventory_exit_state: GlobalState = GlobalState.title,
    // global state
    state: GlobalState = GlobalState.title,
    visited_events: [visited_events_max_size]bool = undefined,
    choices: [spell_book_max_size]Spell = undefined,
    // player
    player_hp: i16 = 0,
    player_max_hp: i16 = 0,
    player_shield: i16 = 0,
    player_alignment: i16 = 0, // -100, +100
    player_gold: i16 = 0,
    spellbook: [spell_book_max_size]Spell = undefined,
    reward_probability: u8 = 0,
    inventory_menu_spell: Spell = undefined,
    // enemy
    enemy_hp: i16 = 0,
    enemy_max_hp: i16 = 0,
    enemy_shield: i16 = 0,
    enemy_intent_current_time: u16 = 0,
    enemy_intent_index: usize = 0,
    enemy_intent: [enemy_intent_max_size]EnemyIntent = undefined,
    enemy_guaranteed_reward: Reward = Reward.no_reward,
    enemy_random_reward: RandomReward = RandomReward.zero(),
    enemy_sprite: [*]const u8 = undefined,
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
                } else {
                    self.player_shield -= dmg;
                }
            },
            Effect.damage_to_enemy => |dmg| {
                if (dmg > self.enemy_shield) {
                    self.enemy_hp -= (dmg - self.enemy_shield);
                    self.enemy_shield = 0;
                    if (self.enemy_hp < 0) {
                        self.enemy_hp = 0;
                    }
                } else {
                    self.enemy_shield -= dmg;
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
                self.enemy_shield += @intCast(i16, amount);
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
    pager.f47_text(&state.pager, spell.name);
    draw_spell_input(&spell.input, spell.current_progress, 10 + (12 * (1 + pager.f47_letter_width)), y);
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

pub fn draw_progress_bubble(x: i32, y: i32, v: u32, max: u32) void {
    w4.DRAW_COLORS.* = 0x21;
    var sprite_index = 9 * (v * 17 / max);
    if (sprite_index >= sprites.progress_bubble_width) {
        sprite_index = sprites.progress_bubble_width - 9;
    }
    w4.blitSub(&sprites.progress_bubble, x, y, 9, 9, sprite_index, 0, sprites.progress_bubble_width, w4.BLIT_1BPP);
    w4.DRAW_COLORS.* = 0x02;
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

pub fn draw_moon(x: i32, y: i32) void {
    w4.blitSub(&sprites.alignment, x, y, 9, 9, 0, 0, sprites.alignment_width, w4.BLIT_1BPP);
}

pub fn draw_sun(x: i32, y: i32) void {
    w4.blitSub(&sprites.alignment, x, y, 9, 9, 9, 0, sprites.alignment_width, w4.BLIT_1BPP);
}

pub fn draw_effect(x: i32, y: i32, s: *State, effect: Effect) void {
    switch (effect) {
        Effect.damage_to_player, Effect.damage_to_enemy => |dmg| {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 0, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.f47_number(&s.pager, @intCast(i32, dmg));
        },
        Effect.player_shield, Effect.enemy_shield => |amount| {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 9, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.f47_number(&s.pager, @intCast(i32, amount));
        },
        Effect.player_heal => |amount| {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 18, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.f47_number(&s.pager, amount);
        },
        Effect.player_healing_max => {
            w4.blitSub(&sprites.effects, x, y, 9, 9, 18, 0, sprites.effects_width, w4.BLIT_1BPP);
            s.pager.set_cursor(x + 12, y + 1);
            pager.f47_text(&s.pager, "max");
        },
        Effect.gold_payment => |amount| {
            draw_coin(x, y);
            s.pager.set_cursor(x + 12, y + 1);
            pager.f47_number(&s.pager, -@intCast(i32, amount));
        },
        else => {},
    }
}

pub fn draw_shop_party(x: i32, y: i23, s: *State, name: []const u8, gold_amount: i16) void {
    s.pager.set_cursor(x, y);
    pager.f47_text(&s.pager, name);
    pager.f47_text(&s.pager, " * ");
    draw_coin(s.pager.cursor_x, y - 1);
    s.pager.set_cursor(s.pager.cursor_x + 11, y);
    pager.f47_number(&s.pager, gold_amount);
}

pub fn draw_spell_details(x: i32, y: i32, s: *State, spell: Spell) void {
    s.pager.set_cursor(x, y);
    pager.f47_text(&s.pager, spell.name);
    if (spell.alignment > 0) {
        draw_sun(s.pager.cursor_x, y - 1);
    } else {
        draw_moon(s.pager.cursor_x, y - 1);
    }
    s.pager.set_cursor(s.pager.cursor_x + 11, y);
    pager.f47_text(&s.pager, " * ");
    draw_effect(s.pager.cursor_x, y - 1, s, spell.effect);
    pager.f47_text(&s.pager, " * ");
    draw_coin(s.pager.cursor_x, y - 1);
    s.pager.set_cursor(s.pager.cursor_x + 11, y);
    pager.f47_number(&s.pager, spell.price);
    draw_spell_input(&spell.input, 0, x, y + 2 * (pager.f47_height + 1));
}

// draws a list of spell names + cursor
pub fn draw_spell_inventory_list(x: i32, y: i32, s: *State, list: []Spell, show_cursor: bool) void {
    var i: usize = 0;
    while (i < list.len) : (i += 1) {
        const y_list = y + @intCast(i32, i * (pager.f47_height + 2));
        s.pager.set_cursor(x, y_list);
        if (show_cursor and i == s.spell_index) {
            w4.blitSub(&sprites.arrows, x + 2, y_list - 1, 5, 9, 0, 9, sprites.arrows_width, w4.BLIT_1BPP | w4.BLIT_FLIP_X);
        }
        s.pager.set_cursor(x + 10, y_list);
        pager.f47_text(&s.pager, list[i].name);
    }
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
    pager.f47_number(&s.pager, s.player_hp);
    pager.f47_text(&s.pager, "/");
    pager.f47_number(&s.pager, s.player_max_hp);
    draw_coin(hp_x, y + 11);
    s.pager.set_cursor(hp_x + 11, y + 12);
    pager.f47_number(&s.pager, s.player_gold);

    draw_moon(x, y + 11);
    draw_sun(x + 72, y + 11);
    w4.DRAW_COLORS.* = 0x20;
    // aligment bar is 60 wide
    w4.rect(x + 10, y + 12, 60, 7);
    //w4.rect(x + 10 + 30, y + 12, 2, 7);
    w4.DRAW_COLORS.* = 0x22;
    // oval x should be between 10 and 55
    w4.oval(x + 10 + @divTrunc((100 + s.player_alignment) * 55, 200), y + 14, 4, 3);
    w4.DRAW_COLORS.* = 0x02;
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
    w4.rect(x + 10, y + 11, @intCast(u32, @divTrunc(2 * sprites.progress_bar_width * s.enemy_hp, s.enemy_max_hp)), sprites.progress_bar_height);
    const hp_x = x + 15 + 2 * sprites.progress_bar_width;
    s.pager.set_cursor(hp_x, y + 11);
    pager.f47_number(&s.pager, s.enemy_hp);

    draw_shield(x, y);
    s.pager.set_cursor(x + 10, y + 1);
    pager.f47_number(&s.pager, s.enemy_shield);
}

pub fn process_choices_input(s: *State, released_keys: u8) void {
    for (s.choices) |*spell| {
        spell.process(released_keys);
    }
}

pub fn process_fight(s: *State, released_keys: u8) void {
    s.inventory_menu_spell.process(released_keys);
    if (s.inventory_menu_spell.is_completed()) {
        s.apply_effect(s.inventory_menu_spell.effect);
        s.inventory_menu_spell.reset();
    }
    if (s.inventory_menu_flag) {
        s.inventory_exit_state = GlobalState.fight;
        s.state = GlobalState.inventory;
        return;
    }

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
        s.reward_probability = @intCast(u8, @mod(rand(), 100));
        s.state = GlobalState.fight_reward;
    }

    if (s.player_hp == 0) {
        s.set_choices_confirm();
        s.state = GlobalState.game_over;
    }

    // drawing
    w4.DRAW_COLORS.* = 2;

    draw_player_hud(s);

    // hero
    draw_shield(10, 22);
    s.pager.set_cursor(20, 22);
    pager.f47_number(&s.pager, s.player_shield);
    w4.blit(&sprites.hero, 20, 32, sprites.hero_width, sprites.hero_height, w4.BLIT_1BPP);

    // enemy
    draw_enemy_hud(s);
    w4.blit(state.enemy_sprite, 105, 42, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);
    s.pager.set_cursor(100, 15);
    draw_progress_bubble(100, 32, s.enemy_intent_current_time, s.enemy_intent[s.enemy_intent_index].trigger_time);
    draw_effect(111, 32, s, s.enemy_intent[s.enemy_intent_index].effect);

    w4.hline(0, 80, 160);
    draw_spell_list(s.spellbook[0..], &s.pager, 10, 90);

    for (s.spellbook) |*spell| {
        if (spell.is_completed()) {
            s.apply_effect(spell.effect);
            s.change_alignment(spell.alignment);
            spell.reset();
        }
    }
}

pub fn draw_reward(s: *State, reward: Reward) void {
    switch (reward) {
        Reward.gold_reward => |amount| {
            pager.f47_text(&s.pager, "You gained ");
            pager.f47_number(&s.pager, amount);
            pager.f47_text(&s.pager, " gold!");
            pager.f47_newline(&s.pager);
        },
        Reward.spell_reward => |spell| {
            pager.f47_text(&s.pager, "You leared the ");
            pager.f47_text(&s.pager, spell.name);
            pager.f47_text(&s.pager, " spell!");
            pager.f47_newline(&s.pager);
        },
        else => {},
    }
}

pub fn process_fight_reward(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.apply_reward(s.enemy_guaranteed_reward);
        if (s.reward_probability < s.enemy_random_reward.probability) {
            s.apply_reward(s.enemy_random_reward.reward);
        }
        s.state = GlobalState.pick_random_event;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "Victory!!");
    pager.f47_newline(&s.pager);
    pager.f47_newline(&s.pager);
    draw_reward(s, s.enemy_guaranteed_reward);

    if (s.reward_probability < s.enemy_random_reward.probability) {
        draw_reward(s, s.enemy_random_reward.reward);
    }

    w4.blit(state.enemy_sprite, 10, 70, sprites.enemy_width, sprites.enemy_height, w4.BLIT_1BPP);

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_game_over(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.title;
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(58, 50);
    pager.f47_text(&s.pager, "GAME OVER");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_inventory(s: *State, released_keys: u8) void {
    _ = released_keys;
    s.set_choices_back();
    s.state = GlobalState.inventory_1;
}

pub fn process_inventory_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.inventory_menu_flag = false;
        s.state = s.inventory_exit_state;
    }

    process_keys_spell_list(s, released_keys, &s.spellbook);

    const spell = s.spellbook[@intCast(usize, s.spell_index)];

    w4.DRAW_COLORS.* = 0x02;
    draw_spell_details(10, 10, s, spell);
    w4.hline(0, 80, 160);
    draw_spell_inventory_list(10, 90, s, &s.spellbook, true);

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_inventory_full(s: *State, released_keys: u8) void {
    _ = released_keys;

    s.state = GlobalState.inventory_full_1;
    s.set_choices_confirm();

    s.spell_index = 0;
    s.shop_list_index = 0;
    s.shop_gold = 0;
    s.reset_shop_items();
}

pub fn process_inventory_full_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.inventory_full_2;
        s.set_choices_inventory_full();
    }
    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(10, 10);
    pager.f47_text(&s.pager, "Your spellbook is full!!");
    pager.f47_newline(&s.pager);
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "You should discard some spells before continuing your adventure.");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_inventory_full_2(s: *State, released_keys: u8) void {
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        s.shop_list_index = 1 - s.shop_list_index;
    }
    var spell: Spell = undefined;
    if (s.shop_list_index == 0) {
        process_keys_spell_list(s, released_keys, &s.spellbook);
        spell = s.spellbook[@intCast(usize, s.spell_index)];
    }
    if (s.shop_list_index == 1) {
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
    w4.hline(0, 40, 160);

    draw_shop_party(10, 50, s, "YOU", s.player_gold);
    draw_spell_inventory_list(10, 70, s, &s.spellbook, s.shop_list_index == 0);

    draw_shop_party(90, 50, s, "GROUND", s.shop_gold);
    draw_spell_inventory_list(90, 70, s, &s.shop_items, s.shop_list_index == 1);

    draw_spell_list(&s.choices, &s.pager, 10, 140);

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.pager.set_cursor(85, 140);
        pager.f47_text(&s.pager, "Can't leave. ");
        s.pager.set_cursor(85, 150);
        pager.f47_text(&s.pager, "Spellbook full");
    }
}

pub fn process_pick_random_event(s: *State, released_keys: u8) void {
    _ = released_keys;

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.state = GlobalState.inventory_full;
        return;
    }

    const max_attempts = 128;
    var attempts: u16 = 0;
    var idx: usize = @intCast(usize, @mod(rand(), event_pool.len));
    while (s.visited_events[idx] and attempts < max_attempts) : (attempts += 1) {
        idx = @intCast(usize, @mod(rand(), event_pool.len));
    }
    if (attempts == max_attempts) {
        s.state = GlobalState.end; // TODO remove this once we have enough fights/events
    } else {
        s.visited_events[idx] = true;
        s.state = event_pool[idx];
    }
}

pub fn process_title(s: *State, released_keys: u8) void {
    _ = released_keys;
    state.set_choices_with_labels_1("Start Game");
    s.state = GlobalState.title_1;
}

pub fn process_title_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.new_game_init;
    }

    // generate randomness
    _ = rand();

    w4.DRAW_COLORS.* = 0x02;
    s.pager.set_cursor(58, 50);
    pager.f47_text(&s.pager, "G A L D R");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_new_game_init(s: *State, released_keys: u8) void {
    _ = released_keys;

    const player_max_hp = 40;
    const enemy_max_hp = 20;

    state = State{
        .previous_input = 0,
        .pager = pager.Pager.new(),
        // global state
        .state = GlobalState.title,
        .choices = undefined,
        .visited_events = undefined,
        // player
        .player_hp = player_max_hp,
        .player_max_hp = player_max_hp,
        .spellbook = undefined,
        .player_gold = 19,
        .inventory_menu_spell = Spell.spell_inventory_menu(),

        // enemy
        .enemy_hp = enemy_max_hp,
        .enemy_max_hp = enemy_max_hp,
        .enemy_intent_current_time = 0,
        .enemy_intent_index = 0,
        .enemy_guaranteed_reward = Reward{ .gold_reward = 10 },
    };

    var i: usize = 0;
    while (i < state.spellbook.len) : (i += 1) {
        state.spellbook[i] = Spell.zero();
    }

    state.reset_visited_events();

    state.spellbook[0] = Spell.spell_fireball();
    state.spellbook[1] = Spell.spell_lightning();
    state.spellbook[2] = Spell.spell_shield();

    s.state = GlobalState.pick_random_event;
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
    process_choices_input(s, released_keys);
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
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "You stumble upon an old man wearing druid clothes. He says:");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "\"I can heal your wounds for 10 gold. Are you interested?\"");

    draw_spell_list(&s.choices, &s.pager, 10, 130);
}

pub fn process_event_healer_decline(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.set_choices_confirm();
        s.state = GlobalState.pick_random_event;
    }

    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "The druid says:");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "\"As you wish. May you be successful in your endeavours.\"");

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_healer_accept(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.set_choices_confirm();
        s.state = GlobalState.pick_random_event;
    }

    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "The druid utters weird sounds that only him can understand, but you already feels better.");
    pager.f47_newline(&s.pager);

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_healing_shop(s: *State, released_keys: u8) void {
    _ = released_keys;

    s.state = GlobalState.event_healing_shop_1;
    s.set_choices_confirm();

    s.spell_index = 0;
    s.shop_list_index = 0;
    s.shop_gold = 50;
    s.reset_shop_items();
    s.shop_items[0] = Spell.spell_heal();
    s.shop_items[1] = Spell.spell_heal_plus();
}

pub fn process_event_healing_shop_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.shop;
        s.set_choices_shop();
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "The merchant greets you:");
    pager.f47_newline(&s.pager);
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "\"Welcome to Hildan's Heap of Heals!\"");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

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

pub fn process_shop(s: *State, released_keys: u8) void {
    if (released_keys == w4.BUTTON_LEFT or released_keys == w4.BUTTON_RIGHT) {
        s.shop_list_index = 1 - s.shop_list_index;
    }
    var spell: Spell = undefined;
    if (s.shop_list_index == 0) {
        process_keys_spell_list(s, released_keys, &s.spellbook);
        spell = s.spellbook[@intCast(usize, s.spell_index)];
    }
    if (s.shop_list_index == 1) {
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
    w4.hline(0, 40, 160);

    draw_shop_party(10, 50, s, "YOU", s.player_gold);
    draw_spell_inventory_list(10, 70, s, &s.spellbook, s.shop_list_index == 0);

    draw_shop_party(90, 50, s, "SHOP", s.shop_gold);
    draw_spell_inventory_list(90, 70, s, &s.shop_items, s.shop_list_index == 1);

    draw_spell_list(&s.choices, &s.pager, 10, 140);

    if (get_spell_list_size(&s.spellbook) >= spell_book_full_size) {
        s.pager.set_cursor(85, 140);
        pager.f47_text(&s.pager, "Can't leave. ");
        s.pager.set_cursor(85, 150);
        pager.f47_text(&s.pager, "Spellbook full");
    }
    if (s.player_gold < 0 or s.shop_gold < 0) {
        s.pager.set_cursor(85, 140);
        pager.f47_text(&s.pager, "Can't leave. ");
        s.pager.set_cursor(85, 150);
        pager.f47_text(&s.pager, "Not enough");
        draw_coin(s.pager.cursor_x + 3, 150 - 1);
    }
}

pub fn process_event_forest_wolf(s: *State, released_keys: u8) void {
    _ = released_keys;
    s.set_choices_fight();
    s.state = GlobalState.event_forest_wolf_1;
}

pub fn process_event_forest_wolf_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
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
        s.enemy_guaranteed_reward = Reward{ .gold_reward = 10 };
        s.enemy_random_reward = RandomReward{
            .probability = 33,
            .reward = Reward{ .spell_reward = Spell.spell_wolf_bite() },
        };
        s.enemy_sprite = &sprites.enemy_00;
        s.state = GlobalState.fight;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "As you pass through the dark woods, you hear a frightening growl behind you.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "A giant lone wolf is snarling at you. You have no choice other than to fight for your life!");

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_militia_ambush(s: *State, released_keys: u8) void {
    _ = released_keys;
    s.set_choices_fight();
    s.state = GlobalState.event_militia_ambush_1;
}

pub fn process_event_militia_ambush_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.reset_player_shield();
        s.reset_enemy_intent();
        const enemy_max_hp = 30;
        s.enemy_hp = enemy_max_hp;
        s.enemy_max_hp = enemy_max_hp;
        s.enemy_intent_current_time = 0;
        s.enemy_intent_index = 0;
        s.enemy_intent[0] = EnemyIntent{
            .trigger_time = 4 * 60,
            .effect = Effect{ .damage_to_player = 5 },
        };
        s.enemy_intent[1] = EnemyIntent{
            .trigger_time = 5 * 60,
            .effect = Effect{ .enemy_shield = 3 },
        };
        s.enemy_guaranteed_reward = Reward{ .gold_reward = 50 };
        s.enemy_random_reward = RandomReward.zero();
        s.enemy_sprite = &sprites.enemy_militia;
        s.state = GlobalState.fight;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "You spot a lone militia soldier coming your way.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "He does not seem aware that you're here.");

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_sun_fountain(s: *State, released_keys: u8) void {
    _ = released_keys;
    s.set_choices_with_labels_2("Skip", "Drink");
    s.state = GlobalState.event_sun_fountain_1;
}

pub fn process_event_sun_fountain_1(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.set_choices_confirm();
        s.state = GlobalState.event_sun_fountain_skip;
        return;
    }
    if (s.choices[1].is_completed()) {
        s.set_choices_confirm();
        if (s.player_alignment < -20) {
            s.state = GlobalState.event_sun_fountain_damage;
            s.apply_effect(Effect{ .damage_to_player = 5 });
        } else if (s.player_alignment > 20) {
            s.state = GlobalState.event_sun_fountain_heal;
            s.apply_effect(Effect{ .player_heal = 10 });
        } else {
            s.state = GlobalState.event_sun_fountain_refresh;
        }
        return;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "You come across a white fountain basking in a pillar of light.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "You feel thirsty. Do you want to drink from the fountain?");

    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_sun_fountain_skip(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.pick_random_event;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "Such a fountain in the middle of nowhere seems strange. You continue your journey without drinking from it.");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_sun_fountain_damage(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.pick_random_event;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "The water has a foul taste and your belly immediately hurts.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "You cast a spell to improve your condition but do not fully recover.");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_sun_fountain_heal(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.pick_random_event;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "The water is cool and you feel calm and relaxed.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "After resting for a bit, you move on to your next adventure.");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

pub fn process_event_sun_fountain_refresh(s: *State, released_keys: u8) void {
    process_choices_input(s, released_keys);
    if (s.choices[0].is_completed()) {
        s.state = GlobalState.pick_random_event;
    }
    w4.DRAW_COLORS.* = 0x02;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "The water is tepid and tasteless.");
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "After resting for a bit, you move on to your next adventure.");
    draw_spell_list(&s.choices, &s.pager, 10, 140);
}

// TODO techical screen/state to debug things, should not be left in the game by the end of the jam
pub fn process_end(s: *State, released_keys: u8) void {
    _ = released_keys;
    draw_player_hud(s);
    s.pager.set_cursor(10, 30);
    pager.f47_text(&s.pager, "(You will have to reset the cart now)");
    pager.f47_newline(&s.pager);
    pager.f47_newline(&s.pager);
    pager.f47_text(&s.pager, "Gold: ");
    pager.f47_number(&s.pager, s.player_gold);
}

var state: State = undefined;

export fn start() void {
    w4.PALETTE.* = .{
        0x000000,
        0xcccccc,
        0x55cc55,
        0xcc5555,
    };

    state = State{};
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
        GlobalState.event_healing_shop => process_event_healing_shop(&state, released_keys),
        GlobalState.event_healing_shop_1 => process_event_healing_shop_1(&state, released_keys),
        GlobalState.event_forest_wolf => process_event_forest_wolf(&state, released_keys),
        GlobalState.event_forest_wolf_1 => process_event_forest_wolf_1(&state, released_keys),
        GlobalState.event_militia_ambush => process_event_militia_ambush(&state, released_keys),
        GlobalState.event_militia_ambush_1 => process_event_militia_ambush_1(&state, released_keys),
        GlobalState.event_sun_fountain => process_event_sun_fountain(&state, released_keys),
        GlobalState.event_sun_fountain_1 => process_event_sun_fountain_1(&state, released_keys),
        GlobalState.event_sun_fountain_skip => process_event_sun_fountain_skip(&state, released_keys),
        GlobalState.event_sun_fountain_damage => process_event_sun_fountain_damage(&state, released_keys),
        GlobalState.event_sun_fountain_heal => process_event_sun_fountain_heal(&state, released_keys),
        GlobalState.event_sun_fountain_refresh => process_event_sun_fountain_refresh(&state, released_keys),
        GlobalState.fight => process_fight(&state, released_keys),
        GlobalState.fight_reward => process_fight_reward(&state, released_keys),
        GlobalState.game_over => process_game_over(&state, released_keys),
        GlobalState.inventory => process_inventory(&state, released_keys),
        GlobalState.inventory_1 => process_inventory_1(&state, released_keys),
        GlobalState.inventory_full => process_inventory_full(&state, released_keys),
        GlobalState.inventory_full_1 => process_inventory_full_1(&state, released_keys),
        GlobalState.inventory_full_2 => process_inventory_full_2(&state, released_keys),
        GlobalState.new_game_init => process_new_game_init(&state, released_keys),
        GlobalState.pick_random_event => process_pick_random_event(&state, released_keys),
        GlobalState.shop => process_shop(&state, released_keys),
        GlobalState.title => process_title(&state, released_keys),
        GlobalState.title_1 => process_title_1(&state, released_keys),
    }
}
