import Foundation
import NoteCraftKit

enum L10n {
    enum App {
        static let name = "NoteCraft"
        static let about = String(localized: "Über NoteCraft")
        static let settings = String(localized: "Einstellungen …")
        static let services = String(localized: "Dienste")
        static let hide = String(localized: "NoteCraft ausblenden")
        static let hideOthers = String(localized: "Andere ausblenden")
        static let showAll = String(localized: "Alle einblenden")
        static let quit = String(localized: "NoteCraft beenden")
        static let credits = String(localized: "Ein schneller, nativer Texteditor für den Mac.")
    }

    enum Menu {
        static let file = String(localized: "Ablage")
        static let edit = String(localized: "Bearbeiten")
        static let text = String(localized: "Text")
        static let view = String(localized: "Darstellung")
        static let window = String(localized: "Fenster")
        static let help = String(localized: "Hilfe")

        static let new = String(localized: "Neu")
        static let newTab = String(localized: "Neuer Tab")
        static let open = String(localized: "Öffnen …")
        static let openRecent = String(localized: "Zuletzt benutzte öffnen")
        static let clearRecent = String(localized: "Einträge löschen")
        static let openFolder = String(localized: "Ordner öffnen …")
        static let openQuickly = String(localized: "Schnell öffnen …")
        static let close = String(localized: "Schließen")
        static let save = String(localized: "Sichern …")
        static let duplicate = String(localized: "Duplizieren")
        static let saveAs = String(localized: "Sichern unter …")
        static let rename = String(localized: "Umbenennen …")
        static let moveTo = String(localized: "Bewegen …")
        static let revertTo = String(localized: "Zurücksetzen auf")
        static let encoding = String(localized: "Kodierung")
        static let reopenWithEncoding = String(localized: "Erneut öffnen mit")
        static let convertToEncoding = String(localized: "Konvertieren in")
        static let lineEnding = String(localized: "Zeilenende")
        static let share = String(localized: "Teilen")
        static let revealInFinder = String(localized: "Im Finder zeigen")
        static let copyPath = String(localized: "Pfad kopieren")
        static let pageSetup = String(localized: "Seite einrichten …")
        static let print = String(localized: "Drucken …")

        static let undo = String(localized: "Widerrufen")
        static let redo = String(localized: "Wiederholen")
        static let cut = String(localized: "Ausschneiden")
        static let copy = String(localized: "Kopieren")
        static let paste = String(localized: "Einsetzen")
        static let delete = String(localized: "Löschen")
        static let selectAll = String(localized: "Alles auswählen")
        static let find = String(localized: "Suchen")
        static let findEllipsis = String(localized: "Suchen …")
        static let findAndReplace = String(localized: "Suchen und Ersetzen …")
        static let findNext = String(localized: "Weitersuchen")
        static let findPrevious = String(localized: "Rückwärts suchen")
        static let useSelectionForFind = String(localized: "Auswahl für Suche verwenden")
        static let useSelectionForReplace = String(localized: "Auswahl für Ersetzen verwenden")
        static let jumpToSelection = String(localized: "Zur Auswahl springen")
        static let fileSearch = String(localized: "In Dateien suchen …")
        static let selection = String(localized: "Auswahl")
        static let selectNextOccurrence = String(localized: "Nächstes Vorkommen auswählen")
        static let selectAllOccurrences = String(localized: "Alle Vorkommen auswählen")
        static let selectLine = String(localized: "Zeile auswählen")
        static let goToLine = String(localized: "Gehe zu Zeile …")
        static let spelling = String(localized: "Rechtschreibung und Grammatik")
        static let showSpelling = String(localized: "Rechtschreibung und Grammatik einblenden")
        static let checkSpelling = String(localized: "Dokument jetzt prüfen")
        static let checkSpellingWhileTyping = String(localized: "Während der Texteingabe prüfen")

