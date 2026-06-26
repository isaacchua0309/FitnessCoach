# FitPilot AI Architecture Document

## 1. Document Purpose

This document defines the architecture for **FitPilot AI**, a local-first AI fitness coaching iOS application.

The goal of the architecture is to support fast product development while preventing long-term code depth, tangled state ownership, and AI-driven business logic errors.

FitPilot AI should borrow the architectural judgment from large-scale production apps such as TikTokStudio, but apply it in a smaller and simpler form.

The core philosophy is:

> FitPilot should use clear ownership boundaries, service facades, deterministic calculation layers, explicit AI task boundaries, and local-first persistence — without copying the infrastructure depth of a large production editor.

---

# 2. Architecture Thesis

FitPilot AI is not just a calorie tracker. It is a structured logging and coaching app where the user interacts conversationally, but the app maintains deterministic source-of-truth state.

The architecture should separate five major responsibilities:

1. **App Shell**

   * Owns app composition, routing, dependency injection, and global environment setup.

2. **Feature Modules**

   * Own UI, screen state, and user interactions for a specific product area.

3. **Service Facades**

   * Own business actions such as logging food, logging water, starting a new day, editing entries, generating reviews, and calculating trends.

4. **Deterministic Calculators**

   * Own all arithmetic and formula-based logic such as macro totals, calorie targets, water targets, maintenance estimates, and weight trend calculations.

5. **AI Adapters**

   * Own natural language parsing, food estimation, meal advice, coaching text, and review generation.
   * AI must not directly mutate app state.
   * AI must not be the source of truth for arithmetic.

The simplified architectural model is:

```text
App Shell
  ↓
Feature Module
  ↓
Feature Model
  ↓
Service Facade
  ↓
Store / Calculator / AI Adapter
```

This gives FitPilot enough structure to scale without becoming over-engineered.

---

# 3. Core Architectural Principles

## 3.1 App Shell as Assembly Layer

The app shell should assemble the application, not own feature logic.

The app shell owns:

* Tab structure
* Navigation root
* Dependency injection
* AppContainer creation
* Global environment objects
* Session/profile loading
* Feature flag loading
* App-wide configuration

The app shell must not own:

* Food logging logic
* Water logging logic
* AI parsing
* Macro calculations
* Workout calculations
* Daily review generation
* SwiftData write logic for specific user actions

The shell is a coordinator, not a business logic owner.

---

## 3.2 Feature Modules Own UI, Not Global Business Logic

Each major tab or product area should be a feature module.

MVP feature modules:

* Onboarding
* Today
* Coach
* Progress
* Training
* Profile

Each feature owns:

* Its SwiftUI views
* Its feature model
* Its local screen state
* Its loading/error state
* Its user interaction handling

Each feature should call services for business actions.

A feature should not directly mutate another feature’s state.

Bad:

```text
CoachModel directly updates TodayModel
```

Good:

```text
CoachModel calls FoodLogService
TodayModel reloads state from DailyLogService
```

---

## 3.3 Local Source of Truth

FitPilot should be local-first.

The first source of truth should be local persistence, likely SwiftData.

The app should work without an account in MVP unless monetization, sync, or authentication requires otherwise.

Primary local data:

* UserProfile
* DailyLog
* FoodEntry
* WaterEntry
* WeightEntry
* WorkoutEntry
* ExerciseSet
* ChatMessage
* DailyReview
* WeeklyReview
* DebugRecord

Cloud sync can be added later through CloudKit or backend sync adapters.

---

## 3.4 Services Hide Complexity

Services should expose simple verbs.

Example:

```text
FoodLogService.addFoodEntry()
WaterLogService.addWater()
DailyLogService.startNewDay()
ReviewService.generateDailyReview()
MaintenanceService.estimateMaintenance()
```

A feature should not need to understand SwiftData, calculators, AI prompt structure, validation rules, and logging at the same time.

Services hide that complexity.

---

## 3.5 Calculators Own Deterministic Math

All formula-based logic should live in pure calculator structs or functions.

Examples:

* MacroCalculator
* CalorieTargetCalculator
* WaterTargetCalculator
* MaintenanceCalculator
* WeightTrendCalculator
* WorkoutCalorieCalculator
* ProgressProjectionCalculator

Calculators should be:

* Pure
* Stateless
* Easy to test
* Independent from SwiftUI
* Independent from SwiftData
* Independent from AI

AI should never be trusted to calculate final totals.

---

## 3.6 AI as Adapter, Not Source of Truth

AI is used for:

* Intent classification
* Natural language parsing
* Food estimation
* Meal advice
* Daily review generation
* Weekly review generation
* Coaching explanation
* Safety tone

AI is not used for:

* Final macro arithmetic
* Final daily totals
* Final remaining calories
* Direct database writes
* Source-of-truth state
* Silent destructive actions

AI should return structured drafts or intents.

Example:

```swift
enum UserIntent {
    case startNewDay(weightKg: Double?)
    case logFood(FoodDraft)
    case logWater(amountMl: Int)
    case logWeight(weightKg: Double)
    case logWorkout(WorkoutDraft)
    case askMealAdvice(String)
    case dailyReview
    case weeklyReview
    case status
    case unknown
}
```

The app then validates the result before mutating state.

---

## 3.7 Explicit Async Boundaries

AI tasks, photo estimation, voice transcription, HealthKit sync, and future cloud sync should be treated as explicit tasks.

Every async task should have:

* Input
* Output
* Loading state
* Success state
* Failure state
* Retry behavior
* Error logging
* User-visible fallback
* Developer debug record, if useful

No async task should silently mutate persistent state without validation.

---

## 3.8 Feature Flags Only Where Useful

FitPilot should use feature flags for risky or premium features, not every small UI change.

Good candidates for flags:

* AI food logging
* Photo meal estimation
* Weekly review
* Maintenance calculator
* HealthKit integration
* Cloud sync
* Subscription features
* Debug tools

Do not overuse flags for core MVP basics such as manual food logging, water logging, or weight logging.

---

# 4. High-Level System Architecture

