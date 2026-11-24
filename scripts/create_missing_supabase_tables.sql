-- ==============================================================================
-- CẬP NHẬT BẢNG CLOUD SUPABASE CHO VIDEO EDITOR (MÔ HÌNH SINGLE-USER)
-- Kiến trúc chuẩn hóa theo AGENTS.md Điều 15:
-- * CHỈ Text (`text_presets`), Adjustment (`adjustment_presets`), Audio (`audio_library`),
--   và Stock Media (`stock_media`) sử dụng bảng Supabase & cột `is_favorite`.
-- * Effect, Transition, Sticker, và Text Animation là Dev-Only System Libraries cục bộ;
--   Favorites của các System Libraries lưu 100% cục bộ qua UserDefaults.
-- ==============================================================================

ALTER TABLE public.stock_media ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.audio_library ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.text_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE public.adjustment_presets ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN NOT NULL DEFAULT false;

DROP TABLE IF EXISTS public.user_favorites;
