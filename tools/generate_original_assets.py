#!/usr/bin/env python3
"""Create all game art as original SVG vectors; never reads the extracted asset bundle."""
from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "godot_project" / "assets" / "own"
COLORS = {
    "red": ("#ff6474", "#b51e52"), "blue": ("#55d8ff", "#1463c7"),
    "green": ("#72edb2", "#12865f"), "yellow": ("#ffe77a", "#dc8b24"),
    "purple": ("#cf91ff", "#7135ad"), "orange": ("#ffb16a", "#d95727"),
}

def write(relative: str, content: str) -> None:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content + "\n", encoding="utf-8")

def main() -> None:
    for name, (light, dark) in COLORS.items():
        write(f"bubbles/{name}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs><radialGradient id="g" cx="30%" cy="23%" r="78%"><stop offset="0" stop-color="#fff"/><stop offset=".18" stop-color="{light}"/><stop offset=".72" stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></radialGradient></defs><circle cx="64" cy="66" r="54" fill="#071b3b" opacity=".25"/><circle cx="62" cy="61" r="51" fill="url(#g)" stroke="#fff" stroke-opacity=".85" stroke-width="4"/><ellipse cx="46" cy="37" rx="24" ry="15" fill="#fff" opacity=".42"/><path d="M31 85 Q60 111 91 80" fill="none" stroke="#fff" stroke-opacity=".22" stroke-width="5" stroke-linecap="round"/></svg>""")
    write("ui/app_icon.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><defs><radialGradient id="bg"><stop stop-color="#287db5"/><stop offset="1" stop-color="#071d4b"/></radialGradient><radialGradient id="bubble"><stop stop-color="#fff"/><stop offset=".22" stop-color="#64ddff"/><stop offset="1" stop-color="#1555aa"/></radialGradient></defs><rect width="512" height="512" rx="112" fill="url(#bg)"/><circle cx="256" cy="240" r="160" fill="url(#bubble)" stroke="#e9fbff" stroke-width="18"/><ellipse cx="205" cy="160" rx="70" ry="43" fill="#fff" opacity=".55"/><path d="M256 120L286 204L378 210L306 268L330 360L256 309L182 360L206 268L134 210L226 204Z" fill="#ffe071" stroke="#fff5bd" stroke-width="13" stroke-linejoin="round"/><path d="M90 425Q256 480 422 425" stroke="#7ff1ff" stroke-width="16" fill="none" stroke-linecap="round"/></svg>""")
    write("ui/background.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="540" height="960" viewBox="0 0 540 960"><defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#102d68"/><stop offset=".55" stop-color="#1767a0"/><stop offset="1" stop-color="#52b9c9"/></linearGradient><linearGradient id="sea" x2="0" y2="1"><stop stop-color="#176c9b"/><stop offset="1" stop-color="#08264f"/></linearGradient></defs><rect width="540" height="960" fill="url(#sky)"/><circle cx="420" cy="145" r="65" fill="#ffe8a4" opacity=".85"/><g fill="#fff" opacity=".7"><circle cx="62" cy="90" r="3"/><circle cx="120" cy="180" r="2"/><circle cx="247" cy="76" r="3"/><circle cx="330" cy="255" r="2"/><circle cx="490" cy="310" r="3"/><circle cx="170" cy="310" r="2"/></g><path d="M0 455 Q70 395 145 455 T290 447 T430 430 T540 460 V960 H0Z" fill="#1c8e91"/><path d="M0 520 Q95 470 190 525 T380 514 T540 525 V960 H0Z" fill="url(#sea)"/><path d="M0 610 Q95 565 190 617 T380 604 T540 615 V960 H0Z" fill="#4fbc9c" opacity=".75"/><path d="M0 735 Q120 675 230 742 T440 720 T540 750 V960 H0Z" fill="#0d4772"/></svg>""")
    write("ui/logo.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="900" height="440" viewBox="0 0 900 440"><defs><linearGradient id="gold" x2="0" y2="1"><stop stop-color="#fff9b5"/><stop offset=".48" stop-color="#ffc84c"/><stop offset="1" stop-color="#e87525"/></linearGradient><linearGradient id="blue" x2="0" y2="1"><stop stop-color="#3ce5ff"/><stop offset="1" stop-color="#1264b6"/></linearGradient></defs><path d="M70 95 Q450 -20 830 95 L790 320 Q450 425 110 320Z" fill="#071b48" stroke="#a8efff" stroke-width="14"/><path d="M88 105 Q450 4 812 105 L774 298 Q450 390 126 298Z" fill="url(#blue)" stroke="#fff" stroke-width="5"/><g fill="url(#gold)" stroke="#713f1c" stroke-width="8" paint-order="stroke"><text x="450" y="177" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-weight="900" font-size="95">BUBBLE</text><text x="450" y="276" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-weight="900" font-size="108">BLAST</text></g><g><circle cx="126" cy="90" r="33" fill="#ff697c" stroke="#fff" stroke-width="6"/><circle cx="776" cy="85" r="34" fill="#ffe27b" stroke="#fff" stroke-width="6"/><circle cx="170" cy="330" r="25" fill="#7ce5ff" stroke="#fff" stroke-width="5"/><circle cx="727" cy="330" r="25" fill="#bd83ff" stroke="#fff" stroke-width="5"/></g><text x="450" y="374" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-weight="700" font-size="32" letter-spacing="8" fill="#f3fcff">CLASSIC SHOOTER</text></svg>""")
    write("ui/cannon.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="260" height="240" viewBox="0 0 260 240"><defs><linearGradient id="metal" x2="0" y2="1"><stop stop-color="#d8faff"/><stop offset=".45" stop-color="#4aa2d9"/><stop offset="1" stop-color="#194b88"/></linearGradient></defs><ellipse cx="130" cy="208" rx="104" ry="22" fill="#061936" opacity=".45"/><path d="M95 170 L95 74 Q130 24 165 74 L165 170Z" fill="url(#metal)" stroke="#e7fbff" stroke-width="8"/><path d="M106 90 L106 42 Q130 4 154 42 L154 90Z" fill="#174777" stroke="#a7eaff" stroke-width="7"/><rect x="65" y="156" width="130" height="55" rx="24" fill="#e9a943" stroke="#fff1b3" stroke-width="8"/><circle cx="130" cy="183" r="31" fill="#245b91" stroke="#b8eeff" stroke-width="8"/><circle cx="130" cy="183" r="12" fill="#ffdc71"/></svg>""")
    write("ui/coin.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="66" r="54" fill="#a64b12"/><circle cx="62" cy="60" r="52" fill="#ffd34f" stroke="#fff0a4" stroke-width="8"/><circle cx="62" cy="60" r="39" fill="none" stroke="#e99b22" stroke-width="5"/><path d="M75 29 Q52 23 43 42 Q39 54 58 61 Q82 68 76 88 Q69 106 43 93" fill="none" stroke="#b66a19" stroke-width="10" stroke-linecap="round"/><path d="M62 18v85" stroke="#b66a19" stroke-width="5"/></svg>""")
    write("ui/star.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="M64 7 L79 45 L120 48 L88 75 L98 117 L64 94 L30 117 L40 75 L8 48 L49 45Z" fill="#ffda4c" stroke="#fff2aa" stroke-width="7" stroke-linejoin="round"/></svg>""")
    write("ui/panel.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="512" height="320" viewBox="0 0 512 320"><defs><linearGradient id="p" x2="0" y2="1"><stop stop-color="#267db0"/><stop offset="1" stop-color="#102f64"/></linearGradient></defs><rect x="8" y="8" width="496" height="304" rx="42" fill="#061b42" opacity=".5"/><rect x="8" y="8" width="496" height="292" rx="42" fill="url(#p)" stroke="#b7f5ff" stroke-width="12"/><rect x="26" y="26" width="460" height="256" rx="30" fill="none" stroke="#ffda77" stroke-width="4"/></svg>""")
    write("blockers/ice.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="M64 8 L108 34 L112 83 L65 119 L18 86 L20 37Z" fill="#81e9ff" fill-opacity=".65" stroke="#e5fcff" stroke-width="8"/><path d="M64 17V109M25 42l78 45M103 40L25 88" stroke="#fff" stroke-width="8" opacity=".75"/></svg>""")
    write("blockers/stone.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="M18 28L53 9L105 26L118 75L84 115L29 105L8 65Z" fill="#728096" stroke="#d2dfed" stroke-width="8"/><path d="M53 11L46 51L74 65L105 27M46 51L20 82M74 65L84 115M74 65L116 73" fill="none" stroke="#344760" stroke-width="7"/></svg>""")
    write("blockers/chain.svg", """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="42" cy="52" r="25" fill="none" stroke="#ffe08b" stroke-width="13"/><circle cx="82" cy="76" r="25" fill="none" stroke="#ffe08b" stroke-width="13"/><path d="M52 62L72 66" stroke="#a85c19" stroke-width="13"/></svg>""")
    for frame in range(1, 9):
        scale = 0.55 + frame * 0.06
        write(f"effects/pop_{frame:02d}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g transform="translate(64 64) scale({scale:.2f})"><path d="M0 -58 L12 -21 L43 -43 L26 -10 L62 0 L25 12 L44 43 L11 25 L0 62 L-13 24 L-43 44 L-25 11 L-62 0 L-24 -12 L-43 -43 L-11 -24Z" fill="#ffe875" stroke="#fff9c8" stroke-width="5" stroke-linejoin="round"/><circle r="23" fill="#fff" opacity=".85"/></g></svg>""")

    # Original UI icon set. These are new vectors, not extracted reference artwork.
    icon_marks = {
        "heart": ('<path d="M64 111L18 65C-5 37 27 7 52 29L64 41L76 29C101 7 133 37 110 65Z" fill="#ff789b" stroke="#fff" stroke-width="8"/>', "#ff789b"),
        "gem": ('<path d="M22 20H106L121 49L64 116L7 49Z" fill="#65dcff" stroke="#fff" stroke-width="7"/><path d="M22 20L46 49L64 116L84 49L106 20M7 49H121" fill="none" stroke="#1877b1" stroke-width="6"/>', "#65dcff"),
        "pause": ('<rect x="23" y="17" width="30" height="94" rx="10" fill="#fff0a4"/><rect x="75" y="17" width="30" height="94" rx="10" fill="#fff0a4"/>', "#fff0a4"),
        "settings": ('<path d="M55 9H73L80 24L94 30L109 24L120 42L111 56L115 71L127 83L118 101L101 100L89 111L86 126H66L58 111L43 106L29 115L13 99L21 84L17 69L5 58L15 39L31 40L44 27Z" fill="#78dfff" stroke="#fff" stroke-width="5"/><circle cx="64" cy="67" r="20" fill="#174b7f" stroke="#fff" stroke-width="6"/>', "#78dfff"),
        "sound_on": ('<path d="M12 47H38L69 22V106L38 81H12Z" fill="#9beaff" stroke="#fff" stroke-width="6"/><path d="M84 42Q110 64 84 86M94 25Q132 64 94 103" fill="none" stroke="#ffe27f" stroke-width="9" stroke-linecap="round"/>', "#9beaff"),
        "sound_off": ('<path d="M12 47H38L69 22V106L38 81H12Z" fill="#9beaff" stroke="#fff" stroke-width="6"/><path d="M84 44L115 84M115 44L84 84" stroke="#ff8297" stroke-width="10" stroke-linecap="round"/>', "#9beaff"),
        "music_on": ('<path d="M58 94V23L108 14V82" fill="none" stroke="#fff1a4" stroke-width="9" stroke-linecap="round"/><path d="M58 41L108 31" stroke="#66dcff" stroke-width="8"/><ellipse cx="38" cy="98" rx="21" ry="14" fill="#66dcff"/><ellipse cx="88" cy="86" rx="21" ry="14" fill="#66dcff"/>', "#66dcff"),
        "music_off": ('<path d="M58 94V23L108 14V82" fill="none" stroke="#fff1a4" stroke-width="9" stroke-linecap="round"/><path d="M58 41L108 31M20 20L112 112" stroke="#ff8297" stroke-width="9" stroke-linecap="round"/>', "#66dcff"),
        "spin": ('<path d="M103 44A44 44 0 0 0 28 35L16 49M16 49L16 22M16 49L43 48M25 84A44 44 0 0 0 100 93L112 79M112 79V106M112 79L85 80" fill="none" stroke="#ffe27f" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/><circle cx="64" cy="64" r="14" fill="#6ddfff" stroke="#fff" stroke-width="5"/>', "#ffe27f"),
        "piggy": ('<path d="M22 58Q21 33 53 29L91 36Q110 48 107 82Q102 107 74 107H43Q18 100 22 58Z" fill="#ff9db7" stroke="#fff0f4" stroke-width="7"/><path d="M43 29L37 13L57 29M83 33L99 18L96 42" fill="#ff9db7" stroke="#fff0f4" stroke-width="7"/><ellipse cx="100" cy="67" rx="17" ry="13" fill="#ffd4df" stroke="#fff" stroke-width="5"/><circle cx="81" cy="52" r="5" fill="#4b3151"/>', "#ff9db7"),
        "shop": ('<path d="M18 52H110V113H18Z" fill="#6fd5ff" stroke="#fff" stroke-width="7"/><path d="M12 49L25 17H103L116 49Q112 67 96 61Q80 69 64 60Q48 69 32 61Q16 68 12 49Z" fill="#ffcf63" stroke="#fff2c0" stroke-width="7"/><rect x="48" y="74" width="31" height="39" rx="5" fill="#164c82" stroke="#b8edff" stroke-width="5"/>', "#ffcf63"),
        "gift": ('<rect x="15" y="47" width="98" height="69" rx="9" fill="#ff7e9e" stroke="#fff" stroke-width="7"/><rect x="9" y="35" width="110" height="24" rx="9" fill="#ffe17e" stroke="#fff" stroke-width="6"/><path d="M58 35Q15 28 29 10Q50 -2 64 35Q77 -3 99 10Q112 27 70 35" fill="#77dcff" stroke="#fff" stroke-width="6"/><path d="M64 36V115" stroke="#fff6c8" stroke-width="11"/>', "#ff7e9e"),
        "lock": ('<rect x="20" y="51" width="88" height="68" rx="15" fill="#8ca2b8" stroke="#e8f3ff" stroke-width="7"/><path d="M38 52V38A26 26 0 0 1 90 38V52" fill="none" stroke="#e8f3ff" stroke-width="12"/><circle cx="64" cy="81" r="9" fill="#223e5c"/>', "#8ca2b8"),
        "play": ('<path d="M34 15L111 64L34 113Z" fill="#7ce7ff" stroke="#fff" stroke-width="9" stroke-linejoin="round"/>', "#7ce7ff"),
        "close": ('<circle cx="64" cy="64" r="54" fill="#ff7287" stroke="#fff" stroke-width="8"/><path d="M42 42L86 86M86 42L42 86" stroke="#fff" stroke-width="13" stroke-linecap="round"/>', "#ff7287"),
        "events": ('<rect x="16" y="25" width="96" height="88" rx="13" fill="#6ccfff" stroke="#fff" stroke-width="7"/><path d="M16 49H112M39 15V36M88 15V36" stroke="#fff" stroke-width="8" stroke-linecap="round"/><path d="M36 70L52 85L91 61" stroke="#fff2a3" stroke-width="9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>', "#6ccfff")
    }
    for name, (mark, tint) in icon_marks.items():
        write(f"ui/icons/{name}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="60" fill="#123d70" stroke="#d9f8ff" stroke-width="5"/>{mark}</svg>""")

    booster_marks = {
        "bomb": '<circle cx="62" cy="70" r="47" fill="url(#g)" stroke="#fff" stroke-width="7"/><path d="M77 27Q78 11 98 11" fill="none" stroke="#ffe9a6" stroke-width="10" stroke-linecap="round"/><path d="M101 8L109 1M101 17L117 17M91 4L90 -2" stroke="#fff3ae" stroke-width="7" stroke-linecap="round"/><ellipse cx="44" cy="43" rx="17" ry="12" fill="#fff" opacity=".65"/>',
        "fireball": '<path d="M64 8Q94 43 85 63Q120 45 108 91Q96 123 59 119Q16 116 18 76Q21 46 49 29Q43 59 60 66Q77 50 64 8Z" fill="#ff7b42" stroke="#fff2b6" stroke-width="7"/><path d="M62 52Q81 79 68 104Q41 106 40 82Q42 67 62 52Z" fill="#fff4a1"/>',
        "rainbow": '<path d="M18 104A46 46 0 0 1 110 104" fill="none" stroke="#ff6474" stroke-width="15"/><path d="M31 104A33 33 0 0 1 97 104" fill="none" stroke="#ffcf62" stroke-width="13"/><path d="M44 104A20 20 0 0 1 84 104" fill="none" stroke="#72e4be" stroke-width="12"/>',
        "swap": '<path d="M20 42H99L82 24M99 42L82 59M108 86H29L46 69M29 86L46 103" fill="none" stroke="#7de5ff" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>',
        "extra_moves": '<circle cx="64" cy="64" r="49" fill="#236ea5" stroke="#e8fbff" stroke-width="8"/><path d="M64 29V65L89 81" stroke="#fff2a2" stroke-width="10" stroke-linecap="round" fill="none"/><path d="M28 16L37 29L48 17M95 104L105 91L117 103" fill="none" stroke="#73e2ff" stroke-width="9" stroke-linecap="round"/>',
        "continue": '<path d="M64 108L19 64C-5 37 27 8 51 29L64 41L77 29C101 8 133 37 109 64Z" fill="#ff7595" stroke="#fff" stroke-width="7"/><path d="M55 42L38 64L57 64L51 88L91 53L70 53L78 42Z" fill="#fff1a0" stroke="#d74e76" stroke-width="4"/>'
    }
    for name, mark in booster_marks.items():
        write(f"boosters/{name}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs><radialGradient id="g" cx="28%" cy="20%"><stop stop-color="#fff8d7"/><stop offset=".25" stop-color="#ffca56"/><stop offset="1" stop-color="#d94b3e"/></radialGradient></defs>{mark}</svg>""")

    node_marks = {
        "locked": ('<rect x="36" y="56" width="56" height="43" rx="10" fill="#d5e1ee"/><path d="M47 56V44A17 17 0 0 1 81 44V56" fill="none" stroke="#d5e1ee" stroke-width="9"/>', "#526a86"),
        "current": ('<path d="M64 28L73 53L100 55L79 72L86 98L64 83L42 98L49 72L28 55L55 53Z" fill="#fff0a4"/>', "#e9b448"),
        "done": ('<path d="M34 65L55 85L96 42" fill="none" stroke="#fff6b5" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>', "#2cb99e"),
        "star": ('<path d="M64 10L78 46L117 50L87 75L97 114L64 92L31 114L41 75L11 50L50 46Z" fill="#ffe178" stroke="#fff4bb" stroke-width="6"/>', "#175b86")
    }
    for name, (mark, tint) in node_marks.items():
        write(f"map_nodes/{name}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="55" fill="{tint}" stroke="#dffaff" stroke-width="8"/>{mark}</svg>""")

    effect_marks = {
        "spark": '<path d="M64 5L75 48L119 64L75 77L64 123L51 77L8 64L51 48Z" fill="#fff2a8"/><circle cx="64" cy="64" r="13" fill="#fff"/>',
        "ring": '<circle cx="64" cy="64" r="48" fill="none" stroke="#8cecff" stroke-width="12"/><circle cx="64" cy="64" r="34" fill="none" stroke="#fff" stroke-width="4"/>',
        "shard": '<path d="M64 7L110 96L53 119L18 47Z" fill="#9cecff" stroke="#fff" stroke-width="6"/><path d="M64 7L53 119L18 47Z" fill="#fff" opacity=".4"/>',
        "bubble_fragment": '<path d="M20 65A45 45 0 0 1 84 22L65 66L111 85A45 45 0 0 1 20 65Z" fill="#63dfff" fill-opacity=".65" stroke="#fff" stroke-width="7"/>',
        "coin_glint": '<path d="M64 5L76 49L120 64L76 77L64 123L51 77L8 64L51 49Z" fill="#fff3a8"/>',
        "star_particle": '<path d="M64 7L78 47L120 49L88 76L99 117L64 94L29 117L40 76L8 49L50 47Z" fill="#ffe27a" stroke="#fff" stroke-width="6"/>',
        "soft_dot": '<defs><radialGradient id="d"><stop stop-color="#fff"/><stop offset=".35" stop-color="#a9efff" stop-opacity=".9"/><stop offset="1" stop-color="#8edfff" stop-opacity="0"/></radialGradient></defs><circle cx="64" cy="64" r="60" fill="url(#d)"/>'
    }
    for name, mark in effect_marks.items():
        write(f"effects/{name}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{mark}</svg>""")

    chrome = {
        "button_primary": ("#238ec7", "#13578f", "#d6faff"),
        "button_secondary": ("#4c79a8", "#183961", "#a6dff4"),
        "pill_coins": ("#235c88", "#102b55", "#ffe38b"),
        "pill_lives": ("#235c88", "#102b55", "#ffafc6"),
        "pill_level": ("#235c88", "#102b55", "#a7eaff"),
        "popup_ribbon": ("#f5c451", "#b36d24", "#fff1b8"),
        "progress_bar": ("#23557d", "#081d41", "#d4f6ff")
    }
    for name, (inner, outer, edge) in chrome.items():
        write(f"ui/{name}.svg", f"""<svg xmlns="http://www.w3.org/2000/svg" width="512" height="160" viewBox="0 0 512 160"><rect x="8" y="8" width="496" height="144" rx="48" fill="{outer}" stroke="{edge}" stroke-width="9"/><rect x="22" y="22" width="468" height="116" rx="40" fill="{inner}"/><path d="M48 38H464" stroke="#fff" stroke-width="5" opacity=".25" stroke-linecap="round"/></svg>""")

    print("Created 64 original SVG assets (24 base + 40 UI, booster, map and effect assets) under", ROOT)

if __name__ == "__main__":
    main()
