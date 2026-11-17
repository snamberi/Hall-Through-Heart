# Test builds and playing together

## Windows (.exe)

1. Open the project in **Godot 4.7**.
2. **Editor → Manage Export Templates → Download and Install** (once per Godot version).
3. **Project → Export…**, pick **Windows Desktop**, then **Export Project…** (untick *Export With Debug* for a normal copy).
   The preset already writes `build/windows/HallThroughHeart.exe`, with the game's icon and the whole game packed inside, so the .exe is all you need to share.

Windows may warn about an unknown publisher the first time, because the .exe is not code-signed. Choose **More info → Run anyway**.

## Android (.apk)

You need two things once, besides the export templates above:

- **A Java JDK 17** (for example Eclipse Temurin 17).
- **The Android SDK.** Install Android Studio, or only the *command-line tools*, then in the SDK Manager install *platform-tools* and *build-tools* (34 or newer).

Then:

1. In Godot, **Editor → Editor Settings → Export → Android**, set *Java SDK Path* and *Android SDK Path*. Godot makes a debug keystore by itself.
2. **Project → Export…**, pick **Android**, then **Export Project…** with *Export With Debug* ticked.
   This writes `build/android/HallThroughHeart.apk`.
3. Put it on the phone:
   - Copy the .apk to the phone and open it. The phone will ask to *allow installs from this source* the first time.
   - Or, with USB debugging on, run `adb install -r build/android/HallThroughHeart.apk`.

On a phone the game turns sideways and shows **touch controls**:

- **Left thumb:** a move stick appears wherever you touch the left side.
- **Right thumb:** the big button strikes at the nearest foe. Drag it to aim.
- **Around it:** the four abilities, plus *Set*, which switches weapon, universal and class abilities.
- **Also:** Dash, Parry and Use.
- **Right edge:** small buttons for the menu, bag, map and a quick drink.
- **Left side:** Run, Ride and Chat.
- **Back button:** works like Esc.

**Settings → Controls → Touch controls** can turn them on for a touchscreen PC too, or off.

## Builds without installing anything (GitHub)

On GitHub, go to **Actions → Build test copies → Run workflow**. A few minutes later the finished run has two downloads, **HallThroughHeart-Windows** and **HallThroughHeart-Android**. GitHub's machines bring their own Godot, templates, Java and Android SDK.

The workflow also runs by itself when a tag starting with `v` is pushed, for example `v0.2`.

## Playing together (LAN)

Everyone must be on the **same Wi-Fi or network cable**.

1. **Host:** on the title screen, choose **Play Together (LAN)**. Type your name, pick a character, and choose **Host this world**.
   That character's world opens to friends. Your address (like `192.168.1.20`) is shown on the page and in the chat when you arrive.
2. **Friends:** choose **Play Together (LAN)**. Type a name and pick the character to bring.
   The host's game shows up in the list by itself. If it does not, type the host's address and choose **Join**.
3. In the game, press **Enter** to chat (the **Chat** button on a phone).

### What is shared

- **The world:** the same land, from the host's seed.
- **The clock:** the host's day and hour.
- **Each other:** everyone sees where the others are, how they move and strike, and their name, level and health.
- **Chat:** messages, plus notes when someone joins, leaves or levels up.
- **Experience:** a monster felled within about 28 tiles of a friend gives that friend 30% of its experience as well.

### What is still each player's own

- **Monsters and loot.** Each game runs its own monsters, so friends fight side by side but not the same monster yet.
- **Building and breaking.** What a guest builds, breaks or opens in the host's world is not kept.

### Guests' characters

A guest's character comes from one of their own worlds. What it carries, learns and earns in the host's world (items, levels, skills, pets) goes home with it. Its own world is left exactly as it was. When the host closes the game, guests are saved and taken back to the title screen. Hardcore characters cannot visit other worlds.

### If friends cannot find or join the game

- **Windows firewall:** the first time a PC hosts, Windows asks whether *Hall Through Heart* may use the network. Allow it on **private networks**.
- **Ports:** the game uses **UDP port 24680** to play and **24681** to be found. Some routers, and guest or school Wi-Fi, keep devices apart ("client isolation"). Joining cannot work on those networks.
- **Phones:** some phones do not hear the "game here" call. Typing the host's address always works.
