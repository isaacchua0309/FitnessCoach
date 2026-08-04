//
//  FormaProductCopy+Settings.swift
//  Fitness Coach
//
//  Settings hub, privacy, theme, and profile form copy.
//

import Foundation

extension FormaProductCopy {
    // MARK: - Settings

    enum Settings {

        enum Hub {
            static let screenTitle = "Settings"
            static let doneAccessibilityLabel = "Done"
            static let accountSectionTitle = "Account"
            static let preferencesSectionTitle = "Preferences"
            static let integrationsSectionTitle = "Integrations"
            static let privacyDataSectionTitle = "Privacy & Data"
            static let supportSectionTitle = "Support"
            static let aboutSectionTitle = "About"
            static let developerSectionTitle = "Developer"
        }

        enum Rows {
            static let account = "Account"
            static let units = "Units"
            static let appleHealth = "Apple Health"
            static let privacyPolicy = "Privacy Policy"
            static let accountDataStatus = "Account data status"
            static let syncStatus = "Sync status"
            static let healthDataNote = "Health data note"
            static let exportAccountData = "Export account data"
            static let exportData = "Export Data"
            static let deleteAccount = "Delete Account"
            static let deleteLocalDeviceData = "Delete local data from this device"
            static let sendFeedback = "Send Feedback"
            static let contactSupport = "Contact Support"
            static let reportProblem = "Report a Problem"
            static let appVersion = "App Version"
            static let termsOfService = "Terms of Service"
            static let authDiagnostics = "Auth diagnostics"
            static let pipelineTraces = "Pipeline traces"
            static let healthIntelligenceSnapshot = "Health intelligence snapshot"
            static let coachContextInspector = "Coach context inspector"
            static let accountSyncDiagnostics = "Account sync diagnostics"
            static let accountRestoreDiagnostics = "Account restore diagnostics"
            static let contextLoopReport = "Report with ContextLoop"
        }

        enum Developer {
            static let sectionFooter = "Debug tools are only visible in internal builds."
        }

        enum Support {
            static let feedbackMailSubject = "Forma Feedback"
            static let contactMailSubject = "Forma Support"
            static let reportProblemMailSubject = "Forma Problem Report"
            static let sectionFooter = "We read every message. Diagnostics help us troubleshoot — no health data is included."
            static let diagnosticsHeader = "Diagnostics"
            static let feedbackMailPrompt = "Share your feedback:"
            static let contactMailPrompt = "How can we help?"
            static let reportProblemMailPrompt = "What went wrong?"
        }

        enum Status {
            static let connected = "Connected"
            static let notConnected = "Not connected"
            static let metric = "Metric"
            static let imperial = "Imperial"
        }

        enum AppleHealth {
            static let screenTitle = "Apple Health"
            static let healthDataDetailsTitle = "Health data details"
            static let permissionsSectionTitle = "Permissions"
            static let statusLabel = "Connection status"
            static let lastLocalSyncLabel = "Last local sync"
            static let lastRemoteSyncLabel = "Last remote summary sync"
            static let remoteSummarySyncLabel = "Remote summary sync"
            static let lastSyncNever = "Not yet synced"
            static let statusConnected = "Connected"
            static let statusPartiallyConnected = "Partially connected"
            static let statusNotConnected = "Not connected"
            static let statusPermissionNeeded = "Permission needed"
            static let statusUnavailable = "Unavailable"
            static let statusConnecting = "Connecting…"
            static let connectAction = "Connect Apple Health"
            static let connectingAction = "Connecting…"
            static let refreshHealthDataAction = "Refresh health data"
            static let refreshingHealthDataAction = "Refreshing…"
            static let openHealthAppAction = "Manage in Apple Health"
            static let manageHealthDataSyncAction = "Manage health data sync"
            static let deleteRemoteSummariesAction = "Delete remote health summaries"
            static let deletingRemoteSummariesAction = "Deleting…"
            static let loadFailedMessage = "Couldn't load Apple Health settings. Try again."
            static let healthKitUnavailableMessage =
                "Apple Health isn't available on this device. Health settings stay read-only here."
            static let deleteRemoteSummariesFailedMessage =
                "Couldn't delete remote health summaries. Try again when you're signed in."
            static let connectAccessibilityHint = "Requests permission to read selected Apple Health signals"
            static let connectingAccessibilityHint = "Unavailable while connecting"
            static let openHealthAccessibilityHint = "Opens the Health app to manage Forma permissions"
            static let refreshHealthDataAccessibilityHint = "Refreshes cached health summaries on this device"
            static let manageHealthDataSyncAccessibilityHint = "Opens cloud health summary sync settings"
            static let deleteRemoteSummariesAccessibilityHint =
                "Deletes normalized health summaries stored for your account"

