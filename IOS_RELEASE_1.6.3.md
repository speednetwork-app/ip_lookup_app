# Pikayun 1.6.3 (17) — TestFlight device testing

## Scope

- Latest consistent yellow/charcoal UI across Home, Lines, IP Lookup, History and Account.
- Smaller transparent cloud-and-lightning in-app mark; opaque yellow-background iOS launcher icon.
- Apple-system typography with Chinese fallback; light/dark and large-text layouts.
- Email registration connected to the existing backend rules, including its one-use arithmetic challenge and conditional email verification/invitation fields.
- Existing login/session storage, subscription, traffic, IP/history and VPN flows preserved.
- No payments, shop, purchase links or new paid products in this build.

## Distribution

Upload to App Store Connect/TestFlight for internal real-device testing only. Do not submit this build for App Store review or change production server settings as part of this upload.

## Device acceptance

1. Confirm version 1.6.3 (17), launcher icon, smaller transparent header mark, all five tabs and both appearances.
2. Test existing-account login, secure session restore and logout.
3. Test registration with an email controlled by the tester; verify validation and real backend rejection/retry states. Registration does not promise a paid plan or free quota.
4. With an active plan, select an online VLESS line, accept first-connection disclosure and the iOS VPN configuration prompt, connect, verify actual public IP, disconnect and relaunch.
5. Check account/traffic refresh, concealed subscription display/copy, IP lookup and local history deletion.
6. Confirm large accessibility text remains usable.

## Not ready for App Store review

- Account creation now exists; user-initiated account deletion is still missing and must be implemented before App Store submission.
- Existing server email-verification code contains sensitive debug logging. Do not enable or exercise real email delivery until this is fixed and delivery/security is verified.
- Hosted privacy policy and App Store Connect disclosures must be synchronized before release.

See `docs/EMAIL_REGISTRATION_CHECKLIST.md` for the audited backend contract and remaining safeguards. These are known limitations, not features hidden from review.
