/*
  # Seed Data for Unconscious Bias Learning Platform

  This migration adds initial content including:
  1. Sample courses
  2. Lessons
  3. Quizzes
  4. Forum posts
*/

-- Sample Courses
INSERT INTO courses (title, description, difficulty_level, estimated_duration, image_url) VALUES
('Introduction to Unconscious Bias', 'Learn the fundamentals of unconscious bias and how it affects our daily decisions.', 'beginner', '2 hours', 'https://images.unsplash.com/photo-1522071820081-009f0129c71c'),
('Workplace Inclusion Strategies', 'Advanced techniques for creating an inclusive workplace environment.', 'intermediate', '3 hours', 'https://images.unsplash.com/photo-1600880292203-757bb62b4baf'),
('Breaking Bias Patterns', 'Deep dive into recognizing and addressing personal bias patterns.', 'advanced', '4 hours', 'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e');

-- Sample Lessons
INSERT INTO lessons (course_id, title, content, type, order_number, video_url) 
SELECT 
  courses.id,
  'Understanding Unconscious Bias',
  'Unconscious biases are social stereotypes about certain groups of people that individuals form outside their own conscious awareness...',
  'video',
  1,
  'https://example.com/video1.mp4'
FROM courses 
WHERE title = 'Introduction to Unconscious Bias';

-- Sample Quiz
INSERT INTO quizzes (lesson_id, title, description, questions)
SELECT 
  lessons.id,
  'Module 1 Assessment',
  'Test your understanding of unconscious bias basics',
  '[
    {
      "question": "What is unconscious bias?",
      "options": [
        "Deliberate discrimination",
        "Social stereotypes formed outside conscious awareness",
        "Personal preferences",
        "Cultural traditions"
      ],
      "correct_answer": 1
    }
  ]'::jsonb
FROM lessons 
WHERE title = 'Understanding Unconscious Bias';

-- Sample Forum Posts
INSERT INTO forum_posts (user_id, title, content)
SELECT 
  auth.uid(),
  'Sharing my unconscious bias journey',
  'I recently completed the Introduction course and wanted to share my experience...'
FROM auth.users
LIMIT 1;