import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Award, BookOpen, TrendingUp } from 'lucide-react';

export function Profile() {
  const { user } = useAuth();
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState<any>({
    coursesCompleted: 0,
    lessonsCompleted: 0,
    averageScore: 0,
  });

  useEffect(() => {
    if (user) {
      loadProfile();
      loadStats();
    }
  }, [user]);

  async function loadProfile() {
    try {
      setLoading(true);
      // Remove .single() to handle case where profile doesn't exist
      const { data, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', user.id);
      
      if (error) throw error;
      
      // If no profile exists, create one
      if (!data || data.length === 0) {
        const { data: newProfile, error: createError } = await supabase
          .from('users')
          .insert({
            id: user.id,
            email: user.email,
            username: user.email?.split('@')[0] || 'user',
          })
          .select()
          .single();
        
        if (createError) throw createError;
        setProfile(newProfile);
      } else {
        setProfile(data[0]);
      }
    } catch (error) {
      console.error('Error loading profile:', error);
    } finally {
      setLoading(false);
    }
  }

  async function loadStats() {
    try {
      // Load user statistics
      const { data: progressData } = await supabase
        .from('progress')
        .select('*')
        .eq('user_id', user.id)
        .eq('completed', true);

      const { data: quizData } = await supabase
        .from('quiz_responses')
        .select('score')
        .eq('user_id', user.id);

      const averageScore = quizData?.length
        ? quizData.reduce((acc, curr) => acc + curr.score, 0) / quizData.length
        : 0;

      setStats({
        coursesCompleted: Math.floor((progressData?.length || 0) / 5), // Assuming 5 lessons per course
        lessonsCompleted: progressData?.length || 0,
        averageScore,
      });
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  }

  if (!user) {
    return <div>Please sign in to view your profile.</div>;
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-gray-600">Loading profile...</div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <header className="text-center">
        <div className="mb-4">
          <img
            src={profile?.avatar_url || 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80'}
            alt={profile?.username}
            className="mx-auto h-24 w-24 rounded-full"
          />
        </div>
        <h1 className="text-3xl font-bold text-gray-900">{profile?.username || user.email}</h1>
        <p className="mt-2 text-gray-600">{profile?.bio || 'No bio yet'}</p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-lg shadow text-center">
          <Award className="h-8 w-8 text-indigo-600 mx-auto mb-2" />
          <h3 className="text-2xl font-bold text-gray-900">{stats.coursesCompleted}</h3>
          <p className="text-gray-600">Courses Completed</p>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow text-center">
          <BookOpen className="h-8 w-8 text-indigo-600 mx-auto mb-2" />
          <h3 className="text-2xl font-bold text-gray-900">{stats.lessonsCompleted}</h3>
          <p className="text-gray-600">Lessons Completed</p>
        </div>
        
        <div className="bg-white p-6 rounded-lg shadow text-center">
          <TrendingUp className="h-8 w-8 text-indigo-600 mx-auto mb-2" />
          <h3 className="text-2xl font-bold text-gray-900">{stats.averageScore}%</h3>
          <p className="text-gray-600">Average Quiz Score</p>
        </div>
      </div>

      <section className="bg-white p-6 rounded-lg shadow">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Account Settings</h2>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Email</label>
            <p className="mt-1 text-gray-600">{user.email}</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Member Since</label>
            <p className="mt-1 text-gray-600">
              {new Date(user.created_at).toLocaleDateString()}
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}