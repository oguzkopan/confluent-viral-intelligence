package services

import (
	"context"
	"sort"
	"time"

	"confluent-viral-intelligence/internal/logger"
	"confluent-viral-intelligence/internal/models"
	"google.golang.org/api/iterator"
)

// DashboardAnalytics provides comprehensive analytics for the dashboard
type DashboardAnalytics struct {
	firestoreClient *FirestoreClient
	ctx             context.Context
}

// NewDashboardAnalytics creates a new dashboard analytics service
func NewDashboardAnalytics(firestoreClient *FirestoreClient) *DashboardAnalytics {
	return &DashboardAnalytics{
		firestoreClient: firestoreClient,
		ctx:             context.Background(),
	}
}

// DashboardMetrics represents comprehensive dashboard metrics
type DashboardMetrics struct {
	TotalViews        int64                `json:"totalViews"`
	TotalInteractions int64                `json:"totalInteractions"`
	ViralPosts        int                  `json:"viralPosts"`
	TotalPosts        int                  `json:"totalPosts"`
	ActiveUsers       int                  `json:"activeUsers"`
	TopContentTypes   map[string]int       `json:"topContentTypes"`
	EngagementRate    float64              `json:"engagementRate"`
	AverageScore      float64              `json:"averageScore"`
	TopPosts          []models.TrendingScore `json:"topPosts"`
	TopCreators       []CreatorMetrics     `json:"topCreators"`
	CalculatedAt      time.Time            `json:"calculatedAt"`
}

// CreatorMetrics represents metrics for a creator
type CreatorMetrics struct {
	UserID             string    `json:"userId"`
	Username           string    `json:"username"`
	DisplayName        string    `json:"displayName"`
	PhotoURL           string    `json:"photoUrl"`
	TotalScore         float64   `json:"totalScore"`
	TotalViews         int64     `json:"totalViews"`
	TotalLikes         int64     `json:"totalLikes"`
	TotalComments      int64     `json:"totalComments"`
	PostCount          int       `json:"postCount"`
	ViralPostCount     int       `json:"viralPostCount"`
	FollowerCount      int       `json:"followerCount"`
	EngagementRate     float64   `json:"engagementRate"`
	AverageScore       float64   `json:"averageScore"`
	CalculatedAt       time.Time `json:"calculatedAt"`
}

