/*
  # Forum and Quiz Enhancements

  1. New Tables
    - `media_attachments`
      - `id` (uuid, primary key)
      - `post_id` (uuid, references forum_posts)
      - `type` (text: 'video', 'audio', 'image')
      - `url` (text)
      - `created_at` (timestamptz)

  2. Changes
    - Add `is_anonymous` column to forum_posts
    - Add `is_anonymous` column to comments
    - Add likes tracking for posts and comments

  3. Security
    - Enable RLS on new tables
    - Add policies for authenticated users
*/

-- Add media attachments table
CREATE TABLE IF NOT EXISTS media_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  type text CHECK (type IN ('video', 'audio', 'image')),
  url text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Add anonymous posting capability
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'forum_posts' AND column_name = 'is_anonymous'
  ) THEN
    ALTER TABLE forum_posts ADD COLUMN is_anonymous boolean DEFAULT false;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'comments' AND column_name = 'is_anonymous'
  ) THEN
    ALTER TABLE comments ADD COLUMN is_anonymous boolean DEFAULT false;
  END IF;
END $$;

-- Create likes tracking tables
CREATE TABLE IF NOT EXISTS post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid REFERENCES forum_posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE IF NOT EXISTS comment_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id uuid REFERENCES comments(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(comment_id, user_id)
);

-- Enable RLS
ALTER TABLE media_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;

-- Policies for media attachments
CREATE POLICY "Media attachments are viewable by everyone" ON media_attachments
  FOR SELECT USING (true);

CREATE POLICY "Users can add media to their own posts" ON media_attachments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM forum_posts
      WHERE id = post_id AND user_id = auth.uid()
    )
  );

-- Policies for likes
CREATE POLICY "Anyone can view likes" ON post_likes
  FOR SELECT USING (true);

CREATE POLICY "Users can manage their own likes" ON post_likes
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Anyone can view comment likes" ON comment_likes
  FOR SELECT USING (true);

CREATE POLICY "Users can manage their own comment likes" ON comment_likes
  FOR ALL USING (user_id = auth.uid());

-- Add some sample forum posts
INSERT INTO forum_posts (user_id, title, content, is_anonymous) 
SELECT 
  auth.uid(),
  'My experience with unconscious bias training',
  'I recently completed the training and wanted to share my insights anonymously. The most surprising thing I learned was...',
  true
FROM auth.users
LIMIT 1;

INSERT INTO forum_posts (user_id, title, content, is_anonymous)
SELECT 
  auth.uid(),
  'Question about microaggressions',
  'I''d like to understand better how to identify and address microaggressions in the workplace...',
  false
FROM auth.users
LIMIT 1;

INSERT INTO forum_posts (user_id, title, content, is_anonymous)
SELECT 
  auth.uid(),
  'Success story: Implementing inclusive practices',
  'Here''s how our team successfully implemented new inclusive practices after the training...',
  false
FROM auth.users
LIMIT 1;