import Foundation
import NoteCraftKit

enum L10n {
    enum App {
        static let name = "NoteCraft"
        static let about = String(localized: "About NoteCraft")
        static let settings = String(localized: "Settings…")
        static let services = String(localized: "Services")
        static let hide = String(localized: "Hide NoteCraft")
        static let hideOthers = String(localized: "Hide Others")
        static let showAll = String(localized: "Show All")
        static let quit = String(localized: "Quit NoteCraft")
        static let credits = String(localized: "A fast, native text editor for the Mac.")
    }

    enum Menu {
        static let file = String(localized: "File")
        static let edit = String(localized: "Edit")
        static let text = String(localized: "Text")
        static let view = String(localized: "View")
        static let window = String(localized: "Window")
        static let help = String(localized: "Help")

        static let new = String(localized: "New")
        static let newTab = String(localized: "New Tab")
        static let open = String(localized: "Open…")
        static let openRecent = String(localized: "Open Recent")
        static let clearRecent = String(localized: "Clear Menu")
        static let openFolder = String(localized: "Open Folder…")
        static let openQuickly = String(localized: "Open Quickly…")
        static let close = String(localized: "Close")
        static let save = String(localized: "Save…")
        static let duplicate = String(localized: "Duplicate")
        static let saveAs = String(localized: "Save As…")
        static let rename = String(localized: "Rename…")
        static let moveTo = String(localized: "Move To…")
        static let revertTo = String(localized: "Revert To")
        static let encoding = String(localized: "Encoding")
        static let reopenWithEncoding = String(localized: "Reopen with Encoding")
        static let convertToEncoding = String(localized: "Convert to Encoding")
        static let lineEnding = String(localized: "Line Ending")
        static let share = String(localized: "Share")
        static let revealInFinder = String(localized: "Show in Finder")
        static let copyPath = String(localized: "Copy Path")
        static let pageSetup = String(localized: "Page Setup…")
        static let print = String(localized: "Print…")

        static let undo = String(localized: "Undo")
        static let redo = String(localized: "Redo")
        static let cut = String(localized: "Cut")
        static let copy = String(localized: "Copy")
        static let paste = String(localized: "Paste")
        static let delete = String(localized: "Delete")
        static let selectAll = String(localized: "Select All")
        static let find = String(localized: "Find")
        static let findEllipsis = String(localized: "Find…")
        static let findAndReplace = String(localized: "Find and Replace…")
        static let findNext = String(localized: "Find Next")
        static let findPrevious = String(localized: "Find Previous")
        static let useSelectionForFind = String(localized: "Use Selection for Find")
        static let useSelectionForReplace = String(localized: "Use Selection for Replace")
        static let jumpToSelection = String(localized: "Jump to Selection")
        static let fileSearch = String(localized: "Find in Files…")
        static let selection = String(localized: "Selection")
        static let selectNextOccurrence = String(localized: "Select Next Occurrence")
        static let selectAllOccurrences = String(localized: "Select All Occurrences")
        static let selectLine = String(localized: "Select Line")
        static let goToLine = String(localized: "Go to Line…")
        static let spelling = String(localized: "Spelling and Grammar")
        static let showSpelling = String(localized: "Show Spelling and Grammar")
        static let checkSpelling = String(localized: "Check Document Now")
        static let checkSpellingWhileTyping = String(localized: "Check Spelling While Typing")

