# Sandfall Rescue

A match-3 rescue puzzle built in Godot 4. Match gems next to the falling debris to drain it before Zaki's door gives way.

- **Android:** download the APK from the [latest release](../../releases/latest).
- **Play in a browser:** the web build is published to GitHub Pages on every push.

Every push to `main` runs `.github/workflows/build.yml`. It imports the project, auto-plays two levels and saves screenshots, then exports the Android APK and the web build.

## Project layout

- `scripts/main.gd`: board, debris simulation, power-ups, levels and rendering
- `scripts/ui.gd`: HUD, level select, win and lose cards
- `shaders/sand.gdshader`: draws each debris cell as a rendered grain sprite
- `assets/gfx`: art rendered with Blender (gems, power-ups, hero, props, walls)
- `assets/sfx`: synthesized sound effects
- `assets/fonts`: Lilita One and Nunito (SIL Open Font License)
- `android/sandfall-test.keystore`: test-only signing key for sideloaded builds. Store builds will use a private key kept in GitHub secrets.
