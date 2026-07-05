//
//  FormaProductCopy+Journey.swift
//  Fitness Coach
//
//  Journey tab, weekly review presentation, and weight spike education copy.
//

import Foundation

extension FormaProductCopy {
    // MARK: - Journey

    enum Journey {
        static let statusNoData = "—"

        enum StartingEmptyState {
            static let title = "Your journey is just starting."
            static let body = "Log meals, workouts, water, and weight to build your transformation story."
            static let action = "Go to Today"
        }

        enum Momentum {
            static let sectionTitle = "Momentum"
            static let buildingHeadline = "You're building consistency."
            static let keepStreakAlive = "Log today to keep your streak alive."

            static func activeHeadline(days: Int) -> String {
                "\(days)-day check-in streak"
            }

            static func longestStreakDetail(days: Int) -> String {
                "Your longest check-in streak is \(days) days."
            }
        }

        enum Hero {
            static let newUserTitle = "Your journey is just starting."
            static let newUserPrimary = "Build your first week."
            static let newUserBody = "Log today to start creating your transformation story."
            static let newUserAction = "Log today"

            static let earlyHabitsTitle = "Building Momentum"
            static let earlyHabitsBody = "Every healthy decision is starting to compound."

            static let weightLossTitle = "Transformation in progress"
            static let gainProgressTitle = "Transformation in progress"
            static let strongConsistencyTitle = "Strong Momentum"
            static let strongConsistencyBody = "Your habits are becoming consistent."

            static let noGoalTitle = "Building Momentum"
            static let noGoalPrimary = "Keep logging"
            static let noGoalBody = "Log meals and weight so Forma can map your progress."

            static func weekLabel(_ week: Int) -> String {
                "Week \(week)"
            }

            static func kgLost(_ kg: String) -> String {
                "\(kg) lost"
            }

            static func kgGained(_ kg: String) -> String {
                "\(kg) gained"
            }

            static func percentTowardGoal(_ percent: Int) -> String {
                "\(percent)% of the way to your goal."
            }

            static func daysShowingUp(_ days: Int) -> String {
                days == 1 ? "1 day showing up" : "\(days) days showing up"
            }

            static func compactWeights(started: String, today: String, goal: String) -> String {
                "\(started) → \(today) → \(goal)"
            }

            static func accessibilitySummary(title: String, primary: String, body: String) -> String {
                "\(title). \(primary). \(body)"
            }
        }

        enum GoalProjection {
            static let sectionTitle = "Goal projection"

            static let insufficientTitle = "Projection unlocks soon"
            static let insufficientDetail = "Log weight for 7 days so Forma can estimate your pace."

            static let towardGoalTitle = "At your current pace"
            static let flatTrendTitle = "Your weight is holding steady"
            static let flatTrendDetail = "Keep logging so Forma can detect your real trend."
            static let awayFromGoalTitle = "Your trend needs more consistency"
            static let awayFromGoalDetail = "Focus on meals and weigh-ins this week."

            static let goalReachedTitle = "Goal reached"
            static let goalReachedDetail = "You're at your target weight. Keep your habits steady."

            static func towardGoalDetail(goalWeight: String, date: String) -> String {
                "You may reach \(goalWeight) around \(date)."
            }

            static func accessibilitySummary(title: String, detail: String) -> String {
                "\(title). \(detail)"
            }
        }

        static func analyticsBasedOnDays(_ days: Int) -> String {
            days == 1 ? "Based on 1 logged day" : "Based on \(days) logged days"
        }

        enum Transformation {
            static let lostHeadline = "You've lost"
            static let gainedHeadline = "You've gained"
            static let maintainingHeadline = "You're maintaining"
            static let columnStarted = "Started"
            static let columnToday = "Today"
            static let columnGoal = "Goal"
            static let onboardingBaseline = "Onboarding"
            static let paceForecastFallback = "Keep logging and Forma will forecast your pace."
            static let progressStarting = "0% complete"
            static let progressAccessibilityLabel = "Progress toward goal"

            static let emotionalLayingFoundation = "Laying the foundation"
            static let emotionalMomentumBuilding = "Momentum Building"
            static let emotionalAheadOfSchedule = "You're ahead of schedule"
            static let emotionalClosingIn = "Closing in"

            static func paceForecast(month: String) -> String {
                "At this pace you'll reach your goal in \(month)."
            }

            static func progressComplete(_ percent: Int) -> String {
                "\(percent)% complete"
            }