        static let shiftRight = String(localized: "Shift Right")
        static let shiftLeft = String(localized: "Shift Left")
        static let toggleComment = String(localized: "Toggle Comment")
        static let duplicateLine = String(localized: "Duplicate Line")
        static let moveLineUp = String(localized: "Move Line Up")
        static let moveLineDown = String(localized: "Move Line Down")
        static let deleteLine = String(localized: "Delete Line")
        static let lines = String(localized: "Lines")
        static let whitespace = String(localized: "Whitespace")
        static let letterCase = String(localized: "Letter Case")
        static let encodeDecode = String(localized: "Encode and Decode")
        static let json = String(localized: "JSON")
        static let convertTabsToSpaces = String(localized: "Convert Tabs to Spaces")
        static let convertSpacesToTabs = String(localized: "Convert Spaces to Tabs")
        static let language = String(localized: "Language")
        static let automaticLanguage = String(localized: "Detect Automatically")
        static let indentation = String(localized: "Indentation")
        static let indentWithTabs = String(localized: "Indent Using Tabs")
        static let indentWithSpaces = String(localized: "Indent Using Spaces")
        static let detectIndentation = String(localized: "Detect Indentation")
        static let statistics = String(localized: "Statistics…")

        static let showSidebar = String(localized: "Show Sidebar")
        static let hideSidebar = String(localized: "Hide Sidebar")
        static let showStatusBar = String(localized: "Show Status Bar")
        static let hideStatusBar = String(localized: "Hide Status Bar")
        static let showToolbar = String(localized: "Show Toolbar")
        static let customizeToolbar = String(localized: "Customize Toolbar…")
        static let showLineNumbers = String(localized: "Show Line Numbers")
        static let hideLineNumbers = String(localized: "Hide Line Numbers")
        static let showInvisibles = String(localized: "Show Invisibles")
        static let hideInvisibles = String(localized: "Hide Invisibles")
        static let wrapLines = String(localized: "Wrap Lines")
        static let highlightCurrentLine = String(localized: "Highlight Current Line")
        static let zoomIn = String(localized: "Zoom In")
        static let zoomOut = String(localized: "Zoom Out")
        static let actualSize = String(localized: "Actual Size")
        static let commandPalette = String(localized: "Command Palette…")
        static let enterFullScreen = String(localized: "Enter Full Screen")
        static let showTabBar = String(localized: "Show Tab Bar")
        static let showAllTabs = String(localized: "Show All Tabs")

        static let minimize = String(localized: "Minimize")
        static let zoom = String(localized: "Zoom")
        static let bringAllToFront = String(localized: "Bring All to Front")

        static let helpItem = String(localized: "NoteCraft Help")
        static let keyboardShortcuts = String(localized: "Keyboard Shortcuts")
        static let regexCheatSheet = String(localized: "Regular Expression Cheat Sheet")
        static let acknowledgements = String(localized: "Acknowledgements")

        static let format = String(localized: "Format")
        static let bold = String(localized: "Bold")
        static let italic = String(localized: "Italic")
        static let strikethrough = String(localized: "Strikethrough")
        static let inlineCode = String(localized: "Inline Code")
        static let link = String(localized: "Link…")
        static let heading = String(localized: "Heading")
        static let bodyText = String(localized: "Body Text")
        static let quote = String(localized: "Quote")
        static let toggleTask = String(localized: "Toggle Task")
        static let table = String(localized: "Table")
        static let insertTable = String(localized: "Insert Table")
        static let formatTable = String(localized: "Format Table")
        static let addTableRow = String(localized: "Add Row")
        static let addTableColumn = String(localized: "Add Column")
        static let tableOfContents = String(localized: "Insert or Update Table of Contents")
        static let showPreview = String(localized: "Show Preview")
        static let hidePreview = String(localized: "Hide Preview")
        static let exportHTML = String(localized: "Export as HTML…")
        static let copyFormatted = String(localized: "Copy as Formatted Text")

        static func headingLevel(_ level: Int) -> String {
            String(localized: "Heading \(level)")
        }
    }

    enum Markdown {
        static func column(_ number: Int) -> String {
            String(localized: "Column \(number)")
        }
    }

    enum Preview {
        static let externalContentBlocked = String(localized: "External content is blocked.")
        static let loadExternalContent = String(localized: "Load External Content")
        static let folderAccessNeeded = String(localized: "Some images can’t be shown without access to their folder.")
        static let allowFolderAccess = String(localized: "Allow Access to Folder…")
        static let folderAccessMessage = String(localized: "Choose the folder with the images so that NoteCraft can show them in the preview.")
        static let allowAccessPrompt = String(localized: "Allow Access")
    }