            enum RemoteSync {
                static let screenTitle = "Health data sync"
                static let intro =
                    "Choose whether Forma stores normalized health summaries in your account. Raw HealthKit samples are never uploaded."
                static let statusLabel = "Sync status"
                static let lastSyncLabel = "Last remote sync"
                static let lastSyncNever = "Not yet synced"
                static let syncNowAction = "Sync now"
                static let syncingAction = "Syncing…"
                static let deleteRemoteSummariesAction = "Delete remote health summaries"
                static let deleteConfirmationTitle = "Delete remote health summaries?"
                static let deleteConfirmationMessage =
                    "This removes normalized health summaries stored for your Forma account. Your Apple Health data is not changed."
                static let deleteConfirmActionTitle = "Delete summaries"
                static let statusDisabled = "Off"
                static let statusIdle = "Ready"
                static let statusSyncing = "Syncing"
                static let statusSucceeded = "Up to date"
                static let statusPartialSuccess = "Partially synced"
                static let statusFailed = "Needs attention"

                enum Consent {
                    static let toggleTitle = "Sync health summaries"
                    static let toggleDescription =
                        "Forma can sync normalized health summaries to keep Coach and weekly insights consistent across devices. This may include daily step totals, workout summaries, recovery status, and weekly review summaries. Forma does not upload raw Apple Health samples."
                    static let enableTitle = "Enable health summary sync?"
                    static let enableMessage = toggleDescription
                    static let enableConfirmAction = "Enable sync"
                    static let disableTitle = "Turn off health summary sync?"
                    static let disableMessage =
                        "Forma will stop syncing new health summaries. Local Apple Health features on this device keep working."
                    static let disableConfirmAction = "Turn off sync"
                    static let disableAndDeleteAction = "Turn off and delete summaries"
                    static let statusOn = "On"
                    static let statusOff = "Off"
                    static let statusNotSet = "Not enabled"
                }
            }

            // Legacy copy retained for settings hub row summaries.
            static let readsWorkoutsCopy =
                "Forma reads workouts to improve activity, Plan confidence, and Journey insights."
            static let doesNotWriteCopy =
                "Forma does not write or change your Health data."
            static let connectionCardTitle = "Connection"
            static let lastSyncLabel = "Last sync"
            static let permissionsLabel = "Permissions"
            static let accessLabel = "Access"
            static let permissionsWorkouts = "Workouts"
            static let accessManagedInHealthApp = "Managed in Health app"
        }

        /// Theme preferences screen and color palette copy.
        enum Theme {
            static let screenTitle = "Theme"
            static let navigationRowTitle = "Theme"
            static let appearanceSectionTitle = "Appearance"
            static let colorThemeSectionTitle = "Color Theme"
            static let livePreviewSectionTitle = "Preview"
            static let livePreviewPrimaryButton = "Continue"
            static let livePreviewLogPill = "Log meal"
            static let livePreviewProgressLabel = "Calories"
            static let livePreviewProgressValue = "68%"
            static let livePreviewAccessibilityLabel =
                "Live theme preview showing a primary button, progress, tab selection, and coach log action"

            enum Appearance {
                static let systemTitle = "System"
                static let systemDescription = "Match device appearance"
                static let lightTitle = "Light"
                static let lightDescription = "Always use light appearance"
                static let darkTitle = "Dark"
                static let darkDescription = "Always use dark appearance"
            }

            enum ColorPalette {
                static let oceanBlueTitle = "Ocean Blue"
                static let oceanBlueDescription = "Calm and focused"
                static let blossomPinkTitle = "Blossom Pink"
                static let blossomPinkDescription = "Warm and friendly"
                static let emeraldGreenTitle = "Emerald Green"
                static let emeraldGreenDescription = "Fresh and healthy"
                static let sunsetOrangeTitle = "Sunset Orange"
                static let sunsetOrangeDescription = "Energetic and bold"
            }

            enum Error {
                static let loadFailedTitle = "Couldn't load your theme"
                static let loadFailedMessage =
                    "We restored Forma's default look. You can pick a color theme below."
            }

            static func appearanceTitle(for mode: AppAppearanceMode) -> String {
                switch mode {
                case .system: Appearance.systemTitle
                case .light: Appearance.lightTitle
                case .dark: Appearance.darkTitle
                }
            }