```text
FitPilotApp
  ↓
AppShell / MainTabView
  ↓
Feature Modules
  ├── Onboarding
  ├── Today
  ├── Coach
  ├── Progress
  ├── Training
  └── Profile
        ↓
Feature Models
        ↓
Service Facades
  ├── DailyLogService
  ├── FoodLogService
  ├── WaterLogService
  ├── WeightLogService
  ├── WorkoutLogService
  ├── ReviewService
  ├── MaintenanceService
  ├── TargetService
  ├── CommandRouter
  └── AIService
        ↓
Core Logic
  ├── Calculators
  ├── Validators
  ├── Formatters
  └── Safety Rules
        ↓
Infrastructure
  ├── SwiftDataStore
  ├── LLMClient
  ├── HealthKitAdapter
  ├── ImageStorage
  ├── CloudSyncAdapter
  └── DebugLogger
```

---

# 5. App Shell Design

## 5.1 Responsibility

The app shell is the top-level assembly layer.

It creates dependencies, injects services, owns the tab structure, and manages top-level navigation.

## 5.2 Proposed Files

```text
FitPilot/
└── App/
    ├── FitPilotApp.swift
    ├── AppShellView.swift
    ├── MainTabView.swift
    ├── AppRouter.swift
    ├── AppContainer.swift
    ├── AppEnvironment.swift
    └── FeatureFlags.swift
```

## 5.3 AppContainer

`AppContainer` owns long-lived dependencies.

```swift
final class AppContainer {
    let dailyLogService: DailyLogService
    let foodLogService: FoodLogService
    let waterLogService: WaterLogService
    let weightLogService: WeightLogService
    let workoutLogService: WorkoutLogService
    let reviewService: ReviewService
    let maintenanceService: MaintenanceService
    let targetService: TargetService
    let commandRouter: CommandRouter
    let aiService: AIService
    let featureFlags: FeatureFlags
}
```

## 5.4 App Shell Owns

* Dependency construction
* Root tab setup
* Onboarding completion routing
* Global app loading state
* Global error state, if needed
* App-level feature flags
* App-wide user profile availability

## 5.5 App Shell Does Not Own

* Individual food entries
* Water entry mutation
* Workout parsing
* Macro math
* Daily review text generation
* AI prompt construction
* SwiftData write details for specific feature actions

---

# 6. Feature Module Map

## 6.1 Onboarding Feature

### Responsibility

Collect baseline user data and generate initial targets.

### Owns

* Onboarding screen flow
* Input state
* Validation state
* Completion action
* Generated plan display

### Proposed Files

```text
Features/
└── Onboarding/
    ├── OnboardingView.swift
    ├── OnboardingModel.swift
    ├── OnboardingStep.swift
    ├── OnboardingInputState.swift
    └── GeneratedPlanView.swift
```

### Can Call

* TargetService
* UserProfileService
* CalorieTargetCalculator
* WaterTargetCalculator

### Must Not Directly Access

* SwiftData internals
* AIService
* DailyLog mutation logic
* Progress charts

---

## 6.2 Today Feature

### Responsibility

Show the current day’s dashboard.

### Owns

* Today dashboard UI
* Macro cards
* Water card
* Weight card
* Food timeline
* Workout summary
* Quick log entry point
* Daily coaching card display

### Proposed Files

```text
Features/
└── Today/
    ├── TodayView.swift
    ├── TodayModel.swift
    ├── TodayDashboardState.swift
    ├── MacroSummaryCard.swift
    ├── WaterSummaryCard.swift
    ├── WeightSummaryCard.swift
    ├── FoodTimelineView.swift
    ├── WorkoutSummaryCard.swift
    └── QuickLogSheet.swift
```

### Can Call

* DailyLogService
* FoodLogService
* WaterLogService
* WeightLogService
* WorkoutLogService
* CommandRouter

### Must Not Directly Access

* AI prompt construction
* SwiftData write operations
* Progress calculation internals
* CoachModel

---

## 6.3 Coach Feature

### Responsibility

Provide conversational interaction for logging, advice, correction, and reviews.

### Owns

* Chat UI
* Message state
* Text input state
* Quick action chips
* Loading indicators
* Confirmation UI for AI-estimated entries

### Proposed Files

```text
Features/
└── Coach/
    ├── CoachView.swift
    ├── CoachModel.swift
    ├── ChatMessageView.swift
    ├── CoachInputBar.swift
    ├── QuickActionChips.swift
    ├── FoodConfirmationView.swift
    └── MealAdviceView.swift
```

### Can Call

* CommandRouter
* ReviewService
* FoodLogService
* WaterLogService
* WorkoutLogService
* DailyLogService

### Must Not Directly Access

* SwiftData write operations
* TodayModel
* ProgressModel
* Raw LLMClient
* Calculator internals

---

## 6.4 Progress Feature

### Responsibility

Show long-term trends and progress insights.

### Owns

* Weight chart
* 7-day average display
* Calorie trend display
* Protein trend display
* Water trend display
* Maintenance estimate display
* Goal projection display
* Weekly review list

### Proposed Files

```text
Features/
└── Progress/
    ├── ProgressView.swift
    ├── ProgressModel.swift
    ├── WeightTrendChart.swift
    ├── CalorieTrendChart.swift
    ├── ProteinTrendChart.swift
    ├── MaintenanceEstimateCard.swift
    ├── GoalProjectionCard.swift
    └── WeeklyReviewListView.swift
```

### Can Call

* DailyLogService
* MaintenanceService
* ReviewService
* WeightTrendCalculator
* ProgressProjectionCalculator

### Must Not Directly Access

* FoodLogService mutation methods
* WaterLogService mutation methods
* AIService directly
* Coach chat state

---

## 6.5 Training Feature

### Responsibility

Show and manage workout logs.

### Owns

* Workout list
* Workout entry UI
* Exercise set display
* Strength trend views
* Recovery note display

### Proposed Files

```text
Features/
└── Training/
    ├── TrainingView.swift
    ├── TrainingModel.swift
    ├── WorkoutLogView.swift
    ├── WorkoutEntryView.swift
    ├── ExerciseSetRow.swift
    ├── StrengthTrendView.swift
    └── RecoveryNoteCard.swift
```

### Can Call

* WorkoutLogService
* DailyLogService
* WorkoutCalorieCalculator
* ReviewService, only for workout-related notes

### Must Not Directly Access

* Food logging internals
* Water logging internals
* SwiftData directly
* AI prompt construction

---

## 6.6 Profile Feature

### Responsibility

Manage user goals, preferences, units, targets, and integrations.

### Owns

* Profile display
* Goal settings
* Macro target settings
* Food preferences
* Unit settings
* Integration settings
* Subscription settings, future

### Proposed Files