    enum Transformation {
        static func title(for transformation: TextTransformation) -> String {
            switch transformation {
            case .sortLinesAscending: String(localized: "Sort Ascending")
            case .sortLinesDescending: String(localized: "Sort Descending")
            case .sortLinesByLength: String(localized: "Sort by Length")
            case .reverseLines: String(localized: "Reverse Order")
            case .shuffleLines: String(localized: "Shuffle")
            case .removeDuplicateLines: String(localized: "Remove Duplicate Lines")
            case .removeEmptyLines: String(localized: "Remove Empty Lines")
            case .trimTrailingWhitespace: String(localized: "Trim Trailing Whitespace")
            case .trimLeadingWhitespace: String(localized: "Trim Leading Whitespace")
            case .joinLines: String(localized: "Join Lines")
            case .uppercase: String(localized: "UPPERCASE")
            case .lowercase: String(localized: "lowercase")
            case .capitalize: String(localized: "Capitalize Words")
            case .invertCase: String(localized: "Invert Case")
            case .camelCase: String(localized: "camelCase")
            case .snakeCase: String(localized: "snake_case")
            case .kebabCase: String(localized: "kebab-case")
            case .base64Encode: String(localized: "Base64 Encode")
            case .base64Decode: String(localized: "Base64 Decode")
            case .urlEncode: String(localized: "URL Encode")
            case .urlDecode: String(localized: "URL Decode")
            case .htmlEscape: String(localized: "Escape HTML Characters")
            case .htmlUnescape: String(localized: "Unescape HTML Characters")
            case .formatJSON: String(localized: "Format JSON")
            case .minifyJSON: String(localized: "Minify JSON")
            }
        }
    }

    enum Find {
        static let searchPlaceholder = String(localized: "Find")
        static let replacePlaceholder = String(localized: "Replace")
        static let replace = String(localized: "Replace")
        static let replaceAll = String(localized: "Replace All")
        static let done = String(localized: "Done")
        static let previous = String(localized: "Previous Match")
        static let next = String(localized: "Next Match")
        static let caseSensitive = String(localized: "Match Case")
        static let wholeWord = String(localized: "Whole Words")
        static let regularExpression = String(localized: "Regular Expression")
        static let inSelection = String(localized: "In Selection")
        static let toggleReplace = String(localized: "Show or Hide Replace")
        static let noMatches = String(localized: "No Matches")
        static let invalidRegularExpression = String(localized: "Invalid regular expression. Check parentheses, quantifiers and escape characters.")
        static let replaceActionName = String(localized: "Replace")
        static let replaceAllActionName = String(localized: "Replace All")

        static func matchStatus(current: Int?, total: Int) -> String {
            if let current {
                return String(localized: "\(current) of \(total)")
            }
            return total == 1 ? String(localized: "1 match") : String(localized: "\(total) matches")
        }

        static func replacedStatus(_ count: Int) -> String {
            count == 1 ? String(localized: "Replaced 1 match") : String(localized: "Replaced \(count) matches")
        }
    }

    enum FileSearch {
        static let title = String(localized: "Find in Files")
        static let queryPlaceholder = String(localized: "Search Term")
        static let filePatternPlaceholder = String(localized: "File pattern, e.g. *.swift, !*.min.js")
        static let search = String(localized: "Find")
        static let cancel = String(localized: "Cancel")
        static let noFolder = String(localized: "No Folder Open")
        static let noFolderDescription = String(localized: "Open a folder to search all of its files.")
        static let noResults = String(localized: "No Matches")
        static let noResultsDescription = String(localized: "Change the search term or the file pattern.")
        static let searching = String(localized: "Searching…")
        static let includesHiddenFiles = String(localized: "Include Hidden Files")

        static func summary(matches: Int, files: Int) -> String {
            let matchText = matches == 1 ? String(localized: "1 match") : String(localized: "\(matches) matches")
            let fileText = files == 1 ? String(localized: "1 file") : String(localized: "\(files) files")
            return String(localized: "\(matchText) in \(fileText)")
        }

