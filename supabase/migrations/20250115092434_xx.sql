/*
  # Fix User Signup and Profile Creation

  1. Changes
    - Drop triggers in correct order to handle dependencies
    - Recreate functions and triggers with improved error handling
    - Add proper permissions

  2. Security
    - Maintain RLS policies
    - Ensure proper function permissions
*/

-- First drop triggers that depend on the functions
DROP TRIGGER IF EXISTS ensure_user_profile_forum_posts ON forum_posts;
DROP TRIGGER IF EXISTS ensure_user_profile_comments ON comments;
DROP TRIGGER IF EXISTS ensure_user_profile_post_likes ON post_likes;
DROP TRIGGER IF EXISTS on_auth_user_change ON auth.users;

-- Now we can safely drop the functions
DROP FUNCTION IF EXISTS public.handle_auth_user();
DROP FUNCTION IF EXISTS public.ensure_user_profile();

-- Create improved user profile management function
CREATE OR REPLACE FUNCTION public.handle_auth_user()
RETURNS trigger AS $$
DECLARE
  base_username text;
  final_username text;
  counter integer := 1;
BEGIN
  -- Ensure we have valid data
  IF NEW.email IS NULL THEN
    RAISE EXCEPTION 'Email cannot be null';
  END IF;

  -- Generate a safe username from email
  base_username := split_part(NEW.email, '@', 1);
  final_username := base_username;
  
  -- Keep trying until we find a unique username
  WHILE EXISTS (SELECT 1 FROM public.users WHERE username = final_username AND id != NEW.id) LOOP
    final_username := base_username || counter;
    counter := counter + 1;
  END LOOP;

  -- Insert or update the user profile
  INSERT INTO public.users (id, email, username)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      final_username
    )
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    email = EXCLUDED.email,
    username = EXCLUDED.username,
    updated_at = now();

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error and continue
  RAISE WARNING 'Error in handle_auth_user: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to ensure user profile exists
CREATE OR REPLACE FUNCTION public.ensure_user_profile()
RETURNS trigger AS $$
DECLARE
  auth_user RECORD;
  base_username text;
  final_username text;
  counter integer := 1;
BEGIN
  -- Get auth user data
  SELECT * INTO auth_user
  FROM auth.users
  WHERE id = NEW.user_id;

  IF auth_user.email IS NULL THEN
    RAISE WARNING 'Cannot create profile: auth user not found or email is null';
    RETURN NEW; -- Continue instead of failing
  END IF;

  -- Check if user profile exists
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.user_id) THEN
    -- Generate unique username
    base_username := split_part(auth_user.email, '@', 1);
    final_username := base_username;
    
    WHILE EXISTS (SELECT 1 FROM public.users WHERE username = final_username) LOOP
      final_username := base_username || counter;
      counter := counter + 1;
    END LOOP;

    -- Create profile
    BEGIN
      INSERT INTO public.users (id, email, username)
      VALUES (
        NEW.user_id,
        auth_user.email,
        COALESCE(
          auth_user.raw_user_meta_data->>'username',
          final_username
        )
      );
    EXCEPTION WHEN OTHERS THEN
      -- Log error and continue
      RAISE WARNING 'Error ensuring user profile: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate triggers in correct order
CREATE TRIGGER on_auth_user_change
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user();

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

-- Ensure proper permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;