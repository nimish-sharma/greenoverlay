GREEN EDGE OVERLAY — GitHub cloud build bundle

This package includes the Xcode project and a GitHub Actions workflow that builds
the macOS app on a GitHub-hosted macOS runner. You do NOT need to install Xcode locally.

BUILD STEPS
1. Sign in to GitHub (create a free account if needed).
2. Create a NEW repository. Private is fine.
3. On the repository page choose Add file > Upload files.
4. Extract this ZIP on your Mac, open the extracted folder, and upload ALL its contents,
   including the hidden .github folder and the GreenEdgeOverlay.xcodeproj folder.
   If Finder hides .github, use the Terminal upload method or enable hidden files with Command+Shift+.
5. Commit the uploaded files to the main branch.
6. Open the repository's Actions tab.
7. Select "Build macOS app" on the left, then click "Run workflow" if it has not started.
8. Wait for the green checkmark. Open the completed workflow run.
9. Download the artifact named "GreenEdgeOverlay-macOS".
10. Unzip it. Move GreenEdgeOverlay.app to Applications.
11. On first launch, right-click the app > Open if macOS warns that it is from an unidentified developer.

NOTES
- This cloud build produces an unsigned local-use app. It is not notarized for public distribution.
- GitHub Actions may require enabling Actions for the repository.
- The workflow runs on Apple's macOS runner; no local Xcode installation is needed.
