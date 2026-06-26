Product Requirements Document: AI Fitness Coach App
1. Product Name
Working Name: FitPilot AI
Alternative Names: MacroMind, CutCoach, LeanOS, FitOS, CalorieCoach AI

2. Product Summary
FitPilot AI is an AI-powered fitness, nutrition, hydration, and weight-loss coaching app designed to help users lose fat, preserve muscle, and understand their body through conversational tracking.
Unlike traditional calorie trackers that require manual search and data entry, FitPilot AI allows users to interact naturally through chat, voice, photos, and quick commands. The app estimates meals, tracks macros, logs water, interprets weight fluctuations, estimates workout calorie burn, and provides daily and weekly coaching.
The core product is not just a calorie tracker. It is a personal AI fitness operating system that helps users make better decisions every day.

3. Problem Statement
Users trying to lose weight often struggle with:
Knowing how many calories and macros they should eat.
Logging food consistently.
Estimating calories from photos or vague meal descriptions.
Understanding daily weight fluctuations.
Staying motivated when progress feels slow.
Adjusting food choices around workouts.
Knowing whether going over calorie targets matters.
Maintaining enough protein while dieting.
Avoiding repetitive, boring meals.
Understanding their true maintenance calories.
Connecting nutrition, workouts, steps, water, and weight trend.
Existing apps are mostly data-entry tools. They tell users numbers but do not provide reasoning, reassurance, or coaching.

4. Product Vision
To build an AI-powered fitness coach that helps users lose weight intelligently by combining calorie tracking, macro coaching, workout logging, hydration tracking, weight trend analysis, and behavioral guidance into one conversational iOS app.
The product should feel like talking to a knowledgeable coach, not filling out a spreadsheet.

5. Target Users
Primary User
A fitness-conscious beginner or intermediate user who wants to lose weight while preserving muscle.
Example profile:
Male or female, 18–40 years old.
Has a weight-loss goal.
Strength trains or wants to begin strength training.
Wants to track calories but finds traditional apps tedious.
Needs coaching, not just numbers.
May use protein powder and simple meal prep.
Wants to understand maintenance, deficit, and body-weight trends.
Secondary Users
People doing body recomposition.
Users maintaining weight after a cut.
Gym-goers tracking strength and nutrition together.
Busy professionals who want low-friction food logging.
Users who prefer chat or voice over manual forms.

6. Core Use Cases
Use Case 1: Start a New Day
User opens the app and starts a new tracking day.
User input:
New day
Weight 90.15
System actions:
Reset daily food log.
Reset water tracker.
Reset workout log.
Store morning weight.
Show daily targets.
Provide quick coaching note.

Use Case 2: Log Food via Chat
User input:
Log 3 scoops ON whey
System actions:
Parse food item.
Estimate calories and macros.
Add to daily totals.
Show remaining calories, protein, carbs, fat.
Provide coaching note.

Use Case 3: Log Food via Photo
User uploads a meal photo.
System actions:
Detect visible food items.
Estimate portion sizes.
Return calories and macros with confidence score.
Ask clarification if needed.
Allow user to confirm before logging.

Use Case 4: Ask Before Eating
User input:
Should I eat this?
I want a stuffed kebab for dinner.
System actions:
Estimate planned food.
Compare against remaining calorie budget.
Suggest lunch/dinner allocation.
Recommend portion adjustments.
Do not log unless user confirms.

Use Case 5: Log Water
User input:
Log 400ml water
System actions:
Add water to daily hydration total.
Show water consumed and remaining.
Give pacing suggestion.

Use Case 6: Log Workout
User input:
Bench 5x5 90kg
Deadlift 5x1 140kg
Lat pulldown 3x8 72kg
System actions:
Parse workout.
Estimate training volume.
Estimate calories burned.
Classify workout intensity.
Give recovery recommendations.
Store strength data for trend tracking.

Use Case 7: Daily Review
User input:
Daily review
System actions:
Summarize calories, macros, water, workout, steps, and weight.
Explain whether the day was successful.
Identify what went well.
Identify what to improve.
Give next-day recommendation.

Use Case 8: Weekly Review
System generates weekly summary.
Includes:
Average calories.
Average protein.
Average water.
Average steps.
Workouts completed.
Weight trend.
Estimated maintenance calories.
Suggested adjustments.

