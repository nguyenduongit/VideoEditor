-- ==============================================================================
-- TẠO CÁC BẢNG SUPABASE CÒN THIẾU CHO VIDEO EDITOR
-- Lưu ý: Các bảng audio_items, stock_items, text_presets, effect_presets,
-- adjustment_presets, animation_presets đã có sẵn trên Supabase của bạn.
-- Script này CHỈ tạo 3 bảng còn thiếu: sticker_presets, transition_presets, user_favorites.
-- ==============================================================================

-- 1. BẢNG STICKER PRESETS (Nhãn dán Vector SVG & Animated SVG)
CREATE TABLE IF NOT EXISTS public.sticker_presets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT DEFAULT ''::text,
    category TEXT NOT NULL,
    format TEXT NOT NULL DEFAULT 'svg',
    tags TEXT[] DEFAULT '{}'::text[],
    default_duration FLOAT8 DEFAULT 3.0,
    asset_path TEXT,
    system_symbol_fallback TEXT,
    config JSONB NOT NULL,
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.sticker_presets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'sticker_presets' AND policyname = 'Public select sticker_presets') THEN
        CREATE POLICY "Public select sticker_presets" ON public.sticker_presets FOR SELECT TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'sticker_presets' AND policyname = 'Public insert sticker_presets') THEN
        CREATE POLICY "Public insert sticker_presets" ON public.sticker_presets FOR INSERT TO public WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'sticker_presets' AND policyname = 'Public update sticker_presets') THEN
        CREATE POLICY "Public update sticker_presets" ON public.sticker_presets FOR UPDATE TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'sticker_presets' AND policyname = 'Public delete sticker_presets') THEN
        CREATE POLICY "Public delete sticker_presets" ON public.sticker_presets FOR DELETE TO public USING (true);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sticker_presets_category ON public.sticker_presets(category);
CREATE INDEX IF NOT EXISTS idx_sticker_presets_is_system ON public.sticker_presets(is_system);

-- 2. BẢNG TRANSITION PRESETS (Hiệu ứng chuyển cảnh Metal Shaders & JSON)
CREATE TABLE IF NOT EXISTS public.transition_presets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT DEFAULT ''::text,
    category TEXT NOT NULL,
    shader_type TEXT NOT NULL,
    tags TEXT[] DEFAULT '{}'::text[],
    default_duration FLOAT8 DEFAULT 1.0,
    icon_name TEXT,
    config JSONB NOT NULL,
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.transition_presets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'transition_presets' AND policyname = 'Public select transition_presets') THEN
        CREATE POLICY "Public select transition_presets" ON public.transition_presets FOR SELECT TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'transition_presets' AND policyname = 'Public insert transition_presets') THEN
        CREATE POLICY "Public insert transition_presets" ON public.transition_presets FOR INSERT TO public WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'transition_presets' AND policyname = 'Public update transition_presets') THEN
        CREATE POLICY "Public update transition_presets" ON public.transition_presets FOR UPDATE TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'transition_presets' AND policyname = 'Public delete transition_presets') THEN
        CREATE POLICY "Public delete transition_presets" ON public.transition_presets FOR DELETE TO public USING (true);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_transition_presets_category ON public.transition_presets(category);
CREATE INDEX IF NOT EXISTS idx_transition_presets_is_system ON public.transition_presets(is_system);

-- 3. BẢNG USER FAVORITES (Bảng trung gian quản lý danh sách Yêu thích của người dùng cho cả 7 tab)
CREATE TABLE IF NOT EXISTS public.user_favorites (
    user_id TEXT NOT NULL,
    tab TEXT NOT NULL,
    item_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, tab, item_id)
);

ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_favorites' AND policyname = 'Public select user_favorites') THEN
        CREATE POLICY "Public select user_favorites" ON public.user_favorites FOR SELECT TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_favorites' AND policyname = 'Public insert user_favorites') THEN
        CREATE POLICY "Public insert user_favorites" ON public.user_favorites FOR INSERT TO public WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_favorites' AND policyname = 'Public update user_favorites') THEN
        CREATE POLICY "Public update user_favorites" ON public.user_favorites FOR UPDATE TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_favorites' AND policyname = 'Public delete user_favorites') THEN
        CREATE POLICY "Public delete user_favorites" ON public.user_favorites FOR DELETE TO public USING (true);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_favorites_user_tab ON public.user_favorites(user_id, tab);