        static func lineLabel(_ line: Int) -> String {
            String(localized: "Line \(line)")
        }
    }

    enum Sidebar {
        static let files = String(localized: "Files")
        static let search = String(localized: "Search")
        static let noFolder = String(localized: "No Folder Open")
        static let noFolderDescription = String(localized: "Open a folder to see its files here.")
        static let openFolder = String(localized: "Open Folder…")
        static let closeFolder = String(localized: "Close Folder")
        static let refresh = String(localized: "Refresh")
        static let filterPlaceholder = String(localized: "Filter")
        static let sections = String(localized: "Sidebar Section")
        static let folderActions = String(localized: "Folder Actions")
    }

    enum StatusBar {
        static func position(line: Int, column: Int) -> String {
            String(localized: "Line \(line), Column \(column)")
        }

        static func selection(characters: Int, ranges: Int) -> String {
            if ranges > 1 {
                return String(localized: "\(ranges) selections")
            }
            return characters == 1 ? String(localized: "1 character selected") : String(localized: "\(characters) characters selected")
        }

        static func indentation(_ indentation: Indentation) -> String {
            indentation.usesTabs
                ? String(localized: "Tabs: \(indentation.width)")
                : String(localized: "Spaces: \(indentation.width)")
        }

        static let mixedLineEndings = String(localized: "Mixed Line Endings")
        static let mixedLineEndingsHelp = String(localized: "The document contains different line endings. Saving converts all of them to the selected line ending.")
        static let largeFile = String(localized: "Large file – syntax highlighting off")
        static let positionHelp = String(localized: "Go to Line")
        static let languageHelp = String(localized: "Language for syntax highlighting")
        static let encodingHelp = String(localized: "Document encoding")
        static let lineEndingHelp = String(localized: "Document line ending")
        static let indentationHelp = String(localized: "Document indentation")
        static let tabWidth = String(localized: "Tab Width")
    }

    enum Statistics {
        static let title = String(localized: "Statistics")
        static let characters = String(localized: "Characters")
        static let words = String(localized: "Words")
        static let lines = String(localized: "Lines")
        static let selection = String(localized: "Selection")
        static let document = String(localized: "Document")
        static let done = String(localized: "Done")
    }

    enum GoToLine {
        static let title = String(localized: "Go to Line")
        static let placeholder = String(localized: "Line or line:column")
        static let go = String(localized: "Go")
        static let cancel = String(localized: "Cancel")

        static func hint(lineCount: Int) -> String {
            String(localized: "The document has \(lineCount) lines.")
        }

        static func outOfRange(lineCount: Int) -> String {
            String(localized: "Enter a line number between 1 and \(lineCount).")
        }

        static let invalidFormat = String(localized: "Enter a number, e.g. 42 or 42:7.")
    }

    enum Banner {
        static let modifiedExternally = String(localized: "The file was changed by another app.")
        static let modifiedExternallyDetail = String(localized: "Your document has unsaved changes.")
        static let deleted = String(localized: "The file was deleted or moved.")
        static let deletedDetail = String(localized: "Save the document to restore it.")
        static let reload = String(localized: "Reload")
        static let keepMine = String(localized: "Keep My Version")
        static let dismiss = String(localized: "Dismiss")
        static let reloaded = String(localized: "Reloaded because the file was changed by another app.")
    }

    enum Palette {
        static let commandsPlaceholder = String(localized: "Search Commands")
        static let filesPlaceholder = String(localized: "Search Files in Folder")
        static let noResults = String(localized: "No Matches")
        static let documents = String(localized: "Open Documents")
        static let commands = String(localized: "Commands")
        static let files = String(localized: "Files")
        static let noFolderForQuickOpen = String(localized: "Open a folder first to open its files quickly.")
    }