7. Product Goals
Goal 1: Reduce Friction
Users should be able to log meals in under 10 seconds using chat, voice, or photo.
Goal 2: Coach, Not Just Track
The app should explain what the data means.
Example:
Instead of:
You are 114 kcal over.
Say:
You are slightly over target, but most of the extra calories came from lean chicken breast. This is still a productive fat-loss day.
Goal 3: Support Muscle Retention
The app should prioritize protein intake, strength training, and sustainable deficit.
Goal 4: Prevent Overreaction
The app should help users understand water weight, glycogen, sodium, digestion, and training-related inflammation.
Goal 5: Personalize Maintenance Calories
The app should estimate user maintenance based on real-world intake, weight changes, steps, and training data.

8. Non-Goals for MVP
The MVP will not include:
Social feed.
Public leaderboard.
Full meal delivery integration.
Advanced medical nutrition planning.
Clinical dietician replacement.
Body image scoring.
Extreme dieting plans.
Complex bodybuilding contest prep.
Full Apple Watch standalone app.

9. Core Features
9.1 Onboarding
Purpose
Collect baseline data to calculate initial targets.
Required Inputs
Age
Sex
Height
Weight
Goal weight
Estimated body fat percentage, optional
Activity level
Training frequency
Average steps
Diet preference
Calorie aggressiveness preference
Example Onboarding Flow
What is your current weight?
What is your goal weight?
What is your height?
What is your age and sex?
How many days per week do you train?
How many steps do you average daily?
How aggressive do you want your cut to be?
Do you want high-protein targets?
Do you have any foods you commonly eat?
Output
The app generates:
Estimated maintenance calories.
Daily calorie target.
Protein target.
Carb target.
Fat target.
Water target.
Expected weekly weight loss.
Safety disclaimer for aggressive deficits.

9.2 Daily Dashboard
Purpose
Provide an at-a-glance view of the user’s current day.
Dashboard Metrics
Calories consumed / target
Protein consumed / target
Carbs consumed / target
Fat consumed / target
Water consumed / target
Morning weight
Workout status
Steps
Estimated deficit
AI daily coaching note
Example
Calories: 710 / 1600 kcal
Protein: 79 / 170 g
Carbs: 55 / 105 g
Fat: 19.5 / 55 g
Water: 400 / 3500 ml
Weight: 90.15 kg
Status: On track
AI Note:
You still have 890 kcal remaining and need 91 g protein. Prioritize lean protein and vegetables for your next meal.

9.3 Conversational AI Logger
Purpose
Allow users to log food, water, workouts, and weight using natural language.
Supported Commands
New day
Weight 90.15
Log 3 scoops protein
Log 400ml water
Should I eat this?
Status
Daily review
Undo last meal
Undo last water
Revert and add
Workout
Steps 7000
Requirements
The AI must:
Parse natural language.
Identify intent.
Extract quantities.
Infer common foods.
Ask clarification when needed.
Maintain daily state.
Show updated totals after logging.
Allow corrections.

9.4 Food Logging
Input Methods
Text
Voice
Photo
Barcode, post-MVP
Saved meals
Frequent foods
Food Log Data Model
Each food entry should contain:
ID
Date
Meal type
Food name
Quantity
Unit
Calories
Protein
Carbs
Fat
Fiber, optional
Sodium, optional
Confidence level
Source
Created timestamp
Edited timestamp
Confidence Levels
High: Nutrition label or verified database.
Medium: Common food estimate.
Low: Photo-only or vague portion.
Example Entry
Food: 3 scoops ON Whey
Calories: 360
Protein: 72 g
Carbs: 9 g
Fat: 4.5 g
Confidence: High

9.5 Photo-Based Meal Estimation
Purpose
Allow users to upload meal photos and receive estimated macros.
Flow
User uploads photo.
AI identifies food items.
AI estimates portions.
AI provides calories/macros.
AI states confidence.
User confirms, edits, or rejects.
Confirmed estimate is logged.
Example Output
Detected:
Chicken breast
Lentil salad
Edamame
No dressing visible
Estimated total:
555 kcal
67 g protein
29 g carbs
17.5 g fat
Confidence: Medium
Question:
Did you eat the dressing?

9.6 Meal Advisor
Purpose
Help users decide what to eat before logging.
User Examples
Should I eat this?
How much should I eat for lunch if I want kebab for dinner?
I want dessert later. What should lunch be?
Should I skip dinner?
I’m hungry. What can I eat?
AI Response Requirements
The AI should:
Show remaining macros.
Estimate planned meal.
Recommend portion size.
Explain tradeoffs.
Suggest alternatives.
Avoid shame-based language.