```text
Features/
└── Profile/
    ├── ProfileView.swift
    ├── ProfileModel.swift
    ├── GoalSettingsView.swift
    ├── MacroTargetSettingsView.swift
    ├── FoodPreferenceView.swift
    ├── UnitSettingsView.swift
    └── IntegrationSettingsView.swift
```

### Can Call

* UserProfileService
* TargetService
* FeatureFlagService
* HealthKitAdapter, future

### Must Not Directly Access

* DailyLog write internals
* FoodLogService internals
* AIService directly
* Chart calculation internals

---

# 7. State Ownership Map

## 7.1 UserProfile

### Owner

`UserProfileService`

### Persistence

SwiftData local store.

### Read Path

```text
FeatureModel → UserProfileService → SwiftDataStore
```

### Mutation Path

```text
Onboarding/Profile → UserProfileService → SwiftDataStore
```

### Displayed By

* Onboarding
* Today
* Profile
* Progress

---

## 7.2 DailyLog

### Owner

`DailyLogService`

### Persistence

SwiftData local store.

### Read Path

```text
TodayModel / ProgressModel / CoachModel → DailyLogService
```

### Mutation Path

```text
DailyLogService.startNewDay()
FoodLogService.addFoodEntry()
WaterLogService.addWater()
WeightLogService.logWeight()
WorkoutLogService.addWorkout()
```

### Displayed By

* Today
* Coach
* Progress

---

## 7.3 FoodEntry

### Owner

`FoodLogService`

### Persistence

SwiftData local store.

### Read Path

```text
TodayModel → DailyLogService → Food entries
ProgressModel → DailyLogService → Food entries
```

### Mutation Path

```text
Coach/Today → CommandRouter or FoodLogService → SwiftDataStore
```

### Displayed By

* Today
* Coach
* Progress

---

## 7.4 WaterEntry

### Owner

`WaterLogService`

### Persistence

SwiftData local store.

### Read Path

```text
TodayModel → DailyLogService
```

### Mutation Path

```text
Coach/Today → WaterLogService → SwiftDataStore
```

### Displayed By

* Today
* Coach
* Progress

---

## 7.5 WeightEntry

### Owner

`WeightLogService`

### Persistence

SwiftData local store.

### Read Path

```text
TodayModel / ProgressModel → WeightLogService
```

### Mutation Path

```text
Onboarding/Today/Coach/Profile → WeightLogService → SwiftDataStore
```

### Displayed By

* Today
* Progress
* Profile

---

## 7.6 WorkoutEntry

### Owner

`WorkoutLogService`

### Persistence

SwiftData local store.

### Read Path

```text
TrainingModel / TodayModel / ProgressModel → WorkoutLogService
```

### Mutation Path

```text
Training/Coach → WorkoutLogService → SwiftDataStore
```

### Displayed By

* Training
* Today
* Progress
* Coach

---

## 7.7 ExerciseSet

### Owner

`WorkoutLogService`

### Persistence

SwiftData local store.

### Read Path

```text
TrainingModel → WorkoutLogService
```

### Mutation Path

```text
Training/Coach → WorkoutLogService → SwiftDataStore
```

### Displayed By

* Training
* Coach

---

## 7.8 ChatMessage

### Owner

`CoachModel` for active session display.

### Persistence

Optional for MVP.

If persisted:

`ChatHistoryService`

### Read Path

```text
CoachModel → ChatHistoryService
```

### Mutation Path

```text
CoachModel → ChatHistoryService
```

### Displayed By

* Coach

### Note

Chat messages are not the main source of truth. Structured logs are the source of truth.

---

## 7.9 DailyReview

### Owner

`ReviewService`

### Persistence

SwiftData local store.

### Read Path

```text
TodayModel / ProgressModel / CoachModel → ReviewService
```

### Mutation Path

```text
ReviewService.generateDailyReview() → AIService + DailyLogService → SwiftDataStore
```

### Displayed By

* Today
* Coach
* Progress

---

## 7.10 WeeklyReview

### Owner

`ReviewService`

### Persistence

SwiftData local store.

### Read Path

```text
ProgressModel → ReviewService
```

### Mutation Path

```text
ReviewService.generateWeeklyReview() → AIService + DailyLogService + MaintenanceService
```

### Displayed By

* Progress
* Coach

---

# 8. Service Facade Design

## 8.1 DailyLogService

### Responsibility

Own daily log lifecycle and daily summary access.

### Public Methods

```swift
func getTodayLog() async throws -> DailyLog
func startNewDay(weightKg: Double?) async throws -> DailyLog
func getLog(for date: Date) async throws -> DailyLog?
func getLogs(from startDate: Date, to endDate: Date) async throws -> [DailyLog]
func recalculateDailyTotals(for date: Date) async throws
```

### Hides

* DailyLog creation
* Date normalization
* Linking entries to daily logs
* Total recalculation
* SwiftData details

### Should Not Do

* AI parsing
* Macro target generation
* Food estimation
* Workout parsing

---

## 8.2 FoodLogService

### Responsibility

Own food entry creation, editing, deletion, and correction.

### Public Methods

```swift
func addFoodEntry(_ draft: FoodDraft, date: Date) async throws -> FoodEntry
func editFoodEntry(id: UUID, update: FoodEntryUpdate) async throws
func deleteFoodEntry(id: UUID) async throws
func undoLastFoodEntry(date: Date) async throws
func confirmFoodEstimate(_ estimate: FoodEstimateDraft) async throws -> [FoodEntry]
```

### Hides

* Food validation
* Confidence handling
* Food entry persistence
* Recalculation trigger
* Correction behavior

### Should Not Do

* Call raw AI APIs directly
* Own chat UI state
* Own daily review generation

---

## 8.3 WaterLogService

### Responsibility

Own hydration entry creation, deletion, and total updates.

### Public Methods

```swift
func addWater(amountMl: Int, date: Date) async throws -> WaterEntry
func undoLastWaterEntry(date: Date) async throws
func getWaterTotal(for date: Date) async throws -> Int
```

### Hides

* Water entry persistence
* Daily total update
* Validation for impossible values

### Should Not Do

* Generate coaching text directly
* Own dashboard state

---

## 8.4 WeightLogService

### Responsibility

Own weight logging and weight trend access.

### Public Methods

```swift
func logWeight(_ weightKg: Double, date: Date) async throws -> WeightEntry
func getLatestWeight() async throws -> WeightEntry?
func getWeightTrend(days: Int) async throws -> WeightTrend
func getSevenDayAverage() async throws -> Double?
```

