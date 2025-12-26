// Firebase service to fetch full post data
import { initializeApp } from 'firebase/app';
import { getFirestore, collection, doc, getDoc, getDocs, query, where, limit as firestoreLimit } from 'firebase/firestore';

// Firebase config (same as main app)
const firebaseConfig = {
  apiKey: "AIzaSyCtKhTf4Ed9QW-i7AA0zlTgVawj7e-FsMI",
  authDomain: "yarimai.firebaseapp.com",
  projectId: "yarimai",
  storageBucket: "yarimai.firebasestorage.app",
  messagingSenderId: "799474804867",
  appId: "1:799474804867:web:ee3094423fdbe3c902d3b6"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

/**
 * Fetch full post data from Firestore
 * @param {string} postId - Post ID
 * @returns {Promise<Object|null>} Full post data
 */
export async function fetchPostData(postId) {
  try {
    const postRef = doc(db, 'posts', postId);
    const postSnap = await getDoc(postRef);
    
    if (postSnap.exists()) {
      return {
        id: postSnap.id,
        ...postSnap.data()
      };
    }
    return null;
  } catch (error) {
    console.error('Error fetching post:', postId, error);
    return null;
  }
}

/**
 * Enrich trending posts with full Firestore data
 * @param {Array} trendingPosts - Posts from viral intelligence API
 * @returns {Promise<Array>} Enriched posts with full data
 */
export async function enrichTrendingPosts(trendingPosts) {
  const enrichedPosts = await Promise.all(
    trendingPosts.map(async (trendingPost) => {
      const fullPost = await fetchPostData(trendingPost.post_id);
      
      if (fullPost) {
        return {
          ...fullPost,
          post_id: trendingPost.post_id,
          score: trendingPost.score,
          engagement_velocity: trendingPost.engagement_velocity,
          viral_probability: trendingPost.viral_probability,
          // Map Firestore fields to expected format
          content_type: fullPost.contentType || fullPost.content_type,
          output_urls: fullPost.outputUrls || fullPost.output_urls || [],
          output_text: fullPost.outputText || fullPost.output_text,
          like_count: fullPost.likeCount || fullPost.like_count || 0,
          comment_count: fullPost.commentCount || fullPost.comment_count || 0,
          view_count: fullPost.viewCount || fullPost.view_count || 0,
          share_count: fullPost.shareCount || fullPost.share_count || 0,
          user: fullPost.user || null
        };
      }
      
      // Return trending data even if full post not found
      return trendingPost;
    })
  );
  
  return enrichedPosts.filter(post => post !== null);
}

/**
 * Fetch trending posts directly from Firestore
 * @param {number} limit - Number of posts to fetch
 * @returns {Promise<Array>} Trending posts
 */
export async function fetchTrendingFromFirestore(limit = 20) {
  try {
    const postsRef = collection(db, 'posts');
    const q = query(
      postsRef,
      where('isPublic', '==', true),
      firestoreLimit(limit)
    );
    
    const querySnapshot = await getDocs(q);
    const posts = [];
    
    querySnapshot.forEach((doc) => {
      const data = doc.data();
      posts.push({
        id: doc.id,
        post_id: doc.id,
        ...data,
        content_type: data.contentType || data.content_type,
        output_urls: data.outputUrls || data.output_urls || [],
        output_text: data.outputText || data.output_text,
        like_count: data.likeCount || data.like_count || 0,
        comment_count: data.commentCount || data.comment_count || 0,
        view_count: data.viewCount || data.view_count || 0,
        share_count: data.shareCount || data.share_count || 0
      });
    });
    
    return posts;
  } catch (error) {
    console.error('Error fetching trending from Firestore:', error);
    return [];
  }
}
