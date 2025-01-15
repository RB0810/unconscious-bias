import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { BookOpen, Users, Home, PenTool } from 'lucide-react';
import { supabase } from '../lib/supabase';

export default function Navigation({ user }: { user: any }) {
  const location = useLocation();

  const links = [
    { to: '/', icon: Home, label: 'Dashboard' },
    { to: '/courses', icon: BookOpen, label: 'Courses' },
    { to: '/quizzes', icon: PenTool, label: 'Quizzes' },
    { to: '/forum', icon: Users, label: 'Forum' },
  ];

  const handleSignOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <nav className="bg-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <Link to="/" className="flex items-center space-x-2">
              <BookOpen className="h-8 w-8 text-indigo-600" />
              <span className="font-bold text-xl">UnBias</span>
            </Link>
            
            <div className="hidden md:flex space-x-4">
              {links.map(({ to, icon: Icon, label }) => (
                <Link
                  key={to}
                  to={to}
                  className={`flex items-center space-x-1 px-3 py-2 rounded-md text-sm font-medium ${
                    location.pathname === to
                      ? 'bg-indigo-100 text-indigo-700'
                      : 'text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  <Icon className="h-4 w-4" />
                  <span>{label}</span>
                </Link>
              ))}
            </div>
          </div>

          <button
            onClick={handleSignOut}
            className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
          >
            Sign Out
          </button>
        </div>
      </div>
    </nav>
  );
}