        static let shiftRight = String(localized: "Einrücken")
        static let shiftLeft = String(localized: "Ausrücken")
        static let toggleComment = String(localized: "Kommentar ein/aus")
        static let duplicateLine = String(localized: "Zeile duplizieren")
        static let moveLineUp = String(localized: "Zeile nach oben bewegen")
        static let moveLineDown = String(localized: "Zeile nach unten bewegen")
        static let deleteLine = String(localized: "Zeile löschen")
        static let lines = String(localized: "Zeilen")
        static let whitespace = String(localized: "Leerraum")
        static let letterCase = String(localized: "Groß-/Kleinschreibung")
        static let encodeDecode = String(localized: "Kodieren und Dekodieren")
        static let json = String(localized: "JSON")
        static let convertTabsToSpaces = String(localized: "Tabulatoren in Leerzeichen umwandeln")
        static let convertSpacesToTabs = String(localized: "Leerzeichen in Tabulatoren umwandeln")
        static let language = String(localized: "Sprache")
        static let automaticLanguage = String(localized: "Automatisch erkennen")
        static let indentation = String(localized: "Einrückung")
        static let indentWithTabs = String(localized: "Mit Tabulatoren einrücken")
        static let indentWithSpaces = String(localized: "Mit Leerzeichen einrücken")
        static let detectIndentation = String(localized: "Einrückung erkennen")
        static let statistics = String(localized: "Statistik …")

        static let showSidebar = String(localized: "Seitenleiste einblenden")
        static let hideSidebar = String(localized: "Seitenleiste ausblenden")
        static let showStatusBar = String(localized: "Statusleiste einblenden")
        static let hideStatusBar = String(localized: "Statusleiste ausblenden")
        static let showToolbar = String(localized: "Symbolleiste einblenden")
        static let customizeToolbar = String(localized: "Symbolleiste anpassen …")
        static let showLineNumbers = String(localized: "Zeilennummern einblenden")
        static let hideLineNumbers = String(localized: "Zeilennummern ausblenden")
        static let showInvisibles = String(localized: "Unsichtbare Zeichen einblenden")
        static let hideInvisibles = String(localized: "Unsichtbare Zeichen ausblenden")
        static let wrapLines = String(localized: "Zeilen umbrechen")
        static let highlightCurrentLine = String(localized: "Aktuelle Zeile hervorheben")
        static let zoomIn = String(localized: "Vergrößern")
        static let zoomOut = String(localized: "Verkleinern")
        static let actualSize = String(localized: "Originalgröße")
        static let commandPalette = String(localized: "Befehlspalette …")
        static let enterFullScreen = String(localized: "Vollbildmodus aktivieren")
        static let showTabBar = String(localized: "Tableiste einblenden")
        static let showAllTabs = String(localized: "Alle Tabs einblenden")

        static let minimize = String(localized: "Im Dock ablegen")
        static let zoom = String(localized: "Zoomen")
        static let bringAllToFront = String(localized: "Alle nach vorne bringen")

        static let helpItem = String(localized: "NoteCraft-Hilfe")
        static let keyboardShortcuts = String(localized: "Tastaturkurzbefehle")
        static let regexCheatSheet = String(localized: "Spickzettel für reguläre Ausdrücke")
    }

    enum Transformation {
        static func title(for transformation: TextTransformation) -> String {
            switch transformation {
            case .sortLinesAscending: String(localized: "Aufsteigend sortieren")
            case .sortLinesDescending: String(localized: "Absteigend sortieren")
            case .sortLinesByLength: String(localized: "Nach Länge sortieren")
            case .reverseLines: String(localized: "Reihenfolge umkehren")
            case .shuffleLines: String(localized: "Zufällig anordnen")
            case .removeDuplicateLines: String(localized: "Doppelte Zeilen entfernen")
            case .removeEmptyLines: String(localized: "Leere Zeilen entfernen")
            case .trimTrailingWhitespace: String(localized: "Leerraum am Zeilenende entfernen")
            case .trimLeadingWhitespace: String(localized: "Leerraum am Zeilenanfang entfernen")
            case .joinLines: String(localized: "Zeilen verbinden")
            case .uppercase: String(localized: "GROSSBUCHSTABEN")
            case .lowercase: String(localized: "kleinbuchstaben")
            case .capitalize: String(localized: "Wortanfänge Groß")
            case .invertCase: String(localized: "Groß-/Kleinschreibung umkehren")
            case .camelCase: String(localized: "camelCase")
            case .snakeCase: String(localized: "snake_case")
            case .kebabCase: String(localized: "kebab-case")
            case .base64Encode: String(localized: "Base64 kodieren")
            case .base64Decode: String(localized: "Base64 dekodieren")
            case .urlEncode: String(localized: "URL kodieren")
            case .urlDecode: String(localized: "URL dekodieren")
            case .htmlEscape: String(localized: "HTML-Zeichen maskieren")
            case .htmlUnescape: String(localized: "HTML-Zeichen demaskieren")
            case .formatJSON: String(localized: "JSON formatieren")
            case .minifyJSON: String(localized: "JSON komprimieren")
            }
        }
    }

