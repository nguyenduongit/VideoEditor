-- ==============================================================================
-- DỌN DẸP CÁC BẢNG TRÙNG LẶP TRÊN SUPABASE (CHẠY TRONG SQL EDITOR)
-- Xóa bỏ 2 bảng cũ audio_items và stock_items, chuẩn hóa hệ thống sang
-- audio_presets và stock_media.
-- ==============================================================================

DROP TABLE IF EXISTS public.audio_items CASCADE;
DROP TABLE IF EXISTS public.stock_items CASCADE;

