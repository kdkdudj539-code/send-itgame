# SEND IT

Pixel-Art Freestyle-Spiel im Browser: im Winter mit Ski oder Snowboard, im Sommer mit dem Downhill-Bike (im Menü umschaltbar). Einfach index.html öffnen oder über GitHub Pages spielen.

Pixel art freestyle game in your browser: ski or snowboard in winter, a downhill bike in summer (switch in the menu). Open index.html or play it on GitHub Pages. The game is in German and English: it picks your browser language, and you can switch with DE / EN in the menu.

Schriften: Press Start 2P, Silkscreen, VT323 (SIL Open Font License, siehe fonts/).

## Online (Supabase)

Einmalig im Supabase SQL Editor ausführen:

1. `supabase-setup.sql`: Konten und Rangliste
2. `supabase-save.sql`: Spielstand im Konto (Münzen, gekaufte Sachen, Outfit, Bestwerte)
3. `supabase-rename.sql`: Spielernamen ändern (Rangliste → NAME ÄNDERN; Login und Profilname ändern sich zusammen)
4. `supabase-japan.sql`: eigene Rangliste für die Japan-Map (die bisherige Rangliste bleibt die der Alpen)
5. `supabase-maxscore.sql`: höchster erlaubter Score 100 Millionen (nur nötig, wenn 1. und 4. noch mit der alten Grenze von 2 Millionen angelegt wurden)
6. `supabase-wiehen.sql`: eigene Rangliste für die Wiehengebirge-Map (Ski und Snowboard)
7. `supabase-downhill.sql`: eigene Rangliste für Downhill (alle Bike-Läufe im Sommer, Alpen und Wiehengebirge)
8. `supabase-race-friends.sql`: DH-Race-Rangliste (Bestzeit, kleinste zählt) und Freunde (per Spielername hinzufügen, Ansicht ALLE/FREUNDE in der Rangliste); sichert außerdem ab, dass es keinen Spielernamen doppelt gibt
9. `supabase-stats.sql`: anonyme Spiel-Statistik (zufällige Geräte-Kennung, ein Ereignis beim Öffnen und nach jedem Lauf; im Spiel unter Einstellungen → Statistik abschaltbar). Unten in der Datei stehen fertige Abfragen für die Auswertung: Spieler pro Tag, Wiederkehr am nächsten Tag, Läufe pro Modus, Spielzeit

Weltkarte im Menü: Küstenlinien aus Natural Earth (naturalearthdata.com, gemeinfrei), als kleine Pixelkarte eingebaut.
