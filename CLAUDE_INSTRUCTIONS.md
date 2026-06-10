# Ladle · Kitchen

A kitchen room: recipes, weekly menu, shopping list, fridge inventory, and cooking logs — for you and your Claude.

**Project ID:** `YOUR_PROJECT_ID`

## Tables

- **recipes** — name, steps (markdown, minute-precise), difficulty (1-3), meal_slot ('morning'/'evening'/'any'), tags TEXT[], times_cooked (auto-incremented by trigger)
- **weekly_menu** — menu_date, slot ('morning'/'evening'), recipe_id (FK, nullable), custom_label (for eating out etc.), is_special, done. UNIQUE(menu_date, slot)
- **shopping_items** — name, kind ('fresh'/'staple'/'oneoff'), checked, note
- **inventory** — name, location ('fridge'/'freezer'/'pantry'), added_on, expires_hint, is_used
- **cook_logs** — log_date, recipe_id (nullable), outcome ('smooth'/'ok'/'flop'), note, photo_url, lux_reply

## Daily routine

1. Check new cook_logs without lux_reply; write a short reply (1-2 sentences, warm, concrete — react to the outcome and note, not generic praise):
```sql
SELECT id, log_date, recipe_id, outcome, note FROM cook_logs WHERE lux_reply IS NULL ORDER BY id;
UPDATE cook_logs SET lux_reply = '...' WHERE id = X;
```
2. Check inventory for items that may need attention (expires_hint, old added_on); mention them to the user if relevant.
3. When the user names a dish they want to eat: search the web for a recipe, rewrite it as foolproof steps (see Data Format), respect the user's dietary preferences, then INSERT into recipes.

## Read

```sql
SELECT * FROM weekly_menu WHERE menu_date BETWEEN '2026-06-08' AND '2026-06-14' ORDER BY menu_date, slot;
SELECT name, difficulty, times_cooked FROM recipes ORDER BY times_cooked DESC;
SELECT name, location, expires_hint FROM inventory WHERE NOT is_used;
```

## Write

```sql
-- Add a recipe (example)
INSERT INTO recipes (name, steps, difficulty, meal_slot, tags) VALUES
('番茄蛋花湯', E'1. 番茄 1 顆切塊,下鍋炒出汁\n2. 加 2 碗水煮開\n3. 蛋 1 顆打散,轉圈淋入\n4. 鹽一撮 + 香油幾滴', 1, 'evening', '{"快手","湯"}');

-- Plan a meal
INSERT INTO weekly_menu (menu_date, slot, recipe_id) VALUES ('2026-06-15', 'evening', 3);

-- Reply to a cook log
UPDATE cook_logs SET lux_reply = '第一次煎魚就沒濺油,擦乾這步你做對了' WHERE id = 5;
```

## Data Format

- **recipes.steps**: numbered lines, one action per line, minute-precise ("煮 3 分鐘" not "煮至熟"), no vague words like 適量/少許 — give starting amounts ("醬油 1 勺")
- **recipes.difficulty**: 1 = cannot fail, 2 = needs a little feel, 3 = advanced
- **cook_logs.lux_reply**: 1-2 sentences, specific to what happened
- Steps must respect dietary preferences recorded by the user (allergies, dislikes)

## Behavior

- When rewriting found recipes, always adapt: remove disliked ingredients, scale to 1 person, simplify tools to what the user owns
- Never auto-fill weekly_menu without being asked; suggest, then write after confirmation
- Keep replies in cook_logs encouraging on 'flop' outcomes — name one concrete fix for next time