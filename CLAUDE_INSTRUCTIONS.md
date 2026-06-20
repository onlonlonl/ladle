# Ladle · Kitchen

A kitchen room: recipes, weekly menu, shopping list, fridge inventory, and cooking logs — for you and your Claude.

**Project ID:** `YOUR_PROJECT_ID`

## Tables

- **recipes** — name, steps (markdown, minute-precise), difficulty (1-3), meal_slot ('morning'/'evening'/'any'), tags TEXT[], times_cooked (auto-incremented by trigger on cook_logs insert)
- **weekly_menu** — menu_date, slot ('morning'/'evening'), recipe_id (FK, nullable), custom_label (for eating out etc.), is_special, done. UNIQUE(menu_date, slot)
- **shopping_items** — name, kind ('fresh'/'staple'/'oneoff'), checked, note
- **inventory** — name, location ('fridge'/'freezer'/'pantry'), added_on, expires_hint, is_used
- **cook_logs** — log_date, recipe_id (nullable), outcome ('smooth'/'ok'/'flop'), note, photo_url, lux_reply

## Auto-flow: Shopping → Inventory

When a shopping item is checked in the frontend:
- **fresh** → automatically creates an inventory record with location = 'fridge'
- **staple** → automatically creates an inventory record with location = 'pantry'
- **oneoff** → just checked, no inventory record (tools, equipment, etc.)

Claude should NOT manually insert inventory for items the user has already checked in shopping — the frontend handles this. Only insert inventory for items the user explicitly asks to track outside of shopping (e.g. "I have leftover chicken from yesterday").

## Edge Function

All resources support GET / POST / PATCH via `/functions/v1/ladle/{resource}/{id}`:
- `/recipes`, `/menu`, `/shopping`, `/inventory`, `/logs`, `/photo`

## Daily routine

1. Check new cook_logs without lux_reply; write a short reply (1-2 sentences, warm, concrete — react to the outcome and note, not generic praise):
```sql
SELECT id, log_date, recipe_id, outcome, note FROM cook_logs WHERE lux_reply IS NULL ORDER BY id;
UPDATE cook_logs SET lux_reply = '...' WHERE id = X;
```
2. Check inventory for items that may need attention (old added_on, expires_hint); mention them to the user if relevant.
3. When the user names a dish they want to eat: search the web for a recipe, rewrite it as foolproof steps (see Data Format), respect dietary preferences, then INSERT into recipes.

## Dietary preferences

- No scallions/green onions (蔥)
- Mild spice OK, not too much
- Fish: only pomfret (鯧魚), no other fish
- Offal: only pork liver (豬肝), no others

## Read

```sql
SELECT * FROM weekly_menu WHERE menu_date BETWEEN '2026-06-23' AND '2026-06-29' ORDER BY menu_date, slot;
SELECT name, difficulty, times_cooked FROM recipes ORDER BY times_cooked DESC;
SELECT name, location, expires_hint FROM inventory WHERE NOT is_used;
SELECT name, checked, kind FROM shopping_items ORDER BY checked, kind;
```

## Write

```sql
-- Add a recipe
INSERT INTO recipes (name, steps, difficulty, meal_slot, tags) VALUES
('番茄蛋花湯', E'1. 番茄 1 顆切塊,下鍋炒出汁\n2. 加 2 碗水煮開\n3. 蛋 1 顆打散,轉圈淋入\n4. 鹽一撮 + 香油幾滴', 1, 'evening', '{"快手","湯"}');

-- Plan a meal
INSERT INTO weekly_menu (menu_date, slot, recipe_id) VALUES ('2026-06-25', 'evening', 3);

-- Reply to a cook log
UPDATE cook_logs SET lux_reply = 'first time pan-frying and no oil splatter — you nailed the drying step' WHERE id = 5;

-- Edit a recipe
UPDATE recipes SET steps = '...' WHERE id = 2;

-- Edit inventory
UPDATE inventory SET location = 'freezer', expires_hint = 'use within 2 weeks' WHERE id = 7;
```

## Data Format

- **recipes.steps**: numbered lines, one action per line, minute-precise ("煮 3 分鐘" not "煮至熟"), no vague words like 適量/少許 — give starting amounts ("醬油 1 勺"). Always adapt to dietary preferences above.
- **recipes.difficulty**: 1 = cannot fail, 2 = needs a little feel, 3 = advanced
- **cook_logs.lux_reply**: 1-2 sentences, specific to what happened. On 'flop', name one concrete fix for next time.

## Behavior

- When rewriting found recipes: remove disliked ingredients, scale to 1 person, simplify tools to what the user owns (induction stove + pot + pan, no oven)
- Never auto-fill weekly_menu without being asked; suggest, then write after confirmation
- All tables support PATCH — if the user asks to change anything, update directly, don't delete and re-create