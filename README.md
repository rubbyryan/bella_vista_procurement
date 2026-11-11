# Bella Vista Procurement System (Flutter web frontend)

Frontend-only build with in-memory demo data. All workflow rules from the spec run in `lib/core/store.dart`.

## Run it
1. Install Flutter (3.27 or newer): https://docs.flutter.dev/get-started/install  then `flutter doctor`
2. `flutter create bella_vista_procurement --platforms=web,android,ios`
3. `flutter pub get` then `flutter run -d chrome`

Demo accounts (password `Bella@2026`): requester@, stores@, head@, om@, ho@, driver@, security@ `bellavista.ac.zw`
(the sign-in page also has one-tap demo chips).

## Test the whole flow
requester: new requisition > stores: review & send > head approve > om approve > ho final approve >
ho: Release batch (partial allowed) > Vouchers: Release funds > driver, security, stores sign > stores: Add to stock.
Reject at any level: a comment of 10+ characters is mandatory. Settings > Reset demo data restores the seed.

