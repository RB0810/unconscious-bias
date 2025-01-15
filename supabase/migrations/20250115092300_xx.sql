-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS sync_user_profile(uuid);

-- Create improved user profile management function
CREATE OR REPLACE FUNCTION public.handle_auth_user()
RETURNS trigger AS $$
BEGIN
  -- Insert or update the user profile
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
  SET 
    email = EXCLUDED.email,
    username = EXCLUDED.username,
    updated_at = now();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for auth user changes
CREATE TRIGGER on_auth_user_change
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user();

-- Create function to ensure user profile exists
CREATE OR REPLACE FUNCTION public.ensure_user_profile()
RETURNS trigger AS $$
DECLARE
  user_exists boolean;
BEGIN
  -- Check if user profile exists
  SELECT EXISTS (
    SELECT 1 FROM public.users WHERE id = NEW.user_id
  ) INTO user_exists;

  -- If user profile doesn't exist, create it
  IF NOT user_exists THEN
    INSERT INTO public.users (id, email, username)
    SELECT 
      id,
      email,
      COALESCE(
        raw_user_meta_data->>'username',
        split_part(email, '@', 1)
      )
    FROM auth.users
    WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for all tables that reference users
CREATE TRIGGER ensure_user_profile_forum_posts
  BEFORE INSERT ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_user_profile();

CREATE TRIGGER ensure_user_profile_comments
  BEFORE INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_user_profile();

CREATE TRIGGER ensure_user_profile_post_likes
  BEFORE INSERT ON post_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_user_profile();

-- Update RLS policies
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

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;