    enum Find {
        static let searchPlaceholder = String(localized: "Suchen")
        static let replacePlaceholder = String(localized: "Ersetzen")
        static let replace = String(localized: "Ersetzen")
        static let replaceAll = String(localized: "Alle ersetzen")
        static let done = String(localized: "Fertig")
        static let previous = String(localized: "Vorheriger Treffer")
        static let next = String(localized: "Nächster Treffer")
        static let caseSensitive = String(localized: "Groß-/Kleinschreibung beachten")
        static let wholeWord = String(localized: "Nur ganze Wörter")
        static let regularExpression = String(localized: "Regulärer Ausdruck")
        static let inSelection = String(localized: "Nur in Auswahl")
        static let toggleReplace = String(localized: "Ersetzen ein-/ausblenden")
        static let noMatches = String(localized: "Keine Treffer")
        static let invalidRegularExpression = String(localized: "Ungültiger regulärer Ausdruck. Prüfe Klammern, Quantoren und Escape-Zeichen.")
        static let replaceActionName = String(localized: "Ersetzen")
        static let replaceAllActionName = String(localized: "Alle ersetzen")

        static func matchStatus(current: Int?, total: Int) -> String {
            if let current {
                return String(localized: "\(current) von \(total)")
            }
            return total == 1 ? String(localized: "1 Treffer") : String(localized: "\(total) Treffer")
        }

        static func replacedStatus(_ count: Int) -> String {
            count == 1 ? String(localized: "1 Treffer ersetzt") : String(localized: "\(count) Treffer ersetzt")
        }
    }

    enum FileSearch {
        static let title = String(localized: "In Dateien suchen")
        static let queryPlaceholder = String(localized: "Suchbegriff")
        static let filePatternPlaceholder = String(localized: "Dateimuster, z. B. *.swift, !*.min.js")
        static let search = String(localized: "Suchen")
        static let cancel = String(localized: "Abbrechen")
        static let noFolder = String(localized: "Kein Ordner geöffnet")
        static let noFolderDescription = String(localized: "Öffne einen Ordner, um in allen seinen Dateien zu suchen.")
        static let noResults = String(localized: "Keine Treffer")
        static let noResultsDescription = String(localized: "Ändere den Suchbegriff oder das Dateimuster.")
        static let searching = String(localized: "Suche läuft …")
        static let includesHiddenFiles = String(localized: "Unsichtbare Dateien einbeziehen")

        static func summary(matches: Int, files: Int) -> String {
            let matchText = matches == 1 ? String(localized: "1 Treffer") : String(localized: "\(matches) Treffer")
            let fileText = files == 1 ? String(localized: "1 Datei") : String(localized: "\(files) Dateien")
            return String(localized: "\(matchText) in \(fileText)")
        }

        static func lineLabel(_ line: Int) -> String {
            String(localized: "Zeile \(line)")
        }
    }

    enum Sidebar {
        static let files = String(localized: "Dateien")
        static let search = String(localized: "Suche")
        static let noFolder = String(localized: "Kein Ordner geöffnet")
        static let noFolderDescription = String(localized: "Öffne einen Ordner, um seine Dateien hier zu sehen.")
        static let openFolder = String(localized: "Ordner öffnen …")
        static let closeFolder = String(localized: "Ordner schließen")
        static let refresh = String(localized: "Aktualisieren")
        static let filterPlaceholder = String(localized: "Filtern")
        static let sections = String(localized: "Bereich der Seitenleiste")
        static let folderActions = String(localized: "Ordneraktionen")
    }

