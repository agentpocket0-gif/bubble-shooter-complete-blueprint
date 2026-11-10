extends Node

const ROOT := "res://assets/own/"
const BUBBLES := {
    "red": ROOT + "bubbles/red.svg",
    "blue": ROOT + "bubbles/blue.svg",
    "green": ROOT + "bubbles/green.svg",
    "yellow": ROOT + "bubbles/yellow.svg",
    "purple": ROOT + "bubbles/purple.svg",
    "orange": ROOT + "bubbles/orange.svg"
}
const UI := {
    "background": ROOT + "ui/background.svg",
    "logo": ROOT + "ui/logo.svg",
    "cannon": ROOT + "ui/cannon.svg",
    "coin": ROOT + "ui/coin.svg",
    "star": ROOT + "ui/star.svg",
    "panel": ROOT + "ui/panel.svg"
}
const BLOCKERS := {
    "ice": ROOT + "blockers/ice.svg",
    "stone": ROOT + "blockers/stone.svg",
    "chain": ROOT + "blockers/chain.svg"
}
const BOOSTER_ICONS := {
    "Bomb": ROOT + "boosters/bomb.svg",
    "Fireball": ROOT + "boosters/fireball.svg",
    "Rainbow": ROOT + "boosters/rainbow.svg",
    "Swap": ROOT + "boosters/swap.svg",
    "+5 Moves": ROOT + "boosters/extra_moves.svg",
    "Continue": ROOT + "boosters/continue.svg"
}
const UI_ICONS := {
    "spin": ROOT + "ui/icons/spin.svg",
    "piggy": ROOT + "ui/icons/piggy.svg",
    "events": ROOT + "ui/icons/events.svg",
    "shop": ROOT + "ui/icons/shop.svg",
    "settings": ROOT + "ui/icons/settings.svg",
    "heart": ROOT + "ui/icons/heart.svg",
    "gem": ROOT + "ui/icons/gem.svg",
    "pause": ROOT + "ui/icons/pause.svg",
    "sound_on": ROOT + "ui/icons/sound_on.svg",
    "sound_off": ROOT + "ui/icons/sound_off.svg",
    "music_on": ROOT + "ui/icons/music_on.svg",
    "music_off": ROOT + "ui/icons/music_off.svg",
    "gift": ROOT + "ui/icons/gift.svg",
    "lock": ROOT + "ui/icons/lock.svg",
    "play": ROOT + "ui/icons/play.svg",
    "close": ROOT + "ui/icons/close.svg"
}

func bubble(color_name: String) -> Texture2D:
    return load(str(BUBBLES.get(color_name, BUBBLES["blue"]))) as Texture2D

func ui(asset_name: String) -> Texture2D:
    return load(str(UI.get(asset_name, UI["background"]))) as Texture2D

func blocker(kind: String) -> Texture2D:
    return load(str(BLOCKERS.get(kind, BLOCKERS["stone"]))) as Texture2D

func booster_icon(kind: String) -> Texture2D:
    return load(str(BOOSTER_ICONS.get(kind, BOOSTER_ICONS["Rainbow"]))) as Texture2D

func ui_icon(icon_name: String) -> Texture2D:
    return load(str(UI_ICONS.get(icon_name, UI_ICONS["play"]))) as Texture2D

func map_node(node_state: String) -> Texture2D:
    var states := ["locked", "current", "done", "star"]
    var safe_state := node_state if states.has(node_state) else "locked"
    return load(ROOT + "map_nodes/%s.svg" % safe_state) as Texture2D

func pop_frame(frame_index: int) -> Texture2D:
    var frame := clampi(frame_index, 1, 8)
    return load(ROOT + "effects/pop_%02d.svg" % frame) as Texture2D
