-- Ladle · Kitchen room setup
-- Tables: recipes, weekly_menu, shopping_items, inventory, cook_logs

-- 食譜庫
CREATE TABLE recipes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,                      -- 菜名
  steps TEXT NOT NULL,                     -- 傻瓜步驟(markdown,精確到分鐘)
  difficulty INT DEFAULT 1,                -- 1-3 星
  meal_slot TEXT DEFAULT 'any',            -- 'morning'(11:00 順口) / 'evening'(21:00 正餐) / 'any'
  tags TEXT[] DEFAULT '{}',                -- 如 {'一鍋流','電飯煲','料理包'}
  times_cooked INT DEFAULT 0,              -- 做過幾次(cook_logs 寫入時自動 +1)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 本週菜單
CREATE TABLE weekly_menu (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  menu_date DATE NOT NULL,
  slot TEXT NOT NULL,                      -- 'morning' / 'evening'
  recipe_id BIGINT REFERENCES recipes(id),
  custom_label TEXT,                       -- 外食/自由發揮等非食譜項
  is_special BOOL DEFAULT FALSE,           -- 升級餐/外食標記
  done BOOL DEFAULT FALSE,
  UNIQUE (menu_date, slot)
);

-- 採購清單
CREATE TABLE shopping_items (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT DEFAULT 'fresh',               -- 'fresh' 每週生鮮 / 'staple' 囤貨 / 'oneoff' 一次性
  checked BOOL DEFAULT FALSE,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 冰箱庫存
CREATE TABLE inventory (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,                      -- 如 '醃雞腿 ×3 袋'
  location TEXT DEFAULT 'fridge',          -- 'fridge' / 'freezer' / 'pantry'
  added_on DATE DEFAULT CURRENT_DATE,
  expires_hint TEXT,                       -- 如 '一週內吃完'
  is_used BOOL DEFAULT FALSE
);

-- 做飯日誌(按日期聚合)
CREATE TABLE cook_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  log_date DATE DEFAULT CURRENT_DATE,
  recipe_id BIGINT REFERENCES recipes(id), -- 可空:外食/自由發揮
  outcome TEXT DEFAULT 'ok',               -- 'smooth' 順利 / 'ok' 還行 / 'flop' 翻車
  note TEXT,                               -- 翻車原因/心得
  photo_url TEXT,                          -- Storage public URL
  lux_reply TEXT,                          -- Lux 的回應
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 做飯日誌寫入時自動更新食譜次數
CREATE OR REPLACE FUNCTION bump_times_cooked() RETURNS TRIGGER AS $fn$
BEGIN
  IF NEW.recipe_id IS NOT NULL THEN
    UPDATE recipes SET times_cooked = times_cooked + 1 WHERE id = NEW.recipe_id;
  END IF;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bump_times_cooked
AFTER INSERT ON cook_logs
FOR EACH ROW EXECUTE FUNCTION bump_times_cooked();

-- RLS:個人工具全開放
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_menu ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE cook_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY open_recipes ON recipes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY open_menu ON weekly_menu FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY open_shopping ON shopping_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY open_inventory ON inventory FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY open_logs ON cook_logs FOR ALL USING (true) WITH CHECK (true);

-- Storage:建 public bucket 'ladle-photos'(在 Dashboard 操作或:)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('ladle-photos', 'ladle-photos', true);