    enum StatusBar {
        static func position(line: Int, column: Int) -> String {
            String(localized: "Zeile \(line), Spalte \(column)")
        }

        static func selection(characters: Int, ranges: Int) -> String {
            if ranges > 1 {
                return String(localized: "\(ranges) Auswahlen")
            }
            return characters == 1 ? String(localized: "1 Zeichen ausgewählt") : String(localized: "\(characters) Zeichen ausgewählt")
        }

        static func indentation(_ indentation: Indentation) -> String {
            indentation.usesTabs
                ? String(localized: "Tabulatoren: \(indentation.width)")
                : String(localized: "Leerzeichen: \(indentation.width)")
        }

        static let mixedLineEndings = String(localized: "Gemischte Zeilenenden")
        static let mixedLineEndingsHelp = String(localized: "Das Dokument enthält unterschiedliche Zeilenenden. Beim Sichern werden alle in das gewählte Zeilenende umgewandelt.")
        static let largeFile = String(localized: "Große Datei – Syntaxhervorhebung aus")
        static let positionHelp = String(localized: "Gehe zu Zeile")
        static let languageHelp = String(localized: "Sprache für die Syntaxhervorhebung")
        static let encodingHelp = String(localized: "Kodierung des Dokuments")
        static let lineEndingHelp = String(localized: "Zeilenende des Dokuments")
        static let indentationHelp = String(localized: "Einrückung des Dokuments")
        static let tabWidth = String(localized: "Tabulatorbreite")
    }

    enum Statistics {
        static let title = String(localized: "Statistik")
        static let characters = String(localized: "Zeichen")
        static let words = String(localized: "Wörter")
        static let lines = String(localized: "Zeilen")
        static let selection = String(localized: "Auswahl")
        static let document = String(localized: "Dokument")
        static let done = String(localized: "Fertig")
    }

    enum GoToLine {
        static let title = String(localized: "Gehe zu Zeile")
        static let placeholder = String(localized: "Zeile oder Zeile:Spalte")
        static let go = String(localized: "Gehe zu")
        static let cancel = String(localized: "Abbrechen")

        static func hint(lineCount: Int) -> String {
            String(localized: "Das Dokument hat \(lineCount) Zeilen.")
        }

        static func outOfRange(lineCount: Int) -> String {
            String(localized: "Gib eine Zeilennummer zwischen 1 und \(lineCount) ein.")
        }

        static let invalidFormat = String(localized: "Gib eine Zahl ein, z. B. 42 oder 42:7.")
    }

    enum Banner {
        static let modifiedExternally = String(localized: "Die Datei wurde von einer anderen App geändert.")
        static let modifiedExternallyDetail = String(localized: "Dein Dokument enthält ungesicherte Änderungen.")
        static let deleted = String(localized: "Die Datei wurde gelöscht oder bewegt.")
        static let deletedDetail = String(localized: "Sichere das Dokument, um es wiederherzustellen.")
        static let reload = String(localized: "Neu laden")
        static let keepMine = String(localized: "Meine Version behalten")
        static let dismiss = String(localized: "Ausblenden")
        static let reloaded = String(localized: "Neu geladen, da die Datei von einer anderen App geändert wurde.")
    }

    enum Palette {
        static let commandsPlaceholder = String(localized: "Befehl suchen")
        static let filesPlaceholder = String(localized: "Datei im Ordner suchen")
        static let noResults = String(localized: "Keine Treffer")
        static let documents = String(localized: "Geöffnete Dokumente")
        static let commands = String(localized: "Befehle")
        static let files = String(localized: "Dateien")
        static let noFolderForQuickOpen = String(localized: "Öffne zuerst einen Ordner, um Dateien schnell zu öffnen.")
    }

