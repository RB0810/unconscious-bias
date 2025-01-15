/*
  # Improve User Profile Management

  1. Changes
    - Add trigger to create user profile on auth signup
    - Add function to handle user profile creation
    - Add better error handling and logging
    - Ensure unique usernames

  2. Security
    - Maintain RLS policies
    - Functions run with SECURITY DEFINER
    - Proper error handling
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
    RAISE WARNING 'Email cannot be null for user %', NEW.id;
    RETURN NEW;
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
  BEGIN
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
  EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail
    RAISE WARNING 'Error creating user profile for %: %', NEW.id, SQLERRM;
  END;

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
  -- Get auth user data with retry logic
  FOR i IN 1..3 LOOP
    BEGIN
      SELECT * INTO auth_user
      FROM auth.users
      WHERE id = NEW.user_id;
      
      EXIT WHEN auth_user.id IS NOT NULL;
      
      -- Small delay before retry
      PERFORM pg_sleep(0.1);
    EXCEPTION WHEN OTHERS THEN
      IF i = 3 THEN
        RAISE WARNING 'Failed to get auth user after 3 attempts: %', SQLERRM;
        RETURN NEW;
      END IF;
    END;
  END LOOP;

  -- Check if user profile exists
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = NEW.user_id) THEN
    -- Generate unique username
    base_username := split_part(COALESCE(auth_user.email, 'user'), '@', 1);
    final_username := base_username;
    
    WHILE EXISTS (SELECT 1 FROM public.users WHERE username = final_username) LOOP
      final_username := base_username || counter;
      counter := counter + 1;
    END LOOP;

    -- Create profile with retry logic
    FOR i IN 1..3 LOOP
      BEGIN
        INSERT INTO public.users (id, email, username)
        VALUES (
          NEW.user_id,
          COALESCE(auth_user.email, 'pending@example.com'),
          final_username
        );
        
        EXIT;
      EXCEPTION WHEN OTHERS THEN
        IF i = 3 THEN
          RAISE WARNING 'Failed to create user profile after 3 attempts: %', SQLERRM;
        END IF;
      END;
    END LOOP;
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