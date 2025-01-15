import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import Navigation from './components/Navigation';
import { Dashboard } from './pages/Dashboard';
import { Courses } from './pages/Courses';
import { Course } from './pages/Course';
import { Forum } from './pages/Forum';
import { Quizzes } from './pages/Quizzes';
import { Login } from './pages/Login';
import { useAuth } from './contexts/AuthContext';

function AppContent() {
  const { user } = useAuth();

  return (
    <div className="min-h-screen bg-gray-50">
      {user && <Navigation user={user} />}
      <main className={user ? "container mx-auto px-4 py-8" : ""}>
        <Routes>
          <Route path="/login" element={user ? <Navigate to="/" /> : <Login />} />
          <Route path="/" element={user ? <Dashboard /> : <Navigate to="/login" />} />
          <Route path="/courses" element={user ? <Courses /> : <Navigate to="/login" />} />
          <Route path="/courses/:id" element={user ? <Course /> : <Navigate to="/login" />} />
          <Route path="/forum" element={user ? <Forum /> : <Navigate to="/login" />} />
          <Route path="/quizzes" element={user ? <Quizzes /> : <Navigate to="/login" />} />
          <Route path="*" element={<Navigate to={user ? "/" : "/login"} />} />
        </Routes>
      </main>
    </div>
  );
}

export default AppContent;