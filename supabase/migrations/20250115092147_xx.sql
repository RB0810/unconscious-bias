-- Drop existing triggers first
DROP TRIGGER IF EXISTS ensure_user_profile_on_post ON forum_posts;
DROP TRIGGER IF EXISTS ensure_user_profile_on_like ON post_likes;
DROP TRIGGER IF EXISTS ensure_user_profile_on_comment ON comments;
DROP FUNCTION IF EXISTS ensure_user_profile();

-- Improved user profile creation function
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      split_part(NEW.email, '@', 1)
    )
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      username = COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1));
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Ensure RLS policies are correct
DROP POLICY IF EXISTS "Users can read all users" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;

CREATE POLICY "Users can read all users"
  ON users FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- Add function to sync user profile
CREATE OR REPLACE FUNCTION sync_user_profile(user_id uuid)
RETURNS void AS $$
DECLARE
  _email text;
  _username text;
BEGIN
  SELECT email, COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1))
  INTO _email, _username
  FROM auth.users
  WHERE id = user_id;

  INSERT INTO public.users (id, email, username)
  VALUES (user_id, _email, _username)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      username = EXCLUDED.username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION sync_user_profile TO authenticated;