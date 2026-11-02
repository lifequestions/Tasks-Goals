# Open Range

An iPhone and iPad app that lifts the 25 km/h speed limit on a Cowboy e-bike
(C1+, C2, C3) for riding on private land, with safety rules built in.

It sends the same Bluetooth commands documented by
[Cowboy Untamed](https://github.com/Imaginous/Cowboy_Untamed/blob/main/IOS.md).
The command bytes were checked against every value in that guide.

## Built-in restrictions

- **Rules screen on first launch.** The rider has to agree to private land only before the app opens.
- **Temporary by default.** The change lasts until the bike is locked, then the 25 km/h limit comes back.
  "Keep after locking" is off by default and asks for confirmation.
- **No maximum setting.** Extra speed tops out at 18%. The guide's 25% "absolute maximum" isn't offered.
- **One-tap restore.** "Restore road-legal settings" puts the factory settings back and saves them to the bike.

## Put it on your phone

**Mac with Xcode (iPhone or iPad):**
1. Open `Open Range.swiftpm` in Xcode.
2. Plug in the phone, pick it as the run destination and press Run.
3. If Xcode asks for a signing team, choose your Apple ID (Xcode → Settings → Accounts).
4. On the phone: Settings → Privacy & Security → Developer Mode → on (first time only).

With a free Apple ID the app stops opening after 7 days; press Run again to renew it.
A paid Apple Developer account (US$99/year) makes it last a year.

**iPad with Swift Playgrounds:** copy `Open Range.swiftpm` to the iPad (AirDrop or Files),
open it in Swift Playgrounds and press Run. There's no 7-day limit this way.

## Using it

1. Unlock the bike in the Cowboy app, then swipe the Cowboy app closed.
2. Open Open Range → Find my bike → tap your bike.
3. Choose the extra speed and tap Unleash.
4. To undo, tap Restore road-legal settings. Locking the bike also undoes it unless "Keep after locking" was on.

## Caveats

- Cowboy voids the warranty on bikes where this has been used.
- Without the limit the bike is illegal on public roads in most countries.
- Not yet tried on a real bike. The commands are reported to work on firmware 4.21 and older. Newer "Adaptive Power 2.0"
  firmware can cut power after a stop. Restore the settings if that happens.
- C4 / C4 ST support is partial according to the Untamed project.
