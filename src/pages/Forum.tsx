import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { MessageSquare, ThumbsUp, Clock, Paperclip, Video, Music, Image } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';
import { useAuth } from '../contexts/AuthContext';

interface Post {
  id: string;
  title: string;
  content: string;
  created_at: string;
  is_anonymous: boolean;
  likes: number;
  user_liked: boolean;
  users?: {
    username: string;
    avatar_url: string;
  };
  media_attachments: {
    type: 'video' | 'audio' | 'image';
    url: string;
  }[];
  comments: {
    id: string;
    content: string;
    created_at: string;
    is_anonymous: boolean;
    users?: {
      username: string;
      avatar_url: string;
    };
  }[];
}

function getVideoEmbedUrl(url: string): string | null {
  if (!url) return null;
  
  try {
    // Handle youtu.be format
    if (url.includes('youtu.be')) {
      const videoId = url.split('youtu.be/')[1].split('?')[0];
      return `https://www.youtube.com/embed/${videoId}`;
    }
    
    // Handle youtube.com format
    if (url.includes('youtube.com/watch')) {
      const videoId = new URL(url).searchParams.get('v');
      return videoId ? `https://www.youtube.com/embed/${videoId}` : null;
    }
    
    // Handle youtube.com/embed format
    if (url.includes('youtube.com/embed/')) {
      return url; // Already in embed format
    }
    
    return null;
  } catch (error) {
    console.error('Error parsing video URL:', error);
    return null;
  }
}

function MediaAttachment({ media }: { media: { type: string; url: string } }) {
  const embedUrl = media.type === 'video' ? getVideoEmbedUrl(media.url) : null;

  if (media.type === 'video' && embedUrl) {
    return (
      <div className="relative w-full pt-[56.25%] bg-gray-100 rounded-lg overflow-hidden">
        <iframe
          src={embedUrl}
          className="absolute top-0 left-0 w-full h-full"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowFullScreen
          title="Embedded video"
        />
      </div>
    );
  }

  if (media.type === 'image') {
    return (
      <img 
        src={media.url} 
        alt="" 
        className="rounded-lg max-h-96 w-auto"
        loading="lazy"
      />
    );
  }

  if (media.type === 'audio') {
    return (
      <audio 
        src={media.url} 
        controls 
        className="w-full"
      />
    );
  }

  return null;
}

