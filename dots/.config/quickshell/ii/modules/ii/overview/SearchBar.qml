pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "../../../services/sim" as SiM
import "../../sim" as SiMUi

RowLayout {
    id: root
    spacing: 6
    property bool animateWidth: false
    property alias searchInput: searchInput
    property string searchingText
    property bool isSimActive: SiM.SiMNLU.isSiMCommand(root.searchingText) || (SiM.SiMSovereign.lockedChips !== undefined && SiM.SiMSovereign.lockedChips.some(c => !c.isStyle))

    function forceFocus() {
        searchInput.forceActiveFocus();
    }

    enum SearchPrefixType { Action, App, Clipboard, Emojis, Math, ShellCommand, WebSearch, DefaultSearch }

    property var searchPrefixType: {
        if (root.searchingText.startsWith(Config.options.search.prefix.action)) return SearchBar.SearchPrefixType.Action;
        if (root.searchingText.startsWith(Config.options.search.prefix.app)) return SearchBar.SearchPrefixType.App;
        if (root.searchingText.startsWith(Config.options.search.prefix.clipboard)) return SearchBar.SearchPrefixType.Clipboard;
        if (root.searchingText.startsWith(Config.options.search.prefix.emojis)) return SearchBar.SearchPrefixType.Emojis;
        if (root.searchingText.startsWith(Config.options.search.prefix.math)) return SearchBar.SearchPrefixType.Math;
        if (root.searchingText.startsWith(Config.options.search.prefix.shellCommand)) return SearchBar.SearchPrefixType.ShellCommand;
        if (root.searchingText.startsWith(Config.options.search.prefix.webSearch)) return SearchBar.SearchPrefixType.WebSearch;
        return SearchBar.SearchPrefixType.DefaultSearch;
    }
    
    MaterialShapeWrappedMaterialSymbol {
        id: searchIcon
        Layout.alignment: Qt.AlignVCenter
        iconSize: Appearance.font.pixelSize.huge
        shape: {
            if (root.isSimActive) {
                if (SiM.SiMSovereign.breathingStyle === "sun") return MaterialShape.Shape.SoftBurst;
                if (SiM.SiMSovereign.breathingStyle === "moon") return MaterialShape.Shape.PuffyDiamond;
                return MaterialShape.Shape.Cookie7Sided;
            } else {
                switch(root.searchPrefixType) {
                    case SearchBar.SearchPrefixType.Action: return MaterialShape.Shape.Pill;
                    case SearchBar.SearchPrefixType.App: return MaterialShape.Shape.Clover4Leaf;
                    case SearchBar.SearchPrefixType.Clipboard: return MaterialShape.Shape.Gem;
                    case SearchBar.SearchPrefixType.Emojis: return MaterialShape.Shape.Sunny;
                    case SearchBar.SearchPrefixType.Math: return MaterialShape.Shape.PuffyDiamond;
                    case SearchBar.SearchPrefixType.ShellCommand: return MaterialShape.Shape.PixelCircle;
                    case SearchBar.SearchPrefixType.WebSearch: return MaterialShape.Shape.SoftBurst;
                    default: return MaterialShape.Shape.Cookie7Sided;
                }
            }
        }
        text: {
            if (root.isSimActive) {
                if (SiM.SiMSovereign.breathingStyle === "sun") return "sunny";
                if (SiM.SiMSovereign.breathingStyle === "moon") return "nightlight";
                return "brightness_low";
            } else {
                switch (root.searchPrefixType) {
                    case SearchBar.SearchPrefixType.Action: return "settings_suggest";
                    case SearchBar.SearchPrefixType.App: return "apps";
                    case SearchBar.SearchPrefixType.Clipboard: return "content_paste_search";
                    case SearchBar.SearchPrefixType.Emojis: return "add_reaction";
                    case SearchBar.SearchPrefixType.Math: return "calculate";
                    case SearchBar.SearchPrefixType.ShellCommand: return "terminal";
                    case SearchBar.SearchPrefixType.WebSearch: return "travel_explore";
                    case SearchBar.SearchPrefixType.DefaultSearch: return "search";
                    default: return "search";
                }
            }
        }
        color: root.isSimActive ? SiM.SiMSovereign.prismaticColor : Appearance.colors.colSecondaryContainer
        colSymbol: root.isSimActive ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer

        Behavior on color { ColorAnimation { duration: 250 } }
    }

    Row {
        id: _lockedChipsRow
        Layout.alignment: Qt.AlignVCenter
        spacing: 6
        visible: SiM.SiMSovereign.lockedChips !== undefined && SiM.SiMSovereign.lockedChips.length > 0

        Repeater {
            id: _runeRepeater
            model: SiM.SiMSovereign.lockedChips
            delegate: SiMUi.RuneChip {
                required property var modelData
                required property int index
                runeData: modelData
                isLast: index === SiM.SiMSovereign.lockedChips.length - 1
            }
        }
    }

    ToolbarTextField { // Search box
        id: searchInput
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 40
        focus: GlobalStates.overviewOpen
        font.pixelSize: Appearance.font.pixelSize.small
        placeholderText: Translation.tr("Search, calculate or run")
        implicitWidth: root.searchingText == "" ? Appearance.sizes.searchWidthCollapsed : Appearance.sizes.searchWidth

        Behavior on implicitWidth {
            id: searchWidthBehavior
            enabled: root.animateWidth
            NumberAnimation {
                duration: 300
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        onTextChanged: {
            LauncherSearch.query = text
            if (SiM.SiMSovereign.recordKeystroke) {
                SiM.SiMSovereign.recordKeystroke()
            }
        }

        onAccepted: {
            if (appResults.count > 0) {
                // Get the first visible delegate and trigger its click
                let firstItem = appResults.itemAtIndex(0);
                if (firstItem && firstItem.clicked) {
                    firstItem.clicked();
                }
            }
        }

        Text {
            id: _ghost
            anchors.verticalCenter: parent.verticalCenter
            x: parent.cursorRectangle.x + parent.cursorRectangle.width + 4
            visible: _ghostStr !== "" && parent.text.length > 0 && parent.activeFocus
            text: _ghostStr
            color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r, SiM.SiMSovereign.prismaticColor.g, SiM.SiMSovereign.prismaticColor.b, 0.45)
            font.family: parent.font.family
            font.pixelSize: parent.font.pixelSize
            font.italic: true

            readonly property string _ghostStr: SiM.SiMNLU.ghostText(parent.text)
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab) {
                var query = searchInput.text.trim().toLowerCase()
                
                // 1. Check if it matches a breathing style command
                if (query === "moon" || query === "sun" || query === "celestial" || query === "prismatic") {
                    var styleCmd = query === "prismatic" ? "celestial" : query;
                    var styleResult = SiM.SiMSovereign.processCommand(styleCmd);
                    if (styleResult.handled) {
                        var styleIcon = styleCmd === "sun" ? "☀" : (styleCmd === "moon" ? "☽" : "◈");
                        var styleColor = styleCmd === "sun" ? "#f43f5e" : (styleCmd === "moon" ? "#00B4D8" : "#B44FE8");
                        var styleLabel = styleCmd.toUpperCase();
                        
                        var newChips = SiM.SiMSovereign.lockedChips.filter(function(c) { return !c.id.startsWith("style_") });
                        newChips.push({ id: "style_" + styleCmd, label: styleLabel, icon: styleIcon, color: styleColor, isStyle: true });
                        SiM.SiMSovereign.lockedChips = newChips;
                        
                        searchInput.text = "";
                        LauncherSearch.query = "";
                        event.accepted = true;
                        return;
                    }
                }
                
                // 2. Check if it matches a recognized tool Rune
                var matchedRune = SiM.SiMRunes.match(query);
                if (matchedRune) {
                    var currentChips = SiM.SiMSovereign.lockedChips.slice();
                    if (!currentChips.some(function(c) { return c.id === matchedRune.id })) {
                        currentChips.push(matchedRune);
                        SiM.SiMSovereign.lockedChips = currentChips;
                    }
                    searchInput.text = "";
                    LauncherSearch.query = "";
                    event.accepted = true;
                    return;
                }
                
                // 3. Ghost text autocomplete
                var ghost = SiM.SiMNLU.ghostText(searchInput.text)
                if (ghost !== "") {
                    searchInput.text = searchInput.text + ghost
                    searchInput.cursorPosition = searchInput.text.length
                    event.accepted = true;
                    return;
                }
                
                // 4. Custom segment lock-in
                if (root.isSimActive && searchInput.text.trim() !== "") {
                    var textSegment = searchInput.text.trim();
                    var customChip = {
                        id: "seg_" + Date.now() + "_" + Math.random(),
                        label: textSegment,
                        icon: "⬡",
                        color: SiM.SiMSovereign.prismaticColor.toString(),
                        cmd: textSegment,
                        isStyle: false
                    };
                    var currentChips = SiM.SiMSovereign.lockedChips.slice();
                    currentChips.push(customChip);
                    SiM.SiMSovereign.lockedChips = currentChips;
                    searchInput.text = "";
                    LauncherSearch.query = "";
                    event.accepted = true;
                    return;
                }
                
                // 5. Default fallback
                if (!root.isSimActive) {
                    if (LauncherSearch.results.length === 0) return;
                    const tabbedText = LauncherSearch.results[0].name;
                    LauncherSearch.query = tabbedText;
                    searchInput.text = tabbedText;
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Backspace && searchInput.text.length === 0 && SiM.SiMSovereign.lockedChips !== undefined && SiM.SiMSovereign.lockedChips.length > 0) {
                event.accepted = true;
                var lastIdx = _runeRepeater.count - 1;
                if (lastIdx >= 0) {
                    var chip = _runeRepeater.itemAt(lastIdx);
                    if (chip && typeof chip.shatter === "function") {
                        chip.shatter();
                        var delayTimer = Qt.createQmlObject("import QtQuick 2.0; Timer { interval: 320; repeat: false; }", root);
                        delayTimer.triggered.connect(function() {
                            var activeChips = SiM.SiMSovereign.lockedChips.slice();
                            activeChips.pop();
                            SiM.SiMSovereign.lockedChips = activeChips;
                            delayTimer.destroy();
                        });
                        delayTimer.start();
                        return;
                    }
                }
                var activeChips = SiM.SiMSovereign.lockedChips.slice();
                activeChips.pop();
                SiM.SiMSovereign.lockedChips = activeChips;
                return;
            }
        }
    }

    IconToolbarButton {
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        onClicked: {
            GlobalStates.overviewOpen = false;
            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]);
        }
        text: "image_search"
        StyledToolTip {
            text: Translation.tr("Google Lens")
        }
    }

    IconToolbarButton {
        id: songRecButton
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        Layout.rightMargin: 4
        toggled: SongRec.running
        onClicked: SongRec.toggleRunning()
        text: "music_cast"

        StyledToolTip {
            text: Translation.tr("Recognize music")
        }

        colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant
        background: MaterialShape {
            RotationAnimation on rotation {
                running: songRecButton.toggled
                duration: 12000
                easing.type: Easing.Linear
                loops: Animation.Infinite
                from: 0
                to: 360
            }
            shape: {
                if (songRecButton.down) {
                    return songRecButton.toggled ? MaterialShape.Shape.Circle : MaterialShape.Shape.Square
                } else {
                    return songRecButton.toggled ? MaterialShape.Shape.SoftBurst : MaterialShape.Shape.Circle
                }
            }
            color: {
                if (songRecButton.toggled) {
                    return songRecButton.hovered ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary
                } else {
                    return songRecButton.hovered ? Appearance.colors.colSurfaceContainerHigh : ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHigh)
                }
            }
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }
}
