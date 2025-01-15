/*
  # Initial Schema for Unconscious Bias Learning Platform

  1. New Tables
    - users
      - Extended user profile information
    - courses
      - Learning content organized into courses
    - lessons
      - Individual learning units within courses
    - progress
      - User progress tracking
    - quizzes
      - Assessment content
    - quiz_responses
      - User quiz attempts and scores
    - forum_posts
      - Discussion forum content
    - comments
      - Comments on forum posts
    - user_recommendations
      - Personalized content recommendations

  2. Security
    - RLS enabled on all tables
    - Policies for authenticated users
*/

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  username text UNIQUE NOT NULL,
  full_name text,
  bio text,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Courses table
CREATE TABLE IF NOT EXISTS courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  image_url text,
  difficulty_level text CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
  estimated_duration interval,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Lessons table
CREATE TABLE IF NOT EXISTS lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid REFERENCES courses(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
  type text CHECK (type IN ('article', 'video', 'interactive')),
  order_number integer NOT NULL,
  video_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Progress tracking
CREATE TABLE IF NOT EXISTS progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  lesson_id uuid REFERENCES lessons(id) ON DELETE CASCADE,
  completed boolean DEFAULT false,
  completion_date timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, lesson_id)
);

-- Quizzes
CREATE TABLE IF NOT EXISTS quizzes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid REFERENCES lessons(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  questions jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Quiz responses
CREATE TABLE IF NOT EXISTS quiz_responses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  quiz_id uuid REFERENCES quizzes(id) ON DELETE CASCADE,
  answers jsonb NOT NULL,
  score integer NOT NULL,
  completed_at timestamptz DEFAULT now(),
  UNIQUE(user_id, quiz_id)
);

-- Forum posts
CREATE TABLE IF NOT EXISTS forum_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  content text NOT NULL,
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
  likes integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- User recommendations
CREATE TABLE IF NOT EXISTS user_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  course_id uuid REFERENCES courses(id) ON DELETE CASCADE,
  reason text NOT NULL,
  priority integer DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, course_id)
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_recommendations ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can read all courses" ON courses FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can read all lessons" ON lessons FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can manage their own progress" ON progress FOR ALL TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can read all quizzes" ON quizzes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can manage their own quiz responses" ON quiz_responses FOR ALL TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can read all forum posts" ON forum_posts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can manage their own forum posts" ON forum_posts FOR ALL TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can read all comments" ON comments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can manage their own comments" ON comments FOR ALL TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can read their own recommendations" ON user_recommendations FOR SELECT TO authenticated USING (auth.uid() = user_id);