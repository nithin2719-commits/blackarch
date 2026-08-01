# Submitting the package

Everything here is built and verified. The remaining steps all need **your**
credentials — an AUR account and SSH key, a GitHub login — which is why they are
written out rather than done for you.

`v1.0.0` is tagged and pushed, and `PKGBUILD` carries the real `sha256sum` of
that tag's tarball. `makepkg` builds it, and `check()` runs the test suite
during the build.

---

## 1. AUR (do this first)

The AUR is the only route you control end to end, and the other two use it as
evidence that the package works and has users.

```bash
# once: an SSH key, registered at https://aur.archlinux.org/ under My Account
ssh-keygen -t ed25519 -C "aur"          # you have no key yet — this creates one
cat ~/.ssh/id_ed25519.pub               # paste into the AUR account page

ssh aur@aur.archlinux.org help          # should greet you, not "Permission denied"

git clone ssh://aur@aur.archlinux.org/blackarch-toolbox.git aur-blackarch-toolbox
cd aur-blackarch-toolbox
cp ../packaging/{PKGBUILD,.SRCINFO,blackarch-toolbox.install} .
git add PKGBUILD .SRCINFO blackarch-toolbox.install
git commit -m "Initial import: blackarch-toolbox 1.0.0"
git push
```

Before pushing, run `namcap PKGBUILD *.pkg.tar.zst` if you have it
(`sudo pacman -S namcap`) — AUR reviewers do.

**On the name.** The package ships BlackArch's logo and calls itself "BlackArch
Toolbox". Add a line to the AUR description making clear it is not an official
BlackArch project, or rename it (`toolbox-launcher`, say) to avoid implying
endorsement. This is the single most likely thing to draw a complaint.

---

## 2. BlackArch

BlackArch takes packages as PRs against their own repository, each as a
`PKGBUILD` under `packages/<name>/`. Their contributing guide is the source of
truth — read it rather than this file, as their layout and required fields
change:

- <https://github.com/BlackArch/blackarch> → `CONTRIBUTING.md`
- <https://blackarch.org/faq.html>

You will need `gh` (`sudo pacman -S github-cli && gh auth login`) or the web UI
to open the PR. Expect them to ask what this does that an existing launcher does
not — have an answer ready, and point at the AUR page as evidence it is used.

---

## 3. Arch official repositories

**There is no submission process.** Packages reach `[extra]` when an Arch
Package Maintainer decides to adopt them, and they look at AUR votes and
popularity when deciding. So this is a consequence of step 1 going well, not a
step you can take. Do not spend time on it now.

---

## Keeping it discoverable

GitHub **topics** are what make the repo show up in searches, and they can only
be set through the web UI or the API:

Repo page → About (gear icon) → Topics. Suggested:

```
blackarch  archlinux  security-tools  pentesting  launcher  rofi
bash  cli  linux  infosec  wayland  hyprland
```

Also worth doing on the repo page:
- set the **description** to the one-liner from the README
- tick **Releases** so `v1.0.0` shows in the sidebar
- add a release from the tag, with the CHANGELOG entry as the body

---

## When you cut the next version

```bash
# bump VERSION and CHANGELOG.md first
git tag -a v1.1.0 -m "..." && git push origin v1.1.0
curl -sL -o /tmp/v.tar.gz \
  https://github.com/nithin2719-commits/blackarch_toolbox/archive/refs/tags/v1.1.0.tar.gz
sha256sum /tmp/v.tar.gz            # put this in PKGBUILD
# bump pkgver, reset pkgrel=1, then:
makepkg --printsrcinfo > .SRCINFO  # in the AUR clone
git commit -am "Update to 1.1.0" && git push
```

---

## Enabling CI

`packaging/ci/tests.yml` is a ready GitHub Actions workflow: it runs the suite on
Arch, Debian, Ubuntu, Fedora and Alpine, plus shellcheck, on every push.

It is **not** in `.github/workflows/` because pushing there needs a token with
the `workflow` scope, which the token in use here does not have. Move it
yourself:

```bash
mkdir -p .github/workflows
git mv packaging/ci/tests.yml .github/workflows/tests.yml
git commit -m "ci: run the suite on five distros" && git push
```

If that push is rejected the same way, regenerate your GitHub token with the
`workflow` scope ticked, or add the file through the web UI
(Actions → New workflow → set up a workflow yourself → paste).

The README already carries the badge for it, which will stay grey until the
workflow exists.