            static func appearanceDescription(for mode: AppAppearanceMode) -> String {
                switch mode {
                case .system: Appearance.systemDescription
                case .light: Appearance.lightDescription
                case .dark: Appearance.darkDescription
                }
            }

            static func colorPaletteTitle(for palette: AppThemePalette) -> String {
                switch palette {
                case .oceanBlue: ColorPalette.oceanBlueTitle
                case .blossomPink: ColorPalette.blossomPinkTitle
                case .emeraldGreen: ColorPalette.emeraldGreenTitle
                case .sunsetOrange: ColorPalette.sunsetOrangeTitle
                }
            }

            static func colorPaletteDescription(for palette: AppThemePalette) -> String {
                switch palette {
                case .oceanBlue: ColorPalette.oceanBlueDescription
                case .blossomPink: ColorPalette.blossomPinkDescription
                case .emeraldGreen: ColorPalette.emeraldGreenDescription
                case .sunsetOrange: ColorPalette.sunsetOrangeDescription
                }
            }

            static func appearanceAccessibilityLabel(
                for mode: AppAppearanceMode,
                isSelected: Bool
            ) -> String {
                let selection = isSelected ? "selected, " : ""
                return "\(appearanceTitle(for: mode)), \(selection)\(appearanceDescription(for: mode))"
            }

            static func colorPaletteAccessibilityLabel(
                for palette: AppThemePalette,
                isSelected: Bool
            ) -> String {
                let title = colorPaletteTitle(for: palette)
                let description = colorPaletteDescription(for: palette)
                let selection = isSelected ? "selected" : "not selected"
                return "\(title), \(description), \(selection)"
            }
        }

        /// Units preference screen copy.
        enum Units {
            static let screenTitle = "Units"
            static let unitSystemSectionTitle = "Unit system"
            static let examplesSectionTitle = "Examples"
            static let storageFootnote =
                "Forma stores values consistently and converts them for display."
            static let imperialDisplayOnlyFootnote =
                "Imperial changes display units only. Values are stored internally in metric."

            static let exampleWeightLabel = "Weight"
            static let exampleHeightLabel = "Height"
            static let exampleWaterLabel = "Water"
            static let exampleEnergyLabel = "Energy"

            static func unitSystemPickerLabel(for unitSystem: UnitSystem) -> String {
                switch unitSystem {
                case .metric:
                    return "Metric (kg, cm, ml)"
                case .imperial:
                    return "Imperial (lb, ft/in, fl oz)"
                }
            }

            static func unitSystemAccessibilityLabel(
                for unitSystem: UnitSystem,
                isSelected: Bool
            ) -> String {
                let selection = isSelected ? "selected" : "not selected"
                return "\(unitSystemPickerLabel(for: unitSystem)), \(selection)"
            }
        }

        /// Body & stats settings screen copy.
        enum BodyDetails {
            static let profileDetailsSectionTitle = "Profile details"
            static let introCopy =
                "These details help Forma estimate targets and personalize your plan."
            static let updateInPlanCTA = "Update in Plan"
            static let updateInPlanAccessibilityHint = "Opens Adjust Plan to update your body details"
            static let startingWeightLabel = "Starting weight"
            static let currentWeightLabel = "Current weight"
            static let notSetValue = "Not set"
        }

        /// Privacy & Data settings section copy.
        enum PrivacyData {
            static let sectionFooter =
                "Counts and timestamps only — no food names, weights, or calories appear here."

            static let accountStatusScreenTitle = "Account data status"
            static let accountStatusAccountLabel = "Account"
            static let accountStatusSignInMethodLabel = "Sign-in method"
            static let accountStatusLastRestoreLabel = "Last restore"
            static let accountStatusSignedIn = "Signed in"
            static let accountStatusSignedOut = "Not signed in"

            static let syncStatusScreenTitle = "Sync status"
            static let syncStatusPendingUploadsLabel = "Pending uploads"
            static let syncStatusLastSyncLabel = "Last sync"
            static let syncStatusLastRestoreLabel = "Last restore"
            static let syncStatusRestoreInProgressLabel = "Restore in progress"
            static let syncStatusYesValue = "Yes"
            static let syncStatusNoValue = "No"
            static let syncStatusNotYetSynced = "Not yet synced"
            static let timestampUnavailable = "Not available"

            static func syncStatusPendingCount(_ count: Int) -> String {
                count == 1 ? "1 pending" : "\(count) pending"
            }

