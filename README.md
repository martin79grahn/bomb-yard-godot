# Bomb Yard (Godot)

Mega Drive-versionen av Bomb Yard ([bomb-yard-nes](https://github.com/martin79grahn/bomb-yard-nes), mappen `md/`) gjord om i Godot 4.5, så att den går att spela på **Android-telefonen**, i Linux och i Windows.

Reglerna är flyttade funktion för funktion från Mega Drive-spelets `md/src/main.c`, med samma siffror: 60 bilder i sekunden, 16 pixlar stora rutor, stubintid, eldens längd, bossarnas träffar, bomber, räckvidd och fart. Musiken och ljudeffekterna är Mega Drive-versionens egna, men grafiken är helt ny:

- **Grafiken** är modern 3D med realistiskt ljus. Banan ses snett uppifrån, med solljus och skuggor, ambient occlusion, glöd och reflektioner, och varje bana har egen himmel, egen dimma och eget ljus. Golv, väggar och sprängbara block har PBR-material (färg, normal map och ojämnhet) som `tools/make_textures.py` räknar fram ur brus, Voronoi-celler och mönster: gräs, krusig sand, sprucken is, vulkansten med glödande lavasprickor, moln och havsbotten; betong, sandsten, isblock, basalt, guldmarmor och korall; trälådor, tegel, snötegel, glödande magma, bomullsmoln och snäckklädd sten. Figurerna, monstren, bossarna, bomberna och power-upsen är 3D-modeller med animationer (`models.gd`): de går, flaxar, viftar på svansen och svävar. Explosionerna är eldstrålar med en shader (`fire.gdshader`), ljusblixtar, gnistor, rök och block som flyger i bitar, och skärmen skakar. Menyerna och panelerna har ny modern design.
- **Musiken** är Mega Drive-låtarna (VGM-filerna från `md/res/music`), renderade till OGG av `tools/render_music.py` med ffmpeg (libgme spelar FM-synten). Titellåten, de sex banornas låtar, bosslåten och jinglarna när du klarar en bana, vinner eller får game over.
- **Ljudeffekterna** är Mega Drive-versionens WAV-filer: explosion, bomb, power-up, hjärta, död, bossträff, klocktick och menyljud.

Banan är 16×13 rutor, som på Mega Drive, mellan två paneler. Skärmen är byggd för 1280×720; på en bredare skärm, till exempel en telefon, blir det plats till vänster och höger, och där sitter knapparna. På datorn används renderaren Forward+, på telefonen Mobile (Vulkan).

## Spela på telefonen (Android)

1. Ladda ner den senaste `BombYard-v….apk` från [Releases](https://github.com/martin79grahn/bomb-yard-godot/releases) på telefonen.
2. Öppna filen. Första gången frågar Android om webbläsaren eller filhanteraren får installera okända appar: tillåt det.
3. Starta **Bomb Yard**. Spelet visas liggande, i helskärm.

På skärmen finns:

| Knapp | Gör |
| --- | --- |
| Styrkorset (vänster) | Gå. Dra fingret mellan riktningarna. I menyerna: välj |
| BOMB (höger) | Lägg bomb. I menyerna: ändra |
| BOOM | Med remote: spräng dina bomber (lyser grönt när du har en). Annars lägger den en bomb. I menyerna: tillbaka |
| START / PAUSE (uppe till höger) | Börja, pausa och fortsätt |
| Tillbakaknappen | Pausa. I pausen: tillbaka till titelskärmen |

Det går också att trycka direkt i menyerna: på 1 PLAYER, 2 PLAYERS eller BOSS RUSH, på en rad i inställningarna för att ändra den, och på START PLAY. Två spelare på samma telefon får varsin uppsättning knappar, spelare 2 i den övre halvan.

En handkontroll via Bluetooth fungerar också.

## Spelet

Allt från Mega Drive-versionen finns med:

- **1 spelare:** sex banor (The Yard, Sand Pit, Frost Cave, Lava Peak, Cloud Nine och Deep Sea) med två monster på varje (Kraxar, kobror, yetis, eldsdjävlar, änglar och clownfiskar) och en bossbana efter varje bana: Krax-kungen, skorpionen, mammuten, draken, åskmolnet och hajen. Sist kommer den gröna bombaren hemma i The Yard. Bossarna blir svårare för varje bana, och halvvägs blir de arga, rödare och snabbare, med en bomb till. De skadas inte av sina egna bomber.
- **Boss rush:** bara de sju bossarna, en efter en.
- **2 spelare:** välj bana, monster på eller av, hur många vunna rundor som krävs (3, 5 eller 10) och vilken figur var och en har.
- **Debugläge:** du går genom väggar och kan inte dö.
- Inställningar: liv (3, 5 eller 10), antal power-ups av varje sort under stenarna (1–7) och figur: Bit, Ruby, Sky eller Nova. Valen sparas till nästa gång.
- Power-ups: bomber, eld, skor, ett hjärta (1 spelare), 2 **penetratorbomber** som spränger igenom stenblocken och 2 **remotes** som låter dig spränga bomberna när du vill. Penetratorn och remoten försvinner när du dör.
- Två minuter per bana. De sista 20 sekunderna går musiken fortare och en klocka tickar.
- Styrhjälpen: ett tryck strax före en korsning sparas, ett tryck upp till 5 pixlar för sent svänger ändå, och motsatt riktning vänder direkt.

## Tangentbord och handkontroll

| | 1 spelare och menyer | 2 spelare: spelare 1 | 2 spelare: spelare 2 |
| --- | --- | --- | --- |
| Gå | Pilarna eller WASD | WASD | Pilarna |
| Lägg bomb | Mellanslag, X eller C | Mellanslag eller F | Enter eller / |
| Remote | Z eller Shift | E eller G | Shift eller . |
| Start / paus | Enter eller P | P | |

Esc pausar, går tillbaka i menyerna och avslutar från titelskärmen. M stänger av och på ljudet, F11 växlar helskärm och T visar knapparna för pekskärm på datorn. C på titelskärmen slår på debugläget.

Handkontroll 1 styr spelare 1 och handkontroll 2 spelare 2: styrkorset eller vänster spak går, A och X/Y lägger bomber, B spränger med remote (annars bomb) och Start pausar.

## Datorn

Ladda ner zip-filen för Linux eller Windows från Releases, packa upp den och kör `BombYard.x86_64` eller `BombYard.exe`.

## Bygga

Du behöver Godot 4.5.1 med exportmallarna. Öppna mappen i Godot, eller:

```sh
godot --headless --export-release "Linux" export/linux/BombYard.x86_64
godot --headless --export-release "Windows" export/windows/BombYard.exe
```

För Android behövs Android SDK (`platform-tools`, `build-tools;35.0.0`, `platforms;android-35`) och Java, inställda i Godots editorinställningar (`export/android/android_sdk_path` och `java_sdk_path`), och en nyckel att signera med. Nyckeln ligger inte i repot:

```sh
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/.android/bomb-yard-release.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=bombyard \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
godot --headless --export-release "Android" export/BombYard.apk
```

Texturerna och musiken i `assets/` är incheckade. Texturerna räknas fram igen med `python3 tools/make_textures.py` (behöver Python 3 med NumPy och Pillow). Om Mega Drive-versionens musik eller ljud ändras hämtas de från bomb-yard-nes (behöver ffmpeg med libgme):

```sh
python3 tools/render_music.py ~/bomb-yard-nes
cp ~/bomb-yard-nes/md/res/sfx/*.wav assets/sfx/
```

## Filer

- `main.gd`: spelet: reglerna (från `main.c`), menyerna, meddelandena och panelerna.
- `world.gd`: 3D-vyn. Den läser spelets läge varje bild och bygger banan, blocken, bomberna, elden, power-upsen och figurerna i 3D, med ljus, himmel, dimma, partiklar och kamera.
- `models.gd`: 3D-modellerna: de fyra figurerna, den gröna bombaren, de sex monstren, bossarna, bomberna och power-upsen.
- `fire.gdshader`: explosionernas eld.
- `touch.gd`: knapparna på skärmen för telefonen.
- `audio.gd`: musik och ljudeffekter, på tre kanaler som på Mega Drive.
- `assets/`: texturerna (`tex/`), typsnitten (Noto Sans, `fonts/`) och musiken och ljuden från Mega Drive-versionen.
- `tools/`: verktygen som tar fram dem.
