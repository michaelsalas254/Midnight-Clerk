# Late Night Pawn

A 2D tactile appraisal simulator for Godot 4 (built on 4.3), in the spirit of *Papers, Please*.
A customer puts an item on your counter. Inspect it with your tools, then **Offer**, **Reject**, or hit the **Silent Alarm**.

**Done so far:** Phase 1 (item inspection) and Phase 2 (customer dialogue state machine).

## Running

1. Open the folder in Godot 4.3 or newer and press **F5**.
2. Optional: pull the real Higgsfield art (see [Art assets](#art-assets)).

**Controls:** click and drag tools. The UV light and magnifier work while you hold them over an item. Drop the acid bottle on an item to test its gold. Click the dialogue text to skip a line that's still typing.

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
  resources/customer.gd        # Customer Resource (who, portrait, lines, item)
  dialogue/customer_dialogue.gd  # Customer state machine + portrait slide
  dialogue/typewriter.gd       # Typewriter RichTextLabel (DialogueText)
  desk/desk.gd                 # Mouse pickup: finds the topmost draggable
  desk/draggable.gd            # Drag behaviour (lift, shadow, clamping)
  desk/pawn_item_node.gd       # Item reactions + public tool API
  tools/inspection_tool.gd     # Base tool: sensor overlap -> begin/end hooks
  tools/uv_blacklight.gd
  tools/magnifying_glass.gd
  tools/acid_test.gd
data/items/*.tres              # Item definitions, made in the Inspector
data/customers/*.tres          # Customers (each references one item)
assets/                        # Art (Higgsfield-generated)
tests/test_uv_flow.gd          # Headless smoke test: inspection + dialogue
tools/                         # Asset fetch + placeholder scripts
```

## 1. Node tree: `Main.tscn`

```
Main (Node2D)                          main.gd
├── ShopView (Control)                 top half, 1920×540, mouse_filter = Ignore
│   ├── Backdrop (TextureRect)         shop interior through the glass
│   ├── CustomerPortrait (TextureRect) %CustomerPortrait, slides in/out
│   ├── DialogueBox (Panel)
│   │   ├── SpeakerName (Label)        %SpeakerName                              [Phase 2]
│   │   └── DialogueText (RichTextLabel)  %DialogueText, typewriter.gd, click = skip  [Phase 2]
│   ├── CustomerDialogue (Node)        %CustomerDialogue, customer_dialogue.gd   [Phase 2]
│   │                                  exports: portrait, text, speaker_label
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

**To add an item without writing code:** in the FileSystem dock, right-click `data/items`, choose **New Resource… → PawnItem**, and fill in the fields. Then give it to a customer (next section).

## 2b. Customer data: `Customer` Resource

`scripts/resources/customer.gd`. The item queue is now a **customer queue**: `Main.customer_queue: Array[Customer]`, and each customer brings one `PawnItem`.

| Field | Meaning |
|---|---|
| `customer_name`, `portrait`, `item` | Who they are, their art, and the `PawnItem` they bring |
| `nervousness` (0–1) | Starting nerves. Higher means faster speech. Above 0.6, lines use `[shake]` and the portrait trembles |
| `nervousness_per_trait` | How much nervousness rises each time you reveal a trait (runtime copy only; the resource isn't modified) |
| `greeting_lines` | First words. The item's `claimed_description` is appended |
| `trait_reactions` | `trait_id` → line, e.g. `"fake_signature"`, `"fake_gold"` |
| `default_trait_reaction` | Used for any trait not in `trait_reactions` |
| `haggle_lines` | Said before accepting a lowball offer (below 60% of claimed value) |
| `accept_lines` / `refuse_lines` | Deal accepted / offer too insulting |
| `leave_lines` / `alarm_lines` | You pressed Reject / Silent Alarm |

Each line is picked at random from its list, and every list has a built-in fallback if it's empty. Lines may use `{name}`, `{item}`, and `{offer}`.

**To add a customer:** right-click `data/customers`, choose **New Resource… → Customer**, fill it in, and drag it into **Main → Customer Queue**.

## 2c. Dialogue state machine: `CustomerDialogue`

```
IDLE ─present()─▶ ARRIVING ─slide in─▶ GREETING ─line typed─▶ WAITING ◀──line typed── REACTING
                  (queues reveals)                               └──react_to_trait()──▶┘
                                        (a reveal during GREETING also jumps to REACTING)

From GREETING / WAITING / REACTING:
  negotiate(offer, accepted)  ─▶ NEGOTIATING ─(haggle line)─▶ LEAVING
  send_away(REJECTED | ALARM) ─────────────────────────────▶ LEAVING

LEAVING: farewell line → read pause → portrait slides out → IDLE, emits customer_left
```

- **Legal moves only.** `TRANSITIONS` lists every allowed edge, and `_set_state()` refuses anything else with a `push_error`. Public calls that don't fit the current state are ignored on purpose. For example, a reveal during LEAVING is ignored, and a reveal during ARRIVING is queued until the customer finishes the greeting.
- **Stale callbacks can't fire.** Every step (typing a line, a pause, a slide) bumps a step counter. A completion callback only runs if no newer step has started, so interrupting a greeting with a reveal is safe.
- **Inspection is never blocked.** The dialogue only listens. It doesn't gate tools or items.
- **Main owns the outcome, dialogue owns the words.** Main still decides whether an offer is accepted, and handles cash and the police payout exactly as in Phase 1. It then tells the dialogue what happened.

```
Main ──present(customer)──────────────────▶ CustomerDialogue ──customer_arrived──▶ Main: spawn item, enable buttons
PawnItemNode.trait_revealed ─▶ Main ──react_to_trait(id)──▶
Offer button ─▶ Main ──negotiate(offer, accepted)──▶
Reject / Alarm ─▶ Main ──send_away(reason)──▶
                                           CustomerDialogue ──customer_left──▶ Main: free item, next customer
```

`Typewriter` (on DialogueText) is generic. `type_line(bbcode, cps)` reveals the line with `visible_characters`, pauses briefly after punctuation, and emits `line_finished`. It also emits `character_typed`, a hook for typing blips. Clicking the text calls `skip()`.

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

All art was generated with **Higgsfield** (GPT Image 2.5, transparent backgrounds for sprites). The UV-revealed watch was made from the normal watch as a reference image, so the two line up when the texture swaps. The Phase 2 portraits (`customer_hoodie.png`, `customer_overcoat.png`) were generated with the leather-jacket portrait as a style reference, then run through Higgsfield's background remover.

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

This sends real mouse events through the viewport and plays a whole shift (32 checks):

- **Inspection:** it picks up the UV light and drags it onto the fake watch. It checks that the texture swaps, the trait is revealed, the texture reverts on drop, and the acid test catches the fake gold.
- **Dialogue:** it checks the portrait arrival, that actions stay locked until the customer arrives, and that the greeting types out and a real click skips it. It also checks trait-specific reactions and rising nervousness, Reject → LEAVING → next customer, a lowball offer (haggle, then accept), and Silent Alarm, ending with the end-of-shift announcement.

## Roadmap (one feature at a time, committed between each)

- [x] Phase 1: PawnItem resource, drag and drop, UV / magnifier / acid inspection
- [x] Phase 2: Customer resource + dialogue state machine (typewriter, portrait slide)
- [ ] Cash register and haggling
- [ ] Police / Silent Alarm consequences
- [ ] Scale tool (uses `expected_weight` vs `actual_weight`)