### Hides

* Weight entry persistence
* Same-day replacement or duplication policy
* Trend calculation calls

### Should Not Do

* Generate long coaching responses
* Own calorie calculations

---

## 8.5 WorkoutLogService

### Responsibility

Own workout and exercise set logging.

### Public Methods

```swift
func addWorkout(_ draft: WorkoutDraft, date: Date) async throws -> WorkoutEntry
func editWorkout(id: UUID, update: WorkoutUpdate) async throws
func deleteWorkout(id: UUID) async throws
func getWorkouts(for date: Date) async throws -> [WorkoutEntry]
func getWorkoutHistory(days: Int) async throws -> [WorkoutEntry]
```

### Hides

* Workout structure
* Exercise set persistence
* Estimated calorie burn calculation
* Recovery demand classification

### Should Not Do

* Own food suggestions directly
* Own Progress chart rendering

---

## 8.6 ReviewService

### Responsibility

Generate daily and weekly reviews using deterministic summaries plus AI coaching.

### Public Methods

```swift
func generateDailyReview(for date: Date) async throws -> DailyReview
func getDailyReview(for date: Date) async throws -> DailyReview?
func generateWeeklyReview(weekStartDate: Date) async throws -> WeeklyReview
func getWeeklyReviews() async throws -> [WeeklyReview]
```

### Hides

* Summary assembly
* AI coaching call
* Review persistence
* Review regeneration policy

### Should Not Do

* Mutate food/water/workout entries
* Own raw calculations directly
* Trust AI for final numbers

---

## 8.7 MaintenanceService

### Responsibility

Estimate real-world maintenance calories from intake and weight trend.

### Public Methods

```swift
func estimateMaintenance(days: Int) async throws -> MaintenanceEstimate
func getMaintenanceConfidence(days: Int) async throws -> ConfidenceLevel
```

### Hides

* Required data checks
* 7-day, 14-day, 28-day logic
* Water-weight warning logic
* Maintenance formula calls

### Should Not Do

* Own onboarding target generation
* Generate AI text directly

---

## 8.8 TargetService

### Responsibility

Generate and update calorie, macro, and water targets.

### Public Methods

```swift
func generateInitialTargets(profile: UserProfile) -> UserTargets
func updateTargets(_ targets: UserTargets) async throws
func getCurrentTargets() async throws -> UserTargets
```

### Hides

* Calorie target formula
* Protein target formula
* Fat/carb split
* Water target formula
* Aggressive deficit warnings

### Should Not Do

* Mutate daily food entries
* Estimate maintenance from trends

---

## 8.9 CommandRouter

### Responsibility

Coordinate user text/photo/voice commands into app actions.

### Public Methods

```swift
func handleTextCommand(_ text: String) async -> CommandResult
func handlePhotoCommand(_ imageData: Data) async -> CommandResult
func handleVoiceCommand(_ audioData: Data) async -> CommandResult
```

### Hides

* Local parser fallback
* AI parser call
* Intent routing
* Confirmation requirements
* Error recovery

### Should Not Do

* Contain all business logic itself
* Directly write SwiftData
* Own dashboard state

---

## 8.10 AIService / AIClient

### Responsibility

Provide structured AI capabilities behind a stable interface.

### Public Methods

```swift
func parseCommand(_ text: String, context: AIContext) async throws -> ParsedCommand
func estimateFood(from text: String, context: AIContext) async throws -> FoodEstimateDraft
func estimateFood(from image: Data, context: AIContext) async throws -> FoodEstimateDraft
func generateMealAdvice(request: MealAdviceRequest) async throws -> CoachingResponse
func generateDailyReview(_ summary: DailyReviewInput) async throws -> String
func generateWeeklyReview(_ summary: WeeklyReviewInput) async throws -> String
```

### Hides

* Prompt construction
* API calls
* Model selection
* Response decoding
* Retry policy
* Safety classification
* Token limits

### Should Not Do

* Directly mutate SwiftData
* Own final arithmetic
* Own app navigation
* Own feature state

---

# 9. Deterministic Calculator Boundary

## 9.1 Why Calculators Exist

Calculators prevent arithmetic from being scattered across views, services, and AI responses.

They make health logic testable and auditable.

## 9.2 Calculator List

```text
Core/
└── Calculators/
    ├── MacroCalculator.swift
    ├── CalorieTargetCalculator.swift
    ├── WaterTargetCalculator.swift
    ├── MaintenanceCalculator.swift
    ├── WeightTrendCalculator.swift
    ├── WorkoutCalorieCalculator.swift
    └── ProgressProjectionCalculator.swift
```

## 9.3 MacroCalculator

Owns:

* Consumed macro totals
* Remaining macros
* Over/under target calculation
* Macro percentage progress

Should not own:

* Food parsing
* AI estimation
* SwiftData access

---

## 9.4 CalorieTargetCalculator

Owns:

* BMR estimate
* TDEE estimate
* Deficit target
* Aggressive deficit warning

Should not own:

* User profile persistence
* Daily log mutation

---

## 9.5 WaterTargetCalculator

Owns:

* Base water target
* Workout day adjustment
* Body weight adjustment

Should not own:

* Water entry logging
* Notifications

---

## 9.6 MaintenanceCalculator

Owns:

* Real-world maintenance formula
* Deficit estimate from weight change
* Confidence level based on data duration

Formula:

```text
Estimated daily deficit = weight lost in kg × 7700 / number of days

Estimated maintenance = average daily intake + estimated daily deficit
```

Should not own:

* AI explanation
* Chart rendering
* SwiftData access

---

## 9.7 WeightTrendCalculator

Owns:

* 7-day average
* Rolling average
* Trend direction
* Weight spike detection
* Short-term fluctuation classification

Should not own:

* Coaching text generation
* Weight entry persistence

---

## 9.8 WorkoutCalorieCalculator

Owns:

* Workout calorie estimate
* Intensity classification
* Recovery demand estimate

Should not own:

* Workout logging UI
* Food recommendation text
* AI parsing

---

## 9.9 ProgressProjectionCalculator

Owns:

* Goal projection
* Estimated time to goal
* Weekly rate of loss
* Trend-based projection

Should not own:

* Motivation/coaching copy
* Data persistence

---

# 10. AI Task Boundary

## 10.1 Text Command Parsing

### Input