    enum Settings {
        static let general = String(localized: "General")
        static let editor = String(localized: "Editor")
        static let themes = String(localized: "Themes")
        static let files = String(localized: "Files")
        static let markdown = String(localized: "Markdown")

        static let windowsSection = String(localized: "Windows")
        static let opensDocumentsInTabs = String(localized: "Open documents in tabs")
        static let restoresSession = String(localized: "Restore session at next launch")
        static let restoresSessionHelp = String(localized: "All windows are restored – including documents that were never saved. Quitting doesn’t ask for confirmation.")
        static let externalChangesSection = String(localized: "Changes by Other Apps")
        static let reloadsUnmodifiedDocuments = String(localized: "Reload unmodified documents automatically")
        static let reloadsUnmodifiedDocumentsHelp = String(localized: "Documents with unsaved changes show a notice instead.")

        static let fontSection = String(localized: "Font")
        static let font = String(localized: "Font")
        static let systemFont = String(localized: "System Font (SF Mono)")
        static let fontSize = String(localized: "Font size")
        static let lineHeight = String(localized: "Line height")
        static let indentationSection = String(localized: "Indentation")
        static let indentWith = String(localized: "Indent using")
        static let tabs = String(localized: "Tabs")
        static let spaces = String(localized: "Spaces")
        static let tabWidth = String(localized: "Tab width")
        static let detectsIndentation = String(localized: "Detect indentation from document")
        static let displaySection = String(localized: "Display")
        static let showsLineNumbers = String(localized: "Show line numbers")
        static let highlightsCurrentLine = String(localized: "Highlight current line")
        static let showsInvisibleCharacters = String(localized: "Show invisible characters")
        static let wrapsLines = String(localized: "Wrap lines")
        static let highlightsMatchingBrackets = String(localized: "Highlight matching brackets")
        static let editingSection = String(localized: "Editing")
        static let autoIndents = String(localized: "Indent automatically")
        static let closesBrackets = String(localized: "Close brackets and quotes automatically")
        static let checksSpelling = String(localized: "Check spelling while typing")

        static let lightTheme = String(localized: "Light Appearance")
        static let darkTheme = String(localized: "Dark Appearance")
        static let themesHelp = String(localized: "NoteCraft switches automatically with the system appearance.")

        static let newDocumentsSection = String(localized: "New Documents")
        static let defaultEncoding = String(localized: "Encoding")
        static let defaultLineEnding = String(localized: "Line ending")
        static let openingSection = String(localized: "Opening")
        static let fallbackEncoding = String(localized: "Fallback encoding")
        static let fallbackEncodingHelp = String(localized: "Used when a file contains neither a BOM nor valid UTF-8.")
        static let largeFileThreshold = String(localized: "Turn off syntax highlighting above")
        static let savingSection = String(localized: "Saving")
        static let trimsTrailingWhitespace = String(localized: "Trim trailing whitespace")
        static let ensuresTrailingNewline = String(localized: "End with a line ending")

        static let previewSection = String(localized: "Preview")
        static let opensMarkdownPreview = String(localized: "Open preview for Markdown automatically")
        static let scrollSync = String(localized: "Scroll sync")
        static let externalContentSection = String(localized: "External Content")
        static let loadsExternalContent = String(localized: "Always load external content")
        static let loadsExternalContentHelp = String(localized: "Images from the internet load only when you allow it. NoteCraft makes no other connections to the internet.")
        static let resetPermissions = String(localized: "Reset Remembered Permissions")
        static let resetPermissionsHelp = String(localized: "Forgets the documents with allowed external content and the folders you allowed for images.")

        static func megabytes(_ value: Int) -> String {
            String(localized: "\(value) MB")
        }

        static func points(_ value: Int) -> String {
            String(localized: "\(value) pt")
        }
    }

    enum Alert {
        static let cancel = String(localized: "Cancel")
        static let reopen = String(localized: "Reopen")
        static let reopenTitle = String(localized: "Reopen the document with a different encoding?")
        static let reopenMessage = String(localized: "Your unsaved changes will be lost.")
        static let transformationFailed = String(localized: "Can’t Transform Text")
        static let binaryFileTitle = String(localized: "The file can’t be opened as text.")
        static let binaryFileMessage = String(localized: "It seems to contain binary data, such as an image or a program.")

