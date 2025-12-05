# Flink SQL Setup - Task 13

This directory contains all the resources needed to execute Task 13: Execute Flink SQL in Confluent Cloud.

## 📁 Files Overview

### Core Files

| File | Purpose | When to Use |
|------|---------|-------------|
| **aggregations.sql** | Main SQL statements | Execute in Confluent Cloud |
| **TASK_13_INSTRUCTIONS.md** | Task overview and quick start | Start here |
| **STEP_BY_STEP_EXECUTION.md** | Detailed execution guide | First-time or need help |
| **QUICK_REFERENCE.md** | Quick reference card | Quick lookups |
| **EXECUTION_CHECKLIST.md** | Original detailed checklist | Alternative guide |
| **EXECUTION_PROGRESS.md** | Progress tracker | Track your progress |
| **verify-flink-setup.sh** | Verification script | After manual execution |

## 🚀 Quick Start

### 1. Read Instructions
```bash
# Start with the task instructions
cat TASK_13_INSTRUCTIONS.md
```

### 2. Follow Detailed Guide
```bash
# Open the step-by-step guide
cat STEP_BY_STEP_EXECUTION.md
```

### 3. Execute in Confluent Cloud
1. Get bootstrap server URL
2. Update `aggregations.sql`
3. Execute statements in Flink SQL workspace
4. Verify jobs are running

### 4. Verify Setup
```bash
# Run verification script
./verify-flink-setup.sh
```

## 📚 Documentation Structure

```
flink-sql/
├── aggregations.sql                    # Main SQL file (execute this)
├── README.md                           # This file
├── TASK_13_INSTRUCTIONS.md            # Task overview
├── STEP_BY_STEP_EXECUTION.md          # Detailed guide
├── QUICK_REFERENCE.md                 # Quick reference
├── EXECUTION_CHECKLIST.md             # Original checklist
├── EXECUTION_PROGRESS.md              # Progress tracker
└── verify-flink-setup.sh              # Verification script
```

## 🎯 What This Task Does

### Creates Tables (4)
- `user_interactions` - Input from Kafka
- `view_events` - Input from Kafka
- `remix_events` - Input from Kafka
- `trending_scores` - Output to Kafka

### Starts Jobs (2)
- **Real-Time Trending:** Calculates scores every minute
- **Remix Boost:** Boosts scores for remixed content

### Creates Views (4 - Optional)
- `view_aggregations` - View metrics
- `remix_aggregations` - Remix metrics
- `hourly_trending` - Hourly trends
- `top_trending` - Top 20 posts
- `user_engagement_patterns` - User behavior

## ✅ Success Criteria

- [ ] 4 tables created
- [ ] 2 jobs running
- [ ] Test data produces output
- [ ] Queries return results
- [ ] No errors in logs

## 🔗 Prerequisites

Before starting:
- ✅ Confluent Cloud account
- ✅ Kafka cluster running
- ✅ All 6 topics created
- ✅ Flink compute pool created
- ✅ Bootstrap server URL obtained

## 📖 Recommended Reading Order

1. **TASK_13_INSTRUCTIONS.md** - Overview and quick start
2. **STEP_BY_STEP_EXECUTION.md** - Detailed instructions
3. **QUICK_REFERENCE.md** - Keep open for reference
4. **EXECUTION_PROGRESS.md** - Track your progress

## 🧪 Testing

### Produce Test Event
```bash
echo '{"post_id":"test-1","user_id":"user-1","event_type":"view","event_timestamp":"2024-12-05T12:00:00.000Z"}' | \
  confluent kafka topic produce user-interactions
```

### Verify Output
```bash
confluent kafka topic consume trending-scores --from-beginning
```

### Run Verification
```bash
./verify-flink-setup.sh
```

## 🐛 Troubleshooting

### Common Issues

1. **"Table already exists"**
   - Solution: `DROP TABLE IF EXISTS table_name;`

2. **"Topic not found"**
   - Solution: Verify topic exists in Confluent Cloud

3. **"No data in output"**
   - Solution: Wait 1-2 minutes for window to close

4. **"Job keeps restarting"**
   - Solution: Check job logs for errors

See **QUICK_REFERENCE.md** for more troubleshooting tips.

## 📊 Expected Results

### Trending Score Calculation
For a post with 1 view, 1 like, 1 comment, 1 share:

```
Score = (1 × 1) + (1 × 2) + (1 × 3) + (1 × 5) = 11.0
```

### Output Format
```json
{
  "post_id": "test-post-1",
  "score": 11.0,
  "engagement_velocity": 4.0,
  "view_count": 1,
  "like_count": 1,
  "comment_count": 1,
  "share_count": 1,
  "remix_count": 0
}
```

## 🔧 Useful Commands

### Confluent CLI
```bash
# List topics
confluent kafka topic list

# Produce message
echo '{"key":"value"}' | confluent kafka topic produce topic-name

# Consume messages
confluent kafka topic consume topic-name --from-beginning
```

### Flink SQL
```sql
-- List tables
SHOW TABLES;

-- Query table
SELECT * FROM trending_scores LIMIT 10;

-- Check top trending
SELECT * FROM top_trending;
```

## 📈 Monitoring

### Job Metrics to Watch
- **Status:** Should be RUNNING
- **Records Sent:** Should increase over time
- **Backlog:** Should be near 0
- **Errors:** Should be 0

### Access Metrics
1. Go to Confluent Cloud Console
2. Navigate to Flink → Jobs
3. Click on job name
4. Review Metrics tab

## 💰 Cost Information

- **Flink Compute Pool:** ~$0.50/CFU/hour
- **5 CFUs:** ~$2.50/hour (~$1,800/month)
- **Recommendation:** Start with 5 CFUs

## 🎬 Next Steps

After Task 13:
1. ✅ Flink SQL is processing events
2. ➡️ Task 14: Create React Dashboard
3. ➡️ Task 15: Create Test Data Generator
4. ➡️ Task 16: Deploy Streaming Service

## 🆘 Getting Help

1. **Check documentation:**
   - Start with TASK_13_INSTRUCTIONS.md
   - Use STEP_BY_STEP_EXECUTION.md for details
   - Reference QUICK_REFERENCE.md for commands

2. **Run verification:**
   ```bash
   ./verify-flink-setup.sh
   ```

3. **External resources:**
   - [Flink SQL Documentation](https://docs.confluent.io/cloud/current/flink/overview.html)
   - [Confluent Community Forum](https://forum.confluent.io/)
   - Confluent Support (if available)

## 📝 Notes

- Flink SQL workspace auto-saves queries
- Jobs run continuously until stopped
- Monitor job metrics regularly
- Set up alerts for failures
- Keep job logs for troubleshooting

## ✨ Tips

- **Save queries:** Workspace auto-saves
- **Monitor jobs:** Keep Jobs page open
- **Test incrementally:** Verify each step
- **Use comments:** Track executed statements
- **Check logs:** Review for errors

---

**Task:** 13. Execute Flink SQL in Confluent Cloud  
**Status:** Ready for Execution  
**Estimated Time:** 30-45 minutes  
**Difficulty:** Intermediate  

**Requirements Validated:**
- Requirement 2.1: 1-minute tumbling window aggregations
- Requirement 2.4: Real-time processing and publishing