            static func countLabel(_ count: Int) -> String {
                "\(count)"
            }

            static let exportUnavailableStatus = "Not available"
            static let exportUnavailableMessage =
                "Export account data is not available in this version of Forma yet."

            static let healthDataNoteScreenTitle = "Health data note"
            static let healthDataNoteBodyParagraphs: [String] = [
                "Forma can remove locally cached health summaries and uploaded app health summaries tied to your account.",
                "Forma cannot delete the original samples stored in Apple Health on your device.",
                "Deleting account or local data does not remove Apple Health source data."
            ]

            static let deleteAccountConfirmationTitle = "Delete your account?"
            static let deleteAccountConsequenceBullets: [String] = [
                "Deleting your account removes your Forma account and app data stored with your account.",
                "This cannot be undone.",
                "This does not delete data stored in Apple Health.",
                "This does not delete your Google account."
            ]
            static let deleteAccountConfirmActionTitle = "Delete account"
            static let deleteAccountConfirmAccessibilityHint =
                "Permanently deletes your Forma account and associated app data. This cannot be undone."

            static let deleteLocalDeviceDataConfirmationTitle = "Delete local data on this device?"
            static let deleteLocalDeviceDataConsequenceBullets: [String] = [
                "This removes Forma data stored on this device only. Your cloud account and sign-in stay active.",
                "Your cloud-backed data remains and can be restored when you sign in again on this device.",
                "This cannot be undone.",
                "This does not delete data stored in Apple Health.",
                "This does not delete your Google account."
            ]
            static let deleteLocalDeviceDataConfirmActionTitle = "Delete local data only"
            static let deleteLocalDeviceDataConfirmAccessibilityHint =
                "Permanently removes Forma data from this device only. Your cloud account stays active."

            static let typedConfirmationPrompt = "Type DELETE to confirm"
            static let typedConfirmationPlaceholder = "DELETE"
            static let typedConfirmationAccessibilityHint =
                "Required safety confirmation. Type DELETE in capital letters to enable deletion."

            static let deletionProgressPreparing = "Preparing…"
            static let deletionProgressDeletingAccountData = "Deleting account data…"
            static let deletionProgressDeletingAccount = "Deleting account…"
            static let deletionProgressRemovingLocalData = "Removing local data…"
            static let deletionProgressCompleted = "Completed"
            static let deletionProgressAccessibilityLabel = "Account deletion in progress"

            static let deletionFlowCancelTitle = "Cancel"
            static let deletionFlowCancelAccessibilityHint = "Cancels account deletion and returns to Settings"
            static let deletionFlowCloseTitle = "Close"
            static let deletionFlowRetryTitle = "Retry"
            static let deletionFlowReauthenticateTitle = "Reauthenticate and continue"
            static let deletionReauthenticationMessage =
                "Confirm your identity to continue account deletion."
            static let deletionFlowReauthenticateAccessibilityHint =
                "Confirms your identity so account deletion can continue"
            static let deletionFlowUnavailableTitle = "Deletion isn't available"
            static let deletionFlowUnavailableMessage =
                "Account deletion could not start. Sign in and try again."

            static let deleteUnavailableTitle = "Deletion isn't available yet"
            static let deleteUnavailableMessage =
                "Data deletion is not available in this version of Forma. Contact \(FormaProductCopy.Legal.supportEmail) for help."

            static let deletionGenericErrorMessage =
                "Account deletion could not be completed. Try again."
            static let deletionOfflineErrorMessage =
                "Connect to the internet to delete your account data."
            static let deletionPermissionDeniedErrorMessage =
                "You do not have permission to delete this account data."
        }
    }
    // MARK: - Profile form

    enum ProfileForm {
        static let baselineWeight = "Baseline weight"
        static let goalWeight = "Goal weight"
        static let calorieAggressiveness = "Calorie aggressiveness"
        static let calorieTarget = "Calorie target"
        static let proteinTarget = "Protein target"
        static let carbTarget = "Carb target"
        static let fatTarget = "Fat target"
        static let weeklyLoss = "Expected weekly loss"
        static let waterTarget = "Water target"
        static let activityLevel = "Activity level"
        static let trainingDays = "Training days per week"
        static let averageSteps = "Average steps per day"
        static let strengthSessions = "Strength sessions per week"
        static let name = "Name"
        static let age = "Age"
        static let sex = "Sex"
        static let height = "Height"
        static let bodyFat = "Body fat"
        static let unitSystem = "Unit system"
    }
}
