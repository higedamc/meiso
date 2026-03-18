# Zapstore Release Checklist v1.1.9

Release target:

- Version: `1.1.9+323`
- Tag: `v1.1.9`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

## Prepared in this pass

- [x] Updated `pubspec.yaml` to `1.1.9+323`
- [x] Added `1.1.9` release notes to `CHANGELOG.md`
- [x] Validated Zapstore config with `zsp publish --check zapstore.yaml`
- [x] Built release APK (`89M` on disk)

## Pre-publish checks

- [ ] Confirm current branch is the intended release branch
- [ ] Confirm `git diff` contains only release-prep changes
- [ ] Confirm APK exists and opens on test device
- [ ] Confirm signer method for `zsp` (`browser` / `bunker` / `nsec`)

## Publish sequence (run manually)

```bash
# 1) Commit release prep (if needed)
git add CHANGELOG.md pubspec.yaml
git commit -m "update: release v1.1.9"

# 2) Create and push tag
git tag -a v1.1.9 -m "Release v1.1.9"
git push origin v1.1.9

# 3) Create GitHub Release and upload APK
gh release create v1.1.9 \
  --title "Release v1.1.9" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk

# 4) Publish to Zapstore
SIGN_WITH=browser zsp publish zapstore.yaml
```

## Post-publish checks

- [ ] `gh release view v1.1.9` succeeds
- [ ] Zapstore listing reflects `v1.1.9`
- [ ] Release notes displayed correctly
- [ ] APK download/install works from release page
