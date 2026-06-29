# Build the APK in the cloud (no tools installed on your PC)

GitHub will build the APK for you on its own servers, for free. You only need to
get this folder onto GitHub once. After that, every time you upload changes, a fresh
APK is built automatically and you download it from the website.

The build recipe is already in this project at `.github/workflows/build-apk.yml` —
you don't need to touch it.

---

## Step 1 — Make a free GitHub account
Go to https://github.com and sign up (free). Verify your email.

## Step 2 — Install GitHub Desktop (no command line needed)
- Download from https://desktop.github.com and install it.
- Open it and sign in with the GitHub account from Step 1.

## Step 3 — Put this project on GitHub
In GitHub Desktop:
1. **File → Add local repository…**
2. Choose this folder: `Project Time`.
3. It will say *"This directory does not appear to be a Git repository."*
   Click **"create a repository"** (the blue link).
4. On the create screen, leave the defaults and click **Create repository**.
5. Top-right, click **Publish repository**.
   - You can tick **"Keep this code private"** — that's fine, the build still works.
   - Click **Publish repository**.

That upload automatically starts the cloud build.

## Step 4 — Download your APK
1. Go to https://github.com and open your new repository (e.g. `your-name/Project-Time`).
2. Click the **Actions** tab at the top.
3. Click the most recent run named **"Build APK"** (a yellow dot = building, green
   check = done). The first build takes ~5–10 minutes.
4. When it's green, scroll to the **Artifacts** section at the bottom of that run page
   and click **project-time-apk** to download it. It downloads as a `.zip`.
5. Unzip it — inside is **`app-release.apk`**. That's your app.

## Step 5 — Install it on your phone
- Copy `app-release.apk` to your phone (email it to yourself, Google Drive, or USB).
- Tap it on the phone. Allow **"Install from unknown sources"** if asked, then Install.

---

## Rebuilding later
Any time you (or I) change the code, open GitHub Desktop, click **Commit to main**, then
**Push origin**. A new APK builds automatically — grab it from the **Actions** tab again.

You can also trigger a build by hand: repo → **Actions** tab → **Build APK** (left side)
→ **Run workflow**.

## If a build fails (red ✗)
Open the failed run in the **Actions** tab, click the step with the ✗ to see the message,
and paste it to me — I'll fix it. The most likely fix-ups are already noted in
`CONSISTENCY_REPORT.md` under "Expected errors".

---

### Notes
- The APK is signed with a debug key, so it installs for personal use but isn't set up
  for the Google Play Store (that needs a separate signing key).
- The build pins Flutter 3.29.3 for reliability. To use a newer Flutter, change the
  `flutter-version` line in `.github/workflows/build-apk.yml`.
