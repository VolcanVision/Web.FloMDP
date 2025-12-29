-- FCM Tables Migration - Updates for existing schema
-- Run this in your Supabase SQL Editor
-- This script is safe to run on existing tables

-- ============================================
-- EXISTING TABLES (already in your schema):
-- - fcm_tokens: stores device tokens
-- - notification_logs: stores sent notifications
-- - users: has role column for targeting
-- ============================================

-- Enable RLS on fcm_tokens if not already enabled
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can manage their own FCM tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can insert their own tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can view their own tokens" ON fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON fcm_tokens;

-- Create RLS policies for fcm_tokens
-- Users can insert their own tokens
CREATE POLICY "Users can insert their own tokens"
  ON fcm_tokens
  FOR INSERT
  WITH CHECK (
    user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  );

-- Users can view their own tokens
CREATE POLICY "Users can view their own tokens"
  ON fcm_tokens
  FOR SELECT
  USING (
    user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  );

-- Users can update their own tokens
CREATE POLICY "Users can update their own tokens"
  ON fcm_tokens
  FOR UPDATE
  USING (
    user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  );

-- Enable RLS on notification_logs if not already enabled
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own notifications" ON notification_logs;

-- Users can view their own notification history
CREATE POLICY "Users can view their own notifications"
  ON notification_logs
  FOR SELECT
  USING (
    user_id IN (
      SELECT id FROM users WHERE auth_id = auth.uid()
    )
  );

-- Create index for faster token lookups by user
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_active ON fcm_tokens(is_active);

-- Create index for notification_logs
CREATE INDEX IF NOT EXISTS idx_notification_logs_user_id ON notification_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON notification_logs(notification_type);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON fcm_tokens TO authenticated;
GRANT SELECT ON notification_logs TO authenticated;

-- ============================================
-- Helper functions to get FCM tokens
-- ============================================

-- Drop functions first to avoid return type mismatch errors
DROP FUNCTION IF EXISTS get_fcm_tokens_by_role(TEXT);
DROP FUNCTION IF EXISTS get_fcm_tokens_by_roles(TEXT[]);

CREATE OR REPLACE FUNCTION get_fcm_tokens_by_role(target_role TEXT)
RETURNS TABLE(user_id BIGINT, fcm_token TEXT, device_info TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT ft.user_id, ft.fcm_token, ft.device_info
  FROM fcm_tokens ft
  JOIN users u ON ft.user_id = u.id
  WHERE u.role = target_role
    AND ft.is_active = true
    AND u.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_fcm_tokens_by_roles(target_roles TEXT[])
RETURNS TABLE(user_id BIGINT, fcm_token TEXT, device_info TEXT, role TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT ft.user_id, ft.fcm_token, ft.device_info, u.role
  FROM fcm_tokens ft
  JOIN users u ON ft.user_id = u.id
  WHERE u.role = ANY(target_roles)
    AND ft.is_active = true
    AND u.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on functions
GRANT EXECUTE ON FUNCTION get_fcm_tokens_by_role(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_fcm_tokens_by_roles(TEXT[]) TO authenticated;