            static func remainingToGo(_ kg: String) -> String {
                "\(kg) to go"
            }

            static func accessibilitySummary(
                headline: String,
                changeValue: String,
                started: String,
                today: String,
                goal: String,
                progressLabel: String,
                emotionalStatus: String,
                startedFootnote: String?
            ) -> String {
                var parts = [
                    "\(headline) \(changeValue).",
                    "Started \(started), today \(today), goal \(goal).",
                    progressLabel + ".",
                    emotionalStatus + "."
                ]
                if let startedFootnote {
                    parts.insert("Started weight from \(startedFootnote.lowercased()).", at: 2)
                }
                return parts.joined(separator: " ")
            }
        }

        enum Milestones {
            static let sectionTitle = "Milestones"
            static let nextUp = "Next up"
            static let emptyBody = "Log your first meal to start building your milestone path."

            enum NextAchievement {
                static let header = "Next Achievement"

                static let firstMealTitle = "Log Your First Meal"
                static let firstFullDayTitle = "Complete Your First Full Day"
                static let firstWorkoutTitle = "Complete Your First Workout"
                static let weightThreeTimesTitle = "Log Weight 3 Times"
                static let firstWeekTitle = "First Week Complete"
                static let proteinThreeDaysTitle = "Hit Protein 3 Days in a Week"
                static let waterThreeDaysTitle = "Hit Water 3 Days in a Week"
                static let firstKgTitle = "Lose Your First Kilogram"
                static let firstKgGainTitle = "Gain Your First Kilogram"
                static let fourWorkoutWeeksTitle = "Complete 4 Workout Weeks"
                static let firstMonthTitle = "Complete Your First Month"

                static let firstMealReward = "Log your first meal to start your milestone path."
                static let firstFullDayReward = "Complete a full day of logging to build momentum."
                static let firstWorkoutReward = "Show up for your first workout to unlock training milestones."
                static let weightThreeTimesReward = "Three weigh-ins help Forma see your real trend."
                static let firstWeekReward = "Complete your first week to unlock your first Journey chapter."
                static let proteinThreeDaysReward = "Three protein days in a week builds a strong anchor."
                static let waterThreeDaysReward = "Three water days in a week keeps your routine steady."
                static let firstKgReward = "Your first kilogram toward goal is a major checkpoint."
                static let fourWorkoutWeeksReward = "Four workout weeks turn training into a habit."
                static let firstMonthReward = "Your first month of consistency becomes part of your story."

                static func progressDays(current: Int, total: Int) -> String {
                    "\(current) / \(total) days"
                }

                static func progressCount(current: Int, total: Int, unit: String) -> String {
                    "\(current) / \(total) \(unit)"
                }

                static func progressKg(current: Double, total: Double) -> String {
                    let currentLabel = String(format: "%.1f", current)
                    let totalLabel = String(format: "%.0f", total)
                    return "\(currentLabel) / \(totalLabel) kg"
                }

                static func accessibilitySummary(
                    header: String,
                    title: String,
                    progress: String,
                    reward: String
                ) -> String {
                    "\(header). \(title). \(progress). \(reward)"
                }
            }

            static let loggedFirstMeal = "Logged first meal"
            static let proteinFiveDays = "Hit protein target 5 days"
            static let waterFiveDays = "Hit water target 5 days"
            static let loggedFirstWorkout = "Logged first workout"
            static let loggingStreakSeven = "7-day logging streak"
            static let loggedThirtyMeals = "Logged 30 meals"
            static let halfwayToGoal = "Halfway to goal"
            static let loggedHundredMeals = "Logged 100 meals"

            static func progressLabel(percent: Int) -> String {
                "\(percent)% there"
            }

            static func firstWeekTitle(direction: JourneyGoalDirection) -> String {
                direction == .maintain
                    ? "Stayed consistent for first week"
                    : "First week complete"
            }

            static func firstKilogramTitle(direction: JourneyGoalDirection) -> String {
                switch direction {
                case .lose: return "Lost first kilogram"
                case .gain: return "Gained first kilogram"
                case .maintain: return "Stayed consistent for first week"
                }
            }

            static func tenKilogramTitle(direction: JourneyGoalDirection) -> String {
                switch direction {
                case .lose: return "10 kg lost"
                case .gain: return "10 kg gained"
                case .maintain: return "10 kg tracked"
                }
            }

            enum Accessibility {
                static let unlocked = "Unlocked"
                static let nextUp = "Next up"
                static let upcoming = "Coming up"

