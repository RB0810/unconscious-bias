import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { PenTool, Clock, CheckCircle, XCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

interface Question {
  question: string;
  options: string[];
  correct_answer: number;
}

interface Quiz {
  id: string;
  title: string;
  description: string;
  questions: Question[];
  lessons: {
    title: string;
    courses: {
      title: string;
    };
  };
  completed?: boolean;
}

export function Quizzes() {
  const { user } = useAuth();
  const [quizzes, setQuizzes] = useState<Quiz[]>([]);
  const [activeQuiz, setActiveQuiz] = useState<Quiz | null>(null);
  const [currentQuestion, setCurrentQuestion] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [showResult, setShowResult] = useState(false);
  const [score, setScore] = useState(0);
  const [answers, setAnswers] = useState<number[]>([]);

  useEffect(() => {
    loadQuizzes();
  }, [user]);

  async function loadQuizzes() {
    if (!user) return;

    // First, get all quizzes
    const { data: quizzesData } = await supabase
      .from('quizzes')
      .select(`
        *,
        lessons (
          title,
          courses (
            title
          )
        )
      `);
    
    // Then, get completed quizzes for the user
    const { data: completedQuizzes } = await supabase
      .from('quiz_responses')
      .select('quiz_id')
      .eq('user_id', user.id);

    const completedQuizIds = new Set(completedQuizzes?.map(q => q.quiz_id) || []);
    
    // Add dummy questions and completion status
    const quizzesWithQuestions = (quizzesData || []).map(quiz => ({
      ...quiz,
      completed: completedQuizIds.has(quiz.id),
      questions: quiz.questions || [
        {
          question: "What is unconscious bias?",
          options: [
            "Deliberate discrimination",
            "Social stereotypes formed outside conscious awareness",
            "Personal preferences",
            "Cultural traditions"
          ],
          correct_answer: 1
        },
        {
          question: "Which of the following is a way to combat unconscious bias?",
          options: [
            "Ignore it completely",
            "Acknowledge and reflect on our biases",
            "Only interact with similar people",
            "Make quick decisions"
          ],
          correct_answer: 1
        },
        {
          question: "How can organizations reduce unconscious bias in hiring?",
          options: [
            "Only hire based on gut feeling",
            "Skip the interview process",
            "Use standardized questions and blind resume reviews",
            "Make decisions quickly"
          ],
          correct_answer: 2
        }
      ]
    }));
    
    setQuizzes(quizzesWithQuestions);
  }

  const startQuiz = (quiz: Quiz) => {
    setActiveQuiz(quiz);
    setCurrentQuestion(0);
    setSelectedAnswer(null);
    setShowResult(false);
    setScore(0);
    setAnswers([]);
  };

  const handleAnswerSelect = (answerIndex: number) => {
    if (showResult) return;
    setSelectedAnswer(answerIndex);
  };

  const handleNextQuestion = () => {
    if (selectedAnswer === null) return;

    const isCorrect = selectedAnswer === activeQuiz?.questions[currentQuestion].correct_answer;
    if (isCorrect) {
      setScore(prev => prev + 1);
    }

    setAnswers([...answers, selectedAnswer]);
    
    if (currentQuestion + 1 < (activeQuiz?.questions.length || 0)) {
      setCurrentQuestion(prev => prev + 1);
      setSelectedAnswer(null);
    } else {
      setShowResult(true);
      if (activeQuiz) {
        markQuizComplete(activeQuiz.id);
      }
    }
  };

  const markQuizComplete = async (quizId: string) => {
    if (!user) return;

    await supabase.from('quiz_responses').insert({
      user_id: user.id,
      quiz_id: quizId,
      score: (score / (activeQuiz?.questions.length || 1)) * 100,
      answers: answers
    });

    // Update local state to show quiz as completed
    setQuizzes(prevQuizzes => 
      prevQuizzes.map(quiz => 
        quiz.id === quizId ? { ...quiz, completed: true } : quiz
      )
    );
  };

  const resetQuiz = () => {
    setActiveQuiz(null);
    setCurrentQuestion(0);
    setSelectedAnswer(null);
    setShowResult(false);
    setScore(0);
    setAnswers([]);
  };

  if (activeQuiz) {
    return (
      <div className="max-w-2xl mx-auto space-y-8">
        <header className="text-center">
          <h1 className="text-3xl font-bold text-gray-900">{activeQuiz.title}</h1>
          <p className="mt-2 text-gray-600">{activeQuiz.description}</p>
        </header>

        {showResult ? (
          <div className="bg-white rounded-lg shadow-lg p-8 text-center">
            <div className="mb-6">
              <div className="inline-block p-4 rounded-full bg-indigo-100 text-indigo-600 mb-4">
                <PenTool className="h-8 w-8" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Quiz Complete!</h2>
              <p className="text-gray-600 mt-2">
                You scored {score} out of {activeQuiz.questions.length}
              </p>
            </div>

            <div className="space-y-4 mb-6">
              {activeQuiz.questions.map((question, index) => (
                <div key={index} className="text-left bg-gray-50 rounded-lg p-4">
                  <div className="flex items-start">
                    <div className="mr-3 mt-1">
                      {answers[index] === question.correct_answer ? (
                        <CheckCircle className="h-5 w-5 text-green-500" />
                      ) : (
                        <XCircle className="h-5 w-5 text-red-500" />
                      )}
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{question.question}</p>
                      <p className="text-sm text-gray-600 mt-1">
                        Correct answer: {question.options[question.correct_answer]}
                      </p>
                      {answers[index] !== question.correct_answer && (
                        <p className="text-sm text-red-600 mt-1">
                          Your answer: {question.options[answers[index]]}
                        </p>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <button
              onClick={resetQuiz}
              className="px-6 py-3 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition-colors"
            >
              Try Another Quiz
            </button>
          </div>
        ) : (
          <div className="bg-white rounded-lg shadow-lg p-8">
            <div className="flex justify-between items-center mb-6">
              <span className="text-sm font-medium text-gray-600">
                Question {currentQuestion + 1} of {activeQuiz.questions.length}
              </span>
              <span className="text-sm font-medium text-gray-600">
                Score: {score}
              </span>
            </div>

            <div className="mb-8">
              <h2 className="text-xl font-semibold text-gray-900 mb-4">
                {activeQuiz.questions[currentQuestion].question}
              </h2>

              <div className="space-y-3">
                {activeQuiz.questions[currentQuestion].options.map((option, index) => (
                  <button
                    key={index}
                    onClick={() => handleAnswerSelect(index)}
                    className={`w-full text-left p-4 rounded-lg border-2 transition-colors ${
                      selectedAnswer === index
                        ? 'border-indigo-600 bg-indigo-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    {option}
                  </button>
                ))}
              </div>
            </div>

            <button
              onClick={handleNextQuestion}
              disabled={selectedAnswer === null}
              className={`w-full py-3 rounded-md transition-colors ${
                selectedAnswer === null
                  ? 'bg-gray-300 cursor-not-allowed'
                  : 'bg-indigo-600 hover:bg-indigo-700 text-white'
              }`}
            >
              {currentQuestion + 1 === activeQuiz.questions.length ? 'Finish Quiz' : 'Next Question'}
            </button>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-3xl font-bold text-gray-900">Knowledge Check</h1>
        <p className="mt-2 text-gray-600">Test your understanding with these quizzes</p>
      </header>

      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        {quizzes.map((quiz) => (
          <div
            key={quiz.id}
            className="bg-white rounded-lg shadow-lg overflow-hidden hover:shadow-xl transition-shadow"
          >
            <div className="p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-2">
                  <PenTool className="h-6 w-6 text-indigo-600" />
                  <h3 className="text-xl font-semibold text-gray-900">{quiz.title}</h3>
                </div>
                {quiz.completed && (
                  <CheckCircle className="h-5 w-5 text-green-500" />
                )}
              </div>
              <p className="text-gray-600 mb-4">{quiz.description}</p>
              <div className="text-sm text-gray-500 mb-4">
                <p>Course: {quiz.lessons?.courses?.title}</p>
                <p>Lesson: {quiz.lessons?.title}</p>
              </div>
              <div className="flex items-center justify-between">
                <div className="flex items-center text-sm text-gray-500">
                  <Clock className="h-4 w-4 mr-1" />
                  <span>15 minutes</span>
                </div>
                <button
                  onClick={() => startQuiz(quiz)}
                  className="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition-colors"
                >
                  {quiz.completed ? 'Retake Quiz' : 'Start Quiz'}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}