// GetDashboardMetrics returns comprehensive metrics for the dashboard
func (da *DashboardAnalytics) GetDashboardMetrics() (*DashboardMetrics, error) {
	logger.Debug("📊 Calculating dashboard metrics...")
	
	metrics := &DashboardMetrics{
		TopContentTypes: make(map[string]int),
		TopPosts:        []models.TrendingScore{},
		TopCreators:     []CreatorMetrics{},
		CalculatedAt:    time.Now(),
	}
	
	// Get all trending scores
	iter := da.firestoreClient.client.Collection("trending_scores").Documents(da.ctx)
	
	var allScores []models.TrendingScore
	totalScore := 0.0
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {			continue
		}
		
		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			continue
		}
		
		allScores = append(allScores, score)
		
		// Aggregate metrics
		metrics.TotalViews += score.ViewCount
		metrics.TotalInteractions += score.LikeCount + score.CommentCount + score.ShareCount
		totalScore += score.Score
		
		// Count viral posts (score > 100 or viral_probability > 0.7)
		if score.Score > 100 || score.ViralProbability > 0.7 {
			metrics.ViralPosts++
		}
	}
	
	metrics.TotalPosts = len(allScores)
	
	// Calculate average score
	if metrics.TotalPosts > 0 {
		metrics.AverageScore = totalScore / float64(metrics.TotalPosts)
	}
	
	// Calculate engagement rate
	if metrics.TotalViews > 0 {
		metrics.EngagementRate = (float64(metrics.TotalInteractions) / float64(metrics.TotalViews)) * 100
	}
	
	// Get top posts (top 3) and enrich with post data
	sort.Slice(allScores, func(i, j int) bool {
		return allScores[i].Score > allScores[j].Score
	})
	
	// Enrich posts with actual post data and filter out test/invalid posts
	enrichedPosts := []models.TrendingScore{}
	
	for _, score := range allScores {
		// Skip if we already have 3 posts
		if len(enrichedPosts) >= 3 {
			break
		}
		
		// Get post details
		postDoc, err := da.firestoreClient.client.Collection("posts").Doc(score.PostID).Get(da.ctx)
		if err != nil {			continue // Skip posts that don't exist in posts collection
		}
		
		var postData map[string]interface{}
		if err := postDoc.DataTo(&postData); err != nil {			continue
		}
		
		// Add post data to the score
		if contentType, ok := postData["contentType"].(string); ok {
			score.ContentType = contentType
		}
		if outputUrls, ok := postData["outputUrls"].([]interface{}); ok && len(outputUrls) > 0 {
			urls := make([]string, 0, len(outputUrls))
			for _, url := range outputUrls {
				if urlStr, ok := url.(string); ok {
					urls = append(urls, urlStr)
				}
			}
			score.OutputURLs = urls
		}
		if title, ok := postData["title"].(string); ok {
			score.Title = title
		}
		if description, ok := postData["description"].(string); ok {
			score.Description = description
		}
		if instructions, ok := postData["instructions"].(string); ok {
			score.Instructions = instructions
		}
		
		// Only add posts that have actual content
		if score.ContentType != "" && len(score.OutputURLs) > 0 {
			enrichedPosts = append(enrichedPosts, score)
			logger.Infof("✅ Enriched post %s: type=%s, urls=%d", score.PostID, score.ContentType, len(score.OutputURLs))
		} else {
			logger.Debugf(" Skipping post %s: no content (type=%s, urls=%d)", score.PostID, score.ContentType, len(score.OutputURLs))
		}
	}
	
	metrics.TopPosts = enrichedPosts
	logger.Debugf("📊 Top posts with content: %d", len(enrichedPosts))
	
	// Get content type distribution and active users
	contentTypes := make(map[string]int)
	activeUsers := make(map[string]bool)
	
	for _, score := range allScores {
		// Get post details for content type and user
		postDoc, err := da.firestoreClient.client.Collection("posts").Doc(score.PostID).Get(da.ctx)
		if err != nil {
			continue
		}
		
		var postData map[string]interface{}
		if err := postDoc.DataTo(&postData); err != nil {
			continue
		}
		
		// Track content type
		if contentType, ok := postData["contentType"].(string); ok {
			contentTypes[contentType]++
		}
		
		// Track active users
		if userID, ok := postData["userId"].(string); ok {
			activeUsers[userID] = true
		}
	}
	
	metrics.TopContentTypes = contentTypes
	metrics.ActiveUsers = len(activeUsers)
	
	logger.Infof("✅ Dashboard metrics calculated: posts=%d, views=%d, interactions=%d, viral=%d",
		metrics.TotalPosts, metrics.TotalViews, metrics.TotalInteractions, metrics.ViralPosts)
	
	return metrics, nil
}

