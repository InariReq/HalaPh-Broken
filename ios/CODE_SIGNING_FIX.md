# iOS Code Signing Fix for Production Deployment

## Issue
The error `0xe8008014 (The executable contains an invalid signature)` occurs when the iOS app binary is not properly signed with a valid certificate and provisioning profile.

## Root Causes
1. **Missing or Invalid Provisioning Profile**: The app doesn't have a valid provisioning profile that matches the bundle identifier
2. **Expired Certificate**: The development certificate has expired
3. **Bundle ID Mismatch**: The certificate doesn't match the app's bundle identifier
4. **Missing Entitlements**: Required capabilities are not included in the provisioning profile

## Solutions

### Option 1: Fix Code Signing (Recommended)
1. **Update Bundle Identifier**:
   - Ensure your bundle ID matches your Apple Developer account
   - Update in `ios/Runner/Info.plist` and `firebase.json`

2. **Generate Valid Provisioning Profile**:
   - Go to Apple Developer Portal
   - Create a development provisioning profile for your bundle ID
   - Download and install the profile

3. **Install Valid Certificate**:
   - Generate or renew your development certificate
   - Install it in Keychain Access

4. **Update Xcode Project**:
   ```bash
   cd ios
   open Runner.xcodeproj
   # In Xcode: Runner → Target → Runner → Signing & Capabilities
   # Select your development team and provisioning profile
   ```

### Option 2: Use Automatic Code Signing
Add to `ios/Runner.xcodeproj/project.pbxproj`:
```xml
<key>CODE_SIGN_STYLE</key>
<string>Automatic</string>
```

### Option 3: Build for Distribution
For production deployment:
```bash
flutter build ios --release
```

### Option 4: Use Fastlane (Advanced)
Create a `Fastfile` for automated code signing:
```ruby
lane :beta do
  build_app(
    scheme: "Runner",
    configuration: "Release",
    export_method: "development"
  )
end
```

## Verification Commands
```bash
# Check code signing status
codesign -dv --verbose=4 build/ios/iphoneos/Runner.app

# Verify provisioning profile
security cms -D -i build/ios/iphoneos/Runner.app/embedded.mobileprovision

# Check entitlements
codesign -d --entitlements -r build/ios/iphoneos/Runner.app
```

## Quick Fix for Development
If you just want to test locally:
```bash
flutter build ios --debug --no-codesign
# This builds without code signing for local testing
```

## Production Deployment Steps
1. Fix code signing in Xcode
2. Build with: `flutter build ios --release`
3. Test on physical device
4. Deploy to App Store Connect

## Files to Check
- `ios/Runner/Info.plist` - Bundle ID and permissions
- `ios/Runner.xcodeproj/project.pbxproj` - Code signing configuration
- `firebase.json` - Firebase configuration
- Your Apple Developer Provisioning Profiles
- Your Certificates in Keychain Access
