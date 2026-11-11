# Bella Vista Procurement System (Flutter web frontend)

Frontend-only build with in-memory demo data. All workflow rules from the spec run in `lib/core/store.dart`.

## Run it
1. Install Flutter (3.27 or newer): https://docs.flutter.dev/get-started/install  then `flutter doctor`
2. `flutter create bella_vista_procurement --platforms=web,android,ios`
3. `flutter pub get` then `flutter run -d chrome`

Demo accounts (password `Bella@2026`): requester@, stores@, head@, om@, ho@, driver@, security@ `bellavista.ac.zw`
(the sign-in page also has one-tap demo chips).

Test registration
Open the app and go to Register.
Click Register with the form empty. Every field should show “Required”.
Try a bad email (abc) and a bad phone (12). Both should be rejected.
Enter mismatched passwords. You should get “Passwords do not match”.
Fill it in properly, for example Test / User / test@bellavista.ac.zw / +263 77 111 2222 / Test@1234, tick the policy box and submit. It should switch to Sign in with a message that the account is inactive until the administrator activates it.
Try signing in as test@bellavista.ac.zw / Test@1234. It should be refused with “pending activation”.
Register the same email again. It should say the account already exists.

Test the admin page
Sign in as admin@bellavista.ac.zw with the demo password Bella@2026. The sidebar should show Dashboard, Users, Settings, and the dashboard should show a “Pending accounts” count.
Open Users. Your new user and Kudzai Banda should be at the top as Pending.
Select your test user. Choose a role, leave the department empty, switch Account active on and click Save. It should refuse with “Select a department before activating”.
Pick a department and save again. The chip should change to Active.
Select your own admin row. The role dropdown and the toggle should be disabled.
Try the search box and the “Pending only” chip.
Narrow the browser window below about 900px and click a user. The editor should open as a bottom sheet.

## Test the whole flow
requester: new requisition > stores: review & send > head approve > om approve > ho final approve >
ho: Release batch (partial allowed) > Vouchers: Release funds > driver, security, stores sign > stores: Add to stock.
Reject at any level: a comment of 10+ characters is mandatory. Settings > Reset demo data restores the seed.

