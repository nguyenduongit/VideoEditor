-- ==============================================================================
-- TẠO CÁC BẢNG SUPABASE CÒN THIẾU CHO VIDEO EDITOR (MÔ HÌNH SINGLE-USER)
-- Lưu ý: Các bảng audio_presets, stock_media, text_presets, effect_presets,
-- adjustment_presets, animation_presets đã có sẵn trên Supabase của bạn.
-- Trạng thái Favorites được lưu trực tiếp bằng cột `is_favorite` trên từng bảng Library
-- thay cho bảng trung gian `user_favorites`.
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
    is_favorite BOOLEAN NOT NULL DEFAULT false,
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
    is_favorite BOOLEAN NOT NULL DEFAULT false,
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

-- 3. BỔ SUNG CỘT `is_favorite` TRỰC TIẾP TRÊN 7 BẢNG LIBRARY & XÓA BẢNG `user_favorites`
ALTER TABLE public.stock_media ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.audio_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.text_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.effect_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.transition_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.adjustment_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.sticker_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;

DROP TABLE IF EXISTS public.user_favorites;
