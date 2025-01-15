import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { BookOpen, Clock, BarChart } from 'lucide-react';

export function Courses() {
  const [courses, setCourses] = useState<any[]>([]);

  useEffect(() => {
    loadCourses();
  }, []);

  async function loadCourses() {
    const { data } = await supabase
      .from('courses')
      .select('*')
      .order('created_at', { ascending: false });
    
    setCourses(data || []);
  }

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-3xl font-bold text-gray-900">Learning Library</h1>
        <p className="mt-2 text-gray-600">Explore our comprehensive collection of courses on unconscious bias.</p>
      </header>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        {courses.map((course) => (
          <Link
            key={course.id}
            to={`/courses/${course.id}`}
            className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow"
          >
            <img
              src={course.image_url}
              alt={course.title}
              className="w-full h-48 object-cover"
            />
            <div className="p-6">
              <h3 className="text-xl font-semibold text-gray-900">{course.title}</h3>
              <p className="mt-2 text-gray-600 line-clamp-2">{course.description}</p>
              
              <div className="mt-4 flex items-center justify-between text-sm text-gray-500">
                <div className="flex items-center space-x-1">
                  <Clock className="h-4 w-4" />
                  <span>{course.estimated_duration}</span>
                </div>
                <div className="flex items-center space-x-1">
                  <BarChart className="h-4 w-4" />
                  <span className="capitalize">{course.difficulty_level}</span>
                </div>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}