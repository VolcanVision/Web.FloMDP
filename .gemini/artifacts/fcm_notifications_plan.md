# FCM Notifications Implementation Plan

## Overview
Implement Firebase Cloud Messaging (FCM) push notifications for the SCM App to notify users about key events based on their roles.

## Target Platforms
- Android (primary)
- iOS (if applicable)
- Web (limited - requires HTTPS and service worker)

---

## Notification Events Matrix

| Event | Admin | Accounts | Production | Lab Testing |
|-------|-------|----------|------------|-------------|
| New Order Creation | ✅ | ✅ | ✅ | ❌ |
| Production Completed | ✅ | ❌ | ✅ | ❌ |
| Order Ready | ✅ | ✅ | ✅ | ❌ |
| Order Dispatched | ✅ | ✅ | ❌ | ❌ |
| Manual Inventory Update | ✅ | ❌ | ✅ | ❌ |
| Lab Test Completed | ✅ | ❌ | ❌ | ✅ |
| Location Updated | ✅ | ✅ | ❌ | ❌ |
| Order Delivered | ✅ | ✅ | ❌ | ❌ |
| Todo Task Allotted | ✅ | Party | Party | Party |
| Todo Reminder (Day of) | ✅ | Party | Party | Party |
| Todo Completed | ✅ | Party | Party | Party |
| Payment Update | ✅ | ✅ | ❌ | ❌ |
| Payment Reminder (Purchase) | ✅ | ✅ | ❌ | ❌ |
| Payment Reminder (Sale-Final) | ✅ | ✅ | ❌ | ❌ |

---

## Phase 1: Firebase Setup (Prerequisites)

### 1.1 Firebase Console Setup
- [x] Create Firebase project (or use existing)
- [x] Register Android app with package name
- [x] Register iOS app with bundle ID
- [x] Download `google-services.json` → placed in `android/app/`
- [x] Download `GoogleService-Info.plist` → placed in `ios/Runner/`
- [x] Generate Firebase Admin SDK private key → placed in root folder

### 1.2 Android Configuration
- [x] Update `android/settings.gradle.kts` with Google Services plugin
- [x] Update `android/app/build.gradle.kts` with apply plugin
- [ ] Set minimum SDK version to 21+ if needed (check after build)

### 1.3 iOS Configuration (if applicable)
- [ ] Enable Push Notifications capability in Xcode
- [ ] Upload APNs key to Firebase Console

---

## Phase 2: Flutter Client Setup

### 2.1 Dependencies
- [x] Added to `pubspec.yaml`:
  - firebase_core: ^2.24.2
  - firebase_messaging: ^14.7.10
  - flutter_local_notifications: ^16.3.0

### 2.2 Files Created
- [x] `lib/services/fcm_service.dart` - FCM initialization and token management

### 2.3 Main.dart Updates
- [x] Initialize Firebase before runApp()
- [x] Initialize FCM service
- [x] Request notification permissions

---

## Phase 3: Database Schema

### 3.1 SQL Migration Created
- [x] `supabase/migrations/create_fcm_tables.sql`
  - `fcm_tokens` table with user_id, token, role, device_info
  - `notifications_log` table for tracking sent notifications
  - RLS policies for security
  
### 3.2 ACTION REQUIRED: Run SQL in Supabase
Go to your Supabase Dashboard → SQL Editor and run the contents of:
`supabase/migrations/create_fcm_tables.sql`

---

## Phase 4: Server-Side (Supabase Edge Functions) - PENDING

### 4.1 Edge Function: `send-notification`
- [ ] Create Edge Function to send FCM messages
- [ ] Store Firebase Admin SDK key as Supabase secret
- [ ] Receives: event_type, title, body, data, target_roles[]
- [ ] Queries fcm_tokens table for matching roles
- [ ] Sends FCM messages via Firebase Admin SDK

### 4.2 Database Triggers - PENDING
- [ ] Create triggers on relevant tables

---

## Phase 5: Next Steps

### Immediate Actions Required:
1. **Run the SQL migration** in Supabase SQL Editor
2. **Add Firebase Admin SDK key to Supabase secrets**:
   - Go to Supabase Dashboard → Settings → Secrets
   - Add a secret named `FIREBASE_SERVICE_ACCOUNT`
   - Paste the contents of `mdplastics-c4912-firebase-adminsdk-fbsvc-1b02ad7d63.json`
3. **Test on Android device** (not web) to verify FCM token generation

### Then we will:
1. Create the Supabase Edge Function for sending notifications
2. Add database triggers for each event type
3. Test end-to-end notification flow

---

## Files Created/Modified

### New Files:
- ✅ `lib/services/fcm_service.dart`
- ✅ `supabase/migrations/create_fcm_tables.sql`
- ✅ `android/app/google-services.json` (user provided)
- ✅ `ios/Runner/GoogleService-Info.plist` (user provided)
- ✅ `mdplastics-c4912-firebase-adminsdk-*.json` (user provided)

### Modified Files:
- ✅ `pubspec.yaml` - added Firebase dependencies
- ✅ `lib/main.dart` - initialize Firebase and FCM
- ✅ `android/settings.gradle.kts` - Google Services plugin
- ✅ `android/app/build.gradle.kts` - apply plugin

---

## Status: PHASE 2 COMPLETE - AWAITING USER ACTION