User text, current day summary, user profile, recent common foods.

### AI Responsibility

* Identify intent
* Extract structured values
* Estimate food if needed
* Return confidence

### Deterministic Responsibility

* Validate quantities
* Validate units
* Recalculate totals
* Apply entry mutation through services

### Mutation Responsibility

Only services mutate app state.

### Confirmation Required

Required when:

* Confidence is low
* Food is vague
* Multiple food items are inferred
* Action is destructive

---

## 10.2 Food Macro Estimation

### Input

Text or photo description.

### AI Responsibility

* Identify likely food
* Estimate portion size
* Estimate calories/macros
* Return confidence and assumptions

### Deterministic Responsibility

* Validate macro totals
* Apply known branded food overrides
* Recalculate daily totals

### Mutation Responsibility

`FoodLogService.confirmFoodEstimate()`

### Error Handling

If estimation fails:

* Show fallback manual entry
* Save debug record
* Do not mutate food log

---

## 10.3 Meal Advice

### Input

User question, current remaining macros, planned food, goal.

### AI Responsibility

* Explain fit against remaining budget
* Suggest portion adjustments
* Give alternatives
* Use supportive tone

### Deterministic Responsibility

* Provide actual remaining macros
* Provide current totals
* Provide target values

### Mutation Responsibility

None unless user confirms logging.

---

## 10.4 Daily Review Generation

### Input

Deterministic daily summary.

### AI Responsibility

* Generate explanation
* Identify what went well
* Identify one improvement
* Give tomorrow recommendation

### Deterministic Responsibility

* Provide final calories
* Provide final protein/carbs/fat
* Provide water total
* Provide workout summary
* Provide weight info

### Mutation Responsibility

`ReviewService` saves review after generation.

---

## 10.5 Weekly Review Generation

### Input

Weekly deterministic summary.

### AI Responsibility

* Explain weekly trend
* Identify consistency patterns
* Recommend adjustment

### Deterministic Responsibility

* Calculate average calories
* Calculate average protein
* Calculate average water
* Calculate weight trend
* Estimate maintenance

### Mutation Responsibility

`ReviewService` saves weekly review.

---

## 10.6 Photo Meal Estimation

Future feature.

### Input

Meal image and optional user text.

### AI Responsibility

* Identify visible food items
* Estimate portion sizes
* Return macro estimate
* Ask clarification where needed

### Deterministic Responsibility

* Validate estimate
* Convert estimate into FoodDraft items
* Require user confirmation

### Mutation Responsibility

`FoodLogService` only after confirmation.

---

## 10.7 Voice Input

Future feature.

### Input

Audio recording.

### AI Responsibility

* Transcribe voice
* Parse command

### Deterministic Responsibility

* Route parsed command
* Validate action

### Mutation Responsibility

Service layer only.

---

# 11. Rollout and Safety Gates

## 11.1 Feature Flag Strategy

Feature flags should control risky, expensive, AI-heavy, or premium features.

## 11.2 Proposed Flags

```swift
struct FeatureFlags {
    var aiFoodLoggingEnabled: Bool
    var photoMealEstimationEnabled: Bool
    var weeklyReviewEnabled: Bool
    var maintenanceCalculatorEnabled: Bool
    var healthKitIntegrationEnabled: Bool
    var cloudSyncEnabled: Bool
    var premiumFeaturesEnabled: Bool
    var debugLogViewerEnabled: Bool
}
```

## 11.3 Flag Map

### AI Food Logging

Purpose:

* Control LLM-based command parsing and food estimation.

Default:

* Enabled after local parser is stable.

Fallback:

* Manual food entry.

---

### Photo Meal Estimation

Purpose:

* Control image-based estimation.

Default:

* Disabled in MVP unless specifically prioritized.

Fallback:

* Text/manual food logging.

---

### Weekly Review

Purpose:

* Control generated weekly summaries.

Default:

* Disabled until enough daily data exists.

Fallback:

* Progress charts only.

---

### Maintenance Calculator

Purpose:

* Control trend-based maintenance estimate.

Default:

* Enabled only after at least 7 days of data.

Fallback:

* Initial estimated maintenance from onboarding.

---

### HealthKit Integration

Purpose:

* Control steps and activity sync.

Default:

* Disabled in MVP.

Fallback:

* Manual step entry.

---

### Cloud Sync

Purpose:

* Control account-based syncing.

Default:

* Disabled in MVP.

Fallback:

* Local-only storage.

---

### Premium Features

Purpose:

* Control monetized feature access.

Default:

* Disabled until monetization is implemented.

Fallback:

* Free manual logging features.

---

### Debug Log Viewer

Purpose:

* Control developer-facing local debug records.

Default:

* Enabled only in debug/internal builds.

Fallback:

* Silent local logging or console logging.

---

# 12. Error Handling and Debug Logging

## 12.1 Error Philosophy

Errors should be classified into:

1. User-correctable errors
2. Temporary system errors
3. AI interpretation errors
4. Persistence errors
5. Calculation validation errors
6. Integration errors

The user should only see actionable and friendly messages.

Developer-only details should be saved in bounded debug logs.

---

## 12.2 Debug Record Model

```swift
struct DebugRecord {
    let id: UUID
    let category: DebugCategory
    let message: String
    let context: [String: String]
    let createdAt: Date
}
```

## 12.3 Debug Categories

```swift
enum DebugCategory {
    case aiParsingFailure
    case foodEstimationFailure
    case persistenceFailure
    case calculationValidationFailure
    case reviewGenerationFailure
    case healthKitSyncFailure
    case cloudSyncFailure
}
```

## 12.4 Bounded Debug History

Keep the latest 50 debug records locally.

This gives enough developer visibility without building a full observability system.

---

## 12.5 User-Visible Error Examples

### AI Parsing Failure

```text
I could not confidently understand that log. Could you enter it manually or rephrase it?
```

### Food Estimation Failure

```text
I could not estimate this meal accurately. You can still add the calories and protein manually.
```

### Persistence Failure

```text
I could not save this entry. Please try again.
```

### Low Confidence Food Estimate

```text
This estimate may be rough. Please confirm or edit before logging.
```

---

# 13. Persistence Architecture

## 13.1 Local-First Strategy

MVP should store all core user data locally using SwiftData.

Benefits:

* Faster development
* Works without account creation
* Lower backend complexity
* Faster reads/writes
* Better privacy posture
* Easier MVP iteration

