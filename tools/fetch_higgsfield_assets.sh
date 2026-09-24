#!/usr/bin/env bash
# Downloads the Higgsfield-generated art (GPT Image 2.5) into assets/,
# replacing the placeholder PNGs. Run from the project root.
set -euo pipefail
CDN="https://d8j0ntlcm91z4.cloudfront.net/user_3J1pn4LpcLQ61ULxe85wHPROtwg"
declare -A ASSETS=(
  [assets/backgrounds/desk_surface.png]=hf_20260924_025535_765699b7-56f2-4af5-a891-3431b173d711.png
  [assets/backgrounds/shop_window.png]=hf_20260924_025535_3dd26d2f-b2fb-4d71-b63c-0ae9e9ef07e4.png
  [assets/characters/customer_leather_jacket.png]=hf_20260924_025536_ee2ea295-2f01-41e1-b811-32a9c1c90e96.png
  [assets/characters/customer_hoodie.png]=hf_20260924_031315_002dc31a-7c3a-42a6-80ee-7a619e88b47e.png
  [assets/characters/customer_overcoat.png]=hf_20260924_031318_46a11328-b795-4245-90a0-6a25b5f5d451.png
  [assets/items/gold_watch.png]=hf_20260924_025535_5011be86-3613-4246-8a1a-4fbd8cd14260.png
  [assets/items/gold_watch_uv.png]=hf_20260924_025648_66ddd3fb-f6e8-40fa-b01e-9d55979d45f2.png
  [assets/items/gold_chain.png]=hf_20260924_025535_08c8abd5-772e-4bcf-b223-f268c0988d53.png
  [assets/tools/magnifying_glass.png]=hf_20260924_025535_80b2b7d6-4ced-4171-a441-5c7fdcb3eaa9.png
  [assets/tools/uv_blacklight.png]=hf_20260924_025535_4b8aa651-380d-436a-a3a7-6b8a43ca3d43.png
  [assets/tools/acid_bottle.png]=hf_20260924_025535_16be257a-3ff7-489a-8bc4-738d9f7e650f.png
)
for dest in "${!ASSETS[@]}"; do
  mkdir -p "$(dirname "$dest")"
  echo "-> $dest"
  curl -fsSL -o "$dest" "$CDN/${ASSETS[$dest]}"
done
echo "Done. Re-open the project in Godot to re-import."
