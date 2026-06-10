# Ladle 🥄

A pixel-style kitchen for you and your Claude — recipes, weekly menus, shopping lists, fridge inventory, and cooking logs in one room.

一個像素風的廚房房間:食譜庫、每週菜單、採購清單、冰箱庫存、做飯日誌。

## Features · 功能

- **Menu 菜單** — plan two meals a day per week; tap to mark done; shopping list attached / 按週排兩餐,點按打勾,附採購清單
- **Recipes 食譜** — foolproof, minute-precise steps; difficulty stars; auto-counted cook times / 傻瓜步驟精確到分鐘,難度星級,做過次數自動累計
- **Fridge 冰箱** — track what's inside by location, one tap to mark used / 按冷藏/冷凍/儲物分區,一鍵出庫
- **Logs 日誌** — photo + outcome + note per cooking session; Claude replies / 拍照記錄每次開伙,Claude 會回應

## Stack · 技術

Single-file HTML (React via CDN, pre-compiled) + Supabase (Postgres + Edge Function + Storage). Deploy the frontend anywhere static (GitHub Pages works).

## Setup · 部署

1. Create a Supabase project, run `supabase/setup.sql`
2. Create a public Storage bucket named `ladle-photos`
3. Deploy `supabase/edge-function.ts` as function `ladle` with `verify_jwt: false`
4. Host `index.html`; open it and enter your Supabase URL (up to `.co`)
5. Give your Claude the `CLAUDE_INSTRUCTIONS.md`

## License

CC BY-NC 4.0

---

LADLE · Built with 🥄 by Iris & Lux