## 13.2 SwiftData Entities

```text
Infrastructure/
└── SwiftData/
    ├── UserProfileEntity.swift
    ├── DailyLogEntity.swift
    ├── FoodEntryEntity.swift
    ├── WaterEntryEntity.swift
    ├── WeightEntryEntity.swift
    ├── WorkoutEntryEntity.swift
    ├── ExerciseSetEntity.swift
    ├── DailyReviewEntity.swift
    ├── WeeklyReviewEntity.swift
    └── DebugRecordEntity.swift
```

## 13.3 App Models

```text
Core/
└── Models/
    ├── UserProfile.swift
    ├── DailyLog.swift
    ├── FoodEntry.swift
    ├── WaterEntry.swift
    ├── WeightEntry.swift
    ├── WorkoutEntry.swift
    ├── ExerciseSet.swift
    ├── DailyReview.swift
    ├── WeeklyReview.swift
    └── DebugRecord.swift
```

## 13.4 Mapping Strategy

Do not create excessive mapper layers.

Use small extensions:

```text
Infrastructure/
└── SwiftData/
    └── Mapping/
        ├── UserProfileEntity+Mapping.swift
        ├── DailyLogEntity+Mapping.swift
        ├── FoodEntryEntity+Mapping.swift
        └── WorkoutEntryEntity+Mapping.swift
```

The goal is to prevent SwiftData implementation details from leaking everywhere, without building heavy repository infrastructure.

---

# 14. Data Models

## 14.1 UserProfile

```swift
struct UserProfile {
    let id: UUID
    var name: String?
    var age: Int
    var sex: Sex
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var estimatedBodyFatPercentage: Double?
    var activityLevel: ActivityLevel
    var trainingFrequency: Int
    var averageSteps: Int
    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var createdAt: Date
    var updatedAt: Date
}
```

---

## 14.2 DailyLog

```swift
struct DailyLog {
    let id: UUID
    let date: Date
    var weightKg: Double?
    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var caloriesConsumed: Int
    var proteinConsumed: Double
    var carbsConsumed: Double
    var fatConsumed: Double
    var waterConsumedMl: Int
    var steps: Int?
    var workoutCaloriesBurned: Int
    var createdAt: Date
    var updatedAt: Date
}
```

---

## 14.3 FoodEntry

```swift
struct FoodEntry {
    let id: UUID
    let dailyLogId: UUID
    var mealType: MealType?
    var name: String
    var quantity: Double?
    var unit: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sodium: Double?
    var source: FoodEntrySource
    var confidence: ConfidenceLevel
    var imageUrl: String?
    var createdAt: Date
    var updatedAt: Date
}
```

---

## 14.4 WaterEntry

```swift
struct WaterEntry {
    let id: UUID
    let dailyLogId: UUID
    var amountMl: Int
    var createdAt: Date
}
```

---

## 14.5 WeightEntry

```swift
struct WeightEntry {
    let id: UUID
    var date: Date
    var weightKg: Double
    var note: String?
    var createdAt: Date
}
```

---

## 14.6 WorkoutEntry

```swift
struct WorkoutEntry {
    let id: UUID
    let dailyLogId: UUID
    var name: String?
    var durationMinutes: Int?
    var estimatedCaloriesBurned: Int?
    var intensity: WorkoutIntensity?
    var recoveryDemand: RecoveryDemand?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
}
```

---

## 14.7 ExerciseSet

```swift
struct ExerciseSet {
    let id: UUID
    let workoutEntryId: UUID
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weightKg: Double?
    var rpe: Double?
    var createdAt: Date
}
```

---

## 14.8 DailyReview

```swift
struct DailyReview {
    let id: UUID
    let dailyLogId: UUID
    var summaryText: String
    var caloriesSummary: String
    var proteinSummary: String
    var hydrationSummary: String
    var workoutSummary: String?
    var tomorrowRecommendation: String
    var createdAt: Date
}
```

---

## 14.9 WeeklyReview

```swift
struct WeeklyReview {
    let id: UUID
    var weekStartDate: Date
    var weekEndDate: Date
    var averageCalories: Int
    var averageProtein: Double
    var averageWaterMl: Int
    var averageSteps: Int?
    var workoutCount: Int
    var weightChangeKg: Double?
    var estimatedMaintenance: Int?
    var summaryText: String
    var recommendationText: String
    var createdAt: Date
}
```

---

# 15. Command Flow Architecture

## 15.1 Text Command Flow

Example user input:

```text
Log 3 scoops ON whey and 400ml water
```

Flow:

```text
CoachView
  ↓
CoachModel.submit(text)
  ↓
CommandRouter.handleTextCommand(text)
  ↓
LocalCommandParser tries simple parse
  ↓
AIService.parseCommand() if local parser is insufficient
  ↓
ParsedCommand
  ↓
CommandRouter routes intent
  ↓
FoodLogService.addFoodEntry()
WaterLogService.addWater()
  ↓
DailyLogService.recalculateDailyTotals()
  ↓
CoachModel receives CommandResult
  ↓
TodayModel reloads updated daily log
```

## 15.2 Important Rule

CommandRouter coordinates the flow.

It should not become a giant business logic class.

If CommandRouter grows too large, move logic into specific services.

---

# 16. Confirmation Flow Architecture

Some AI outputs should not be logged immediately.

Confirmation is required for:

* Photo meal estimates
* Low-confidence text food estimates
* Vague food entries
* Destructive corrections
* Replacing existing entries
* Very large calorie values
* Unusual water amounts
* Very low daily calorie patterns

Flow:

```text
User command
  ↓
AI estimate
  ↓
FoodEstimateDraft
  ↓
FoodConfirmationView
  ↓
User confirms or edits
  ↓
FoodLogService.confirmFoodEstimate()
  ↓
SwiftData save
  ↓
Daily totals recalculate
```

---

# 17. Folder Structure