                static func progressPercent(_ percent: Int) -> String {
                    "\(percent) percent there"
                }
            }
        }

        enum HealthIntelligence {
            static let loadingTitle = FormaProductCopy.HealthIntelligence.Loading.title
            static let loadingSubtitle = FormaProductCopy.HealthIntelligence.Loading.subtitle(for: .journey)
            static let loadingAccessibilityLabel = FormaProductCopy.HealthIntelligence.Loading.accessibilityLabel
            static let limitedEstimate = FormaProductCopy.HealthIntelligence.limitedEstimateLabel
            static let unavailableTitle =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .journey).title
            static let unavailableSubtitle =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .journey).bannerMessage
            static let connectHealthTitle =
                FormaProductCopy.HealthIntelligence.NoHealthPermission.title
            static let connectHealthMessage =
                FormaProductCopy.HealthIntelligence.NoHealthPermission.message
            static let connectHealthCTA =
                FormaProductCopy.HealthIntelligence.NoHealthPermission.actionTitle
            static let connectedNoWorkoutsMessage =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .journey).message
            static let errorTitle =
                FormaProductCopy.HealthIntelligence.SyncFailed.title
            static let errorSubtitle =
                FormaProductCopy.HealthIntelligence.message(for: .syncFailed, surface: .journey).bannerMessage
            static let staleDataLabel = FormaProductCopy.Today.HealthIntelligence.staleDataLabel
            static let syncFailedWithCacheLabel = FormaProductCopy.Today.HealthIntelligence.syncFailedWithCacheLabel

            enum RecoveryTimeline {
                static let sectionTitle = "Recovery timeline"
                static let headline = "Last 7 days"
                static let headline14Days = "Last 14 days"
                static let emptyMessage = "Recovery trends appear after a few days of synced signals."
                static let limitedTimelineNote =
                    "Limited timeline — recovery history is still building from Apple Health."
            }

            enum WorkoutHistory {
                static let sectionTitle = "Recent workouts"
                static let headline = "Last 30 days"
                static let emptyMessage = "Workouts from Apple Health will show up here."
            }

            enum Milestones {
                static let sectionTitle = "Health milestones"
                static let headline = "Highlights"
                static let emptyMessage = "Milestones appear as workouts and recovery patterns build."
            }

            enum Progress {
                static let sectionTitle = "Health progress"
                static let headline = "This week at a glance"
                static let emptyMessage = "Weekly health progress unlocks with more synced activity."
            }

            static let milestoneAchieved = "Achieved"
            static let milestoneInProgress = "In progress"
            static let milestoneUpcoming = "Up next"

            static func workoutStreak(_ days: Int) -> String {
                days == 1 ? "1-day workout streak" : "\(days)-day workout streak"
            }

            static func longestWorkout(minutes: Int, title: String) -> String {
                "Longest session: \(durationLabel(minutes: minutes)) \(title)"
            }

            static func mostActiveDay(steps: Int, dateLabel: String) -> String {
                "Most active day: \(steps.formatted()) steps on \(dateLabel)"
            }

            static func workoutConsistency(days: Int, windowDays: Int) -> String {
                "\(days) workout days in the last \(windowDays) days"
            }

            static func weightTrend(_ changeKg: Double) -> String {
                let formatted = String(format: "%.1f", abs(changeKg))
                if changeKg < 0 {
                    return "\(formatted) kg down this week"
                }
                if changeKg > 0 {
                    return "\(formatted) kg up this week"
                }
                return "Weight held steady this week"
            }

            static func recoveryScoreLabel(_ score: Int) -> String {
                "Score \(score)"
            }

            enum WeeklyReview {
                static let sectionTitle = "Weekly health review"
            }

            static func durationLabel(minutes: Int) -> String {
                guard minutes > 0 else { return "—" }
                if minutes >= 60 {
                    let hours = minutes / 60
                    let remainder = minutes % 60
                    if remainder == 0 {
                        return hours == 1 ? "1 hr" : "\(hours) hr"
                    }
                    return "\(hours) hr \(remainder) min"
                }
                return "\(minutes) min"
            }

            static func demandLabel(_ demand: String) -> String {
                switch demand.lowercased() {
                case "high": return "High demand"
                case "moderate": return "Moderate demand"
                case "low": return "Low demand"
                default: return demand.capitalized
                }
            }

            static func workoutsThisWeek(_ count: Int) -> String {
                count == 1 ? "1 workout" : "\(count) workouts"
            }

            static func limitedRecoveryDays(_ count: Int) -> String {
                count == 1 ? "1 day with limited recovery" : "\(count) days with limited recovery"
            }
        }

        enum Timeline {
            static let sectionTitle = "Your story"
            static let emptyBody = "Your story starts today."

            static let startedForma = "Started Forma"
            static let loggedFirstMeal = "Logged first meal"
            static let completedFirstWorkout = "Completed first workout"
            static let loggedFirstWeight = "Logged first weigh-in"
            static let completedFirstFullDay = "Completed first full day"
            static let completedFirstWeek = "Completed first week"
            static let stayedConsistentFirstWeek = "Stayed consistent for first week"
            static let proteinThreeDaysInWeek = "Hit protein goal for 3 days"
            static let waterThreeDaysInWeek = "Hit water goal for 3 days"
            static let reachedNewChapter = "Reached a new chapter"
            static let completedFirstMonth = "Completed first month"

            static func lostFirstKilogram() -> String { "Lost first 1 kg" }
            static func gainedFirstKilogram() -> String { "Gained first 1 kg" }

            enum Reflection {
                static let startedForma = "This is where your transformation began."
                static let loggedFirstMeal = "You began building your daily rhythm."
                static let completedFirstWorkout = "Your training story started here."
                static let loggedFirstWeight = "Your first weigh-in marks the start of your trend."
                static let completedFirstFullDay = "A full day of logging builds real momentum."
                static let completedFirstWeek = "Seven days in — consistency is forming."
                static let lostFirstKg = "Your effort is starting to show."
                static let gainedFirstKg = "Your consistency is starting to pay off."
                static let proteinThreeDays = "Protein is becoming a steady anchor."
                static let waterThreeDays = "Hydration is turning into a habit."
                static let reachedNewChapter = "A new chapter of your journey is opening."
                static let completedFirstMonth = "Your first month is part of your story now."
            }

            static func reflection(for type: JourneyTimelineEventType) -> String? {
                switch type {
                case .onboardingStarted:
                    return Reflection.startedForma
                case .firstMealLogged:
                    return Reflection.loggedFirstMeal
                case .firstWorkoutLogged:
                    return Reflection.completedFirstWorkout
                case .firstWeightLogged:
                    return Reflection.loggedFirstWeight
                case .firstFullDayComplete:
                    return Reflection.completedFirstFullDay
                case .firstWeekComplete:
                    return Reflection.completedFirstWeek
                case .firstKgTowardGoal:
                    return Reflection.lostFirstKg
                case .proteinThreeDaysInWeek:
                    return Reflection.proteinThreeDays
                case .waterThreeDaysInWeek:
                    return Reflection.waterThreeDays
                case .chapterReached:
                    return Reflection.reachedNewChapter
                case .firstMonthComplete:
                    return Reflection.completedFirstMonth
                default:
                    return nil
                }
            }
        }

        typealias StoryTimeline = Timeline

        enum HabitLabels {
            static let foodLoggingLabel = "Food logging consistency"
            static let proteinLabel = "Protein consistency"
            static let waterLabel = "Water consistency"
            static let calorieLabel = "Calorie adherence"
            static let trainingLabel = "Training consistency"
            static let weightLabel = "Weight logging consistency"
            static let weekendLabel = "Weekend logging"
        }

        enum PersonalizedInsights {
            static let sectionTitle = "Personal insights"

            static let learningTitle = "Forma is learning your pattern."
            static let learningDetail =
                "Log meals, water, workouts, and weight this week to unlock personal insights."

            static let proteinStrongestTitle = "Protein is becoming your strongest habit."
            static let waterStrongestTitle = "Water is becoming a steady habit."
            static let workoutConsistencyTitle = "Training is showing up in your week."
            static let weightTrendTowardTitle = "Your weight trend is moving in the right direction."
            static let weightTrendMaintainTitle = "Your weight trend is holding steady."
            static let weekendCalorieTitle = "Your weekends are where calories drift."
            static let bestHabitTitle = "This is your strongest habit this week."
            static let biggestOpportunityTitle = "Your biggest opportunity this week"

            static func proteinDaysThisWeek(_ days: Int) -> String {
                "You hit protein \(days) \(days == 1 ? "day" : "days") this week."
            }

            static func waterDaysThisWeek(_ days: Int) -> String {
                "You hit water \(days) \(days == 1 ? "day" : "days") this week."
            }

            static func workoutDaysThisWeek(_ days: Int, expected: Int) -> String {
                if expected > 0 {
                    return "You completed \(days) of \(expected) planned workout days."
                }
                return days == 1
                    ? "You logged 1 workout day this week."
                    : "You logged \(days) workout days this week."
            }

            static func weekendCalorieDrift(averageKcal: Int) -> String {
                "Saturday and Sunday averaged \(averageKcal) kcal above target."
            }

            static func sevenDayAverageChange(deltaKg: Double, direction: JourneyGoalDirection) -> String {
                let magnitude = abs(deltaKg)
                let formatted = magnitude.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", magnitude)
                    : String(format: "%.1f", magnitude)
                switch direction {
                case .lose:
                    return deltaKg < 0
                        ? "Your 7-day average is down \(formatted) kg."
                        : "Your 7-day average is up \(formatted) kg."
                case .gain:
                    return deltaKg > 0
                        ? "Your 7-day average is up \(formatted) kg."
                        : "Your 7-day average is down \(formatted) kg."
                case .maintain:
                    return "Your 7-day average moved by \(formatted) kg."
                }
            }

            static func bestHabitDetail(habit: String, days: Int, total: Int) -> String {
                "You stayed consistent with \(habit.lowercased()) on \(days) of \(total) days."
            }

            static func opportunityDetail(habit: String) -> String {
                "A little more focus on \(habit.lowercased()) would balance your week."
            }
        }

        enum Header {
            static let title = "Your journey"
        }

        enum Chapters {
            static let sectionTitle = "Your chapter"
            static let emptyBody = "Log your first meal to begin Chapter 1."

            static func chapterLabel(_ number: Int) -> String {
                "Chapter \(number)"
            }

            static func nextUnlock(_ chapterTitle: String) -> String {
                "Next: \(chapterTitle)"
            }

            static func title(for chapter: Int) -> String {
                switch chapter {
                case 1: return "Building Foundations"
                case 2: return "Creating Consistency"
                case 3: return "Building Momentum"
                case 4: return "Transformation"
                case 5: return "Lifestyle"
                default: return "Lifestyle"
                }
            }
        }

        enum MonthlyRecap {
            static let minimumFoodLogDaysForRecap = 5

            static let mealsLoggedTitle = "Meals logged"
            static let proteinTitle = "Protein"
            static let waterTitle = "Water"
            static let caloriesTitle = "Calories"
            static let workoutDaysTitle = "Workout days"
            static let weightTitle = "Weight"
            static let bestStreakTitle = "Best streak"
            static let overallTitle = "Overall"

            static let teaserDetail =
                "Complete more logs to unlock your first monthly recap."

            static func sectionTitle(monthName: String) -> String {
                "\(monthName) Recap"
            }

            static func teaserTitle(monthName: String) -> String {
                "\(monthName) is building."
            }

            static func mealsLoggedValue(_ count: Int) -> String {
                "\(count)"
            }

            static func hitRatePercent(_ percent: Int) -> String {
                "\(percent)%"
            }

            static func workoutDays(_ count: Int) -> String {
                "\(count)"
            }

            static func bestStreak(days: Int) -> String {
                days == 1 ? "1 day" : "\(days) days"
            }

            static func weightChange(deltaKg: Double) -> String {
                let formatted = abs(deltaKg).truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", abs(deltaKg))
                    : String(format: "%.1f", abs(deltaKg))
                if deltaKg < -0.05 {
                    return "-\(formatted) kg"
                }
                if deltaKg > 0.05 {
                    return "+\(formatted) kg"
                }
                return "\(formatted) kg"
            }

            enum Grade: String, Equatable, Sendable {
                case starting
                case building
                case consistent
                case strong
                case excellent

                var label: String {
                    switch self {
                    case .starting: return "Starting"
                    case .building: return "Building"
                    case .consistent: return "Consistent"
                    case .strong: return "Strong month"
                    case .excellent: return "Excellent month"
                    }
                }
            }

            static func overallGrade(_ grade: Grade) -> String {
                grade.label
            }

            static let buildingBody = teaserDetail

            static func loggedDaysSummary(_ days: Int) -> String {
                days == 1
                    ? "You logged 1 day this month."
                    : "You logged \(days) days this month."
            }

            static func bestHabit(for kind: JourneyHabitKind) -> String {
                switch kind {
                case .foodLogging:
                    return "Food logging was your strongest habit this month."
                case .protein:
                    return "Protein was your strongest habit this month."
                case .water:
                    return "Water was your strongest habit this month."
                case .calorieAdherence:
                    return "Calorie adherence was your strongest habit this month."
                case .training:
                    return "Training was your strongest habit this month."
                case .weightLogging:
                    return "Weight logging was your strongest habit this month."
                case .weekendLogging:
                    return "Weekend logging was your strongest habit this month."
                }
            }

            static func weightDelta(deltaKg: Double, direction: JourneyGoalDirection) -> String {
                weightChange(deltaKg: deltaKg)
            }
        }

        enum CTA {
            static let updateGoal = "Update goal"
            static let opensCoach = "Opens Coach"
            static let opensPlan = "Opens Plan to update your goal"
            static let opensPlanForAppleHealth = "Opens Plan to connect Apple Health"
        }

        enum Streaks {
            static let buildingConsistency = "You're building consistency."
            static let keepStreakAlive = "Log today to keep your streak alive."

            static func mealLoggingStreak(days: Int) -> String {
                days == 1 ? "1-day meal logging streak" : "\(days)-day meal logging streak"
            }

            static func checkInStreak(days: Int) -> String {
                days == 1 ? "1-day check-in streak" : "\(days)-day check-in streak"
            }

            static func activityStreak(days: Int) -> String {
                days == 1 ? "1-day activity streak" : "\(days)-day activity streak"
            }

            /// Legacy label — prefer `checkInStreak(days:)`.
            static func loggingStreak(days: Int) -> String {
                checkInStreak(days: days)
            }

            static func longestMealLoggingStreak(days: Int) -> String {
                "Your longest meal logging streak is \(days) days."
            }

            static func longestCheckInStreak(days: Int) -> String {
                "Your longest check-in streak is \(days) days."
            }

            /// Legacy label — prefer `longestCheckInStreak(days:)`.
            static func longestLoggingStreak(days: Int) -> String {
                longestCheckInStreak(days: days)
            }

            static func proteinStreak(days: Int) -> String {
                days == 1 ? "1-day protein streak" : "\(days)-day protein streak"
            }

            static func waterStreak(days: Int) -> String {
                days == 1 ? "1-day water streak" : "\(days)-day water streak"
            }

            static func trainingStreakWeeks(weeks: Int) -> String {
                weeks == 1 ? "1-week training streak" : "\(weeks)-week training streak"
            }

            static func keepStreakAlive(streakDays: Int) -> String {
                "Log today to keep your \(streakDays)-day streak alive."
            }
        }

        enum WeeklyConfidence {
            static let building = "Confidence building"
            static let moderate = "Moderate confidence"
            static let high = "High confidence"
        }

        enum Sync {
            static let healthDataSyncing = "Some health data is still syncing."
        }

        enum NextBestAction {
            static let logFirstMeal = "Log your first meal"
            static let logFirstMealDetail = "Start your journey by logging what you eat today."

            static let logMealsConsistently = "Log meals consistently"
            static func logMealsConsistentlyDetail(logged: Int, required: Int) -> String {
                "You've logged meals on \(logged) of the last 7 days. Aim for \(required) to unlock your weekly review."
            }

            static let logWeightMoreOften = "Log weight more often"
            static func logWeightMoreOftenDetail(logged: Int, required: Int) -> String {
                "Add \(max(required - logged, 1)) more weigh-in\(required - logged == 1 ? "" : "s") this week for a clearer trend."
            }

            static let completeFirstWorkout = "Complete your first workout"
            static let completeFirstWorkoutDetail = "Log a workout in Today or connect Apple Health to track training."
            static let completeFirstWorkoutHealthDetail = "Your next workout will appear here automatically from Apple Health."

            static let syncRecoveryData = "Keep wearing your watch"
            static let syncRecoveryDataDetail = "Recovery insights need a few more days of sleep and heart-rate data."
            static let connectHealthForRecoveryDetail = "Connect Apple Health to unlock recovery insights."

            static let keepStreakGoing = "Keep your streak going"
            static func keepStreakGoingDetail(days: Int) -> String {
                days == 1
                    ? "You're on a 1-day streak. Log today to keep it alive."
                    : "You're on a \(days)-day streak. Log today to keep it alive."
            }
        }

        enum EmptyState {
            static let weightTrendBody = FormaProductCopy.EmptyState.WeightTrend.body
            static let weightTrendAction = FormaProductCopy.EmptyState.WeightTrend.action
            static let weightTrendActionHint = FormaProductCopy.EmptyState.WeightTrend.actionAccessibilityHint
            static let consistencyBody = FormaProductCopy.EmptyState.Consistency.body
            static let timelineBody = Timeline.emptyBody
            static let milestonesBody = Milestones.emptyBody
        }

        enum WeeklyReview {
            static let sectionTitle = "This week"
            static let foodTitle = "Food Logging"
            static let proteinTitle = "Protein"
            static let waterTitle = "Water"
            static let trainingTitle = "Workout"
            static let calorieTitle = "Calorie Target"
            static let weightTitle = "Weight Logging"
            static let trainingNone = "None yet"

            static let weightUnavailable = "Log weight to see weekly change"
            static let trainingConnectAppleHealth = TrainingIntegrationCopy.includeWorkoutsInProgress
            static let noFoodLogsSummary = "Log a meal to start building your weekly pattern."
            static let emptyState = "Your weekly pattern starts today."
            static let oneMoreDayMomentum = "One more day builds momentum."

            static func weekDayCount(current: Int, total: Int) -> String {
                "\(current) / \(total) days"
            }

            static func streakLabel(days: Int) -> String {
                "🔥 \(days)-day streak"
            }

            static func dayFraction(achieved: Int, total: Int) -> String {
                "\(achieved)/\(total) days"
            }

            static func gymFraction(achieved: Int, expected: Int) -> String {
                "\(achieved)/\(expected)"
            }

            static func trainingDays(_ count: Int) -> String {
                count == 1 ? "1 day" : "\(count) days"
            }

            static func foodLoggedDaysSummary(_ days: Int) -> String {
                "You logged food \(days) of 7 days this week."
            }

            static func strongWeekSummary(highlights: String) -> String {
                "Strong week for \(highlights)."
            }

            static func weekOverWeekFood(
                achieved: Int,
                total: Int,
                previousAchieved: Int
            ) -> String {
                "Food \(achieved)/\(total) vs \(previousAchieved)/\(total) last week"
            }

            static func weekOverWeekProtein(
                achieved: Int,
                total: Int,
                previousAchieved: Int
            ) -> String {
                "Protein \(achieved)/\(total) vs \(previousAchieved)/\(total) last week"
            }

            static func weekOverWeekWater(
                achieved: Int,
                total: Int,
                previousAchieved: Int
            ) -> String {
                "Water \(achieved)/\(total) vs \(previousAchieved)/\(total) last week"
            }

            static func weekOverWeekTraining(
                achieved: Int,
                previousAchieved: Int
            ) -> String {
                "Training \(achieved) vs \(previousAchieved) last week"
            }
        }
    }
    // MARK: - Weekly review presentation

    enum WeeklyReviewPresentation {
        static let sectionTitle = "Weekly health review"
        static let loadingTitle = "Loading weekly review"
        static let loadingSubtitle = "Summarizing your week."
        static let loadingAccessibilityLabel = "Loading weekly health review"
        static let emptyTitle = "Weekly review building"
        static let notEnoughDataTitle = "Not enough data yet"
        static let notEnoughDataSummary =
            "Log meals, workouts, and recovery signals for at least 7 days to unlock your weekly review."
        static let notEnoughDataRequirements =
            "Requires: 7 days of activity or recovery signals, plus consistent meal logging."
        static let emptySummary =
            "Keep logging meals, workouts, and recovery signals to unlock your weekly health review."
        static let emptyAccessibilityLabel = "Weekly health review unavailable. Keep logging to unlock it."
        static let partialDataSummary =
            "Your weekly health patterns are summarized using the data available this week."

        static let confidenceHigh = "High confidence"
        static let confidenceModerate = "Moderate confidence"
        static let confidenceLow = "Limited confidence"

        static let statUnavailable = "Not enough data"
        static let weightUnavailable = "Log weight to see weekly change"
        static let nutritionLimitedDetail = "Limited nutrition data this week"
        static let activityLimitedDetail = "Limited activity data this week"
        static let recoveryLimitedDetail = "Limited recovery data this week"

        static let workoutsTitle = "Workouts"
        static let stepsTitle = "Average steps"
        static let proteinTitle = "Protein days"
        static let caloriesTitle = "Calorie days"
        static let waterTitle = "Water days"
        static let recoveryTitle = "Recovery"
        static let weightTitle = "Weight trend"
        static let loggingTitle = "Logging days"

        static let statsSectionTitle = "This week at a glance"
        static let limitedStatAccessibilitySuffix = "Limited data"

        static let winsHeader = "Wins"
        static let risksHeader = "Watch next week"
        static let focusHeader = "Next week focus"

        static func generatedAtLabel(for date: Date, calendar: Calendar = .current) -> String {
            let dayLabel = JourneyFormatter.timelineDayLabel(date, calendar: calendar)
            return "Updated \(dayLabel)"
        }

        static func missingDataNotice(for signals: Set<WeeklyReviewMissingSignal>) -> String {
            guard !signals.isEmpty else { return "" }

            let labels = missingSignalLabels(for: signals).sorted()
            if labels.count == 1 {
                return "\(labels[0]) was limited this week, so parts of this review use partial data."
            }
            let joined = labels.dropLast().joined(separator: ", ")
            let last = labels.last ?? "Some signals"
            return "\(joined), and \(last) were limited this week, so parts of this review use partial data."
        }

        static func confidenceLabel(for confidence: WeeklyReviewConfidence) -> String {
            switch confidence {
            case .high: return confidenceHigh
            case .moderate: return confidenceModerate
            case .low: return confidenceLow
            }
        }

        static func workoutsValue(count: Int, minutes: Int) -> String {
            guard count > 0 else { return "None logged" }
            let workoutLabel = count == 1 ? "1 workout" : "\(count) workouts"
            guard minutes > 0 else { return workoutLabel }
            return "\(workoutLabel) · \(FormaProductCopy.Journey.HealthIntelligence.durationLabel(minutes: minutes))"
        }

        static func dayCountValue(_ count: Int, total: Int = 7) -> String {
            "\(count) of \(total) days"
        }

        static let dailyReviewsTitle = "Daily reviews"

        static func dailyReviewsValue(_ count: Int, total: Int = 7) -> String {
            dayCountValue(count, total: total)
        }

        enum Freshness {
            static let updatedJustNow = "Updated just now"
            static let savedToAccount = "Saved to your account"
            static let syncingChanges = "Some changes are still syncing"
            static let reviewMayUpdate = "Review may update when your latest logs finish syncing"
            static let restoringAccount = "Restoring account data…"
        }

        static func weightTrendValue(_ changeKg: Double) -> String {
            let formatted = String(format: "%.1f", abs(changeKg))
            if changeKg < 0 {
                return "\(formatted) kg down"
            }
            if changeKg > 0 {
                return "\(formatted) kg up"
            }
            return "Held steady"
        }

        static func recoveryValue(score: Double?) -> String {
            guard let score else { return statUnavailable }
            return "Avg \(Int(score.rounded()))"
        }

        private static func missingSignalLabels(for signals: Set<WeeklyReviewMissingSignal>) -> [String] {
            signals.map { signal in
                switch signal {
                case .sleep: return "Sleep"
                case .hrv: return "Heart variability"
                case .weight: return "Weight"
                case .nutrition: return "Nutrition"
                case .workouts: return "Workouts"
                case .activity: return "Activity"
                case .recovery: return "Recovery"
                }
            }
        }
    }
    // MARK: - Weight spike education

    enum WeightSpikeEducation {
        static let shortTitle = "Noisy scale week"

        static let shortBody =
            "One weigh-in can jump without meaning your plan stopped working. "
            + "Look at your weekly trend before changing calories."

        static let detailBody =
            "Your latest weigh-in jumped, but one spike does not mean your plan stopped working. "
            + "Sodium, carbs, soreness, sleep, and hydration can all move the scale. "
            + "Look at your weekly trend before changing calories."

        static let accessibilityLabel =
            "Noisy scale week. Your latest weigh-in jumped, but one spike does not mean your plan stopped working. "
            + "Sodium, carbs, soreness, sleep, and hydration can all move the scale. "
            + "Look at your weekly trend before changing calories."

        static let waitRecommendationTitle = "Wait before changing calories"

        static let waitRecommendationMessage = shortBody

        static let waitRecommendationReason =
            "A sudden jump can reflect sodium, carbs, soreness, sleep, or hydration — not a full week of progress."

        static let holdSteadyNote =
            "Hold steady for now and keep logging. One weigh-in is not enough to change your plan."

        static let confidenceSuffix =
            " The scale looks noisy this week, so look at the weekly trend before changing calories."

        static let noisyWeekHeadline = shortTitle
    }
}
