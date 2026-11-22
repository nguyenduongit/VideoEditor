-- ==============================================================================
-- MIGRATION SINGLE-USER: CHUYỂN FAVORITES SANG CỘT `is_favorite` TRÊN 7 BẢNG LIBRARY
-- Chạy script này 1 lần trên Supabase SQL Editor để:
-- 1. Thêm cột `is_favorite BOOLEAN NOT NULL DEFAULT false` cho toàn bộ 7 bảng Library.
-- 2. Chuyển toàn bộ dữ liệu yêu thích hiện có từ `user_favorites` (nếu có) sang 7 bảng.
-- 3. Tạo partial index tối ưu lọc `is_favorite = true`.
-- 4. Xóa bỏ hoàn toàn bảng trung gian `user_favorites`.
-- ==============================================================================

-- 1. Thêm cột `is_favorite` cho cả 7 bảng Library
ALTER TABLE public.stock_media ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.audio_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.text_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.effect_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.transition_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.adjustment_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.sticker_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;

-- 2. Di chuyển dữ liệu từ `user_favorites` (nếu bảng tồn tại) sang cột `is_favorite`
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'user_favorites'
    ) THEN
        UPDATE public.stock_media t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'media' AND f.item_id = t.id;

        UPDATE public.audio_presets t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'audio' AND f.item_id = t.id;

        UPDATE public.text_presets t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'text' AND f.item_id = t.id;

        UPDATE public.effect_presets t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'effect' AND f.item_id = t.id;

        UPDATE public.transition_presets t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'transition' AND f.item_id = t.id;

        UPDATE public.adjustment_presets t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'adjustment' AND f.item_id = t.id;

        UPDATE public.sticker_presets t
        SET is_favorite = true
        FROM public.user_favorites f
        WHERE f.tab = 'sticker' AND f.item_id = t.id;

        DROP TABLE public.user_favorites;
    END IF;
END $$;

-- 3. Tạo Partial Index cho truy vấn `WHERE is_favorite = true`
CREATE INDEX IF NOT EXISTS idx_stock_media_is_favorite ON public.stock_media(is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_audio_presets_is_favorite ON public.audio_presets(is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_text_presets_is_favorite ON public.text_presets(is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_effect_presets_is_favorite ON public.effect_presets(is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_transition_presets_is_favorite ON public.transition_presets(is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_adjustment_presets_is_favorite ON public.adjustment_presets(is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_sticker_presets_is_favorite ON public.sticker_presets(is_favorite) WHERE is_favorite = true;