```text
FitPilot/
├── App/
│   ├── FitPilotApp.swift
│   ├── AppShellView.swift
│   ├── MainTabView.swift
│   ├── AppRouter.swift
│   ├── AppContainer.swift
│   ├── AppEnvironment.swift
│   └── FeatureFlags.swift
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   ├── OnboardingModel.swift
│   │   ├── OnboardingStep.swift
│   │   ├── OnboardingInputState.swift
│   │   └── GeneratedPlanView.swift
│   │
│   ├── Today/
│   │   ├── TodayView.swift
│   │   ├── TodayModel.swift
│   │   ├── TodayDashboardState.swift
│   │   ├── MacroSummaryCard.swift
│   │   ├── WaterSummaryCard.swift
│   │   ├── WeightSummaryCard.swift
│   │   ├── FoodTimelineView.swift
│   │   ├── WorkoutSummaryCard.swift
│   │   └── QuickLogSheet.swift
│   │
│   ├── Coach/
│   │   ├── CoachView.swift
│   │   ├── CoachModel.swift
│   │   ├── ChatMessageView.swift
│   │   ├── CoachInputBar.swift
│   │   ├── QuickActionChips.swift
│   │   ├── FoodConfirmationView.swift
│   │   └── MealAdviceView.swift
│   │
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   ├── ProgressModel.swift
│   │   ├── WeightTrendChart.swift
│   │   ├── CalorieTrendChart.swift
│   │   ├── ProteinTrendChart.swift
│   │   ├── MaintenanceEstimateCard.swift
│   │   ├── GoalProjectionCard.swift
│   │   └── WeeklyReviewListView.swift
│   │
│   ├── Training/
│   │   ├── TrainingView.swift
│   │   ├── TrainingModel.swift
│   │   ├── WorkoutLogView.swift
│   │   ├── WorkoutEntryView.swift
│   │   ├── ExerciseSetRow.swift
│   │   ├── StrengthTrendView.swift
│   │   └── RecoveryNoteCard.swift
│   │
│   └── Profile/
│       ├── ProfileView.swift
│       ├── ProfileModel.swift
│       ├── GoalSettingsView.swift
│       ├── MacroTargetSettingsView.swift
│       ├── FoodPreferenceView.swift
│       ├── UnitSettingsView.swift
│       └── IntegrationSettingsView.swift
│
├── Core/
│   ├── Models/
│   ├── Drafts/
│   ├── Services/
│   ├── Calculators/
│   ├── AI/
│   ├── Validation/
│   ├── Formatting/
│   └── Debug/
│
├── Infrastructure/
│   ├── SwiftData/
│   ├── LLM/
│   ├── HealthKit/
│   ├── ImageStorage/
│   └── CloudSync/
│
└── DesignSystem/
    ├── Components/
    ├── Tokens/
    ├── Charts/
    └── Modifiers/
```

---

# 18. Testing Strategy

## 18.1 Highest Priority Tests

The most important tests are deterministic calculator tests.

Test:

* Macro totals
* Remaining macros
* Water target calculation
* Maintenance estimate
* 7-day weight average
* Workout calorie estimate
* Progress projection

## 18.2 Service Tests

Test:

* Start new day
* Add food entry
* Edit food entry
* Delete food entry
* Undo last food
* Add water
* Undo last water
* Log weight
* Generate daily summary input

## 18.3 AI Boundary Tests

Test with mocked AI responses:

* Parsed command routes correctly
* Low-confidence food requires confirmation
* AI parsing failure does not mutate state
* Daily review uses deterministic input
* AI output is safely decoded

## 18.4 UI Tests

MVP UI tests should cover:

* Complete onboarding
* Start new day
* Log food manually
* Log water
* View Today dashboard
* Generate daily review

Do not over-invest in UI tests before core services and calculators are stable.

---

# 19. Implementation Sequence

## Step 1: Core Models

### Goal

Create the core data structures.

### Files

* UserProfile.swift
* DailyLog.swift
* FoodEntry.swift
* WaterEntry.swift
* WeightEntry.swift
* WorkoutEntry.swift
* ExerciseSet.swift

### Acceptance Criteria

* Models compile.
* Models are independent from SwiftUI and SwiftData.
* Basic sample data can be created.

### Do Not Overbuild

* Do not add backend sync fields yet.
* Do not add advanced recipe models yet.

---

## Step 2: SwiftData Local Store

### Goal

Persist core models locally.

### Files

* SwiftDataStore.swift
* UserProfileEntity.swift
* DailyLogEntity.swift
* FoodEntryEntity.swift
* WaterEntryEntity.swift
* WeightEntryEntity.swift
* WorkoutEntryEntity.swift
* ExerciseSetEntity.swift

### Acceptance Criteria

* Can save and load a user profile.
* Can save and load a daily log.
* Can attach food/water/workout entries to a day.

### Do Not Overbuild

* Do not build cloud sync yet.
* Do not create excessive repository abstractions.

---

## Step 3: Deterministic Calculators

### Goal

Create pure calculator logic.

### Files

* MacroCalculator.swift
* CalorieTargetCalculator.swift
* WaterTargetCalculator.swift
* MaintenanceCalculator.swift
* WeightTrendCalculator.swift
* WorkoutCalorieCalculator.swift

### Acceptance Criteria

* Calculators have unit tests.
* Calculators have no SwiftUI dependency.
* Calculators have no SwiftData dependency.
* Calculators have no AI dependency.

### Do Not Overbuild

* Do not use AI for calculations.
* Do not put formulas inside views.

---

## Step 4: Core Services

### Goal

Create service facades for core user actions.

### Files

* DailyLogService.swift
* FoodLogService.swift
* WaterLogService.swift
* WeightLogService.swift
* WorkoutLogService.swift
* TargetService.swift

### Acceptance Criteria

* Can start a new day.
* Can log food.
* Can log water.
* Can log weight.
* Can log a basic workout.
* Daily totals recalculate correctly.

### Do Not Overbuild

* Do not add full AI yet.
* Do not add weekly review yet.

---

## Step 5: Today Dashboard

### Goal

Build the primary dashboard.

### Files

* TodayView.swift
* TodayModel.swift
* TodayDashboardState.swift
* MacroSummaryCard.swift
* WaterSummaryCard.swift
* FoodTimelineView.swift

### Acceptance Criteria

* Today dashboard loads current log.
* Displays calories/macros/water/weight.
* Updates after food or water is added.
* Shows food timeline.

### Do Not Overbuild

* Do not build advanced charts here.
* Do not put business logic in views.

---

## Step 6: Local Command Parser

### Goal

Support simple commands without AI.

### Files

* LocalCommandParser.swift
* ParsedCommand.swift
* CommandRouter.swift

### Acceptance Criteria

Can parse:

* `new day 90.15`
* `log 400ml water`
* `weight 90.15`
* `status`
* `daily review`

### Do Not Overbuild

* Do not try to parse every food item locally.
* Do not replace the future AI parser.

