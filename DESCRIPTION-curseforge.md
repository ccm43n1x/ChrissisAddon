# Chrissi's Addon

**Heads up: the in-game UI is in German.** The addon works on any client, but all labels and guide texts are written in German. If you do not read German, this addon will be of limited use to you.

Sorts your weekly gearing into four priority blocks, tracks crests and Great Vault, and ticks itself off automatically.

## What it does

Every week you face the same question: what actually moves your character forward, and what is a waste of time? This addon answers that in one window instead of five browser tabs.

- **Pinned currencies at the top** — Mistcrests, Sparks, Coffer Keys, Voidcores and Field Accolades, each with a progress bar
- **A weekly checklist as a carousel** — one week per page, click through with `<` and `>`
- **Four priority blocks** instead of a flat list: Do now, Do next, Only if you have time, Do not bother
- **All currencies** on a second tab

## The average item level lies

Most tools show you `GetAverageItemLevel` and leave it at that. A single weak slot drags that number down by roughly one sixteenth, which is easy to miss but still costs you in group finder.

This addon therefore checks **every equipment slot individually**. Hover the item level line and you see your weakest slot by name, plus how many slots sit below your target.

Thresholds live in `data.lua` and can be adjusted without touching any code.

## Ticks itself off

Entries marked `[auto]` are detected by the addon and checked automatically. Detection runs through:

| Type | API |
|---|---|
| Quests | `C_QuestLog.IsQuestFlaggedCompleted` |
| Currencies | `C_CurrencyInfo.GetCurrencyInfo` |
| Renown | `C_MajorFactions.GetMajorFactionData` |
| Great Vault | `C_WeeklyRewards.GetActivities` |

**The automation never removes a tick you set yourself.** Ticks are stored per character, so every alt keeps its own list. They hang on a fixed ID rather than a line number, which means guide text can be rewritten without losing your progress.

## Commands

| Command | Effect |
|---|---|
| `/chrissi` | Toggle window |
| `/chrissi scale 120` | Set size, 50 to 150 percent |
| `/chrissi quellen` | Guide version and source list |
| `/chrissi clear` | Clear all ticks for this character |
| `/chrissi zero` | Show or hide zero balances |
| `/chrissi reset` | Reset position and size |
| `/chrissi help` | Command overview |

Window is draggable, resizable via `-` / `+` or **Ctrl + mousewheel**. Position, size, tab and last viewed week survive a logout.

## Design

Built deliberately without decorative borders, to sit well next to minimal UI setups such as EllesmereUI. Flat semi transparent surface, hairline separators instead of boxes, values right aligned, and colour used only where it carries meaning.

## Accessibility

The four block colours were not picked by taste. They are validated against colour vision deficiency (OKLab distance, deuteranopia / protanopia / tritanopia). The worst neighbouring pair sits at ΔE 9.1 for deuteranopia against a target of 8 or higher. The first draft scored 3.0, where green and yellow were effectively identical for red green colour blind players.

**Colour is never the only carrier of information.** Every block is labelled in text, and the colour sits in a stripe next to the text rather than in the text itself.

## Known limitations

- **The currency tab only shows expanded categories.** Collapsed categories in Blizzard's own currency panel hide their entries from addons too. The addon tells you when entries are missing. The pinned block at the top is unaffected, it queries by ID.
- **Coffer Keys and Voidcores are matched by name** and therefore only resolve on an English client. Everything else in the pinned block runs on IDs and is language independent. If you want to help: run `/chrissi scan` and send me the output.
- The addon only reads and calculates. It cannot make decisions for you or automate anything in game, the WoW API does not allow that.
- The checklist is **not** yet coupled to your character state. It shows the rules but does not apply them to your item level automatically. That is planned.

## Sources

Guide content comes from own research, cross checked against at least two of: Blizzard patch notes, Method, Icy Veins, Wowhead, Warcraft Wiki. Entries resting on a single unverified source are flagged with `[1 Quelle]` in the window.

## License

MIT. The idea of modelling a weekly checklist through fixed hash IDs is inspired by Larias' Weekly Checklist. No code was taken from it.
