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

func bubble(color_name: String) -> Texture2D:
    return load(str(BUBBLES.get(color_name, BUBBLES["blue"]))) as Texture2D

func ui(asset_name: String) -> Texture2D:
    return load(str(UI.get(asset_name, UI["background"]))) as Texture2D

func blocker(kind: String) -> Texture2D:
    return load(str(BLOCKERS.get(kind, BLOCKERS["stone"]))) as Texture2D

func pop_frame(frame_index: int) -> Texture2D:
    var frame := clampi(frame_index, 1, 8)
    return load(ROOT + "effects/pop_%02d.svg" % frame) as Texture2D
