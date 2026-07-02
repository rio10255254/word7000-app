# Word7000 App Store Submission Notes

This file is the launch handoff for the first iOS submission. Use it when App Store Connect becomes available.

## App Identity

- App Name: Word7000
- Subtitle: Daily vocabulary practice
- Category: Education
- Age Rating Direction: 4+, no user-generated public content, no objectionable content, no unrestricted web browsing.
- Bundle ID: com.rio.word7000

## Description Draft

Word7000 helps learners build a steady daily vocabulary habit with a focused 7000-word library, study cards, quizzes, review lists, custom word sets, and account sync.

Practice English vocabulary with Chinese explanations, or switch into Chinese word mode with an English interface. Save words, review weak items, create custom folders, and keep progress available across devices after signing in.

## Keywords

vocabulary, english, chinese, flashcards, quiz, word list, language learning, study, review, TOEIC, exam

## Promotional Text

Build a daily word habit with study cards, quizzes, review lists, and custom vocabulary sets.

## Privacy Policy URL

https://word7000-app.rio10255254.workers.dev/privacy.html

## Support URL

https://word7000-app.rio10255254.workers.dev/support.html

## Support Email

rio10255254@gmail.com

## Review Notes

Most learning features work without signing in. Sign-in is optional and is used for cloud sync across devices.

Google sign-in is the primary sync method. Apple Sign In is enabled for the iOS build. Email sign-in remains as a fallback.

If App Review needs a test account for cloud sync, create a temporary Supabase email/password user before submission and enter it here:

- Demo Account: create before submission
- Demo Password: create before submission

Do not reuse a personal account for review.

## Account Deletion

Signed-in users can open My > Settings > Delete Account Learning Data. The app asks for confirmation before deletion. This removes synced learning progress, custom sets, and daily active records, then signs the user out.

## Privacy Nutrition Label Direction

- Data linked to user: email or account identifier for sign-in and sync.
- User content: custom word sets and manually added vocabulary.
- Usage data: daily active usage record for basic app analytics.
- Not used for third-party advertising.
- Not sold to data brokers.

## Screenshot Checklist

- Home screen showing daily progress and mode switch.
- Study card with example sentence and save/review actions.
- Quiz screen with selectable question count.
- Library screen with search, filters, and custom sets entry.
- Word detail screen.
- My screen with sign-in and learning stats.
- Settings screen with privacy, support, dark mode, and account data deletion.

## Before Submission

- Confirm Apple Developer membership is active.
- Configure EAS Update after Expo login.
- Build a production iOS binary.
- Upload to TestFlight.
- Install TestFlight build on an iPhone and test sign-in, sign-out, account deletion, study, quiz, library, and custom sets.
- Fill App Store Connect privacy answers consistently with this file.