9.7 Water Tracker
Purpose
Track hydration and coach pacing.
Default Target
User-specific, based on:
Body weight
Training day or rest day
Climate
Sweat level
For the example user:
Default: 3500 ml
Workout day: 4000 ml+
Commands
Log water 600ml
+500ml
Drank 1L
Undo last water
Dashboard
Water: 1200 / 3500 ml
Remaining: 2300 ml
AI Note:
Try to reach 2L by mid-afternoon so you do not need to drink too much at night.

9.8 Weight Tracker
Purpose
Track daily weight and explain fluctuations.
Requirements
The app should:
Encourage morning weigh-ins.
Store daily weights.
Calculate 7-day average.
Compare trend, not single-day changes.
Explain spikes calmly.
Estimate fat loss over time.
Weight Fluctuation Explanation
If weight increases suddenly, AI should explain likely causes:
Water retention
Glycogen
Sodium
Food volume
Digestion
Training inflammation
Poor sleep
Example
Your weight increased from 89.15 to 90.50 kg. This is almost certainly not fat gain. To gain 1.35 kg of fat, you would need around 10,000 kcal surplus. This is likely water, glycogen, sodium, or training recovery.

9.9 Workout Logger
Purpose
Track training and estimate calorie burn.
Supported Inputs
Natural language workout logs:
Bench 5x5 90kg
Deadlift 5x1 140kg
Lat pulldown 3x8 72kg
Stored Workout Fields
Date
Duration
Exercises
Sets
Reps
Weight
RPE, optional
Rest time, optional
Estimated calories burned
Training intensity
Recovery demand
Output
Estimated burn
Training volume
Intensity rating
Recovery advice
Strength trend
Example
Estimated burn: 430 kcal
Intensity: High
Recovery demand: High
Advice:
Prioritize 40–60 g protein, 30–60 g carbs, and 750–1000 ml water after this session.

9.10 Steps Tracker
Purpose
Improve maintenance calorie estimates.
Input
Manual: Steps 7200
HealthKit sync, post-MVP
Usage
Steps influence:
Estimated daily expenditure
Weekly activity summary
Maintenance calorie model

9.11 Maintenance Calculator
Purpose
Estimate true maintenance calories using real user data.
Inputs
Average calorie intake
Weight trend
Time period
Steps
Workouts
Body weight
Formula
Estimated daily deficit:
Weight lost in kg × 7700 / number of days
Estimated maintenance:
Average daily calories + estimated daily deficit
Example
User eats 1700 kcal/day and loses 1 kg/week.
Deficit:
7700 / 7 = 1100 kcal/day
Maintenance:
1700 + 1100 = 2800 kcal/day
Requirements
The app should:
Use at least 7 days of data before giving trend estimate.
Prefer 14–28 days for better accuracy.
Warn that water weight can distort short-term estimates.
Show confidence level.

9.12 Daily Review
Trigger
User taps Daily Review or types:
Daily review
Review Sections
Calories
Protein
Carbs
Fat
Water
Weight
Workout
Steps
Coaching summary
Tomorrow’s recommendation
Example
Today’s Summary:
Calories: 1714 kcal
Protein: 217 g
Carbs: 113 g
Fat: 40 g
Water: 0 ml logged
Workout: Heavy lifting
AI Review:
This was a strong cutting day despite being slightly over your 1600 kcal target. Most extra calories came from lean chicken breast, so there is no major concern. Your protein was excellent. The main improvement is hydration.

9.13 Weekly Review
Trigger
Automatically generated every 7 days.
Contents
Average calories
Average protein
Average water
Average steps
Number of workouts
Weight change
7-day average weight
Estimated maintenance
Recommended calorie adjustment
Behavioral insight
Example
Weekly Summary:
Average calories: 1680 kcal
Average protein: 182 g
Average water: 2.6 L
Workouts: 3
Average steps: 5800
Weight trend: -0.8 kg
Estimated maintenance: 2790 kcal
Recommendation:
Keep calories the same. Weight loss is aggressive but still reasonable. Improve water consistency.

