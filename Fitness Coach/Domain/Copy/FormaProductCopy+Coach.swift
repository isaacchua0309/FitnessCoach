//
//  FormaProductCopy+Coach.swift
//  Fitness Coach
//
//  Coach and food form copy.
//

import Foundation

extension FormaProductCopy {
    // MARK: - Coach

    enum Coach {
        static let headerSubtitle = "What do you want to log or ask?"
        static let todaySoFarSectionTitle = "Today so far"
        static let suggestedNextSectionTitle = "Suggested next"
        static let quickActionsSectionTitle = "Quick actions"
        static let emptyIntro = EmptyState.CoachConversation.body
        static let composerPlaceholder = "Message Coach…"
        static let scanMealPrefill = "Scan my meal"
        static let mealLoggingComposerPlaceholder = "Send a photo or describe your meal."

        static func mealLoggingComposerPlaceholder(mealType: MealType?) -> String {
            switch mealType {
            case .breakfast:
                return "What did you eat for breakfast? Send a photo or describe your meal."
            case .lunch:
                return "What did you eat for lunch? Send a photo or describe your meal."
            case .dinner:
                return "What did you eat for dinner? Send a photo or describe your meal."
            case .snack:
                return "What did you eat for a snack? Send a photo or describe your meal."
            case .unknown, nil:
                return "What did you eat? Send a photo or describe your meal."
            }
        }

        static let composerListeningPlaceholder = "Listening…"
        static let composerPhotoClarificationPlaceholder = "Add a detail about your meal…"
        static let foodEstimatePending = "Food estimate ready"
        static let reviewEstimate = "Review estimate"
        static let logPending = "Log"
        static let confirmPending = "Confirm"
        static let editPending = "Edit"
        static let discardPending = "Discard"
        static let retryMealPhotoAnalysis = "Retry analysis"
        static let removePhotoBeforeAddingAnother = "Remove the current photo before adding another."
        static let composerImageProcessing = "Preparing photo…"
        static let composerImageRetry = "Retry"
        static let mealPhotoPreparationFailed =
            "Couldn't prepare this photo. Try taking another photo in better lighting."
        static let photoAnalysisLeadIn = "From your meal photo:"
        static let foodEditPortionFooter = "Edit if the portion or cut is different."
        static let foodEditIngredientsFooter = "Edit if you know the ingredients."
        static let foodConfirmBelowFooter = "Confirm below to add it."
        static let pendingBarHint = "Use the bar below to log, edit, or discard."
        static let foodLoggedTimelineNote = "Added to today's timeline."
        static let pendingReviewBeforeLogging = "Please review before logging."
        static let pendingSourceMealPhoto = "Source: meal photo"
        static let pendingSourceCommonFood = "Source: usual food"

        static func latestMealLine(name: String, calories: Int) -> String {
            "Latest: \(name) · \(calories) kcal"
        }

        enum Launch {
            static let logMealBody = "Send a photo, speak, or describe your meal — whatever is easiest."
            static let analyzePhotoHeadline = "Scan your meal"
            static let analyzePhotoBody = "Take a photo or describe what you ate — Coach handles the rest."
            static let logWaterHeadline = "Log water"
            static let logWaterBody = "Tap below to add water, or tell Coach how much you drank."
            static let chipSectionTitle = "Get started"

            static func logMealHeadline(mealType: MealType?) -> String {
                switch mealType {
                case .breakfast: return "Log breakfast"
                case .lunch: return "Log lunch"
                case .dinner: return "Log dinner"
                case .snack: return "Log a snack"
                case .unknown, nil: return "Log your meal"
                }
            }

            static func waterLogCommand(amountMl: Int) -> String {
                "Add \(amountMl)ml water"
            }

            enum Chip {
                static let takePhoto = "Take photo"
                static let describeMeal = "Describe meal"
                static let useVoice = "Use voice"
                static let takePhotoHint = "Opens the camera to photograph your meal"
                static let describeMealHint = "Focuses the message field to type your meal"
                static let useVoiceHint = "Starts voice input for your meal"
                static let addWaterHint = "Sends a water log command to Coach"

                static func addWater(amountMl: Int) -> String {
                    amountMl >= 1_000 ? "Add \(amountMl / 1_000)L water" : "Add \(amountMl)ml water"
                }
            }
        }
    }

    // MARK: - Food form

    enum FoodForm {
        static let estimateSection = "Estimate"
        static let whatYouAteSection = "What you ate"
        static let portionSection = "Portion"
        static let componentsSection = "Components"
        static let nutritionSection = "Nutrition"
        static let advancedSection = "More details"

        static let foodName = "Food name"
        static let foodNamePlaceholder = "e.g. chicken rice"
        static let mealType = "Meal type"
        static let amount = "Amount"
        static let amountPlaceholder = "1"
        static let unit = "Unit"
        static let unitPlaceholder = "g, pieces, bowl…"
        static let calories = "Calories"
        static let protein = "Protein"
        static let carbs = "Carbs"
        static let fat = "Fat"
        static let fiber = "Fiber"
        static let sodium = "Sodium"
        static let notes = "Notes"
        static let notesPlaceholder = "Optional notes"

        static let editNutritionTitle = "Edit nutrition"
        static let createCustomFoodTitle = "Create custom food"

        static let kcalUnit = "kcal"
        static let gramsUnit = "g"
        static let mgUnit = "mg"
        static let mlUnit = "ml"
        static let kgUnit = "kg"
    }
}