// GetTopCreators returns the top creators based on their content performance
func (da *DashboardAnalytics) GetTopCreators(limit int) ([]CreatorMetrics, error) {
	logger.Debugf("📊 Calculating top %d creators...", limit)
	
	// Get all trending scores
	iter := da.firestoreClient.client.Collection("trending_scores").Documents(da.ctx)
	
	// Aggregate by user
	creatorMap := make(map[string]*CreatorMetrics)
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			continue
		}
		
		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			continue
		}
		
		// Get post details to find user
		postDoc, err := da.firestoreClient.client.Collection("posts").Doc(score.PostID).Get(da.ctx)
		if err != nil {
			continue
		}
		
		var postData map[string]interface{}
		if err := postDoc.DataTo(&postData); err != nil {
			continue
		}
		
		userID, ok := postData["userId"].(string)
		if !ok || userID == "" {
			continue
		}
		
		// Initialize creator metrics if not exists
		if _, exists := creatorMap[userID]; !exists {
			creatorMap[userID] = &CreatorMetrics{
				UserID:       userID,
				CalculatedAt: time.Now(),
			}
		}
		
		creator := creatorMap[userID]
		creator.PostCount++
		creator.TotalScore += score.Score
		creator.TotalViews += score.ViewCount
		creator.TotalLikes += score.LikeCount
		creator.TotalComments += score.CommentCount
		
		// Count viral posts
		if score.Score > 100 || score.ViralProbability > 0.7 {
			creator.ViralPostCount++
		}
	}
	
	// Enrich with user data and calculate averages
	creators := make([]CreatorMetrics, 0, len(creatorMap))
	for userID, creator := range creatorMap {
		// Get user details
		userDoc, err := da.firestoreClient.client.Collection("users").Doc(userID).Get(da.ctx)
		if err != nil {			continue
		}
		
		var userData map[string]interface{}
		if err := userDoc.DataTo(&userData); err != nil {
			continue
		}
		
		// Set user details
		if username, ok := userData["username"].(string); ok {
			creator.Username = username
		}
		if displayName, ok := userData["displayName"].(string); ok {
			creator.DisplayName = displayName
		}
		if photoURL, ok := userData["photoURL"].(string); ok {
			creator.PhotoURL = photoURL
		}
		if followerCount, ok := userData["followerCount"].(int64); ok {
			creator.FollowerCount = int(followerCount)
		}
		
		// Calculate averages
		if creator.PostCount > 0 {
			creator.AverageScore = creator.TotalScore / float64(creator.PostCount)
		}
		if creator.TotalViews > 0 {
			totalEngagement := creator.TotalLikes + creator.TotalComments
			creator.EngagementRate = (float64(totalEngagement) / float64(creator.TotalViews)) * 100
		}
		
		creators = append(creators, *creator)
	}
	
	// Sort by total score
	sort.Slice(creators, func(i, j int) bool {
		return creators[i].TotalScore > creators[j].TotalScore
	})
	
	// Limit results
	if len(creators) > limit {
		creators = creators[:limit]
	}
	
	logger.Infof("✅ Top creators calculated: %d creators", len(creators))
	return creators, nil
}

// GetContentTypeBreakdown returns breakdown of content by type
func (da *DashboardAnalytics) GetContentTypeBreakdown() (map[string]ContentTypeMetrics, error) {
	logger.Debug("📊 Calculating content type breakdown...")
	
	breakdown := make(map[string]ContentTypeMetrics)
	
	// Get all posts
	iter := da.firestoreClient.client.Collection("posts").
		Where("isPublic", "==", true).
		Limit(1000).
		Documents(da.ctx)
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			continue
		}
		
		var postData map[string]interface{}
		if err := doc.DataTo(&postData); err != nil {
			continue
		}
		
		contentType, ok := postData["contentType"].(string)
		if !ok {
			contentType = "unknown"
		}
		
		metrics := breakdown[contentType]
		metrics.ContentType = contentType
		metrics.Count++
		
		if viewCount, ok := postData["viewCount"].(int64); ok {
			metrics.TotalViews += viewCount
		}
		if likeCount, ok := postData["likeCount"].(int64); ok {
			metrics.TotalLikes += likeCount
		}
		
		breakdown[contentType] = metrics
	}
	
	// Calculate averages
	for contentType, metrics := range breakdown {
		if metrics.Count > 0 {
			metrics.AvgViews = float64(metrics.TotalViews) / float64(metrics.Count)
			metrics.AvgLikes = float64(metrics.TotalLikes) / float64(metrics.Count)
		}
		breakdown[contentType] = metrics
	}
	
	logger.Infof("✅ Content type breakdown calculated: %d types", len(breakdown))
	return breakdown, nil
}

