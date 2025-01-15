/*
  # Fix User Signup Process

  1. Changes
    - Drop existing triggers and functions in correct order
    - Add trigger to create user profile on auth signup
    - Improve error handling and retry logic
    - Ensure unique usernames
    - Add automatic profile creation

  2. Security
    - Maintain RLS policies
    - Functions run with SECURITY DEFINER
    - Safe error handling
*/

-- First drop triggers that depend on the functions
DROP TRIGGER IF EXISTS ensure_user_profile_forum_posts ON forum_posts;
DROP TRIGGER IF EXISTS ensure_user_profile_comments ON comments;
DROP TRIGGER IF EXISTS ensure_user_profile_post_likes ON post_likes;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_change ON auth.users;

-- Now we can safely drop the functions
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.handle_auth_user();
DROP FUNCTION IF EXISTS public.ensure_user_profile();

-- Create improved user signup handler
CREATE OR REPLACE FUNCTION public.handle_user_signup()
RETURNS trigger AS $$
DECLARE
  base_username text;
  final_username text;
  counter integer := 1;
  max_retries constant integer := 3;
  current_try integer := 0;
BEGIN
  -- Ensure we have valid data
  IF NEW.email IS NULL THEN
    RAISE WARNING 'Email cannot be null for user %', NEW.id;
    RETURN NEW;
  END IF;

  -- Generate base username from email
  base_username := split_part(NEW.email, '@', 1);
  final_username := base_username;
  
  -- Find unique username
  WHILE EXISTS (SELECT 1 FROM public.users WHERE username = final_username AND id != NEW.id) LOOP
    counter := counter + 1;
    final_username := base_username || counter;
  END LOOP;

  -- Insert user profile with retries
  LOOP
    current_try := current_try + 1;
    BEGIN
      INSERT INTO public.users (id, username)
      VALUES (
        NEW.id,
        COALESCE(
          NEW.raw_user_meta_data->>'username',
          final_username
        )
      )
      ON CONFLICT (id) DO UPDATE
      SET 
        username = EXCLUDED.username,
        updated_at = now();
        
      EXIT; -- Success, exit loop
    EXCEPTION WHEN OTHERS THEN
      IF current_try >= max_retries THEN
        RAISE WARNING 'Failed to create user profile after % attempts: %', max_retries, SQLERRM;
        EXIT;
      END IF;
      -- Wait a bit before retrying (10ms, 20ms, 30ms)
      PERFORM pg_sleep(current_try * 0.01);
    END;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger that runs immediately after user signup
CREATE TRIGGER on_auth_user_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_signup();

-- Ensure proper permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Backfill any missing user profiles
DO $$ 
DECLARE 
  auth_user RECORD;
BEGIN
  FOR auth_user IN 
    SELECT * FROM auth.users 
    WHERE NOT EXISTS (
      SELECT 1 FROM public.users WHERE users.id = auth.users.id
    )
  LOOP
    INSERT INTO public.users (id, username)
    VALUES (
      auth_user.id,
      COALESCE(
        auth_user.raw_user_meta_data->>'username',
        split_part(auth_user.email, '@', 1)
      )
    )
    ON CONFLICT (id) DO NOTHING;
  END LOOP;
END $$;