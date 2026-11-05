# Home Assistant Blueprints: Write Once
Three small blueprints (two automation, one script) that show inputs, selectors, collapsible sections, `variables`, `trigger_variables`, and the action selector.

Companion to the article: [Home Assistant Blueprints: Reusable Automations](https://sumguy.com/home-assistant-blueprints/) on SumGuy's Ramblings.

## What it does
- `motion_light.yaml`: motion turns lights on, a wait timer turns them off. Optional "only when dark" and "active after" in a collapsed Extras section.
- `door_open_alert.yaml`: runs any actions you pick when a door stays open too long. Optional repeat at :00 and :30 of each hour while it is still open.
- `fade_lights_off.yaml` (script blueprint): dims lights in N steps, then turns them off.

## Prerequisites
- Home Assistant 2024.10.0 or newer (the blueprints use the plural `triggers:`/`conditions:`/`actions:` syntax)
- Written against the 2026.11 docs. The YAML parses and every key is a documented one, but the files were not run on a live instance. Test with a spare light first.

## How to install
### Option A: import by URL
1. Go to Settings > Automations & scenes > Blueprints.
2. Select Import blueprint.
3. Paste the GitHub URL of a blueprint file, select Preview, then Import blueprint.

### Option B: copy the files
```bash
cp -r blueprints/automation/sumguy /config/blueprints/automation/
cp -r blueprints/script/sumguy /config/blueprints/script/
```
Then reload automations (Developer tools > YAML > Reload automations) and reload scripts.

## How to use
Create automations from the UI (Blueprints page > pick one > Create automation), or in YAML. `automations.yaml` and `scripts.yaml` in this folder show the `use_blueprint:` form. Replace every entity ID with your own.

## Files
- `blueprints/automation/sumguy/motion_light.yaml`
- `blueprints/automation/sumguy/door_open_alert.yaml`
- `blueprints/script/sumguy/fade_lights_off.yaml`
- `automations.yaml`: example `use_blueprint:` instances
- `scripts.yaml`: example script instance