// ContentTypeMetrics represents metrics for a content type
type ContentTypeMetrics struct {
	ContentType string  `json:"contentType"`
	Count       int     `json:"count"`
	TotalViews  int64   `json:"totalViews"`
	TotalLikes  int64   `json:"totalLikes"`
	AvgViews    float64 `json:"avgViews"`
	AvgLikes    float64 `json:"avgLikes"`
}

// GetEngagementTrends returns engagement trends over time
func (da *DashboardAnalytics) GetEngagementTrends(days int) ([]EngagementTrend, error) {
	logger.Debugf("📊 Calculating engagement trends for last %d days...", days)
	
	trends := make([]EngagementTrend, 0, days)
	
	for i := 0; i < days; i++ {
		date := time.Now().AddDate(0, 0, -i)
		startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
		endOfDay := startOfDay.Add(24 * time.Hour)
		
		trend := EngagementTrend{
			Date: startOfDay,
		}
		
		// Query posts created on this day
		iter := da.firestoreClient.client.Collection("posts").
			Where("isPublic", "==", true).
			Where("createdAt", ">=", startOfDay).
			Where("createdAt", "<", endOfDay).
			Documents(da.ctx)
		
		for {
			doc, err := iter.Next()
			if err == iterator.Done {
				break
			}
			if err != nil {
				continue
			}
			
			var postData map[string]interface{}
			if err := doc.DataTo(&postData); err != nil {
				continue
			}
			
			trend.PostCount++
			
			if viewCount, ok := postData["viewCount"].(int64); ok {
				trend.Views += viewCount
			}
			if likeCount, ok := postData["likeCount"].(int64); ok {
				trend.Likes += likeCount
			}
			if commentCount, ok := postData["commentCount"].(int64); ok {
				trend.Comments += commentCount
			}
		}
		
		trends = append(trends, trend)
	}
	
	// Reverse to get chronological order
	for i, j := 0, len(trends)-1; i < j; i, j = i+1, j-1 {
		trends[i], trends[j] = trends[j], trends[i]
	}
	
	logger.Infof("✅ Engagement trends calculated: %d days", len(trends))
	return trends, nil
}

// GetTrendingPostsWithContent returns trending posts that have actual content (for trending feed)
func (da *DashboardAnalytics) GetTrendingPostsWithContent(limit int) ([]models.TrendingScore, error) {
	logger.Debugf("📊 Getting trending posts with content (limit: %d)...", limit)
	
	// Get all trending scores
	iter := da.firestoreClient.client.Collection("trending_scores").Documents(da.ctx)
	
	var allScores []models.TrendingScore
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {			continue
		}
		
		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			continue
		}
		
		allScores = append(allScores, score)
	}
	
	// Sort by score
	sort.Slice(allScores, func(i, j int) bool {
		return allScores[i].Score > allScores[j].Score
	})
	
	// Enrich posts with actual post data and filter out posts without content
	enrichedPosts := []models.TrendingScore{}
	
	for _, score := range allScores {
		// Skip if we already have enough posts
		if len(enrichedPosts) >= limit {
			break
		}
		
		// Get post details
		postDoc, err := da.firestoreClient.client.Collection("posts").Doc(score.PostID).Get(da.ctx)
		if err != nil {			continue // Skip posts that don't exist in posts collection
		}
		
		var postData map[string]interface{}
		if err := postDoc.DataTo(&postData); err != nil {			continue
		}
		
		// Add post data to the score
		if contentType, ok := postData["contentType"].(string); ok {
			score.ContentType = contentType
		}
		if outputUrls, ok := postData["outputUrls"].([]interface{}); ok && len(outputUrls) > 0 {
			urls := make([]string, 0, len(outputUrls))
			for _, url := range outputUrls {
				if urlStr, ok := url.(string); ok {
					urls = append(urls, urlStr)
				}
			}
			score.OutputURLs = urls
		}
		if title, ok := postData["title"].(string); ok {
			score.Title = title
		}
		if description, ok := postData["description"].(string); ok {
			score.Description = description
		}
		if instructions, ok := postData["instructions"].(string); ok {
			score.Instructions = instructions
		}
		
		// Only add posts that have actual content
		if score.ContentType != "" && len(score.OutputURLs) > 0 {
			enrichedPosts = append(enrichedPosts, score)
			logger.Infof("✅ Enriched post %s: type=%s, urls=%d", score.PostID, score.ContentType, len(score.OutputURLs))
		} else {
			logger.Debugf(" Skipping post %s: no content (type=%s, urls=%d)", score.PostID, score.ContentType, len(score.OutputURLs))
		}
	}
	
	logger.Debugf("📊 Trending posts with content: %d", len(enrichedPosts))
	return enrichedPosts, nil
}

