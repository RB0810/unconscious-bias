/*
  # Forum System Schema

  1. Tables
    - users
      - Core user profile data
      - Links to auth.users
    - forum_posts
      - Main posts table with content and metadata
    - comments
      - Post comments with threading support
    - post_likes
      - Tracks post likes with user association
    - media_attachments
      - Handles post media (images, videos, etc)

  2. Security
    - RLS enabled on all tables
    - Policies for authenticated users
    - Anonymous read access where appropriate
*/

-- Users table (extends auth.users)
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  username text UNIQUE NOT NULL,
  email text UNIQUE NOT NULL,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Forum posts
CREATE TABLE IF NOT EXISTS forum_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
  is_anonymous boolean DEFAULT false,
  likes integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Comments
CREATE TABLE IF NOT EXISTS comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  content text NOT NULL,
  is_anonymous boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Post likes tracking
CREATE TABLE IF NOT EXISTS post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

-- Media attachments
CREATE TABLE IF NOT EXISTS media_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  type text CHECK (type IN ('video', 'audio', 'image')),
  url text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Like management functions
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

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_attachments ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can read all users" ON users
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE TO authenticated USING (auth.uid() = id);

CREATE POLICY "Anyone can read posts" ON forum_posts
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create posts" ON forum_posts
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own posts" ON forum_posts
  FOR UPDATE TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Anyone can read comments" ON comments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create comments" ON comments
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage their likes" ON post_likes
  FOR ALL TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view media" ON media_attachments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can add media to their posts" ON media_attachments
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM forum_posts
      WHERE id = post_id AND user_id = auth.uid()
    )
  );

-- Grant function execution permissions
GRANT EXECUTE ON FUNCTION increment_post_likes TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_post_likes TO authenticated;