-- Add functions to handle likes count
CREATE OR REPLACE FUNCTION increment_post_likes(post_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE forum_posts
  SET likes = likes + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrement_post_likes(post_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE forum_posts
  SET likes = GREATEST(0, likes - 1)
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add trigger to ensure user exists before inserting quiz responses
CREATE OR REPLACE FUNCTION ensure_user_exists()
RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.user_id) THEN
    INSERT INTO users (id, email, username)
    SELECT 
      NEW.user_id,
      auth.email(),
      COALESCE(
        (SELECT raw_user_meta_data->>'username' 
         FROM auth.users 
         WHERE id = NEW.user_id),
        split_part(auth.email(), '@', 1)
      )
    WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.user_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER ensure_user_exists_before_quiz_response
  BEFORE INSERT ON quiz_responses
  FOR EACH ROW
  EXECUTE FUNCTION ensure_user_exists();

-- Add policies for the new functions
GRANT EXECUTE ON FUNCTION increment_post_likes TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_post_likes TO authenticated;