9.14 AI Coaching System
Tone
The AI should be:
Calm
Encouraging
Practical
Non-judgmental
Honest
Data-driven
Emotionally supportive
Coaching Principles
Weekly average matters more than daily perfection.
Protein matters during a cut.
Slight calorie overages are not failures.
Maintenance days do not erase progress.
Weight fluctuations are normal.
Training performance matters.
Consistency beats perfection.
Avoid
Shame
Extreme diet advice
Eating disorder language
Fear-based coaching
Overemphasis on scale weight
Encouraging starvation
Moralizing food as good or bad

10. User Stories
Nutrition
As a user, I want to log food using normal language so that I do not need to search a database manually.
As a user, I want the app to estimate macros from photos so that I can log restaurant meals easily.
As a user, I want to ask whether a meal fits my remaining calories so that I can make better decisions before eating.
As a user, I want to correct a logged item so that my totals stay accurate.

Weight Loss
As a user, I want to know whether my weight increase is fat or water so that I do not panic.
As a user, I want my maintenance calories estimated from real data so that I can understand my deficit.
As a user, I want weekly trends instead of daily judgment so that I stay motivated.

Training
As a user, I want to log gym workouts in natural language so that I can track training without complex forms.
As a user, I want the app to estimate workout calories so that I understand my energy expenditure.
As a user, I want to know whether I should eat carbs around training so that I can perform better.

Coaching
As a user, I want daily reviews so that I understand what went well and what to improve.
As a user, I want the app to reassure me when I slightly exceed calories so that I do not quit.
As a user, I want food variety suggestions so that I do not get bored of chicken breast every day.

11. Success Metrics
Activation
Percentage of users who complete onboarding.
Percentage of users who log first meal.
Percentage of users who complete first daily review.
Engagement
Daily active users.
Average logs per day.
Number of chat interactions per day.
Number of food photos uploaded.
Number of daily reviews generated.
Weekly review completion rate.
Retention
Day 1 retention.
Day 7 retention.
Day 30 retention.
Percentage of users still logging after 4 weeks.
Outcome Metrics
Average weight trend after 4 weeks.
Percentage of users hitting protein target.
Percentage of users logging 5+ days/week.
Percentage of users completing 2+ workouts/week.
User-reported confidence in dieting.
AI Quality Metrics
Food estimate correction rate.
User acceptance rate of AI estimates.
Clarification rate.
Hallucinated food detection rate.
Coaching satisfaction rating.

12. MVP Scope
Must Have
Onboarding
Daily dashboard
New day reset
Weight logging
Text-based food logging
Macro tracking
Water tracking
Daily review
Basic workout logging
AI coaching responses
Local data persistence
Edit/delete food entries
Manual correction of calories/macros
Should Have
Photo-based meal estimation
Frequent foods
Weekly review
Maintenance estimate
Strength workout calorie estimation
Saved meals
Voice input
Could Have
HealthKit steps integration
Barcode scanning
Apple Watch companion
Grocery planner
Meal plan generator
Restaurant mode
Mood tracking
Sleep tracking
Won’t Have in MVP
Social features
Meal delivery
Complex recipe database
Paid coach marketplace
Full medical-grade nutrition
Competitive leaderboards

13. App Navigation
Tab 1: Today
Daily macro dashboard
Water tracker
Weight
Food timeline
Workout summary
Quick log button
AI coaching card
Tab 2: Coach
Conversational chat
Food logging
Meal questions
Corrections
Daily review
Tab 3: Progress
Weight chart
7-day average
Calorie trends
Protein trends
Water trends
Maintenance estimate
Goal projection
Tab 4: Training
Workout logs
Strength trends
Estimated calorie burn
Recovery notes
Tab 5: Profile
Goals
Macro targets
Food preferences
Activity level
Units
Integrations
Data export

14. Key Screens
14.1 Onboarding Screen
Purpose: Collect user baseline.
Main elements:
Progress indicator
Single-question screens
Friendly explanation
Final generated plan

14.2 Today Dashboard
Main elements:
Calories ring
Protein progress bar
Carbs progress bar
Fat progress bar
Water progress bar
Weight card
AI coaching card
Food timeline
Quick log input

14.3 Coach Chat
Main elements:
Chat messages
Quick action chips
Camera button
Mic button
Text input
Suggested prompts
Example quick chips:
Log food
Should I eat this?
Status
Daily review
Log water
Workout

14.4 Food Confirmation Screen
Used after AI estimates food.
Elements:
Food items
Estimated portion
Calories/macros
Confidence
Edit button
Confirm log button

