import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Play, FileText, CheckCircle } from 'lucide-react';

export function Course() {
  const { id } = useParams();
  const [course, setCourse] = useState<any>(null);
  const [lessons, setLessons] = useState<any[]>([]);
  const [selectedVideo, setSelectedVideo] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      loadCourse();
      loadLessons();
    }
  }, [id]);

  async function loadCourse() {
    const { data } = await supabase
      .from('courses')
      .select('*')
      .eq('id', id)
      .single();
    
    setCourse(data);
  }

  async function loadLessons() {
    const { data } = await supabase
      .from('lessons')
      .select('*')
      .eq('course_id', id)
      .order('order_number', { ascending: true });
    
    setLessons(data || []);
  }

  // Function to convert YouTube URL to embed URL
  const getEmbedUrl = (url: string) => {
    if (!url) return null;
    
    // Handle youtu.be format
    if (url.includes('youtu.be')) {
      const videoId = url.split('youtu.be/')[1];
      return `https://www.youtube.com/embed/${videoId}`;
    }
    
    // Handle youtube.com format
    if (url.includes('youtube.com/watch')) {
      const videoId = new URL(url).searchParams.get('v');
      return `https://www.youtube.com/embed/${videoId}`;
    }
    
    return url; // Return as is if it's already an embed URL
  };

  if (!course) {
    return <div>Loading...</div>;
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <header>
        <img
          src={course.image_url}
          alt={course.title}
          className="w-full h-64 object-cover rounded-lg"
        />
        <div className="mt-6">
          <h1 className="text-3xl font-bold text-gray-900">{course.title}</h1>
          <p className="mt-2 text-gray-600">{course.description}</p>
          
          <div className="mt-4 flex items-center space-x-4 text-sm text-gray-500">
            <span className="capitalize">Level: {course.difficulty_level}</span>
            <span>Duration: {course.estimated_duration}</span>
          </div>
        </div>
      </header>

      {selectedVideo && (
        <div className="bg-white p-6 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-4">Video Lesson</h2>
          <div className="relative pb-[56.25%] h-0">
            <iframe
              src={getEmbedUrl(selectedVideo)}
              className="absolute top-0 left-0 w-full h-full rounded-lg"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          </div>
        </div>
      )}

      <section className="space-y-4">
        <h2 className="text-2xl font-semibold text-gray-900">Course Content</h2>
        
        <div className="space-y-4">
          {lessons.map((lesson) => (
            <div
              key={lesson.id}
              className="bg-white p-4 rounded-lg shadow flex items-center space-x-4 cursor-pointer hover:bg-gray-50"
              onClick={() => lesson.type === 'video' && setSelectedVideo(lesson.video_url)}
            >
              {lesson.type === 'video' ? (
                <Play className="h-6 w-6 text-indigo-600" />
              ) : (
                <FileText className="h-6 w-6 text-indigo-600" />
              )}
              
              <div className="flex-1">
                <h3 className="font-medium text-gray-900">{lesson.title}</h3>
                <p className="text-sm text-gray-500 capitalize">{lesson.type}</p>
              </div>

              <CheckCircle className="h-6 w-6 text-gray-300" />
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}