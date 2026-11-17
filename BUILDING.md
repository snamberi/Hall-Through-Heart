# Test builds and playing together

## Windows (.exe)

1. Open the project in **Godot 4.7**.
2. **Editor → Manage Export Templates → Download and Install** (once per Godot version).
3. **Project → Export…**, pick **Windows Desktop**, then **Export Project…** (untick *Export With Debug* for a normal copy).
   The preset already writes `build/windows/HallThroughHeart.exe`, with the game's icon and the whole game packed inside, so the .exe is all you need to share.

Windows may warn about an unknown publisher the first time, because the .exe is not code-signed. Choose **More info → Run anyway**.

### The server program (optional)

Pick **Windows Server** in the same window to export `build/windows/HTH_Server.exe`. It is the game built as a *dedicated server*: no window, no sound, made only to host worlds in the background (see **My Servers** below). Put it **next to** `HallThroughHeart.exe`; the game uses it by itself when it is there. Without it, the game hosts with a second, windowless copy of itself, which works the same.

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

On GitHub, go to **Actions → Build test copies → Run workflow**. A few minutes later the finished run has its downloads: **HallThroughHeart-Windows** (the game, with `HTH_Server.exe` beside it) and **HallThroughHeart-Android**. GitHub's machines bring their own Godot, templates, Java and Android SDK.

The workflow also runs by itself when a tag starting with `v` is pushed, for example `v0.2`.

## Playing together (LAN)

Everyone must be on the **same Wi-Fi or network cable**.

1. **Host:** on the title screen, choose **Multiplayer**. Type your name, pick a character, and choose **Host this world**.
   That character's world opens to friends. Your address (like `192.168.1.20`) is shown on the page and in the chat when you arrive.
2. **Friends:** choose **Multiplayer**. Type a name and pick the character to bring.
   The host's game shows up in the list by itself. If it does not, type the host's address and choose **Join**. A game with a password shows a **Password** mark; type it beside the address first.
3. In the game, press **Enter** to chat (the **Chat** button on a phone).

### What is shared

- **The world:** the same land, from the host's seed.
- **The clock:** the host's day and hour.
- **Each other:** everyone sees where the others are, how they move and strike, and their name, level and health.
- **Chat:** messages, plus notes when someone joins, leaves or levels up.
- **Experience:** a monster felled within about 28 tiles of a friend gives that friend 30% of its experience as well.
- **Building:** what anyone builds or takes down is checked by the host and shown to everyone, and kept in the host's world. Only the builder can take down what they built.
- **Weather:** the host's storms and clear skies.

### What is still each player's own

- **Monsters and loot.** Each game runs its own monsters, so friends fight side by side but not the same monster yet.
- **Chests, doors and the ground.** Opening a chest, mining or felling a tree happens in each player's own game.

### Guests' characters

A guest's character comes from one of their own worlds. What it carries, learns and earns in the host's world (items, levels, skills, pets) goes home with it. Its own world is left exactly as it was. When the host closes the game (or a server stops), guests are told why, saved and taken back to the title screen. Hardcore characters cannot visit other worlds.

### If friends cannot find or join the game

- **Windows firewall:** the first time a PC hosts, Windows asks whether *Hall Through Heart* may use the network. Allow it on **private networks**.
- **Ports:** the game uses **UDP port 24680** to play and **24681** to be found. Some routers, and guest or school Wi-Fi, keep devices apart ("client isolation"). Joining cannot work on those networks.
- **Phones:** some phones do not hear the "game here" call. Typing the host's address always works.

## My Servers: hosting in the background

**Host this world** (above) is *normal hosting*: the world is open while you play it, and closes when you leave. **Multiplayer → My Servers** keeps a world up on its own, as a separate program, so friends can play in it whether or not you are.

- **Create Server** makes a new world for the server. **Host Existing World** gives the server a *copy* of one of your worlds. Your own single-player world stays as it was.
- **Play** starts the server and joins it with the character chosen at the top. **Start** only starts it.
- **Rejoin**, **Save**, **Stop**, **Settings**, **Log** and **Delete** do what they say. **Log** also lists the server's backups, each with **Restore** (when the server is stopped).
- While a server of yours runs, the title screen says **Your Server Is Running**, with **Rejoin**.

### The settings

- **World:** the server's name, a new world or a copy of one of yours, world name, seed, difficulty and **Permadeath** (a player who dies may not come back).
- **Who can join:**
  - up to **20 players**;
  - **LAN** (shown to players on your network) or **Private** (joined by address only);
  - an optional **password**, kept only as a hash;
  - **Let others join** (off: only you);
  - the **port**. Each server needs its own port, to run at the same time as another.
- **Hosting:**
  - **Background:** keeps running when you close the game.
  - **Persistent:** Background, plus it comes back by itself after a crash.
  - **Restart after a crash:** at most 5 times in 10 minutes, so a world that cannot start does not spin.
  - **Start with Windows:** off unless you turn it on.
  - **Tray icon:** on by default.
  - **Autosave:** every 1–60 minutes.
  - **Rest when nobody is on:** 4 updates a second instead of 20.
  - **Pause time when empty.**
- **Resources:** most active chunks, simulation distances, most open dungeons, background quality, and a memory warning. Today the server keeps the clock, weather and buildings and lets players in. These limits are for its world simulation as that grows.

### Seeing and stopping it

Nothing about a server is hidden.

- **Task Manager:** each server shows as **HTH_Server.exe** (or a second **HallThroughHeart.exe**). A server with crash restart also has a small supervisor of the same name.
- **Tray icon:** shows the server's status and who is on. It can save, restart or stop the server, open its log, or open the game, even with the game closed. On Windows it sits by the clock. On Linux it is a small window.
- **Stopping:**
  - **Stop** (in My Servers or the tray) tells everyone why, saves, keeps a backup and ends the program.
  - A stopped server never starts again by itself. Crash restart only applies to a server that ended without being told to.
  - Start with Windows only applies when you sign in, and only if you turned it on.

### Where it lives, and why it is safe

Each server has a folder: `%APPDATA%\Godot\app_userdata\Hall Through Heart\servers\<id>\` on Windows (**Log → Open Folder** opens it). It holds:

- `server.json`: the settings.
- `world.json`: the world.
- `players\`: where each player left off.
- `backups\`: the 6 newest copies, made every 30 minutes and each time the server stops.
- `server.log`: what the server did.

Saving is safe in three ways:

- **Whole saves only:** the world is written to a new file first and only then put in place, so a crash mid-save never leaves half a world. If the file is ever damaged, the last whole copy or the newest backup is used.
- **One writer:** only one program can host a world at a time. A second one, started by mistake, refuses and stops.
- **No early saves:** a server saves nothing until it has fully loaded its world. A request left over from before it started (like an old *stop*) is ignored.

### Not there yet

- **Monsters, bosses and loot** are still each player's own (see *What is still each player's own* above). The server does not run them yet.
- **Public server list:** there is no listing on the internet, because that needs a separate service. LAN discovery and joining by address work without one. To play over the internet, forward the server's UDP port on your router and share your public address.
- **Moving a world to another host** (host migration) is not built.
