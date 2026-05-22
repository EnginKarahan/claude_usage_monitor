# Claude Usage Monitor — KDE Plasma 6 Widget

[Read in English](README.md)

![Screenshot der Pills in der Leiste und des Detail-Tooltips](docs/screenshot.png)

Ein dezentes Taskleisten-Widget für **KDE Plasma 6** (getestet auf
Plasma 6.6, Fedora 44), das deinen Claude.ai-Pro/Max-**Sitzungs**- (5 h)
und **Wochen**-Tokenverbrauch (7 d) anzeigt, samt Prognose bis zum
nächsten Reset.

Es nutzt den OAuth-Token, den Claude Code bereits in
`~/.claude/.credentials.json` abgelegt hat, und fragt denselben Endpoint
ab wie der `/usage`-Slash-Befehl von Claude Code — kein Scraping, kein
separater Login.

> **Hinweis.** Dieses Projekt ist **nicht mit Anthropic verbunden, von
> Anthropic unterstützt oder gesponsert**. „Claude" und „Claude.ai" sind
> Marken von Anthropic, PBC und werden hier nur nominativ verwendet, um
> den Dienst zu bezeichnen, mit dem das Widget kommuniziert. Das Widget
> nutzt einen undokumentierten Endpoint, den Anthropic jederzeit ändern
> oder einschränken kann.

## Was du siehst

Zwei kleine Pillen in der Leiste:

- `S 42 %` — aktueller 5-Stunden-Sitzungsverbrauch
- `W 79 %` — aktueller 7-Tage-Wochenverbrauch

Farbe (pro Pille unabhängig berechnet):

| Farbe   | Bedeutung                                                       |
|---------|------------------------------------------------------------------|
| 🔵 Blau   | Prognose unter 95 % — Tokens werden voraussichtlich übrig sein. |
| 🟢 Grün   | Prognose 95–100 % — Optimum.                                    |
| 🟡 Gelb   | Prognose 100–103 % — am Limit.                                  |
| 🔴 Rot    | Prognose ≥ 103 % — du wirst vor dem Reset leerlaufen.            |

Die Prognose basiert auf einer gleitenden Burn-Rate aus den letzten
Samples und ist auf einen 4-Stunden-Horizont begrenzt, damit ein kurzer
Burst direkt nach einem Reset nicht ins nächste Quartal extrapoliert wird.

Mauszeiger drauf für Tooltip mit den vollen Zahlen; Klick öffnet die
Detail-Ansicht mit Fortschrittsbalken, Burn-Rate und Reset-Zeit.
Mittelklick erzwingt sofortiges Neu-Lesen des Caches.

## Installation (aus dem Quellcode)

```bash
git clone https://github.com/EnginKarahan/claude_usage_monitor.git
cd claude_usage_monitor
./install.sh
```

Dabei wird:
- `~/.local/bin/claude-widget-poll` (Python-Poller) installiert
- ein systemd-User-Timer eingerichtet und aktiviert (Polling alle 5 min)
- das Plasmoid via `kpackagetool6` installiert

Danach in KDE: Rechtsklick auf die Leiste → *Elemente hinzufügen oder
verwalten…* → suche nach **Claude Usage Monitor** und ziehe es an die
gewünschte Stelle.

## Installation (KDE Store)

Nach Veröffentlichung im KDE Store installierbar über *Elemente hinzufügen
oder verwalten…* → *Neue Elemente holen…* und Suche nach „Claude Usage
Monitor". Der Backend-Poller braucht trotzdem den einmaligen
`./install.sh`-Lauf für den systemd-Timer — der KDE Store liefert nur
das Plasmoid aus.

## Voraussetzungen

- **KDE Plasma 6.x** mit `kpackagetool6` (`plasma-workspace`)
- **Python 3.9+** (nur Standardbibliothek, kein `pip install` nötig)
- Ein **Claude-Code-Login**: einmalig `claude` starten und
  authentifizieren; das Widget liest den Token aus
  `~/.claude/.credentials.json`.

## So funktioniert es

1. **Backend** (`backend/claude_widget_poll.py`)
   - Liest den OAuth-Access-Token aus `~/.claude/.credentials.json`.
   - `GET https://api.anthropic.com/api/oauth/usage` → liefert
     `{five_hour: {utilization, resets_at}, seven_day: {…}, …}`.
   - Hält die letzten 24 Samples in `~/.cache/claude-widget/history.json`
     und berechnet daraus die Burn-Rate, wobei Samples vor dem letzten
     erkannten Reset ignoriert werden.
   - Schreibt `~/.cache/claude-widget/status.json` atomar.

2. **systemd-User-Timer** (`backend/systemd/`)
   - `claude-widget-poll.timer` triggert den Dienst alle 5 min.
   - Übersteht Neustarts (`Persistent=true`); feuert 2 min nach Login
     einmal initial.

3. **Frontend** (`plasmoid/`)
   - QML-Plasmoid (`PlasmoidItem`) mit Compact- und Full-Representation.
   - Liest `status.json` alle 30 s via `Plasma5Support.DataSource`
     (billig, lokal, kein Netzwerk).

## Nützliche Befehle

```bash
systemctl --user status  claude-widget-poll.timer
systemctl --user start   claude-widget-poll.service   # jetzt pollen
journalctl   --user -u   claude-widget-poll -f         # Poller-Logs verfolgen

# Letzten Status zeigen:
jq . ~/.cache/claude-widget/status.json

# Plasma neu starten (sicher; Fenster bleiben offen):
systemctl --user restart plasma-plasmashell
```

## Deinstallation

```bash
./uninstall.sh
```

## Bekannte Einschränkungen

- Der Endpoint `/api/oauth/usage` ist **undokumentiert**. Ändert Anthropic
  ihn, liefert der Poller HTTP-4xx/5xx und das Widget zeigt einen Fehler
  im Tooltip; Details in `journalctl --user -u claude-widget-poll`.
- Der OAuth-`accessToken` läuft regelmäßig ab. Claude Code erneuert ihn
  bei jeder interaktiven Sitzung; wenn du Claude eine Weile nicht nutzt
  und das Widget `HTTP 401` zeigt, einfach einmal `claude` starten.
- Das `seven_day`-Fenster rollt offenbar stündlich, nicht wöchentlich —
  `resets_at` ist der nächste stündliche Tick, nicht „Ende der Woche".
  Das Widget begrenzt den Prognose-Horizont auf 4 h, damit das keine
  unsinnigen Zahlen produziert.

## Lizenz

[MIT](LICENSE). Marken gehören ihren jeweiligen Eigentümern (siehe
LICENSE für den Markenhinweis).

## Mitwirken

Übersetzungen und Bugfixes sind willkommen. Übersetzungsdateien liegen
in `plasmoid/contents/locale/`. Für eine neue Sprache:

1. `template.pot` zu `<lang>.po` kopieren und übersetzen.
2. Mit `msgfmt <lang>.po -o <lang>/LC_MESSAGES/plasma_applet_com.karahan.claudewidget.mo` kompilieren.
3. Pull Request öffnen.

Bug-Reports: bitte `journalctl --user -t plasmashell -n 200` und die
Ausgabe von `~/.local/bin/claude-widget-poll` mitschicken, damit die
relevanten Logs vorhanden sind.