14.5 Daily Review Screen
Elements:
Overall score
Macro summary
Hydration summary
Workout summary
Weight explanation
Coaching notes
Tomorrow focus

14.6 Progress Screen
Elements:
Weight chart
7-day average line
Calories average
Maintenance estimate
Projection to goal weight
Weekly summaries

15. Data Models
15.1 UserProfile
Fields:
userId
name
age
sex
heightCm
currentWeightKg
goalWeightKg
estimatedBodyFatPercentage
activityLevel
trainingFrequency
averageSteps
calorieTarget
proteinTarget
carbTarget
fatTarget
waterTargetMl
createdAt
updatedAt

15.2 DailyLog
Fields:
id
date
weightKg
calorieTarget
proteinTarget
carbTarget
fatTarget
waterTargetMl
caloriesConsumed
proteinConsumed
carbsConsumed
fatConsumed
waterConsumedMl
steps
workoutCaloriesBurned
dailyReviewText
createdAt
updatedAt

15.3 FoodEntry
Fields:
id
dailyLogId
mealType
name
quantity
unit
calories
protein
carbs
fat
fiber
sodium
source
confidence
imageUrl
createdAt
updatedAt

15.4 WaterEntry
Fields:
id
dailyLogId
amountMl
createdAt

15.5 WorkoutEntry
Fields:
id
dailyLogId
name
durationMinutes
estimatedCaloriesBurned
intensity
recoveryDemand
notes
createdAt
updatedAt

15.6 ExerciseSet
Fields:
id
workoutEntryId
exerciseName
setNumber
reps
weightKg
rpe
createdAt

15.7 WeightEntry
Fields:
id
date
weightKg
note
createdAt

16. AI System Design
16.1 AI Responsibilities
The AI handles:
Intent classification
Food parsing
Macro estimation
Meal advice
Weight trend explanation
Workout parsing
Workout calorie estimation
Daily reviews
Weekly reviews
Coaching tone

16.2 Deterministic Engine Responsibilities
The deterministic app logic handles:
Adding calories
Subtracting remaining macros
Storing logs
Calculating totals
Calculating averages
Applying formulas
Managing targets
The AI should not be the source of truth for arithmetic. It should explain and interpret.

16.3 AI Response Structure
For logging:
Confirmation
Nutrition estimate
Updated dashboard
Coaching note
For advice:
Current status
Food estimate
Recommendation
Optional alternative
For review:
Summary
What went well
What to improve
Tomorrow recommendation

17. Safety and Health Guardrails
The app should:
Warn users when calorie targets are too aggressive.
Avoid recommending extremely low calories.
Avoid encouraging meal skipping if protein is too low.
Suggest professional help for medical issues.
Avoid diagnosing medical conditions.
Encourage sustainable habits.
Detect potential harmful patterns such as repeated very low intake.
Example Guardrail
If user target is below safe threshold:
This target is very aggressive. I can help you track it, but I recommend monitoring energy, mood, training performance, and hunger closely. If you feel unwell, increase calories or speak with a healthcare professional.

18. Personalization
The app should adapt based on:
User’s common foods
Preferred protein sources
Dietary restrictions
Training days
Rest days
Weight trend
Hunger patterns
Meal timing
Food boredom
User tone preference
Example
If the user often eats chicken breast and gets bored:
You can swap some chicken breast for chicken thigh, white fish, lean beef, prawns, eggs, tofu, or Greek yogurt. Chicken thigh is higher calorie but more enjoyable, so we can adjust portions.

19. Notifications
MVP Notifications
Morning weigh-in reminder
Water reminder
Meal logging reminder
Daily review reminder
Weekly review reminder
Notification Style
Supportive, not guilt-based.
Examples:
“Ready to start today’s log?”
“You’re 1L into your water goal. Want to log another cup?”
“Daily review is ready when you are.”
“Your weekly trend is more important than today’s weight.”

20. Monetization
Free Tier
Manual food logging
Water tracking
Weight tracking
Basic dashboard
Limited AI messages per day
Premium Tier
Unlimited AI coaching
Photo meal estimation
Weekly reviews
Maintenance calculator
Workout analysis
Meal planning
Trend insights
Cloud sync
Possible Pricing
Monthly: $9.99
Yearly: $69.99
Student plan: $4.99/month