// GetTrendingPostsByContentType returns trending posts filtered by content type
func (da *DashboardAnalytics) GetTrendingPostsByContentType(contentType string, limit int) ([]models.TrendingScore, error) {
	logger.Debugf("📊 Getting trending posts for content type '%s' (limit: %d)...", contentType, limit)
	
	// Get all trending scores
	iter := da.firestoreClient.client.Collection("trending_scores").Documents(da.ctx)
	
	var allScores []models.TrendingScore
	
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {			continue
		}
		
		var score models.TrendingScore
		if err := doc.DataTo(&score); err != nil {
			continue
		}
		
		allScores = append(allScores, score)
	}
	
	// Sort by score
	sort.Slice(allScores, func(i, j int) bool {
		return allScores[i].Score > allScores[j].Score
	})
	
	// Enrich posts with actual post data and filter by content type
	enrichedPosts := []models.TrendingScore{}
	
	for _, score := range allScores {
		// Skip if we already have enough posts
		if len(enrichedPosts) >= limit {
			break
		}
		
		// Get post details
		postDoc, err := da.firestoreClient.client.Collection("posts").Doc(score.PostID).Get(da.ctx)
		if err != nil {			continue
		}
		
		var postData map[string]interface{}
		if err := postDoc.DataTo(&postData); err != nil {			continue
		}
		
		// Add post data to the score
		if ct, ok := postData["contentType"].(string); ok {
			score.ContentType = ct
		}
		
		// Skip if content type doesn't match
		if score.ContentType != contentType {
			continue
		}
		
		if outputUrls, ok := postData["outputUrls"].([]interface{}); ok && len(outputUrls) > 0 {
			urls := make([]string, 0, len(outputUrls))
			for _, url := range outputUrls {
				if urlStr, ok := url.(string); ok {
					urls = append(urls, urlStr)
				}
			}
			score.OutputURLs = urls
		}
		if title, ok := postData["title"].(string); ok {
			score.Title = title
		}
		if description, ok := postData["description"].(string); ok {
			score.Description = description
		}
		if instructions, ok := postData["instructions"].(string); ok {
			score.Instructions = instructions
		}
		
		// Only add posts that have actual content
		if len(score.OutputURLs) > 0 {
			enrichedPosts = append(enrichedPosts, score)
			logger.Infof("✅ Enriched post %s: type=%s, urls=%d", score.PostID, score.ContentType, len(score.OutputURLs))
		}
	}
	
	logger.Debugf("📊 Trending posts for type '%s': %d", contentType, len(enrichedPosts))
	return enrichedPosts, nil
}

// EngagementTrend represents engagement metrics for a specific day
type EngagementTrend struct {
	Date      time.Time `json:"date"`
	PostCount int       `json:"postCount"`
	Views     int64     `json:"views"`
	Likes     int64     `json:"likes"`
	Comments  int64     `json:"comments"`
}
