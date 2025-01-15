import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { BookOpen, Award, TrendingUp, Clock, BarChart } from 'lucide-react';

export function Dashboard() {
  const { user } = useAuth();
  const [recentCourses, setRecentCourses] = useState<any[]>([]);

  useEffect(() => {
    if (user) {
      loadDashboardData();
    }
  }, [user]);

  async function loadDashboardData() {
    const { data: coursesData } = await supabase
      .from('courses')
      .select('*')
      .limit(3);

    setRecentCourses(coursesData || []);
  }

  return (
    <div className="space-y-8">
      <header className="text-center bg-gradient-to-r from-indigo-600 to-purple-600 text-white py-12 rounded-lg shadow-lg">
        <h1 className="text-4xl font-bold">Welcome Back!</h1>
        <p className="mt-4 text-lg opacity-90">Continue your journey in understanding unconscious bias</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-lg shadow-lg border-l-4 border-indigo-600">
          <Award className="h-8 w-8 text-indigo-600 mb-2" />
          <h3 className="text-2xl font-bold text-gray-900">3</h3>
          <p className="text-gray-600">Courses Completed</p>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow-lg border-l-4 border-purple-600">
          <BookOpen className="h-8 w-8 text-purple-600 mb-2" />
          <h3 className="text-2xl font-bold text-gray-900">12</h3>
          <p className="text-gray-600">Lessons Completed</p>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow-lg border-l-4 border-pink-600">
          <TrendingUp className="h-8 w-8 text-pink-600 mb-2" />
          <h3 className="text-2xl font-bold text-gray-900">85%</h3>
          <p className="text-gray-600">Average Quiz Score</p>
        </div>
      </div>

      <section className="bg-white p-6 rounded-lg shadow-lg">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Continue Learning</h2>
        <div className="grid md:grid-cols-3 gap-6">
          {recentCourses.map((course) => (
            <Link
              key={course.id}
              to={`/courses/${course.id}`}
              className="group relative overflow-hidden rounded-lg shadow-md hover:shadow-lg transition-shadow"
            >
              <img
                src={course.image_url}
                alt={course.title}
                className="w-full h-48 object-cover group-hover:scale-105 transition-transform duration-300"
              />
              <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-4">
                <h3 className="text-white font-semibold">{course.title}</h3>
                <div className="flex items-center space-x-3 mt-2 text-white/80 text-sm">
                  <span className="flex items-center">
                    <Clock className="h-4 w-4 mr-1" />
                    {course.estimated_duration}
                  </span>
                  <span className="flex items-center">
                    <BarChart className="h-4 w-4 mr-1" />
                    {course.difficulty_level}
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}