# Localization and resources

Every string a person sees, and every resource a module ships, goes through the accessors Tuist generates
(`Tuist/ProjectDescriptionHelpers/Resources.swift`). Nothing is looked up by a name in code.

## Languages

`appLanguages`: en (the source), ar, de, es, fr, hi, it, ja, pl, pt, ru, tr, uk, zh-Hans, zh-Hant. The Settings app's
Acknowledgements (`OpenSkateMap/Resources/Settings.bundle`) ship the same set.

## Strings

- Each module keeps its own strings in `Resources/<language>.lproj/Localizable.strings` (`buildableFolders:
  ["Sources", "Resources"]` in its `Project.swift`). English is written by hand; the other languages are translations
  of it, with the same keys. A new or changed English string ships with all 14 translations:
  `mise run ios:check-translations` (also run before every push) fails on a missing key, a format specifier that differs
  from English, or a plural without `other`.
- The system's permission prompts are in the app's `Resources/<language>.lproj/InfoPlist.strings`, keyed by the
  Info.plist key (`NSCameraUsageDescription`); Info.plist keeps the English as the fallback. The strings template
  (`Tuist/ResourceSynthesizers/Strings.stencil`, Tuist's own with the enum `nonisolated`, so nonisolated code in
  main-actor modules can read it) generates accessors for the `Localizable` table only.
- Tuist generates `<Module>Strings` from the English file, nested by the key's dots: `"welcome.map.title"` is
  `OnboardingKitStrings.Welcome.Map.title`. Key segments are lowerCamelCase words (`newSpot`, `deleteAccount`); every
  segment but the last becomes an enum (`NewSpot`). Keys start with the screen or component (`welcome.`, `profile.`,
  `newSpot.`), then the element (`title`, `subtitle`, `confirm`, `a11y.close`).
- Text with values in it is one key with format specifiers, never concatenation: `"%@ in %@"` becomes
  `func x(_ p1: Any, _ p2: Any) -> String`; use positional specifiers (`%1$@`, `%2$@`) when there are two or more, so
  translations can reorder them. `%@` takes strings, `%d` / `%ld` integers.
- Anything with a count is a plural in `Localizable.stringsdict` (`one` and `other` in English; translators add the
  categories their language needs, such as `few` and `many` in Russian, Polish, Ukrainian and Arabic). Tuist generates
  a function taking the count.
- A comment above an entry (`/* … */`) tells translators what it is when the key doesn't: a button, a VoiceOver
  label, a word in a sentence, the 30-character width of a tab.
- Copy rules stay as in English: no closing period on a headline, label, button or single sentence.
- Quotation marks are the language's own and live in the format string: “%@”, „%@“ (German), „%@” (Polish), «%@»
  (French with no-break spaces, Italian, Russian, Ukrainian, Arabic), 「%@」 (Japanese, Traditional Chinese). A value is
  inserted isolated, so an Arabic string with only punctuation around its value starts with `\U200F` (a right-to-left
  mark); without it the line runs left to right and the marks wrap onto the wrong ends.
- Not localized: log messages, identifiers (accessibility identifiers, user-defaults keys, URLs, SF Symbol names),
  brand names standing alone (OpenSkateMap, Instagram), and DEBUG-only text.
- Arabic lays the whole interface out right to left: layout uses PinLayout's start and end, and left and right only for
  physical placements (root `AGENTS.md`, Right to left; lint `pinlayout_left_right`).

## Images, clips and fonts

- Images live in a module's `Resources/Assets.xcassets` and are used through `<Module>Asset.<name>.image`
  (`"instagram-glyph"` is `instagramGlyph`). A clip's poster is an image set too.
- Clips and other loose files are used through `<Module>Files.<name>.url` (`WelcomeMap.mp4` is
  `OnboardingKitFiles.welcomeMap`): the project's own template, `Tuist/ResourceSynthesizers/Files.stencil`, makes one
  flat, module-prefixed enum, so two modules' accessors never clash.
- Fonts (none yet) are used through `<Module>FontFamily`.
- `UIImage(named:)`, `Bundle.module.url(forResource:)` and `UIFont(name:)` don't appear in `Sources` (lint
  `generated_resource_accessors`).
