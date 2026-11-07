-- Tạo bảng animation_presets trên Supabase
CREATE TABLE IF NOT EXISTS public.animation_presets (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT DEFAULT ''::text,
    category TEXT NOT NULL,
    tags TEXT[] DEFAULT '{}'::text[],
    preview_badge TEXT,
    config JSONB NOT NULL,
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Kích hoạt Row Level Security (RLS)
ALTER TABLE public.animation_presets ENABLE ROW LEVEL SECURITY;

-- Thiết lập các Policies cho phép truy cập theo chuẩn Supabase REST API
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'animation_presets' AND policyname = 'Public select animation_presets') THEN
        CREATE POLICY "Public select animation_presets" ON public.animation_presets FOR SELECT TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'animation_presets' AND policyname = 'Public insert animation_presets') THEN
        CREATE POLICY "Public insert animation_presets" ON public.animation_presets FOR INSERT TO public WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'animation_presets' AND policyname = 'Public update animation_presets') THEN
        CREATE POLICY "Public update animation_presets" ON public.animation_presets FOR UPDATE TO public USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'animation_presets' AND policyname = 'Public delete animation_presets') THEN
        CREATE POLICY "Public delete animation_presets" ON public.animation_presets FOR DELETE TO public USING (true);
    END IF;
END $$;

-- Tạo index hỗ trợ phân loại và tối ưu truy vấn
CREATE INDEX IF NOT EXISTS idx_animation_presets_category ON public.animation_presets(category);
CREATE INDEX IF NOT EXISTS idx_animation_presets_is_system ON public.animation_presets(is_system);
