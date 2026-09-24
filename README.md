# Late Night Pawn

A 2D tactile appraisal simulator for Godot 4 (built on 4.3), in the spirit of *Papers, Please*.
A customer puts an item on your counter. Inspect it with your tools, then **Offer**, **Reject**, or hit the **Silent Alarm**.

This is **Phase 1 (MVP)**. The focus is the item inspection system.

## Running

1. Open the folder in Godot 4.3 or newer and press **F5**.
2. Optional: pull the real Higgsfield art (see [Art assets](#art-assets)).

**Controls:** click and drag tools. The UV light and magnifier work while you hold them over an item. Drop the acid bottle on an item to test its gold.

## Project layout

```
project.godot
scenes/
  main.tscn                    # The single game screen
  desk/pawn_item_node.tscn     # On-desk item (driven by a PawnItem resource)
  tools/uv_blacklight.tscn     # Inspection tools
  tools/magnifying_glass.tscn
  tools/acid_test.tscn
scripts/
  main.gd                      # Customer queue, action buttons, signal routing
  resources/pawn_item.gd       # PawnItem Resource (item data)
  desk/desk.gd                 # Mouse pickup: finds the topmost draggable
  desk/draggable.gd            # Drag behaviour (lift, shadow, clamping)
  desk/pawn_item_node.gd       # Item reactions + public tool API
  tools/inspection_tool.gd     # Base tool: sensor overlap -> begin/end hooks
  tools/uv_blacklight.gd
  tools/magnifying_glass.gd
  tools/acid_test.gd
data/items/*.tres              # Item definitions, made in the Inspector
assets/                        # Art (Higgsfield-generated)
tests/test_uv_flow.gd          # Headless drag + UV + acid smoke test
tools/                         # Asset fetch + placeholder scripts
```

## 1. Node tree: `Main.tscn`

```
Main (Node2D)                          main.gd
├── ShopView (Control)                 top half, 1920×540, mouse_filter = Ignore
│   ├── Backdrop (TextureRect)         shop interior through the glass
│   ├── CustomerPortrait (TextureRect) %CustomerPortrait
│   ├── DialogueBox (Panel)
│   │   └── DialogueText (RichTextLabel)  %DialogueText, BBCode
│   └── CounterEdge (ColorRect)        divides the shop from the desk
├── DeskSurface (TextureRect)          bottom half, mouse_filter = Ignore
├── Desk (Node2D)                      desk.gd, handles pickup
│   ├── ItemSpawn (Marker2D)           %ItemSpawn
│   ├── Items (Node2D)                 %Items, PawnItemNode instances go here
│   └── Tools (Node2D)                 %Tools
│       ├── Magnifier   (Area2D)       magnifying_glass.tscn
│       ├── UVLight     (Area2D)       uv_blacklight.tscn
│       └── AcidTest    (Area2D)       acid_test.tscn
└── HUD (CanvasLayer)
    └── ActionPanel (PanelContainer)
        └── VBox
            ├── CashLabel, LogTitle
            ├── InspectionLog (RichTextLabel)
            ├── OfferRow: OfferInput (SpinBox) + OfferButton
            ├── RejectButton
            └── AlarmButton
```

Each draggable scene (tool or item) looks like this:

```
Tool (Area2D, layer 1 "tools")     draggable.gd subclass
├── Shadow (Sprite2D)              grows its offset when lifted
├── Sprite (Sprite2D)
├── Shape (CollisionShape2D)       grab area, sized from the texture
└── Sensor (Area2D, mask 2 "items")   the tool's working end
    ├── SensorShape (CollisionShape2D)
    └── Beam (Sprite2D, additive)  UV light only
```

### Why the desk uses Node2D + Area2D and the rest uses Control

The game uses both, each where it fits best:

- **Control nodes for the shop view and HUD.** Text, panels, buttons, and a SpinBox need layout, themes, focus, and button signals. Controls give you those for free.
- **Node2D / Area2D for everything on the desk.** The main question on the desk is "is this tool over that item?". `Area2D.area_entered` and `area_exited` answer it directly, even when the item moves under a tool you're holding still. Controls have no overlap events, so you'd have to compare rectangles every frame. Area2D also gives you:
  - **Arbitrary shapes:** the UV beam is a circle, and the magnifier lens can be smaller than its sprite.
  - **Collision layers:** tools and items sit on separate layers, so a sensor only detects items.
  - **Free rotation and scaling:** the "lift" effect doesn't disturb any layout.
  - **Room to grow:** physics toys later, like an item scale or sliding cash, need no redesign.
- **Pickup is centralized in `Desk`.** It runs one point query in `_unhandled_input` and grabs the topmost draggable (highest `z_index`, then latest in the tree). Overlapping objects never both grab one click, and HUD buttons still get their clicks first.
- **Positions come from the input events themselves**, not from polling the cursor. `Input.use_accumulated_input = false` passes every motion event through, so dragging has no frame of lag.

## 2. Item data: `PawnItem` Resource

`scripts/resources/pawn_item.gd` holds these fields:

| Field | Meaning |
|---|---|
| `item_name`, `claimed_description` | Name, and what the customer says about it |
| `default_sprite`, `uv_revealed_sprite`, `desk_size` | Artwork, and its size on the desk |
| `expected_weight`, `actual_weight` | For the scale tool (later phase) |
| `true_value`, `counterfeit_value` | Payout depending on authenticity |
| `has_fake_signature` | Revealed by the UV light |
| `claims_gold`, `is_real_gold` | Checked by the acid test |
| `is_stolen` | Silent Alarm hook |
| `magnifier_note` | What the magnifier shows |

**To add an item without writing code:** in the FileSystem dock, right-click `data/items`, choose **New Resource… → PawnItem**, fill in the fields, and drag the new `.tres` into **Main → Item Queue**.

## 3–4. Drag and drop, and inspection signals

```
Desk._unhandled_input ──pick_up(point)──▶ Draggable (follows motion events in _input)
                                              │ picked_up / dropped
                                              ▼
InspectionTool ── Sensor.area_entered/exited ──▶ _begin_inspecting(item) / _end_inspecting(item)
      │                                                     │
      │ inspection_started / inspection_ended               │ public API only
      ▼                                                     ▼
    Main (sfx hooks)                  PawnItemNode.set_uv_exposure(true/false)
                                      PawnItemNode.inspect_magnified()
                                      PawnItemNode.apply_acid_test()
                                                            │
                                     trait_revealed / inspected signals
                                                            ▼
                                            Main ──▶ InspectionLog
```

The **UV Blacklight** never touches item data. It calls `item.set_uv_exposure(true)` when its beam covers an item while held, and `false` when it leaves or is dropped. The item then does the rest:

- If `has_fake_signature` is true, it swaps its texture to `uv_revealed_sprite` and emits `trait_revealed(&"fake_signature")`, once per item.
- Otherwise, it tints violet and reports that nothing fluoresces.
- When the light leaves, the default sprite comes back.

Exposure is reference-counted, so a second UV light later won't break it.

## Art assets

All art was generated with **Higgsfield** (GPT Image 2.5, transparent backgrounds for sprites). The UV-revealed watch was made from the normal watch as a reference image, so the two line up when the texture swaps.

The repo ships **flat placeholder PNGs** at the same paths. To pull the real art:

```bash
./tools/fetch_higgsfield_assets.sh
```

To regenerate the placeholders after deleting a file:

```bash
godot --headless --script res://tools/make_placeholders.gd
```

## Tests

```bash
godot --headless --path . --script res://tests/test_uv_flow.gd
```

This sends real mouse events through the viewport. It picks up the UV light, drags it onto the fake watch, and checks four things: the texture swaps, the trait is revealed, the texture reverts on drop, and the acid test catches the fake gold.

## Roadmap (one feature at a time, committed between each)

- [x] Phase 1: PawnItem resource, drag and drop, UV / magnifier / acid inspection
- [ ] Customer dialogue state machine
- [ ] Cash register and haggling
- [ ] Police / Silent Alarm consequences
- [ ] Scale tool (uses `expected_weight` vs `actual_weight`)