---

## Step 7: Coach Chat Shell

### Goal

Build the conversational interface.

### Files

* CoachView.swift
* CoachModel.swift
* ChatMessage.swift
* ChatMessageView.swift
* CoachInputBar.swift
* QuickActionChips.swift

### Acceptance Criteria

* User can send a message.
* App can return a structured response.
* Local command parser works through chat.
* Chat does not become the source of truth.

### Do Not Overbuild

* Do not persist all chat history at first.
* Do not place business logic inside CoachModel.

---

## Step 8: AI Command Parser

### Goal

Add AI parsing behind a safe boundary.

### Files

* AIService.swift
* LLMClient.swift
* AICommandParser.swift
* AIResponseDecoder.swift
* PromptTemplates.swift

### Acceptance Criteria

* AI returns structured parsed commands.
* Low-confidence results require confirmation.
* AI failure does not mutate state.
* Raw AI client is hidden from features.

### Do Not Overbuild

* Do not let AI write directly to SwiftData.
* Do not build photo estimation yet unless necessary.

---

## Step 9: Daily Review

### Goal

Generate daily reviews from deterministic summaries.

### Files

* ReviewService.swift
* DailyReview.swift
* DailyReviewEntity.swift
* DailyReviewInput.swift

### Acceptance Criteria

* Review uses deterministic totals.
* AI generates only the coaching explanation.
* Review is saved locally.
* Review can be displayed in Today or Coach.

### Do Not Overbuild

* Do not generate medical advice.
* Do not let AI invent totals.

---

## Step 10: Progress Trends

### Goal

Show basic progress.

### Files

* ProgressView.swift
* ProgressModel.swift
* WeightTrendChart.swift
* MaintenanceEstimateCard.swift
* GoalProjectionCard.swift

### Acceptance Criteria

* Shows weight trend.
* Shows 7-day average.
* Shows calorie/protein averages.
* Maintenance estimate appears only with enough data.

### Do Not Overbuild

* Do not build advanced analytics too early.
* Do not build social comparison.

---

## Step 11: Workout Logging

### Goal

Support basic workout logging.

### Files

* TrainingView.swift
* TrainingModel.swift
* WorkoutLogService.swift
* WorkoutCalorieCalculator.swift

### Acceptance Criteria

* User can log workout manually.
* User can enter exercises and sets.
* App estimates basic calorie burn.
* Today dashboard shows workout summary.

### Do Not Overbuild

* Do not build a full gym app.
* Do not add complex progression engine yet.

---

## Step 12: Debug Logs and Feature Flags

### Goal

Add lightweight safety tools.

### Files

* FeatureFlags.swift
* DebugLogger.swift
* DebugRecord.swift
* DebugRecordEntity.swift

### Acceptance Criteria

* AI parsing failures are logged.
* Food estimation failures are logged.
* Persistence failures are logged.
* Latest 50 debug records are retained.
* Debug viewer is gated.

### Do Not Overbuild

* Do not build full observability.
* Do not send logs to backend unless needed.

---

# 20. Low-Code-Depth Code Review Rules

1. A SwiftUI view must not directly write to SwiftData.
2. A SwiftUI view must not perform macro, calorie, water, or trend calculations.
3. A feature model must not call another feature model.
4. A feature module may call services, not infrastructure directly.
5. AI must return structured drafts or intents.
6. AI must not directly mutate persistent state.
7. AI must not be trusted for final arithmetic.
8. All deterministic calculations must live in calculator structs or functions.
9. Services should expose simple verbs.
10. One user command should not require changing more than 5–7 files.
11. Do not create use-case, interactor, repository, and data-source layers unless real complexity proves they are needed.
12. Prefer one model per major feature over many tiny view models.
13. Feature flags should protect risky or premium features, not every small UI change.
14. Chat messages are not the source of truth; structured logs are.
15. If a class starts coordinating too many flows, split by service responsibility, not by abstract architecture layers.
16. Async tasks must have loading, success, failure, and retry behavior.
17. Low-confidence AI food estimates must require confirmation.
18. Daily and weekly reviews must use deterministic summaries as input.
19. App shell owns composition, not business logic.
20. Keep MVP local-first unless account, sync, or monetization requires backend support.

---

# 21. Anti-Patterns to Avoid

## 21.1 Over-Clean Architecture

Avoid:

```text
View → ViewModel → UseCase → Interactor → Repository → DataSource → Mapper → DTO → Entity
```

This creates unnecessary depth for MVP.

Use:

```text
View → FeatureModel → Service → Store
```

---

## 21.2 AI as App Brain

Avoid:

```text
User input → AI → database mutation
```

Use:

```text
User input → AI structured intent → service validation → database mutation
```

---

## 21.3 Feature-to-Feature Coupling

Avoid:

```text
CoachModel updates TodayModel
```

Use:

```text
CoachModel calls service
TodayModel reloads from service
```

---

## 21.4 Calculations in Views

Avoid:

```swift
Text("\(targetCalories - consumedCalories)")
```

Use:

```swift
Text("\(state.remainingCalories)")
```

---

## 21.5 Massive CommandRouter

Avoid allowing CommandRouter to become the whole app.

CommandRouter should coordinate intent routing.

Actual business logic belongs in services.

---

## 21.6 Premature Backend

Avoid backend-first architecture before local MVP is proven.

Start with local-first SwiftData.

Add backend only when needed for:

* Account sync
* Cross-device usage
* Subscription validation
* Shared coach access
* Server-side AI cost control

---

# 22. Final Architecture Doctrine

FitPilot AI uses a shallow local-first architecture.

The app shell owns composition, routing, dependency injection, and global environment setup.

Feature modules own UI and screen state.

Services own business actions and persistent state mutation.

SwiftData owns local source-of-truth persistence.

Pure calculators own deterministic math.

AI adapters parse, estimate, and explain, but they do not own truth.

AI must return structured drafts or intents.

AI must not directly mutate persistent state.

Views must not perform calculations or persistence writes.

Features must not call other feature models directly.

Async AI flows must have explicit task boundaries, error handling, retry behavior, and confirmation rules.

Feature flags should protect risky, expensive, premium, or unfinished features, not every minor UI change.

The architecture should stay shallow unless complexity proves that more layers are necessary.

The guiding principle is:

> Build FitPilot like a disciplined product, not an enterprise framework. Keep state ownership explicit, calculations deterministic, AI bounded, and feature modules simple.