export function Forum() {
  const { user } = useAuth();
  const [posts, setPosts] = useState<Post[]>([]);
  const [newPost, setNewPost] = useState({
    title: '',
    content: '',
    is_anonymous: false,
    media: [] as { type: string; url: string }[]
  });
  const [selectedPost, setSelectedPost] = useState<Post | null>(null);
  const [newComment, setNewComment] = useState({
    content: '',
    is_anonymous: false
  });

  useEffect(() => {
    loadPosts();
  }, [user]);

  async function loadPosts() {
    if (!user) return;

    const { data } = await supabase
      .from('forum_posts')
      .select(`
        *,
        users (
          username,
          avatar_url
        ),
        media_attachments (
          type,
          url
        ),
        comments (
          id,
          content,
          created_at,
          is_anonymous,
          users (
            username,
            avatar_url
          )
        )
      `)
      .order('created_at', { ascending: false });

    // Get user's likes
    const { data: userLikes } = await supabase
      .from('post_likes')
      .select('post_id')
      .eq('user_id', user.id);

    const userLikedPosts = new Set(userLikes?.map(like => like.post_id) || []);
    
    setPosts(data?.map(post => ({
      ...post,
      user_liked: userLikedPosts.has(post.id)
    })) || []);
  }

  async function handleSubmitPost(e: React.FormEvent) {
    e.preventDefault();
    if (!user) return;

    // Create the post
    const { data: post } = await supabase
      .from('forum_posts')
      .insert({
        user_id: user.id,
        title: newPost.title,
        content: newPost.content,
        is_anonymous: newPost.is_anonymous
      })
      .select()
      .single();

    // Add media attachments if any
    if (post && newPost.media.length > 0) {
      await supabase
        .from('media_attachments')
        .insert(
          newPost.media.map(media => ({
            post_id: post.id,
            type: media.type,
            url: media.url
          }))
        );
    }

    setNewPost({ title: '', content: '', is_anonymous: false, media: [] });
    loadPosts();
  }

  async function handleLikePost(postId: string, currentlyLiked: boolean) {
    if (!user) return;

    if (currentlyLiked) {
      await supabase
        .from('post_likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', user.id);
    } else {
      await supabase
        .from('post_likes')
        .insert({ post_id: postId, user_id: user.id });
    }

    loadPosts();
  }

  async function handleSubmitComment(postId: string) {
    if (!user || !newComment.content) return;

    await supabase
      .from('comments')
      .insert({
        post_id: postId,
        user_id: user.id,
        content: newComment.content,
        is_anonymous: newComment.is_anonymous
      });

    setNewComment({ content: '', is_anonymous: false });
    loadPosts();
  }

  function handleAddMedia(type: 'video' | 'audio' | 'image', url: string) {
    setNewPost(prev => ({
      ...prev,
      media: [...prev.media, { type, url }]
    }));
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      <header>
        <h1 className="text-3xl font-bold text-gray-900">Discussion Forum</h1>
        <p className="mt-2 text-gray-600">Share your thoughts and experiences with the community.</p>
      </header>

      {user && (
        <form onSubmit={handleSubmitPost} className="bg-white p-6 rounded-lg shadow space-y-4">
          <div>
            <label htmlFor="title" className="block text-sm font-medium text-gray-700">
              Title
            </label>
            <input
              type="text"
              id="title"
              value={newPost.title}
              onChange={(e) => setNewPost(prev => ({ ...prev, title: e.target.value }))}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              required
            />
          </div>

          <div>
            <label htmlFor="content" className="block text-sm font-medium text-gray-700">
              Content
            </label>
            <textarea
              id="content"
              value={newPost.content}
              onChange={(e) => setNewPost(prev => ({ ...prev, content: e.target.value }))}
              rows={4}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
              required
            />
          </div>

          <div className="flex items-center space-x-4">
            <div className="flex items-center">
              <input
                type="checkbox"
                id="anonymous"
                checked={newPost.is_anonymous}
                onChange={(e) => setNewPost(prev => ({ ...prev, is_anonymous: e.target.checked }))}
                className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              <label htmlFor="anonymous" className="ml-2 text-sm text-gray-600">
                Post anonymously
              </label>
            </div>

            <div className="flex space-x-2">
              <button
                type="button"
                onClick={() => {
                  const url = prompt('Enter video URL:');
                  if (url) handleAddMedia('video', url);
                }}
                className="p-2 text-gray-500 hover:text-indigo-600"
                title="Add video"
              >
                <Video className="h-5 w-5" />
              </button>
              <button
                type="button"
                onClick={() => {
                  const url = prompt('Enter audio URL:');
                  if (url) handleAddMedia('audio', url);
                }}
                className="p-2 text-gray-500 hover:text-indigo-600"
                title="Add audio"
              >
                <Music className="h-5 w-5" />
              </button>
              <button
                type="button"
                onClick={() => {
                  const url = prompt('Enter image URL:');
                  if (url) handleAddMedia('image', url);
                }}
                className="p-2 text-gray-500 hover:text-indigo-600"
                title="Add image"
              >
                <Image className="h-5 w-5" />
              </button>
            </div>
          </div>

          {newPost.media.length > 0 && (
            <div className="flex flex-wrap gap-2">
              {newPost.media.map((media, index) => (
                <div key={index} className="flex items-center bg-gray-100 rounded px-3 py-1">
                  {media.type === 'video' && <Video className="h-4 w-4 mr-2" />}
                  {media.type === 'audio' && <Music className="h-4 w-4 mr-2" />}
                  {media.type === 'image' && <Image className="h-4 w-4 mr-2" />}
                  <span className="text-sm text-gray-600">{media.url.substring(0, 20)}...</span>
                  <button
                    type="button"
                    onClick={() => setNewPost(prev => ({
                      ...prev,
                      media: prev.media.filter((_, i) => i !== index)
                    }))}
                    className="ml-2 text-red-500 hover:text-red-700"
                  >
                    ×
                  </button>
                </div>
              ))}
            </div>
          )}

          <button
            type="submit"
            className="w-full px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
          >
            Create Post
          </button>
        </form>
      )}

      <div className="space-y-6">
        {posts.map((post) => (
          <article key={post.id} className="bg-white p-6 rounded-lg shadow">
            <div className="flex items-start justify-between">
              <div className="flex items-center space-x-3">
                {!post.is_anonymous && (
                  <div className="flex-shrink-0">
                    <img
                      src={post.users?.avatar_url || 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80'}
                      alt={post.users?.username}
                      className="h-10 w-10 rounded-full"
                    />
                  </div>
                )}
                <div>
                  <p className="text-sm font-medium text-gray-900">
                    {post.is_anonymous ? 'Anonymous' : post.users?.username}
                  </p>
                  <p className="text-sm text-gray-500">
                    <Clock className="inline h-4 w-4 mr-1" />
                    {formatDistanceToNow(new Date(post.created_at), { addSuffix: true })}
                  </p>
                </div>
              </div>
            </div>

            <h2 className="mt-4 text-xl font-semibold text-gray-900">{post.title}</h2>
            <p className="mt-2 text-gray-600">{post.content}</p>

            {post.media_attachments?.length > 0 && (
              <div className="mt-4 space-y-4">
                {post.media_attachments.map((media, index) => (
                  <MediaAttachment key={index} media={media} />
                ))}
              </div>
            )}

            <div className="mt-4 flex items-center space-x-4 text-sm text-gray-500">
              <button
                onClick={() => handleLikePost(post.id, post.user_liked)}
                className={`flex items-center space-x-1 ${post.user_liked ? 'text-indigo-600' : ''}`}
              >
                <ThumbsUp className="h-4 w-4" />
                <span>{post.likes || 0}</span>
              </button>
              <button
                onClick={() => setSelectedPost(selectedPost?.id === post.id ? null : post)}
                className="flex items-center space-x-1"
              >
                <MessageSquare className="h-4 w-4" />
                <span>{post.comments?.length || 0} comments</span>
              </button>
            </div>

            {selectedPost?.id === post.id && (
              <div className="mt-4 space-y-4">
                <div className="pl-6 space-y-4">
                  {post.comments?.map((comment) => (
                    <div key={comment.id} className="bg-gray-50 p-4 rounded-lg">
                      <div className="flex items-center space-x-2 mb-2">
                        {!comment.is_anonymous && comment.users?.avatar_url && (
                          <img
                            src={comment.users.avatar_url}
                            alt=""
                            className="h-6 w-6 rounded-full"
                          />
                        )}
                        <span className="text-sm font-medium">
                          {comment.is_anonymous ? 'Anonymous' : comment.users?.username}
                        </span>
                        <span className="text-xs text-gray-500">
                          {formatDistanceToNow(new Date(comment.created_at), { addSuffix: true })}
                        </span>
                      </div>
                      <p className="text-gray-600">{comment.content}</p>
                    </div>
                  ))}
                </div>

                <div className="pl-6">
                  <div className="flex items-center space-x-2 mb-2">
                    <input
                      type="checkbox"
                      id={`anonymous-comment-${post.id}`}
                      checked={newComment.is_anonymous}
                      onChange={(e) => setNewComment(prev => ({ ...prev, is_anonymous: e.target.checked }))}
                      className="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                    />
                    <label htmlFor={`anonymous-comment-${post.id}`} className="text-sm text-gray-600">
                      Comment anonymously
                    </label>
                  </div>
                  <div className="flex space-x-2">
                    <input
                      type="text"
                      value={newComment.content}
                      onChange={(e) => setNewComment(prev => ({ ...prev, content: e.target.value }))}
                      placeholder="Write a comment..."
                      className="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-300 focus:ring focus:ring-indigo-200 focus:ring-opacity-50"
                    />
                    <button
                      onClick={() => handleSubmitComment(post.id)}
                      className="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700"
                    >
                      Post
                    </button>
                  </div>
                </div>
              </div>
            )}
          </article>
        ))}
      </div>
    </div>
  );
}