    enum Settings {
        static let general = String(localized: "Allgemein")
        static let editor = String(localized: "Editor")
        static let themes = String(localized: "Farbschema")
        static let files = String(localized: "Dateien")

        static let windowsSection = String(localized: "Fenster")
        static let opensDocumentsInTabs = String(localized: "Dokumente in Tabs öffnen")
        static let restoresSession = String(localized: "Sitzung beim nächsten Start wiederherstellen")
        static let restoresSessionHelp = String(localized: "Alle Fenster werden wiederhergestellt – auch Dokumente, die noch nie gesichert wurden. Beim Beenden wird nicht nachgefragt.")
        static let externalChangesSection = String(localized: "Änderungen durch andere Apps")
        static let reloadsUnmodifiedDocuments = String(localized: "Unveränderte Dokumente automatisch neu laden")
        static let reloadsUnmodifiedDocumentsHelp = String(localized: "Dokumente mit ungesicherten Änderungen zeigen stattdessen einen Hinweis.")

        static let fontSection = String(localized: "Schrift")
        static let font = String(localized: "Schrift")
        static let systemFont = String(localized: "Systemschrift (SF Mono)")
        static let fontSize = String(localized: "Schriftgröße")
        static let lineHeight = String(localized: "Zeilenhöhe")
        static let indentationSection = String(localized: "Einrückung")
        static let indentWith = String(localized: "Einrücken mit")
        static let tabs = String(localized: "Tabulatoren")
        static let spaces = String(localized: "Leerzeichen")
        static let tabWidth = String(localized: "Tabulatorbreite")
        static let detectsIndentation = String(localized: "Einrückung aus dem Dokument erkennen")
        static let displaySection = String(localized: "Darstellung")
        static let showsLineNumbers = String(localized: "Zeilennummern anzeigen")
        static let highlightsCurrentLine = String(localized: "Aktuelle Zeile hervorheben")
        static let showsInvisibleCharacters = String(localized: "Unsichtbare Zeichen anzeigen")
        static let wrapsLines = String(localized: "Zeilen umbrechen")
        static let highlightsMatchingBrackets = String(localized: "Passende Klammern hervorheben")
        static let editingSection = String(localized: "Bearbeitung")
        static let autoIndents = String(localized: "Automatisch einrücken")
        static let closesBrackets = String(localized: "Klammern und Anführungszeichen automatisch schließen")
        static let checksSpelling = String(localized: "Rechtschreibung während der Eingabe prüfen")

        static let lightTheme = String(localized: "Helles Erscheinungsbild")
        static let darkTheme = String(localized: "Dunkles Erscheinungsbild")
        static let themesHelp = String(localized: "NoteCraft wechselt automatisch mit dem Erscheinungsbild des Systems.")

        static let newDocumentsSection = String(localized: "Neue Dokumente")
        static let defaultEncoding = String(localized: "Kodierung")
        static let defaultLineEnding = String(localized: "Zeilenende")
        static let openingSection = String(localized: "Öffnen")
        static let fallbackEncoding = String(localized: "Ersatzkodierung")
        static let fallbackEncodingHelp = String(localized: "Wird verwendet, wenn eine Datei weder eine BOM noch gültiges UTF-8 enthält.")
        static let largeFileThreshold = String(localized: "Syntaxhervorhebung deaktivieren ab")
        static let savingSection = String(localized: "Sichern")
        static let trimsTrailingWhitespace = String(localized: "Leerraum am Zeilenende entfernen")
        static let ensuresTrailingNewline = String(localized: "Mit Zeilenende abschließen")

        static func megabytes(_ value: Int) -> String {
            String(localized: "\(value) MB")
        }

        static func points(_ value: Int) -> String {
            String(localized: "\(value) pt")
        }
    }

    enum Alert {
        static let cancel = String(localized: "Abbrechen")
        static let reopen = String(localized: "Erneut öffnen")
        static let reopenTitle = String(localized: "Dokument mit anderer Kodierung erneut öffnen?")
        static let reopenMessage = String(localized: "Deine ungesicherten Änderungen gehen dabei verloren.")
        static let transformationFailed = String(localized: "Umwandlung nicht möglich")
        static let binaryFileTitle = String(localized: "Die Datei kann nicht als Text geöffnet werden.")
        static let binaryFileMessage = String(localized: "Sie scheint Binärdaten zu enthalten, zum Beispiel ein Bild oder ein Programm.")