21. Technical Architecture
21.1 iOS App
Recommended stack:
SwiftUI
SwiftData
MVVM or Clean Architecture
Swift Concurrency
HealthKit
CloudKit
Vision framework
WidgetKit, post-MVP

21.2 Backend
Recommended stack:
FastAPI or Node.js
PostgreSQL
Redis for caching
Object storage for images
LLM API gateway
Nutrition database service
Authentication service

21.3 AI Layer
Components:
Intent classifier
Food parser
Nutrition estimator
Coaching generator
Safety classifier
User memory/profile context
Deterministic calculation engine

21.4 Local-First Strategy
MVP can be local-first:
Store daily logs on device using SwiftData.
Sync later using CloudKit or backend.
Use AI API only for interpretation and estimation.

22. Example User Flow
Morning
User:
New day 90.15
App:
Starts new day.
Logs weight.
Shows targets.
Breakfast
User:
Log 3 ON scoops and 400ml water
App:
Logs protein shake.
Logs water.
Updates dashboard.
Lunch
User uploads food photo.
App:
Estimates meal.
Asks clarification.
Logs after confirmation.
Workout
User:
Bench 5x5 90kg, deadlift 5x1 140kg
App:
Logs workout.
Estimates 430 kcal burn.
Recommends protein and hydration.
Night
User:
Daily review
App:
Summarizes day.
Gives score.
Gives tomorrow recommendation.

23. Edge Cases
User Gives Vague Food
Input:
Log chicken rice
App should ask:
Was it regular chicken rice, half rice, extra chicken, or roasted/steamed?
Or estimate with low confidence.

User Corrects Entry
Input:
Actually the wrap was 131 calories
App should:
Revert previous entry.
Replace with corrected macros.
Update totals.

User Exceeds Calories
App should not shame.
Response:
You are over target, but still likely below maintenance. This does not ruin progress. Let’s focus on weekly average.

User Weight Spikes
App should explain water weight.

User Wants to Cut Faster
App should explain limits and risks.

User Logs Very Low Calories
App should warn gently and suggest adequate protein and nutrition.

24. Competitive Differentiation
Compared with MyFitnessPal:
Conversational logging.
AI interpretation.
Weight fluctuation explanations.
Workout calorie estimation from actual sets.
Maintenance calculation from real trends.
Emotional coaching.
Compared with MacroFactor:
More conversational.
More beginner-friendly.
More behavior coaching.
More meal decision support.
Compared with ChatGPT:
Persistent app state.
Structured dashboard.
HealthKit integration.
Charts and trend analytics.
Faster logging UX.

25. MVP Acceptance Criteria
The MVP is successful if a user can:
Complete onboarding.
Start a new day.
Log food through chat.
Log water.
Log weight.
View daily macro dashboard.
Ask whether a meal fits their targets.
Receive a daily review.
Log a workout.
See basic weight trend.
Edit or undo entries.
Use the app for 7 consecutive days without needing a spreadsheet or external tracker.

26. Future Roadmap
Phase 1: MVP
Onboarding
Dashboard
Chat logging
Manual food log
Water
Weight
Daily review
Basic workout logging
Phase 2: Intelligence
Photo estimation
Weekly reviews
Maintenance calculator
Frequent foods
Voice input
HealthKit steps
Phase 3: Coaching Expansion
Meal planner
Grocery list
Workout progression
Recovery score
Sleep tracking
Mood tracking
Phase 4: Ecosystem
Apple Watch
Widgets
Social accountability
Coach sharing
Exportable reports
Wearable integration

27. Open Questions
Should the app require account creation at launch?
Should food data be local-first or backend-first?
Which nutrition database should be used?
Should photo estimation be included in MVP?
Should the AI coach be fully chat-based or card-based?
Should users be allowed to set very aggressive calorie targets?
Should the app support maintenance and bulking, or only cutting?
How much should the app rely on HealthKit?
Should workout tracking be simple or advanced from MVP?
What is the first monetizable premium feature?

28. Recommendation
The best MVP should focus on the core loop:
Start day with weight.
Log food and water conversationally.
Ask meal questions.
Log workout.
Receive daily review.
See weekly trend.
Do not overbuild the first version.
The strongest differentiator is not the calorie database. It is the AI coach that explains the user’s progress, prevents panic, and keeps them consistent.
The app should feel like:
A fitness coach in your pocket who remembers everything, does the math, and tells you what actually matters.

