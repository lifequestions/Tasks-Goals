# Notes for Claude

## Journal app (`journal/`, "Undercurrent" / Life Questions Journal)

- Develop on the branch `claude/adoring-faraday-5opi29`. Pull it before editing: a
  cloud session and a Mac session both push to it.
- **Getting changes onto the iPhone: always over Wi‑Fi, unless the user says otherwise.**
  After any change to the app, on the Mac, run `./journal/install-on-phone.sh` (it
  pulls the branch, builds, and installs on the paired iPhone with `devicectl`). Do not
  wait to be asked, and do not point the user at TestFlight instead.
- A cloud session can't reach the phone. It pushes to the branch and tells the user to
  have the Mac session install it.
- Pushing also sends a TestFlight build through GitHub Actions; that's a backup, not
  the way updates are delivered.