        static func unrepresentableCharacter(character: Character?, line: Int, column: Int, encoding: String) -> String {
            if let character {
                return String(localized: "The character “\(String(character))” in line \(line), column \(column) can’t be saved in the \(encoding) encoding.")
            }
            return String(localized: "The document contains characters that can’t be saved in the \(encoding) encoding.")
        }

        static let unrepresentableRecovery = String(localized: "Choose a Unicode encoding such as UTF-8 in “File › Encoding › Convert to Encoding”, or remove the character.")

        static func undecodable(encoding: String) -> String {
            String(localized: "The file isn’t valid in the \(encoding) encoding.")
        }

        static let undecodableRecovery = String(localized: "Choose another encoding in “File › Encoding › Reopen with Encoding”.")
        static let invalidBase64 = String(localized: "The selected text isn’t valid Base64 or doesn’t decode to UTF-8 text.")
        static let invalidPercentEncoding = String(localized: "The selected text contains invalid percent encodings.")

        static func invalidJSON(line: Int, column: Int) -> String {
            String(localized: "Invalid JSON in line \(line), column \(column).")
        }
    }

    enum Help {
        static let title = String(localized: "NoteCraft Help")
        static let shortcutsTitle = String(localized: "Keyboard Shortcuts")
        static let regexTitle = String(localized: "Regular Expressions")
        static let intro = String(localized: "NoteCraft is a text editor for code, notes and data. You find every command in the menu bar or in the command palette (⇧⌘A).")
        static let documentsSection = String(localized: "Documents")
        static let editingSection = String(localized: "Editing")
        static let searchSection = String(localized: "Search")
        static let viewSection = String(localized: "View")
        static let tipsTitle = String(localized: "Tips")
        static let tipSession = String(localized: "Unsaved documents are kept when you quit and restored at the next launch.")
        static let tipColumns = String(localized: "Hold down Option and drag to make a rectangular selection. Then type to edit all lines at once.")
        static let tipEncoding = String(localized: "Click encoding, line ending or indentation in the status bar to change it.")
        static let tipVersions = String(localized: "Use “File › Revert To › Browse All Versions” to bring back earlier versions.")
        static let markdownSection = String(localized: "Markdown")
        static let tipMarkdown = String(localized: "In Markdown documents, ⌥⌘P shows the preview. While it is open, “Print” prints the rendered document.")
    }

    enum Accessibility {
        static let editor = String(localized: "Text Editor")
        static let lineNumbers = String(localized: "Line Numbers")
        static let statusBar = String(localized: "Status Bar")
        static let findBar = String(localized: "Find Bar")
        static let sidebar = String(localized: "Sidebar")
        static let commandPalette = String(localized: "Command Palette")
        static let toolbarFind = String(localized: "Find")
        static let toolbarPalette = String(localized: "Commands")
        static let toolbarShare = String(localized: "Share")
        static let preview = String(localized: "Preview")
    }

    enum Undo {
        static let transformation = String(localized: "Transform")
        static let lineOperation = String(localized: "Edit Lines")
        static let indentation = String(localized: "Indentation")
        static let comment = String(localized: "Comment")
        static let encoding = String(localized: "Change Encoding")
        static let lineEnding = String(localized: "Change Line Ending")
        static let typing = String(localized: "Typing")
        static let paste = String(localized: "Paste")
        static let formatting = String(localized: "Formatting")
        static let link = String(localized: "Link")
        static let task = String(localized: "Task")
        static let table = String(localized: "Table")
        static let tableOfContents = String(localized: "Table of Contents")
        static let insertImage = String(localized: "Insert Image")
    }

    enum ThemePreview {
        static let comment = String(localized: "Note for tomorrow")
        static let greeting = String(localized: "Hello NoteCraft")
    }
}