        static func unrepresentableCharacter(character: Character?, line: Int, column: Int, encoding: String) -> String {
            if let character {
                return String(localized: "Das Zeichen „\(String(character))“ in Zeile \(line), Spalte \(column) kann in der Kodierung \(encoding) nicht gesichert werden.")
            }
            return String(localized: "Das Dokument enthält Zeichen, die in der Kodierung \(encoding) nicht gesichert werden können.")
        }

        static let unrepresentableRecovery = String(localized: "Wähle unter „Ablage › Kodierung › Konvertieren in“ eine Unicode-Kodierung wie UTF-8 oder entferne das Zeichen.")

        static func undecodable(encoding: String) -> String {
            String(localized: "Die Datei ist nicht gültig in der Kodierung \(encoding).")
        }

        static let undecodableRecovery = String(localized: "Wähle eine andere Kodierung unter „Ablage › Kodierung › Erneut öffnen mit“.")
        static let invalidBase64 = String(localized: "Der ausgewählte Text ist kein gültiges Base64 oder ergibt keinen UTF-8-Text.")
        static let invalidPercentEncoding = String(localized: "Der ausgewählte Text enthält ungültige Prozent-Kodierungen.")

        static func invalidJSON(line: Int, column: Int) -> String {
            String(localized: "Ungültiges JSON in Zeile \(line), Spalte \(column).")
        }
    }

    enum Help {
        static let title = String(localized: "NoteCraft-Hilfe")
        static let shortcutsTitle = String(localized: "Tastaturkurzbefehle")
        static let regexTitle = String(localized: "Reguläre Ausdrücke")
        static let intro = String(localized: "NoteCraft ist ein Texteditor für Code, Notizen und Daten. Alle Befehle findest du in der Menüleiste oder über die Befehlspalette (⇧⌘A).")
        static let documentsSection = String(localized: "Dokumente")
        static let editingSection = String(localized: "Bearbeiten")
        static let searchSection = String(localized: "Suchen")
        static let viewSection = String(localized: "Darstellung")
        static let tipsTitle = String(localized: "Tipps")
        static let tipSession = String(localized: "Ungesicherte Dokumente bleiben beim Beenden erhalten und werden beim nächsten Start wiederhergestellt.")
        static let tipColumns = String(localized: "Halte die Wahltaste gedrückt und ziehe, um eine rechteckige Auswahl zu erstellen. Tippe anschließend, um alle Zeilen gleichzeitig zu bearbeiten.")
        static let tipEncoding = String(localized: "Klicke in der Statusleiste auf Kodierung, Zeilenende oder Einrückung, um sie zu ändern.")
        static let tipVersions = String(localized: "Mit „Ablage › Zurücksetzen auf › Alle Versionen durchsuchen“ holst du frühere Stände zurück.")
    }

    enum Accessibility {
        static let editor = String(localized: "Texteditor")
        static let lineNumbers = String(localized: "Zeilennummern")
        static let statusBar = String(localized: "Statusleiste")
        static let findBar = String(localized: "Suchleiste")
        static let sidebar = String(localized: "Seitenleiste")
        static let commandPalette = String(localized: "Befehlspalette")
        static let toolbarFind = String(localized: "Suchen")
        static let toolbarPalette = String(localized: "Befehle")
        static let toolbarShare = String(localized: "Teilen")
    }

    enum Undo {
        static let transformation = String(localized: "Umwandeln")
        static let lineOperation = String(localized: "Zeilen bearbeiten")
        static let indentation = String(localized: "Einrückung")
        static let comment = String(localized: "Kommentar")
        static let encoding = String(localized: "Kodierung ändern")
        static let lineEnding = String(localized: "Zeilenende ändern")
        static let typing = String(localized: "Tippen")
        static let paste = String(localized: "Einsetzen")
    }
}
