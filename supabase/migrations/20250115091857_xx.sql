/*
  # Fix user profile creation

  1. Changes
    - Add trigger to automatically create user profiles
    - Update user profile creation logic
    - Add function to ensure user exists

  2. Security
    - Function runs with security definer to ensure proper permissions
*/

-- Function to ensure user profile exists
CREATE OR REPLACE FUNCTION ensure_user_profile()
RETURNS trigger AS $$
DECLARE
  _email text;
  _username text;
BEGIN
  -- Get email from auth.users
  SELECT email INTO _email
  FROM auth.users
  WHERE id = NEW.user_id;

  -- Generate username from email
  _username := split_part(_email, '@', 1);

  -- Create user profile if it doesn't exist
  INSERT INTO users (id, email, username)
  VALUES (NEW.user_id, _email, _username)
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add triggers for automatic user profile creation
CREATE TRIGGER ensure_user_profile_on_post
  BEFORE INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION ensure_user_profile();

CREATE TRIGGER ensure_user_profile_on_like
  BEFORE INSERT ON post_likes
  FOR EACH ROW
  EXECUTE FUNCTION ensure_user_profile();

CREATE TRIGGER ensure_user_profile_on_comment
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION ensure_user_profile();