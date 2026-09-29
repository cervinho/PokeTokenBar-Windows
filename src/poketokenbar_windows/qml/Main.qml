import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root
    width: 560
    height: 740
    color: appModel.darkMode ? "#0d121b" : "#f4f7fb"
    border.color: root.borderColor
    border.width: 1

    property int currentPage: 0
    property var activeTooltip: null
    HoverHandler { id: appPointer; acceptedDevices: PointerDevice.Mouse }
    Connections {
        target: appModel
        function onDataChanged() {
            if (!appModel.windowActive) root.activeTooltip = null
        }
    }
    onCurrentPageChanged: Qt.callLater(root.syncDexViewport)
    property int trendHoveredIndex: -1
    property string collectionMode: "dex"
    property int selectedDexIndex: -1
    property int returnDexIndex: -1
    readonly property var selectedDex: selectedDexIndex >= 0 && selectedDexIndex < appModel.dexBrowseEntries.length
        ? appModel.dexBrowseEntries[selectedDexIndex] : ({})
    onCollectionModeChanged: {
        if (collectionMode !== "dex") {
            selectedDexIndex = -1
            returnDexIndex = -1
        }
        collectionPage.contentItem.contentY = 0
        Qt.callLater(root.syncDexViewport)
    }
    onSelectedDexIndexChanged: if (selectedDexIndex < 0) Qt.callLater(root.syncDexViewport)

    function openDex(speciesId) {
        for (let index = 0; index < appModel.dexBrowseEntries.length; ++index) {
            if (appModel.dexBrowseEntries[index].speciesId === speciesId) {
                returnDexIndex = -1
                selectedDexIndex = index
                collectionPage.contentItem.contentY = 0
                return
            }
        }
    }

    function closeDex() {
        if (selectedDexIndex < 0)
            return
        returnDexIndex = selectedDexIndex
        appModel.showDexIndex(returnDexIndex)
        selectedDexIndex = -1
        collectionPage.contentItem.contentY = 0
        Qt.callLater(root.syncDexViewport)
    }

    function syncDexViewport() {
        if (root.currentPage !== 1 || root.collectionMode !== "dex"
                || root.selectedDexIndex >= 0 || collectionPage.availableHeight <= 0
                || dexGrid.width <= 0 || dexPagination.height <= 0)
            return
        const height = Math.floor(
            collectionPage.availableHeight - dexGrid.y
            - dexPagination.height - collectionContent.spacing - 4
        )
        appModel.setDexViewport(dexGrid.columns, height)
        if (returnDexIndex >= 0)
            appModel.showDexIndex(returnDexIndex)
    }

    function navigateDex(direction) {
        if (root.currentPage !== 1 || root.collectionMode !== "dex")
            return
        if (root.selectedDexIndex >= 0) {
            const next = root.selectedDexIndex + direction
            if (next < 0 || next >= appModel.dexBrowseEntries.length)
                return
            root.selectedDexIndex = next
        } else {
            returnDexIndex = -1
            appModel.moveDexPage(direction)
        }
        collectionPage.contentItem.contentY = 0
    }

    readonly property bool darkMode: appModel.darkMode
    property color textColor: appModel.darkMode ? "#edf2ff" : "#172033"
    property color mutedColor: appModel.darkMode ? "#b9c7db" : "#5b6a80"
    property color panelColor: appModel.darkMode ? "#18212e" : "#ffffff"
    property color panelAltColor: appModel.darkMode ? "#202b3b" : "#edf3ff"
    property color borderColor: appModel.darkMode ? "#2b394e" : "#dce3ed"
    property color accentColor: appModel.darkMode ? "#8facff" : "#315da8"
    property color trendHoverColor: appModel.darkMode ? "#c2d1ff" : "#6388c7"
    property color accentSurface: appModel.darkMode ? "#263754" : "#dbe7fb"
    property color successColor: appModel.darkMode ? "#75d6a7" : "#237a55"
    property color warningColor: appModel.darkMode ? "#f0bc68" : "#a45b00"
    property color dangerColor: appModel.darkMode ? "#ff9494" : "#b52c3b"

    function format(template, values) {
        let result = template
        for (const key in values)
            result = result.replace("{" + key + "}", values[key])
        return result
    }

    function revealKeyboardFocus() {
        const item = root.Window.window ? root.Window.window.activeFocusItem : null
        if (!item) return
        for (const page of [collectionPage, bagPage, shopPage, settingsPage]) {
            let ancestor = item
            while (ancestor && ancestor !== page) ancestor = ancestor.parent
            if (ancestor === page && page.visible) {
                page.revealItem(item)
                return
            }
        }
    }

    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealKeyboardFocus) }
    }

    component ActionPopup: Popup {
        id: actionPopup
        property string headingText: ""
        property string questionText: ""
        property string detailText: ""
        property string dangerText: ""
        property string confirmText: ""
        signal confirmed()
        parent: Overlay.overlay
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(370, root.width - 32)
        height: Math.min(root.height - 32, Math.max(158, contentItem.implicitHeight + 2 * padding))
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 16
        Overlay.modal: Rectangle { color: "#80000000" }
        background: Rectangle { color: root.panelColor; radius: 12; border.color: root.borderColor; border.width: 1 }
        contentItem: ColumnLayout {
            spacing: 11
            Text { text: actionPopup.headingText; color: root.textColor; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text {
                objectName: "actionQuestionText"
                Layout.fillWidth: true
                text: actionPopup.questionText
                color: root.mutedColor
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Text {
                objectName: "actionDetailText"
                Layout.fillWidth: true
                visible: actionPopup.detailText.length > 0
                text: actionPopup.detailText
                color: root.mutedColor
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Text {
                objectName: "actionDangerText"
                Layout.fillWidth: true
                visible: actionPopup.dangerText.length > 0
                text: actionPopup.dangerText
                color: root.warningColor
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                AppButton { text: appModel.strings.cancel; onClicked: actionPopup.close() }
                AppButton {
                    text: actionPopup.confirmText
                    highlighted: true
                    onClicked: {
                        actionPopup.close()
                        actionPopup.confirmed()
                    }
                }
            }
        }
    }

    ActionPopup {
        id: useItemPopup
        objectName: "useItemPopup"
        property string itemKind: ""
        function confirm(kind) { itemKind = kind; open() }
        headingText: appModel.strings.use_item_title
        questionText: root.format(appModel.strings.use_item_question, {
            item: itemKind === "rare_candy" ? appModel.strings.rare_candy : appModel.strings.mint
        })
        confirmText: appModel.strings.confirm_use
        onConfirmed: appModel.useItem(itemKind)
    }

    Popup {
        id: candyPopup
        objectName: "candyPopup"
        property var options: ({maxCount: 0})
        property int selectedCount: 1
        readonly property var preview: appModel.candyPreview(selectedCount)
        function confirm() {
            const current = appModel.candyOptions()
            if (!current.maxCount) return
            options = current
            selectedCount = 1
            open()
        }
        parent: Overlay.overlay
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: Math.min(500, root.width - 32)
        height: Math.min(root.height - 32, Math.max(360, contentItem.implicitHeight + 2 * padding))
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 18
        Overlay.modal: Rectangle { color: "#80000000" }
        background: Rectangle { color: root.panelColor; radius: 12; border.color: root.borderColor; border.width: 1 }
        contentItem: ColumnLayout {
            spacing: 12
            Text { Layout.fillWidth: true; text: appModel.strings.candy_modal_title; color: root.textColor; font.pixelSize: 19; font.weight: Font.DemiBold }
            Text {
                Layout.fillWidth: true
                text: root.format(appModel.strings.candy_modal_subtitle, {
                    name: candyPopup.options.name || "", progress: candyPopup.options.progress || "",
                    available: candyPopup.options.available || 0
                })
                color: root.mutedColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            Item { Layout.preferredHeight: 2 }
            Text { text: appModel.strings.candy_quantity; color: root.mutedColor; font.pixelSize: 11; font.weight: Font.DemiBold }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                radius: 8
                color: root.panelAltColor
                border.color: root.borderColor
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    AppButton {
                        text: "−"
                        accessibleName: appModel.strings.candy_quantity + " −"
                        enabled: candyPopup.selectedCount > 1
                        implicitWidth: 48
                        onClicked: candyPopup.selectedCount--
                    }
                    Text {
                        objectName: "candySelectedCount"
                        Layout.fillWidth: true
                        text: String(candyPopup.selectedCount)
                        color: root.textColor
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                    AppButton {
                        objectName: "candyIncrementButton"
                        text: "+"
                        accessibleName: appModel.strings.candy_quantity + " +"
                        enabled: candyPopup.selectedCount < candyPopup.options.maxCount
                        implicitWidth: 48
                        onClicked: candyPopup.selectedCount++
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.borderColor }
            RowLayout {
                visible: candyPopup.options.nextCount > 0
                Layout.fillWidth: true
                Text { text: appModel.strings.candy_until_next; color: root.mutedColor; font.pixelSize: 13; Layout.fillWidth: true }
                Button {
                    objectName: "candyNextQuick"
                    text: root.format(appModel.strings.candy_choose_count, {count: candyPopup.options.nextCount || 0})
                    enabled: candyPopup.options.nextCount <= candyPopup.options.maxCount
                    implicitHeight: 30
                    activeFocusOnTab: true
                    Accessible.name: appModel.strings.candy_until_next + ": " + text
                    Accessible.role: Accessible.Button
                    FocusFrame { }
                    contentItem: Text { text: parent.text; color: parent.enabled ? root.accentColor : root.mutedColor; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    background: Item { }
                    onClicked: candyPopup.selectedCount = candyPopup.options.nextCount
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: appModel.strings.candy_until_finish; color: root.mutedColor; font.pixelSize: 13; Layout.fillWidth: true }
                Button {
                    objectName: "candyFinishQuick"
                    text: root.format(appModel.strings.candy_choose_count, {count: candyPopup.options.completionCount || 0})
                    enabled: candyPopup.options.completionCount <= candyPopup.options.maxCount
                    implicitHeight: 30
                    activeFocusOnTab: true
                    Accessible.name: appModel.strings.candy_until_finish + ": " + text
                    Accessible.role: Accessible.Button
                    FocusFrame { }
                    contentItem: Text { text: parent.text; color: parent.enabled ? root.accentColor : root.mutedColor; font.pixelSize: 13; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    background: Item { }
                    onClicked: candyPopup.selectedCount = candyPopup.options.completionCount
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: candyPopup.preview.discarded ? 67 : 51
                radius: 8
                color: root.accentSurface
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Text { text: appModel.strings.candy_result_label; color: root.mutedColor; font.pixelSize: 10; font.weight: Font.DemiBold }
                    Text {
                        Layout.fillWidth: true
                        text: "+" + (candyPopup.preview.amount || "0") + " EXP  →  " + (candyPopup.preview.outcome || "")
                        color: root.textColor
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !!candyPopup.preview.discarded
                        Layout.fillWidth: true
                        text: candyPopup.preview.discarded || ""
                        color: root.warningColor
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
            Item { Layout.fillHeight: true; Layout.preferredHeight: 2 }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                AppButton { text: appModel.strings.cancel; onClicked: candyPopup.close() }
                AppButton {
                    objectName: "candyConfirmButton"
                    text: root.format(appModel.strings.candy_confirm_count, {count: candyPopup.selectedCount})
                    highlighted: true
                    onClicked: {
                        const count = candyPopup.selectedCount
                        candyPopup.close()
                        appModel.useRareCandy(count)
                    }
                }
            }
        }
    }

    ActionPopup {
        id: purchasePopup
        objectName: "purchasePopup"
        property var selection: ({kind: "item", key: "", title: "", price: ""})
        function confirm(item) { selection = item; open() }
        headingText: selection.kind === "egg" ? appModel.strings.buy_egg_title : appModel.strings.buy_item_title
        questionText: root.format(appModel.strings.purchase_question, {
            item: selection.title, price: selection.price
        })
        detailText: selection.kind === "egg" && appModel.hasActiveCompanion
            ? appModel.strings.egg_replacement_warning : ""
        dangerText: selection.kind === "egg" && appModel.activeCompanionShiny
            ? appModel.strings.egg_shiny_warning : ""
        confirmText: selection.kind === "egg" ? appModel.strings.confirm_buy_egg : appModel.strings.confirm_buy_item
        onConfirmed: appModel.buy(selection.kind, selection.key)
    }

    component MiddleAutoScroll: Item {
        id: autoScroll
        required property var flickable
        property bool scrolling: false
        property real originX: 0
        property real originY: 0
        readonly property bool canScroll: flickable && flickable.contentHeight > flickable.height + 1
        z: 20

        function stop() { scrolling = false }
        onVisibleChanged: if (!visible) stop()
        onCanScrollChanged: if (!canScroll) stop()
        Connections {
            target: appModel
            function onDataChanged() {
                if (!appModel.windowActive) autoScroll.stop()
            }
        }
        TapHandler {
            acceptedDevices: PointerDevice.Mouse
            acceptedButtons: Qt.MiddleButton
            onTapped: (point, button) => {
                if (autoScroll.scrolling) {
                    autoScroll.stop()
                } else if (autoScroll.canScroll) {
                    autoScroll.originX = point.position.x
                    autoScroll.originY = point.position.y
                    autoScroll.scrolling = true
                }
            }
        }
        TapHandler {
            enabled: autoScroll.scrolling
            acceptedDevices: PointerDevice.Mouse
            acceptedButtons: Qt.LeftButton
            onTapped: autoScroll.stop()
        }
        Timer {
            interval: 16
            repeat: true
            running: autoScroll.scrolling
            onTriggered: {
                if (!autoScroll.visible || !autoScroll.canScroll || !appPointer.hovered) {
                    autoScroll.stop()
                    return
                }
                const pointer = autoScroll.mapFromItem(
                    root, appPointer.point.position.x, appPointer.point.position.y
                )
                const distance = pointer.y - autoScroll.originY
                const beyondDeadZone = Math.max(0, Math.abs(distance) - 12)
                if (beyondDeadZone === 0) return
                const step = Math.sign(distance) * Math.min(36, beyondDeadZone * 0.12)
                const maxY = Math.max(0, autoScroll.flickable.contentHeight - autoScroll.flickable.height)
                autoScroll.flickable.contentY = Math.max(0, Math.min(maxY, autoScroll.flickable.contentY + step))
            }
        }
        Rectangle {
            visible: autoScroll.scrolling
            x: Math.max(2, Math.min(autoScroll.width - width - 2, autoScroll.originX - width / 2))
            y: Math.max(2, Math.min(autoScroll.height - height - 2, autoScroll.originY - height / 2))
            width: 28
            height: 28
            radius: 14
            color: root.panelColor
            border.color: root.accentColor
            border.width: 1
            Text { anchors.centerIn: parent; text: "↕"; color: root.accentColor; font.pixelSize: 18 }
        }
    }

    component PageScroll: ScrollView {
        id: pageScroll
        MiddleAutoScroll {
            objectName: "pageAutoScroll"
            parent: pageScroll
            anchors.fill: parent
            flickable: pageScroll.contentItem
        }
        function revealItem(item) {
            const flickable = contentItem
            const position = item.mapToItem(flickable.contentItem, 0, 0)
            const bottom = position.y + item.height + 10
            let nextY = flickable.contentY
            if (position.y - 10 < nextY) nextY = position.y - 10
            else if (bottom > nextY + availableHeight) nextY = bottom - availableHeight
            flickable.contentY = Math.max(0, Math.min(nextY, flickable.contentHeight - availableHeight))
        }
    }

    component FocusFrame: Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        visible: parent.visualFocus
        color: "transparent"
        radius: 6
        border.width: 2
        border.color: root.accentColor
        z: 10
    }

    component PokeBall: Item {
        implicitWidth: 24
        implicitHeight: 24
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const size = Math.min(width, height)
                const cx = width / 2
                const cy = height / 2
                const radius = size / 2 - 1.2
                const outline = "#151922"

                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                ctx.clip()
                ctx.fillStyle = "#ffffff"
                ctx.fillRect(cx - radius, cy, radius * 2, radius)
                ctx.fillStyle = "#ef4455"
                ctx.fillRect(cx - radius, cy - radius, radius * 2, radius)
                ctx.restore()

                ctx.strokeStyle = outline
                ctx.lineWidth = Math.max(1.6, size * 0.08)
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                ctx.stroke()
                ctx.fillStyle = outline
                ctx.fillRect(cx - radius, cy - size * 0.075, radius * 2, size * 0.15)
                ctx.beginPath()
                ctx.arc(cx, cy, size * 0.20, 0, 2 * Math.PI)
                ctx.fill()
                ctx.fillStyle = "#ffffff"
                ctx.beginPath()
                ctx.arc(cx, cy, size * 0.105, 0, 2 * Math.PI)
                ctx.fill()
            }
        }
    }

    component WarningIcon: Item {
        property color markColor: root.warningColor
        implicitWidth: 16
        implicitHeight: 16
        Accessible.ignored: true
        Canvas {
            anchors.fill: parent
            property color iconColor: parent.markColor
            onIconColorChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const scale = Math.min(width, height) / 16
                ctx.save()
                ctx.scale(scale, scale)
                ctx.fillStyle = iconColor
                ctx.beginPath()
                ctx.moveTo(8, 1)
                ctx.lineTo(15, 14)
                ctx.quadraticCurveTo(15.4, 15, 14.1, 15)
                ctx.lineTo(1.9, 15)
                ctx.quadraticCurveTo(0.6, 15, 1, 14)
                ctx.closePath()
                ctx.fill()
                ctx.fillStyle = root.darkMode ? "#172033" : "#ffffff"
                ctx.fillRect(7.25, 5, 1.5, 5.5)
                ctx.beginPath()
                ctx.arc(8, 12.5, 1, 0, 2 * Math.PI)
                ctx.fill()
                ctx.restore()
            }
        }
    }

    component EggIcon: Item {
        required property string tier
        implicitWidth: 42
        implicitHeight: 42
        Canvas {
            anchors.fill: parent
            property string eggTier: parent.tier
            onEggTierChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const scale = Math.min(width / 42, height / 42)
                ctx.save()
                ctx.scale(scale, scale)
                const fill = eggTier === "rare" ? "#936fe2"
                    : (eggTier === "uncommon" ? "#58a7e8" : "#faf8ef")
                const spots = eggTier === "rare" ? "#f2c653"
                    : (eggTier === "uncommon" ? "#d8f2ff" : "#c7ccd5")
                const outline = eggTier === "rare" ? "#352253"
                    : (eggTier === "uncommon" ? "#173b61" : "#30343b")

                ctx.fillStyle = fill
                ctx.strokeStyle = outline
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(21, 3)
                ctx.bezierCurveTo(14, 3, 8, 17, 8, 27)
                ctx.bezierCurveTo(8, 36, 13, 40, 21, 40)
                ctx.bezierCurveTo(29, 40, 34, 36, 34, 27)
                ctx.bezierCurveTo(34, 17, 28, 3, 21, 3)
                ctx.closePath()
                ctx.fill()
                ctx.stroke()

                ctx.fillStyle = spots
                for (const spot of [[15, 23, 2.2], [25, 15, 1.8], [26, 30, 2.4]]) {
                    ctx.beginPath()
                    ctx.arc(spot[0], spot[1], spot[2], 0, 2 * Math.PI)
                    ctx.fill()
                }
                if (eggTier === "uncommon") {
                    ctx.fillStyle = "#e8fbff"
                    ctx.beginPath()
                    ctx.moveTo(34, 5); ctx.lineTo(36, 9); ctx.lineTo(40, 11)
                    ctx.lineTo(36, 13); ctx.lineTo(34, 17); ctx.lineTo(32, 13)
                    ctx.lineTo(28, 11); ctx.lineTo(32, 9); ctx.closePath(); ctx.fill()
                } else if (eggTier === "rare") {
                    ctx.fillStyle = "#ffd96a"
                    ctx.beginPath()
                    ctx.moveTo(34, 3); ctx.lineTo(36, 8); ctx.lineTo(41, 10)
                    ctx.lineTo(36, 12); ctx.lineTo(34, 17); ctx.lineTo(32, 12)
                    ctx.lineTo(27, 10); ctx.lineTo(32, 8); ctx.closePath(); ctx.fill()
                }
                ctx.restore()
            }
        }
    }

    component RepresentativeCheck: Rectangle {
        required property string label
        implicitWidth: 26
        implicitHeight: 26
        radius: 13
        color: root.successColor
        border.color: root.panelColor
        border.width: 2
        Accessible.name: label
        Canvas {
            anchors.centerIn: parent
            width: 14
            height: 14
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "#ffffff"
                ctx.lineWidth = 2.2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(2, 7)
                ctx.lineTo(6, 11)
                ctx.lineTo(12, 3)
                ctx.stroke()
            }
        }
        HoverHandler { id: representativeHover }
        AppToolTip { requestedVisible: representativeHover.hovered; text: label }
    }

    component AppToolTip: ToolTip {
        id: tooltip
        property bool requestedVisible: false
        visible: requestedVisible && appModel.windowActive && root.activeTooltip === tooltip
        onRequestedVisibleChanged: {
            if (requestedVisible && appModel.windowActive) root.activeTooltip = tooltip
            else if (root.activeTooltip === tooltip) root.activeTooltip = null
        }
        delay: 550
        timeout: 5000
        padding: 8
        TextMetrics { id: textMetrics; font.pixelSize: 11; text: tooltip.text }
        width: Math.min(320, Math.max(32, Math.ceil(textMetrics.advanceWidth) + 2 * padding))
        contentItem: Text {
            text: tooltip.text
            color: root.textColor
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: root.panelColor
            radius: 7
            border.color: root.borderColor
            border.width: 1
        }
    }

    component Panel: Rectangle {
        color: root.panelColor
        radius: 11
        border.color: root.borderColor
        border.width: 1
    }

    component BagItemCard: Panel {
        id: bagCard
        property string itemKind: ""
        property string itemName: ""
        property string icon: ""
        property string description: ""
        property string effectHint: ""
        property string unavailableReason: ""
        property int count: 0
        property bool passive: false
        property bool canUse: false
        Layout.fillWidth: true
        Layout.preferredHeight: 128
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    Layout.preferredWidth: 42
                    Layout.alignment: Qt.AlignTop
                    text: bagCard.icon
                    font.pixelSize: 35
                    horizontalAlignment: Text.AlignHCenter
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    RowLayout {
                        spacing: 8
                        Text { text: bagCard.itemName; color: root.textColor; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text {
                            visible: !bagCard.passive
                            text: "×" + bagCard.count
                            color: root.mutedColor
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: bagCard.description
                        color: root.mutedColor
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: bagCard.passive || bagCard.canUse ? bagCard.effectHint : bagCard.unavailableReason
                    color: bagCard.passive ? root.successColor : root.mutedColor
                    font.pixelSize: 12
                    font.weight: bagCard.passive ? Font.DemiBold : Font.Normal
                    wrapMode: Text.WordWrap
                }
                AppButton {
                    visible: !bagCard.passive && bagCard.canUse
                    text: appModel.strings.bag_use
                    accessibleName: bagCard.itemName + ": " + text
                    implicitHeight: 34
                    leftPadding: 10
                    rightPadding: 10
                    onClicked: {
                        if (bagCard.itemKind === "rare_candy") candyPopup.confirm()
                        else useItemPopup.confirm(bagCard.itemKind)
                    }
                }
            }
        }
    }

    component InfoLabel: Text {
        required property string helpText
        color: root.textColor
        font.pixelSize: 12
        HoverHandler { id: infoHover }
        AppToolTip { requestedVisible: infoHover.hovered; text: helpText }
        Accessible.description: helpText
    }

    component StyledComboBox: ComboBox {
        id: styledCombo
        implicitHeight: 38
        implicitWidth: 144
        background: Rectangle {
            radius: 8
            color: root.panelAltColor
            border.color: styledCombo.visualFocus ? root.accentColor : root.borderColor
            border.width: styledCombo.visualFocus ? 2 : 1
        }
        contentItem: Text {
            leftPadding: 11
            rightPadding: 24
            text: styledCombo.displayText
            color: root.textColor
            font.pixelSize: 12
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        indicator: Canvas {
            width: 16
            height: 16
            x: styledCombo.width - width - 10
            y: (styledCombo.height - height) / 2
            property color strokeColor: root.mutedColor
            onStrokeColorChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = strokeColor
                ctx.lineWidth = 1.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(3, 6)
                ctx.lineTo(8, 11)
                ctx.lineTo(13, 6)
                ctx.stroke()
            }
        }
        delegate: ItemDelegate {
            required property var modelData
            width: styledCombo.width
            contentItem: Text {
                text: typeof modelData === "object"
                    ? (modelData.label || modelData.display || "")
                    : String(modelData)
                color: root.textColor
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: parent.hovered || parent.highlighted ? root.accentSurface : root.panelColor
            }
        }
        popup: Popup {
            y: styledCombo.height - 1
            width: styledCombo.width
            implicitHeight: Math.min(260, contentItem.implicitHeight + 6)
            padding: 3
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: styledCombo.popup.visible ? styledCombo.delegateModel : null
                currentIndex: styledCombo.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
            }
            background: Rectangle {
                color: root.panelColor
                radius: 8
                border.color: root.borderColor
            }
        }
    }

    component StyledSpinBox: SpinBox {
        id: styledSpin
        implicitWidth: 88
        implicitHeight: 36
        background: Rectangle {
            color: root.panelAltColor
            radius: 8
            border.color: styledSpin.visualFocus ? root.accentColor : root.borderColor
            border.width: styledSpin.visualFocus ? 2 : 1
        }
        contentItem: Text {
            text: styledSpin.textFromValue(styledSpin.value, styledSpin.locale)
            color: root.textColor
            font.pixelSize: 12
            leftPadding: 10
            rightPadding: 30
            verticalAlignment: Text.AlignVCenter
        }
        up.indicator: Item {
            x: styledSpin.width - 28
            y: 1
            width: 27
            height: 17
            Canvas {
                anchors.centerIn: parent
                width: 12
                height: 12
                property color strokeColor: styledSpin.up.pressed ? root.accentColor : root.textColor
                onStrokeColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = strokeColor
                    ctx.lineWidth = 1.5
                    ctx.beginPath()
                    ctx.moveTo(2, 6)
                    ctx.lineTo(10, 6)
                    ctx.moveTo(6, 2)
                    ctx.lineTo(6, 10)
                    ctx.stroke()
                }
            }
        }
        down.indicator: Item {
            x: styledSpin.width - 28
            y: 18
            width: 27
            height: 17
            Canvas {
                anchors.centerIn: parent
                width: 12
                height: 12
                property color strokeColor: styledSpin.down.pressed ? root.accentColor : root.textColor
                onStrokeColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = strokeColor
                    ctx.lineWidth = 1.5
                    ctx.beginPath()
                    ctx.moveTo(2, 6)
                    ctx.lineTo(10, 6)
                    ctx.stroke()
                }
            }
        }
    }

    component AppButton: Button {
        id: control
        property string accessibleName: text
        implicitHeight: 34
        leftPadding: 12
        rightPadding: 12
        activeFocusOnTab: true
        Accessible.name: accessibleName
        Accessible.role: Accessible.Button
        FocusFrame { }
        contentItem: Text {
            text: control.text
            color: control.enabled ? (control.highlighted ? "#ffffff" : root.textColor) : root.mutedColor
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 7
            color: control.enabled
                ? (control.highlighted ? root.accentColor : (control.hovered ? root.accentSurface : root.panelAltColor))
                : (root.darkMode ? "#1a2230" : "#edf0f4")
            border.color: control.visualFocus ? root.accentColor : (control.highlighted ? "transparent" : root.borderColor)
            border.width: control.visualFocus ? 2 : 1
        }
    }

    component ShinyVariantToggle: Item {
        id: variant
        required property int speciesId
        required property string speciesName
        required property bool hasNormal
        required property bool showShiny
        readonly property string hint: hasNormal
            ? root.format(showShiny ? appModel.strings.view_normal : appModel.strings.view_shiny,
                          {name: speciesName})
            : root.format(appModel.strings.shiny_only_caught, {name: speciesName})
        implicitWidth: 40
        implicitHeight: 40
        z: 3
        Button {
            id: variantButton
            objectName: "dexShinyToggle"
            anchors.fill: parent
            enabled: variant.hasNormal
            activeFocusOnTab: variant.hasNormal
            Accessible.name: variant.hint
            Accessible.role: Accessible.Button
            FocusFrame { }
            contentItem: Text {
                text: "✨"
                font.pixelSize: 23
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 8
                color: variant.showShiny
                    ? (root.darkMode ? "#3b3322" : "#fff1cf") : root.panelAltColor
                border.color: variant.showShiny ? root.warningColor : root.borderColor
                border.width: 1
            }
            onClicked: appModel.toggleDexVariant(variant.speciesId)
        }
        HoverHandler { id: variantHover; acceptedDevices: PointerDevice.Mouse }
        AppToolTip {
            requestedVisible: variantHover.hovered || variantButton.visualFocus
            text: variant.hint
        }
    }

    component WindowButton: Button {
        id: windowControl
        required property string iconKind
        required property string helpText
        property bool closeStyle: false
        implicitWidth: 46
        implicitHeight: 34
        activeFocusOnTab: true
        Accessible.name: helpText
        Accessible.role: Accessible.Button
        AppToolTip { requestedVisible: windowControl.hovered || windowControl.visualFocus; delay: 500; text: helpText }
        padding: 0
        contentItem: Item {
            Canvas {
                id: windowGlyph
                objectName: windowControl.objectName + "Glyph"
                anchors.centerIn: parent
                width: 16
                height: 16
                property string renderedKind: windowControl.iconKind
                onRenderedKindChanged: requestPaint()
                property color strokeColor: windowControl.closeStyle && windowControl.hovered
                    ? "#ffffff" : root.textColor
                onStrokeColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = strokeColor
                    ctx.lineWidth = 1
                    ctx.lineCap = "square"
                    ctx.lineJoin = "miter"
                    if (renderedKind === "minimize") {
                        ctx.beginPath()
                        ctx.moveTo(3.5, 11.5)
                        ctx.lineTo(12.5, 11.5)
                        ctx.stroke()
                    } else if (renderedKind === "maximize") {
                        ctx.strokeRect(3.5, 3.5, 9, 9)
                    } else if (renderedKind === "restore") {
                        ctx.strokeRect(3.5, 5.5, 7, 7)
                        ctx.beginPath()
                        ctx.moveTo(5.5, 5.5)
                        ctx.lineTo(5.5, 3.5)
                        ctx.lineTo(12.5, 3.5)
                        ctx.lineTo(12.5, 10.5)
                        ctx.lineTo(10.5, 10.5)
                        ctx.stroke()
                    } else {
                        ctx.beginPath()
                        ctx.moveTo(4, 4)
                        ctx.lineTo(12, 12)
                        ctx.moveTo(12, 4)
                        ctx.lineTo(4, 12)
                        ctx.stroke()
                    }
                }
            }
        }
        background: Rectangle {
            color: windowControl.closeStyle && windowControl.hovered
                ? "#c42b1c"
                : (windowControl.hovered ? root.panelAltColor : "transparent")
        }
    }

    component ResizeHandle: MouseArea {
        required property int resizeEdges
        enabled: !appModel.windowMaximized
        acceptedButtons: Qt.LeftButton
        z: 100
        onPressed: appModel.startWindowResize(resizeEdges)
    }

    component NavButton: Button {
        id: nav
        required property int pageIndex
        required property string iconKind
        required property string description
        checkable: true
        checked: root.currentPage === pageIndex
        activeFocusOnTab: true
        Accessible.name: nav.text
        Accessible.description: nav.description
        Accessible.role: Accessible.PageTab
        AppToolTip { objectName: "navigationTooltip-" + nav.pageIndex; requestedVisible: nav.hovered || nav.visualFocus; text: nav.description }
        implicitHeight: 38
        onClicked: root.currentPage = pageIndex
        background: Rectangle {
            radius: 7
            color: nav.checked ? root.accentSurface : (nav.hovered ? root.panelAltColor : "transparent")
            border.color: nav.visualFocus ? root.accentColor : "transparent"
            border.width: nav.visualFocus ? 2 : 0
            Rectangle {
                visible: nav.checked
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 3
                radius: 2
                color: root.accentColor
            }
        }
        contentItem: RowLayout {
            spacing: root.width < 600 ? 3 : 6
            Item { Layout.fillWidth: true }
            Canvas {
                id: navIcon
                Layout.preferredWidth: 15
                Layout.preferredHeight: 15
                property color strokeColor: nav.checked ? root.textColor : root.mutedColor
                onStrokeColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = strokeColor
                    ctx.fillStyle = strokeColor
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    if (nav.iconKind === "home") {
                        ctx.beginPath(); ctx.moveTo(2, 7); ctx.lineTo(7.5, 2); ctx.lineTo(13, 7)
                        ctx.moveTo(3.5, 6); ctx.lineTo(3.5, 13); ctx.lineTo(11.5, 13); ctx.lineTo(11.5, 6); ctx.stroke()
                    } else if (nav.iconKind === "collection") {
                        for (let x = 2; x <= 8; x += 6)
                            for (let y = 2; y <= 8; y += 6) ctx.strokeRect(x, y, 4, 4)
                    } else if (nav.iconKind === "bag") {
                        ctx.strokeRect(2.5, 5, 10, 8)
                        ctx.beginPath(); ctx.arc(7.5, 5, 3, Math.PI, 2 * Math.PI); ctx.stroke()
                    } else if (nav.iconKind === "shop") {
                        ctx.beginPath(); ctx.moveTo(1.5, 2.5); ctx.lineTo(3, 2.5); ctx.lineTo(4.2, 9.5)
                        ctx.lineTo(11.5, 9.5); ctx.lineTo(13, 4.5); ctx.lineTo(3.5, 4.5); ctx.stroke()
                        ctx.beginPath(); ctx.arc(5.5, 12.5, 1, 0, 2 * Math.PI); ctx.arc(10.5, 12.5, 1, 0, 2 * Math.PI); ctx.fill()
                    } else {
                        ctx.beginPath()
                        ctx.moveTo(2, 3); ctx.lineTo(13, 3); ctx.moveTo(2, 7.5); ctx.lineTo(13, 7.5)
                        ctx.moveTo(2, 12); ctx.lineTo(13, 12); ctx.stroke()
                        ctx.beginPath(); ctx.arc(5, 3, 1.6, 0, 2 * Math.PI)
                        ctx.arc(10, 7.5, 1.6, 0, 2 * Math.PI); ctx.arc(6.5, 12, 1.6, 0, 2 * Math.PI); ctx.fill()
                    }
                }
            }
            Text {
                text: nav.text
                color: nav.checked ? root.textColor : root.mutedColor
                font.pixelSize: root.width < 600 ? 11 : 12
                font.weight: nav.checked ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Item { Layout.fillWidth: true }
        }
    }



    component ModernProgress: Rectangle {
        id: progressTrack
        required property real value
        property color barColor: root.accentColor
        implicitHeight: 8
        radius: 4
        color: root.darkMode ? "#303c50" : "#dce3ee"
        clip: true
        Rectangle {
            width: Math.max(0, Math.min(parent.width, parent.width * progressTrack.value / 100))
            height: parent.height
            radius: parent.radius
            color: progressTrack.barColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    component WalletBar: Rectangle {
        implicitHeight: 38
        color: root.panelColor
        border.color: root.borderColor
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 7
            Rectangle {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                radius: 9
                color: root.accentSurface
                border.color: root.accentColor
                Text { anchors.centerIn: parent; text: "•"; color: root.accentColor; font.pixelSize: 14; font.weight: Font.Bold }
            }
            Text { text: appModel.strings.wallet; color: root.mutedColor; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            Text { text: appModel.wallet; color: root.textColor; font.pixelSize: 15; font.weight: Font.DemiBold }
        }
    }

    component ToggleRow: RowLayout {
        id: toggleRow
        required property string label
        property string detail: ""
        property alias checked: toggle.checked
        signal changed(bool value)
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: toggleRow.label; color: root.textColor; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }

        }
        HoverHandler { id: toggleHover }
        AppToolTip {
            requestedVisible: (toggleHover.hovered || toggle.visualFocus) && toggleRow.detail.length > 0
            text: toggleRow.detail
        }
        Switch {
            id: toggle
            activeFocusOnTab: true
            Accessible.name: toggleRow.label
            Accessible.description: toggleRow.detail
            FocusFrame { }
            onToggled: toggleRow.changed(checked)
        }
    }

    component FilterChip: Button {
        id: chip
        required property string filterKey
        required property string label
        required property int itemCount
        checkable: true
        checked: appModel.dexFilter === filterKey
        activeFocusOnTab: true
        implicitHeight: 28
        leftPadding: 7
        rightPadding: 7
        implicitWidth: chipContent.implicitWidth + leftPadding + rightPadding
        Accessible.name: root.format(appModel.strings.filter_by, {label: label})
        Accessible.role: Accessible.RadioButton
        onClicked: {
            root.returnDexIndex = -1
            appModel.setDexFilter(filterKey)
        }
        contentItem: RowLayout {
            id: chipContent
            spacing: 6
            Text {
                text: chip.label
                color: chip.checked ? root.textColor : root.mutedColor
                font.pixelSize: 11
                font.weight: chip.checked ? Font.Medium : Font.Normal
            }
            Rectangle {
                implicitWidth: Math.max(20, chipCount.implicitWidth + 10)
                implicitHeight: 18
                radius: 9
                color: chip.checked ? root.accentColor : root.panelColor
                Text {
                    id: chipCount
                    anchors.centerIn: parent
                    text: chip.itemCount
                    color: chip.checked ? "#ffffff" : root.mutedColor
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }
        background: Rectangle {
            radius: 7
            color: chip.checked ? root.accentSurface : "transparent"
            border.color: chip.visualFocus ? root.accentColor : (chip.checked ? root.accentColor : root.borderColor)
            border.width: chip.visualFocus || chip.checked ? 2 : 1
        }
    }

    component ShinyFilterChip: Button {
        id: shinyChip
        objectName: "shinyFilterChip"
        checkable: true
        checked: appModel.dexShinyOnly
        enabled: appModel.dexShinyCount > 0 || appModel.dexShinyOnly
        activeFocusOnTab: enabled
        implicitHeight: 28
        leftPadding: 8
        rightPadding: 8
        implicitWidth: shinyContent.implicitWidth + leftPadding + rightPadding
        Accessible.name: appModel.strings.shiny_filter_hint
        Accessible.role: Accessible.CheckBox
        FocusFrame { }
        onClicked: {
            root.returnDexIndex = -1
            appModel.setDexShinyOnly(checked)
        }
        contentItem: RowLayout {
            id: shinyContent
            spacing: 6
            Text { text: "✨"; color: root.warningColor; font.pixelSize: 14 }
            Rectangle {
                implicitWidth: Math.max(20, shinyCount.implicitWidth + 10)
                implicitHeight: 18
                radius: 9
                color: shinyChip.checked ? root.warningColor : root.panelColor
                Text {
                    id: shinyCount
                    anchors.centerIn: parent
                    text: appModel.dexShinyCount
                    color: shinyChip.checked ? "#182231" : root.mutedColor
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }
        background: Rectangle {
            radius: 7
            color: shinyChip.checked ? (root.darkMode ? "#3b3322" : "#fff1cf") : "transparent"
            border.color: shinyChip.checked || shinyChip.visualFocus
                ? root.warningColor : root.borderColor
            border.width: shinyChip.checked || shinyChip.visualFocus ? 2 : 1
        }
        HoverHandler { id: shinyFilterHover; acceptedDevices: PointerDevice.Mouse }
        AppToolTip {
            requestedVisible: shinyFilterHover.hovered || shinyChip.visualFocus
            text: appModel.strings.shiny_filter_hint
        }
    }

    component SegmentedControl: Rectangle {
        id: segment
        required property var options
        required property string currentValue
        property string accessibleName: ""
        signal selected(string value)
        implicitHeight: 34
        implicitWidth: optionRow.implicitWidth + 6
        radius: 8
        color: root.panelAltColor
        border.color: root.borderColor
        RowLayout {
            id: optionRow
            anchors.fill: parent
            anchors.margins: 3
            spacing: 2
            Repeater {
                model: segment.options
                Button {
                    id: optionButton
                    required property var modelData
                    checkable: true
                    checked: segment.currentValue === modelData.value
                    activeFocusOnTab: true
                    implicitHeight: 28
                    leftPadding: 9
                    rightPadding: 9
                    Accessible.name: segment.accessibleName + ": " + modelData.label
                    Accessible.role: Accessible.RadioButton
                    onClicked: segment.selected(modelData.value)
                    contentItem: Text {
                        text: optionButton.modelData.label
                        color: optionButton.checked ? root.textColor : root.mutedColor
                        font.pixelSize: 12
                        font.weight: optionButton.checked ? Font.Medium : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 5
                        color: optionButton.checked ? root.panelColor : "transparent"
                        border.color: optionButton.visualFocus ? root.accentColor : (optionButton.checked ? root.borderColor : "transparent")
                    }
                }
            }
        }
    }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: shellHeader
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            color: root.panelColor
            border.color: root.borderColor
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Item {
                    id: customTitleBar
                    objectName: "customTitleBar"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: appModel.startWindowMove()
                        onDoubleClicked: appModel.toggleMaximizeWindow()
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 7
                        PokeBall { objectName: "brandMark"; Layout.preferredWidth: 25; Layout.preferredHeight: 25 }
                        Text {
                            text: "PokeTokenBar"
                            color: root.textColor
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        WindowButton {
                            objectName: "minimizeWindowButton"
                            iconKind: "minimize"
                            helpText: appModel.strings.window_minimize
                            onClicked: appModel.minimizeWindow()
                        }
                        WindowButton {
                            objectName: "maximizeWindowButton"
                            iconKind: appModel.windowMaximized ? "restore" : "maximize"
                            helpText: appModel.windowMaximized ? appModel.strings.window_restore : appModel.strings.window_maximize
                            onClicked: appModel.toggleMaximizeWindow()
                        }
                        WindowButton {
                            objectName: "closeWindowButton"
                            iconKind: "close"
                            helpText: appModel.strings.window_close
                            closeStyle: true
                            onClicked: appModel.closeWindow()
                        }
                    }
                }
                RowLayout {
                    objectName: "topNavigation"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    spacing: 2
                    NavButton { pageIndex: 0; iconKind: "home"; text: appModel.strings.nav_home; description: appModel.strings.home_description; Layout.fillWidth: true }
                    NavButton { pageIndex: 1; iconKind: "collection"; text: appModel.strings.nav_collection; description: appModel.strings.collection_description; Layout.fillWidth: true }
                    NavButton { pageIndex: 2; iconKind: "bag"; text: appModel.strings.nav_bag; description: appModel.strings.bag_description; Layout.fillWidth: true }
                    NavButton { pageIndex: 3; iconKind: "shop"; text: appModel.strings.nav_shop; description: appModel.strings.shop_description; Layout.fillWidth: true }
                    NavButton { pageIndex: 4; iconKind: "settings"; text: appModel.strings.nav_settings; description: appModel.strings.settings_description; Layout.fillWidth: true }
                }
            }
        }

        WalletBar {
            objectName: "sharedWalletBar"
            Layout.fillWidth: true
            visible: root.currentPage === 2 || root.currentPage === 3
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.currentPage

            PageScroll {
                id: homePage
                objectName: "homePage"
                clip: true
                contentWidth: availableWidth
                contentHeight: homeContent.height + 20
                ColumnLayout {
                    id: homeContent
                    x: 10
                    y: 10
                    width: homePage.availableWidth - 20
                    height: Math.max(homePage.availableHeight - 20, implicitHeight)
                    spacing: 7

                    Panel {
                        id: companionPanel
                        objectName: "companionPanel"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 158
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 11
                            spacing: 12
                            Rectangle {
                                objectName: "companionFrame"
                                Layout.preferredWidth: 136
                                Layout.preferredHeight: 136
                                radius: 12
                                color: root.accentSurface
                                AnimatedImage {
                                    objectName: "companionAnimation"
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    source: appModel.spriteUrl
                                    fillMode: Image.PreserveAspectFit
                                    smooth: false
                                    playing: visible && root.currentPage === 0
                                    visible: !appModel.loading && !appModel.revealActive
                                }
                                PokeBall {
                                    id: revealBall
                                    objectName: "companionReveal"
                                    anchors.centerIn: parent
                                    width: 48; height: 48
                                    visible: appModel.loading || appModel.revealActive
                                    property int shakeFrame: 0
                                    transform: Translate {
                                        x: [0, -5, 5, -4, 4, -2, 2, 0][revealBall.shakeFrame] * revealBall.width / 96
                                        y: revealBall.height * 0.1
                                    }
                                    Timer {
                                        interval: 90
                                        running: revealBall.visible
                                        repeat: true
                                        onTriggered: revealBall.shakeFrame = (revealBall.shakeFrame + 1) % 8
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { objectName: "companionName"; text: appModel.companionName; color: root.textColor; font.pixelSize: 24; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                    AppButton {
                                        objectName: "homeRefreshButton"
                                        Layout.preferredHeight: 30
                                        text: appModel.strings.refresh
                                        accessibleName: appModel.strings.refresh
                                        highlighted: true
                                        enabled: appModel.refreshEnabled
                                        onClicked: appModel.requestRefresh()
                                        AppToolTip {
                                            objectName: "refreshTooltip"
                                            requestedVisible: parent.hovered || parent.visualFocus
                                            text: appModel.strings.refresh_shortcut_help
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    Text { text: appModel.companionSubtitle; color: root.mutedColor; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Rectangle {
                                        objectName: "growthBoostBadge"
                                        visible: appModel.growthBoost
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 18
                                        radius: 9
                                        color: root.darkMode ? "#503b22" : "#fff0d6"
                                        Text { anchors.centerIn: parent; text: appModel.strings.repeat_boost; color: root.warningColor; font.pixelSize: 10; font.weight: Font.Bold }
                                        HoverHandler { id: growthHover }
                                        AppToolTip {
                                            requestedVisible: growthHover.hovered
                                            delay: 450
                                            text: appModel.strings.repeat_boost_help
                                        }
                                        Accessible.name: appModel.strings.repeat_boost_help
                                    }
                                }
                                Text { objectName: "companionEvolution"; text: appModel.companionEvolutionText; color: appModel.darkMode ? "#96a5bc" : "#66758a"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                                Item { Layout.fillHeight: true }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: appModel.companionProgressText; color: root.textColor; font.pixelSize: 12; Layout.fillWidth: true }
                                    Text { text: appModel.companionLevelText; color: root.textColor; font.pixelSize: 15; font.weight: Font.Bold }
                                }
                                ModernProgress { objectName: "companionProgressBar"; Layout.fillWidth: true; value: appModel.companionProgress }
                            }
                        }
                    }

                    Panel {
                        id: usagePanel
                        objectName: "monthTrendPanel"
                        Layout.fillWidth: true
                        Layout.preferredHeight: appModel.trendMonthLabel !== "" ? 198 : 101
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4
                            RowLayout {
                                id: usageMetricRow
                                objectName: "usageMetricRow"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 55
                                Layout.minimumHeight: 55
                                Layout.maximumHeight: 55
                                spacing: 5
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    Layout.fillHeight: true
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 0
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 18
                                            Text {
                                                text: appModel.strings.tokens_today
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: root.mutedColor
                                                font.pixelSize: 12
                                            }
                                        }
                                        RowLayout {
                                            Layout.alignment: Qt.AlignLeft
                                            Layout.preferredHeight: 24
                                            spacing: 5
                                            Text { text: appModel.todayTokens; color: root.textColor; font.pixelSize: 20; font.weight: Font.DemiBold }
                                            Text { text: appModel.todayCost; color: root.mutedColor; font.pixelSize: 11 }
                                        }
                                    }
                                }
                                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 35; color: root.borderColor }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    Layout.fillHeight: true
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 0
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 18
                                            Text {
                                                text: appModel.strings.this_week
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: root.mutedColor
                                                font.pixelSize: 12
                                            }
                                        }
                                        RowLayout {
                                            Layout.alignment: Qt.AlignLeft
                                            Layout.preferredHeight: 24
                                            spacing: 5
                                            Text { text: appModel.weekTokens; color: root.textColor; font.pixelSize: 20; font.weight: Font.DemiBold }
                                            Text { text: appModel.weekCost; color: root.mutedColor; font.pixelSize: 11 }
                                        }
                                    }
                                }
                                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 35; color: root.borderColor }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    Layout.fillHeight: true
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 0
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 18
                                            RowLayout {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1
                                                Button {
                                                    objectName: "trendPreviousMonth"
                                                    enabled: appModel.trendCanPrevious
                                                    implicitWidth: 17; implicitHeight: 19
                                                    Accessible.name: appModel.strings.trend_previous_month
                                                    text: "‹"
                                                    font.pixelSize: 17
                                                    onClicked: { root.trendHoveredIndex = -1; appModel.moveMonth(-1) }
                                                    background: Rectangle { radius: 4; color: parent.hovered ? root.panelAltColor : "transparent" }
                                                    contentItem: Text { text: parent.text; color: parent.enabled ? root.accentColor : root.mutedColor; opacity: parent.enabled ? 1 : 0.4; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                }
                                                Text { text: appModel.trendMonthLabel; color: root.accentColor; font.pixelSize: 12; font.weight: Font.DemiBold }
                                                Button {
                                                    objectName: "trendNextMonth"
                                                    enabled: appModel.trendCanNext
                                                    implicitWidth: 17; implicitHeight: 19
                                                    Accessible.name: appModel.strings.trend_next_month
                                                    text: "›"
                                                    font.pixelSize: 17
                                                    onClicked: { root.trendHoveredIndex = -1; appModel.moveMonth(1) }
                                                    background: Rectangle { radius: 4; color: parent.hovered ? root.panelAltColor : "transparent" }
                                                    contentItem: Text { text: parent.text; color: parent.enabled ? root.accentColor : root.mutedColor; opacity: parent.enabled ? 1 : 0.4; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.alignment: Qt.AlignLeft
                                            Layout.preferredHeight: 24
                                            spacing: 5
                                            Text { text: appModel.trendMonthTokens; color: root.textColor; font.pixelSize: 20; font.weight: Font.DemiBold }
                                            Text { text: appModel.trendMonthCost; color: root.mutedColor; font.pixelSize: 11 }
                                        }
                                    }
                                }
                            }
                            Item {
                                visible: appModel.trendMonthLabel !== ""
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 1
                                    color: root.borderColor
                                }
                            }
                            RowLayout {
                                visible: appModel.trendMonthLabel !== ""
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                Text { text: appModel.strings.month_trend; color: root.textColor; font.pixelSize: 12; font.weight: Font.DemiBold }
                                Item { Layout.fillWidth: true }
                                Text { text: appModel.trendPeak; color: root.mutedColor; font.pixelSize: 10 }
                            }
                            RowLayout {
                                visible: appModel.trendMonthLabel !== ""
                                Layout.fillWidth: true
                                Layout.preferredHeight: 17
                                Text {
                                    Layout.fillWidth: true
                                    text: appModel.trendLoading ? appModel.strings.trend_loading
                                        : (root.trendHoveredIndex >= 0 && root.trendHoveredIndex < appModel.monthTrend.length
                                            ? appModel.monthTrend[root.trendHoveredIndex].caption : appModel.trendCaption)
                                    color: root.mutedColor
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                            Item {
                                visible: appModel.trendMonthLabel !== ""
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 15
                                    height: 1
                                    color: root.borderColor
                                }
                                Row {
                                    id: trendBars
                                    anchors.fill: parent
                                    spacing: 2
                                    Repeater {
                                        model: appModel.monthTrend
                                        delegate: Item {
                                            required property var modelData
                                            required property int index
                                            property bool hoveredDay: root.trendHoveredIndex === index
                                            width: Math.max(2, (trendBars.width - Math.max(0, appModel.monthTrend.length - 1) * trendBars.spacing) / Math.max(1, appModel.monthTrend.length))
                                            height: trendBars.height
                                            Rectangle {
                                                objectName: "trendDayBar"
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 16
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: Math.max(2, parent.width - 2)
                                                height: modelData.barHeight
                                                radius: 2
                                                color: parent.hoveredDay ? root.trendHoverColor
                                                    : (modelData.today ? root.accentColor
                                                        : (root.darkMode ? "#71839f" : "#8193af"))
                                                opacity: modelData.empty && !parent.hoveredDay ? 0.25 : 0.95
                                            }
                                            Rectangle {
                                                visible: modelData.weekend
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 11
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 1.5; height: 3
                                                color: root.mutedColor
                                            }
                                            Text {
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.label
                                                color: root.mutedColor
                                                font.pixelSize: 8
                                            }
                                            HoverHandler {
                                                onHoveredChanged: root.trendHoveredIndex = hovered ? index : -1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Panel {
                        id: providersPanel
                        objectName: "providersPanel"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16 + providersTitle.implicitHeight + 4 + Math.min(82, Math.max(26, appModel.providers.length * 28 - 2))
                        Layout.minimumHeight: Layout.preferredHeight
                        Layout.maximumHeight: Layout.preferredHeight
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4
                            Text { id: providersTitle; text: appModel.strings.providers; color: root.textColor; font.pixelSize: 13; font.weight: Font.DemiBold }
                            ListView {
                                id: providersList
                                objectName: "providersList"
                                MiddleAutoScroll {
                                    objectName: "providersListAutoScroll"
                                    parent: providersList
                                    anchors.fill: parent
                                    flickable: providersList
                                }
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: contentHeight > height
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 2
                                model: appModel.providers
                                ScrollBar.vertical: ScrollBar { policy: providersList.contentHeight > providersList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
                                delegate: Rectangle {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: 26
                                    radius: 6
                                    color: root.panelAltColor
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        Text { text: modelData.name; color: modelData.error ? root.dangerColor : root.textColor; font.pixelSize: 11; font.weight: Font.Medium; Layout.preferredWidth: 74; elide: Text.ElideRight }
                                        Text { text: modelData.today + " " + appModel.strings.today_short; color: root.textColor; font.pixelSize: 10 }
                                        Text { text: modelData.week + " " + appModel.strings.week_short; color: root.mutedColor; font.pixelSize: 10 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: modelData.cost; color: root.textColor; font.pixelSize: 10; font.weight: Font.Medium }
                                    }
                                }
                            }
                            Text { visible: appModel.providers.length === 0; text: appModel.strings.no_provider_data; color: root.mutedColor; font.pixelSize: 11 }
                        }
                    }

                    Panel {
                        id: limitsPanel
                        objectName: "limitsPanel"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 90
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 5
                            Text { text: appModel.strings.official_limits; color: root.textColor; font.pixelSize: 13; font.weight: Font.DemiBold }
                            ListView {
                                id: limitsContent
                                objectName: "limitsContent"
                                MiddleAutoScroll {
                                    objectName: "limitsContentAutoScroll"
                                    parent: limitsContent
                                    anchors.fill: parent
                                    flickable: limitsContent
                                }
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 5
                                model: appModel.limits
                                ScrollBar.vertical: ScrollBar { policy: limitsContent.contentHeight > limitsContent.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
                                delegate: Rectangle {
                                    required property var modelData
                                    width: ListView.view.width
                                    height: modelData.kind === "window" ? (modelData.forecast.length > 0 ? 61 : 49) : 38
                                    radius: 7
                                    color: modelData.kind === "credit"
                                        ? (modelData.urgency === "critical" ? (root.darkMode ? "#4a2328" : "#fff0f1") : (modelData.urgency === "warning" ? (root.darkMode ? "#48381f" : "#fff7e7") : root.accentSurface))
                                        : root.panelAltColor
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 7
                                        spacing: 2
                                        RowLayout {
                                            Layout.fillWidth: true
                                            WarningIcon {
                                                objectName: "resetCreditWarningIcon"
                                                visible: modelData.kind === "credit" && modelData.urgency !== "neutral"
                                                markColor: modelData.urgency === "critical" ? root.dangerColor : root.warningColor
                                                Layout.preferredWidth: 16
                                                Layout.preferredHeight: 16
                                            }
                                            Text {
                                                text: modelData.kind === "credit"
                                                    ? modelData.provider + " · " + modelData.label
                                                    : modelData.provider + (modelData.plan.length ? " · " + modelData.plan : "") + " · " + modelData.label
                                                color: modelData.urgency === "critical" ? root.dangerColor : (modelData.urgency === "warning" ? root.warningColor : root.textColor)
                                                font.pixelSize: 11
                                                font.weight: modelData.kind === "credit" ? Font.DemiBold : Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text { visible: modelData.kind !== "credit"; text: modelData.percentText; color: root.textColor; font.pixelSize: 11; font.weight: Font.DemiBold }
                                        }
                                        RowLayout {
                                            visible: modelData.kind === "window"
                                            Layout.fillWidth: true
                                            Text { text: modelData.reset; color: root.mutedColor; font.pixelSize: 10; Layout.fillWidth: true }
                                            Text { visible: modelData.forecast.length > 0; text: appModel.strings.forecast + ": " + modelData.forecast; color: root.mutedColor; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 230 }
                                        }
                                        ModernProgress {
                                            visible: modelData.kind === "window"
                                            Layout.fillWidth: true
                                            value: modelData.percent
                                            barColor: modelData.urgency === "critical" ? root.dangerColor : (modelData.urgency === "warning" ? root.warningColor : root.accentColor)
                                        }
                                    }
                                }
                            }
                            Text { visible: appModel.limits.length === 0; text: appModel.strings.no_limit_data; color: root.mutedColor; font.pixelSize: 11 }
                        }
                    }
                }
            }


            PageScroll {
                id: collectionPage
                objectName: "collectionPage"
                clip: true
                onAvailableHeightChanged: Qt.callLater(root.syncDexViewport)
                onAvailableWidthChanged: Qt.callLater(root.syncDexViewport)
                contentWidth: availableWidth
                ColumnLayout {
                    id: collectionContent
                    width: collectionPage.availableWidth
                    spacing: 10
                    Item { Layout.preferredHeight: 4 }
                    ColumnLayout {
                        id: collectionToolbar
                        objectName: "collectionToolbar"
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        spacing: 5
                        RowLayout {
                            objectName: "collectionModeControl"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            spacing: 14
                            Repeater {
                                model: [
                                    {label: appModel.strings.pokedex, value: "dex"},
                                    {label: appModel.strings.catch_log, value: "catches"}
                                ]
                                Button {
                                    id: collectionTab
                                    required property var modelData
                                    checkable: true
                                    checked: root.collectionMode === modelData.value
                                    activeFocusOnTab: true
                                    implicitHeight: 34
                                    leftPadding: 4
                                    rightPadding: 4
                                    Accessible.name: appModel.strings.collection_view + ": " + modelData.label
                                    Accessible.role: Accessible.PageTab
                                    onClicked: root.collectionMode = modelData.value
                                    contentItem: Text {
                                        text: collectionTab.modelData.label
                                        color: collectionTab.checked ? root.textColor : root.mutedColor
                                        font.pixelSize: 12
                                        font.weight: collectionTab.checked ? Font.DemiBold : Font.Normal
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Item {
                                        Rectangle {
                                            visible: collectionTab.checked
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 3
                                            radius: 2
                                            color: root.accentColor
                                        }
                                        Rectangle {
                                            visible: collectionTab.visualFocus
                                            anchors.fill: parent
                                            radius: 6
                                            color: "transparent"
                                            border.color: root.accentColor
                                            border.width: 2
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        RowLayout {
                            objectName: "dexFilterRow"
                            visible: root.collectionMode === "dex" && root.selectedDexIndex < 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(28, rarityFilterFlow.childrenRect.height)
                            spacing: 5
                            Flow {
                                id: rarityFilterFlow
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.max(28, childrenRect.height)
                                spacing: 4
                                Repeater {
                                    model: appModel.dexFilters
                                    FilterChip {
                                        required property var modelData
                                        filterKey: modelData.key
                                        label: modelData.label
                                        itemCount: modelData.count
                                    }
                                }
                            }
                            ShinyFilterChip { }
                        }
                    }
                    GridLayout {
                        id: dexGrid
                        objectName: "dexGrid"
                        visible: root.collectionMode === "dex" && root.selectedDexIndex < 0
                        onWidthChanged: Qt.callLater(root.syncDexViewport)
                        onYChanged: Qt.callLater(root.syncDexViewport)
                        onColumnsChanged: Qt.callLater(root.syncDexViewport)
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        columns: width >= 720 ? 4 : (width >= 470 ? 3 : 2)
                        columnSpacing: 7
                        rowSpacing: 7
                        Repeater {
                            model: appModel.dexEntries
                            Panel {
                                id: dexCard
                                objectName: "dexCard"
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 174
                                border.color: modelData.representative
                                    ? root.successColor
                                    : (dexCardButton.hovered ? root.accentColor : root.borderColor)
                                border.width: modelData.representative || dexCardButton.hovered ? 2 : 1
                                Button {
                                    id: dexCardButton
                                    anchors.fill: parent
                                    activeFocusOnTab: true
                                    Accessible.name: root.format(appModel.strings.dex_open, {name: modelData.name})
                                    Accessible.description: modelData.representative
                                        ? (modelData.followingCurrent ? appModel.strings.following_current : appModel.strings.representative_selected)
                                        : ""
                                    Accessible.role: Accessible.Button
                                    onClicked: root.openDex(modelData.speciesId)
                                    background: Item { }
                                    contentItem: Item { }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    FocusFrame { }
                                }
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 2
                                    Image { source: modelData.sprite; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 108; Layout.preferredHeight: 108; fillMode: Image.PreserveAspectFit; smooth: false }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        spacing: 4
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text { text: modelData.number; color: root.mutedColor; font.pixelSize: 10 }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.name
                                                color: root.textColor
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }
                                        }
                                        ShinyVariantToggle {
                                            visible: modelData.hasShiny
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 40
                                            speciesId: modelData.speciesId
                                            speciesName: modelData.name
                                            hasNormal: modelData.hasNormal
                                            showShiny: modelData.showShiny
                                        }
                                    }
                                }
                                RepresentativeCheck {
                                    objectName: "representativeBadge"
                                    visible: modelData.representative
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 8
                                    z: 4
                                    label: modelData.followingCurrent
                                        ? appModel.strings.following_current
                                        : appModel.strings.representative_selected
                                }
                            }
                        }
                    }
                    Text { visible: root.collectionMode === "dex" && root.selectedDexIndex < 0 && appModel.dexEntries.length === 0; Layout.leftMargin: 14; text: appModel.strings.empty_pokedex; color: root.mutedColor; font.pixelSize: 12 }
                    RowLayout {
                        id: dexPagination
                        objectName: "dexPagination"
                        visible: root.collectionMode === "dex" && root.selectedDexIndex < 0
                        onHeightChanged: Qt.callLater(root.syncDexViewport)
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        AppButton {
                            objectName: "dexPreviousPage"
                            text: appModel.strings.previous
                            enabled: appModel.dexPage > 1
                            onClicked: root.navigateDex(-1)
                        }
                        Text {
                            objectName: "dexPagePosition"
                            Layout.fillWidth: true
                            text: root.format(appModel.strings.page, {page: appModel.dexPage, count: appModel.dexPageCount})
                            color: root.mutedColor
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        AppButton {
                            objectName: "dexNextPage"
                            text: appModel.strings.next
                            enabled: appModel.dexPage < appModel.dexPageCount
                            onClicked: root.navigateDex(1)
                        }
                    }
                    Panel {
                        objectName: "dexDetailPanel"
                        visible: root.collectionMode === "dex" && root.selectedDexIndex >= 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.preferredHeight: appModel.representativeFollowsCurrent ? 388 : 426
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                AppButton {
                                    text: appModel.strings.dex_back
                                    onClicked: root.closeDex()
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.format(appModel.strings.dex_position, {
                                        position: root.selectedDexIndex + 1,
                                        count: appModel.dexBrowseEntries.length
                                    })
                                    color: root.mutedColor
                                    font.pixelSize: 13
                                }
                            }
                            AnimatedImage {
                                objectName: "dexDetailAnimation"
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                Layout.preferredHeight: 216
                                source: root.selectedDex.animatedSprite || root.selectedDex.sprite || ""
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                playing: visible && root.currentPage === 1
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: (root.selectedDex.name || "") + "  " +
                                          (root.selectedDex.number || "")
                                    color: root.textColor
                                    font.pixelSize: 19
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }
                                ShinyVariantToggle {
                                    visible: !!root.selectedDex.hasShiny
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    speciesId: root.selectedDex.speciesId || 0
                                    speciesName: root.selectedDex.name || ""
                                    hasNormal: !!root.selectedDex.hasNormal
                                    showShiny: !!root.selectedDex.showShiny
                                }
                            }
                            Text {
                                text: appModel.strings[root.selectedDex.rarity] || ""
                                color: root.mutedColor
                                font.pixelSize: 13
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                AppButton {
                                    objectName: "dexRepresentativeButton"
                                    Layout.fillWidth: true
                                    highlighted: !!root.selectedDex.representative
                                    text: root.selectedDex.representative
                                        ? (root.selectedDex.followingCurrent
                                            ? appModel.strings.following_current
                                            : appModel.strings.representative_selected)
                                        : appModel.strings.set_representative
                                    accessibleName: text
                                    onClicked: {
                                        if (!root.selectedDex.representative)
                                            appModel.chooseDexRepresentative(
                                                root.selectedDex.speciesId,
                                                !!root.selectedDex.showShiny
                                            )
                                    }
                                }
                                AppButton {
                                    objectName: "followCurrentRepresentativeButton"
                                    visible: !appModel.representativeFollowsCurrent
                                    Layout.fillWidth: true
                                    text: appModel.strings.follow_companion
                                    onClicked: appModel.followCurrentRepresentative()
                                }
                            }
                        }
                    }
                    RowLayout {
                        objectName: "dexDetailNavigation"
                        visible: root.collectionMode === "dex" && root.selectedDexIndex >= 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        AppButton {
                            text: appModel.strings.previous
                            enabled: root.selectedDexIndex > 0
                            onClicked: root.navigateDex(-1)
                        }
                        Item { Layout.fillWidth: true }
                        AppButton {
                            text: appModel.strings.next
                            enabled: root.selectedDexIndex < appModel.dexBrowseEntries.length - 1
                            onClicked: root.navigateDex(1)
                        }
                    }
                    Text { visible: root.collectionMode === "catches" && appModel.catches.length === 0; Layout.leftMargin: 14; text: appModel.strings.empty_catches; color: root.mutedColor; font.pixelSize: 12 }
                    Repeater {
                        model: root.collectionMode === "catches" ? appModel.catches : []
                        Panel {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.preferredHeight: 230
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 5
                                Item {
                                    objectName: "catchHeader"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    Column {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        spacing: 2
                                        Text { text: (modelData.shiny ? "✨ " : "") + modelData.name + "  " + modelData.number; color: root.textColor; font.pixelSize: 14; font.weight: Font.Medium }
                                        Text { text: modelData.meta; color: root.mutedColor; font.pixelSize: 10 }
                                    }
                                    Text {
                                        objectName: "catchStatusBadge"
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        visible: modelData.statusLabel !== ""
                                        text: modelData.statusLabel
                                        color: modelData.current ? root.accentColor : root.mutedColor
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }
                                Text {
                                    text: modelData.description
                                    color: root.mutedColor
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Repeater {
                                        model: modelData.stages
                                        RowLayout {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Text { objectName: "evolutionArrow"; visible: index > 0; text: "→"; color: root.accentColor; font.pixelSize: 18; font.weight: Font.Bold }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1
                                                Image { source: modelData.sprite; opacity: modelData.owned ? 1 : 0.3; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 104; Layout.preferredHeight: 104; fillMode: Image.PreserveAspectFit; smooth: false }
                                                Text { text: modelData.name; color: modelData.owned ? root.textColor : root.mutedColor; font.pixelSize: 11; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                                Text { text: modelData.status; color: modelData.current ? root.accentColor : root.mutedColor; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        visible: root.collectionMode !== "dex" || root.selectedDexIndex >= 0
                        Layout.preferredHeight: 10
                    }
                }
            }

            PageScroll {
                id: bagPage
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: bagPage.availableWidth
                    spacing: 10
                    Item { Layout.preferredHeight: 4 }
                    GridLayout {
                        id: bagGrid
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        columns: width > 740 ? 2 : 1
                        columnSpacing: 8
                        rowSpacing: 8
                        BagItemCard {
                            objectName: "rareCandyBagCard"
                            visible: appModel.rareCandyCount > 0
                            itemKind: "rare_candy"
                            itemName: appModel.strings.rare_candy
                            icon: "🍬"
                            count: appModel.rareCandyCount
                            description: root.format(appModel.strings.bag_candy_description, {amount: appModel.rareCandyXp})
                            effectHint: root.format(appModel.strings.bag_candy_effect, {amount: appModel.rareCandyXp})
                            unavailableReason: appModel.strings.bag_use_after_hatch
                            canUse: appModel.hasActiveCompanion
                        }
                        BagItemCard {
                            objectName: "mintBagCard"
                            visible: appModel.mintCount > 0
                            itemKind: "mint"
                            itemName: appModel.strings.mint
                            icon: "🌿"
                            count: appModel.mintCount
                            description: appModel.strings.bag_mint_description
                            effectHint: appModel.strings.bag_mint_effect
                            unavailableReason: appModel.strings.bag_use_after_hatch
                            canUse: appModel.hasActiveCompanion
                        }
                        BagItemCard {
                            objectName: "shinyCharmBagCard"
                            visible: appModel.shinyCharmActive
                            Layout.columnSpan: bagGrid.columns
                            itemKind: "shiny_charm"
                            itemName: appModel.strings.shiny_charm
                            icon: "✨"
                            description: appModel.strings.bag_charm_description
                            effectHint: appModel.strings.bag_charm_effect
                            passive: true
                        }
                    }
                    Panel {
                        visible: appModel.rareCandyCount === 0 && appModel.mintCount === 0 && !appModel.shinyCharmActive
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.preferredHeight: 130
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 28
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: appModel.strings.bag_empty
                            color: root.mutedColor
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            PageScroll {
                id: shopPage
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: shopPage.availableWidth
                    spacing: 10
                    Item { Layout.preferredHeight: 4 }
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        columns: width > 720 ? 3 : (width > 470 ? 2 : 1)
                        columnSpacing: 8
                        rowSpacing: 8
                        Repeater {
                            model: appModel.shopItems
                            Panel {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: modelData.disabledReason.length ? 192 : 172
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 4
                                    Item {
                                        Layout.preferredWidth: 46
                                        Layout.preferredHeight: 46
                                        Text {
                                            visible: modelData.kind !== "egg"
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.pixelSize: 30
                                        }
                                        EggIcon {
                                            objectName: "shopEggIcon-" + modelData.key
                                            visible: modelData.kind === "egg"
                                            anchors.centerIn: parent
                                            width: 42
                                            height: 42
                                            tier: modelData.eggTier
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text { text: modelData.title; color: root.textColor; font.pixelSize: 15; font.weight: Font.Medium; Layout.fillWidth: true }
                                        Rectangle {
                                            visible: modelData.kind === "egg" && modelData.key !== "normal"
                                            implicitHeight: 18
                                            implicitWidth: eggRarityLabel.implicitWidth + 12
                                            radius: 9
                                            color: modelData.key === "rare" ? "#7b4bc4" : "#2f7fca"
                                            Text {
                                                id: eggRarityLabel
                                                anchors.centerIn: parent
                                                text: (appModel.strings[modelData.key] || "").toUpperCase()
                                                color: "#ffffff"
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                    Text { text: modelData.subtitle; color: root.mutedColor; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Text { visible: modelData.disabledReason.length > 0; text: modelData.disabledReason; color: root.mutedColor; font.pixelSize: 10; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Item { Layout.fillHeight: true }
                                    AppButton {
                                        Layout.fillWidth: true
                                        text: modelData.owned ? appModel.strings.already_active : modelData.price + " " + appModel.strings.tokens
                                        accessibleName: root.format(appModel.strings.buy, {title: modelData.title, price: text})
                                        highlighted: modelData.enabled
                                        enabled: modelData.enabled
                                        onClicked: purchasePopup.confirm(modelData)
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.preferredHeight: 10 }
                }
            }


            PageScroll {
                id: settingsPage
                objectName: "settingsPage"
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: settingsPage.availableWidth
                    spacing: 9
                    Item { Layout.preferredHeight: 4 }
                    GridLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        columns: width > 760 ? 2 : 1
                        columnSpacing: 8
                        rowSpacing: 8

                        Panel {
                            objectName: "generalSettingsPanel"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 182
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 8
                                Text { text: appModel.strings.general; color: root.textColor; font.pixelSize: 15; font.weight: Font.Medium }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.refresh_interval; helpText: appModel.strings.refresh_help; Layout.fillWidth: true }
                                    StyledComboBox {
                                        objectName: "refreshIntervalCombo"
                                        model: [1, 2, 5, 10, 15]
                                        activeFocusOnTab: true
                                        Accessible.name: appModel.strings.refresh_interval
                                        FocusFrame { }
                                        currentIndex: Math.max(0, model.indexOf(appModel.refreshMinutes))
                                        delegate: ItemDelegate {
                                            required property var modelData
                                            width: parent ? parent.width : 100
                                            contentItem: Text {
                                                text: root.format(appModel.strings.minutes, {count: modelData})
                                                color: root.textColor
                                                font.pixelSize: 12
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            background: Rectangle {
                                                color: parent.hovered || parent.highlighted ? root.accentSurface : root.panelColor
                                            }
                                        }
                                        contentItem: Text { text: root.format(appModel.strings.minutes, {count: parent.currentText}); color: root.textColor; verticalAlignment: Text.AlignVCenter; leftPadding: 8 }
                                        onActivated: appModel.setRefreshMinutes(model[currentIndex])
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel {
                                        text: appModel.strings.language
                                        helpText: appModel.strings.language_help
                                        Layout.fillWidth: true
                                    }
                                    StyledComboBox {
                                        id: languageCombo
                                        objectName: "languageCombo"
                                        activeFocusOnTab: true
                                        Accessible.name: appModel.strings.language
                                        FocusFrame { }
                                        model: appModel.languageOptions
                                        textRole: "label"
                                        currentIndex: ["en", "es", "gl"].indexOf(appModel.language)
                                        onActivated: appModel.setLanguage(model[currentIndex].key)
                                    }
                                }
                                ToggleRow { label: appModel.strings.start_windows; detail: appModel.strings.start_windows_help; checked: appModel.autostart; onChanged: value => appModel.setAutostart(value) }
                            }
                        }

                        Panel {
                            objectName: "desktopPetPanel"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 258
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 7
                                Text { text: appModel.strings.desktop_pet; color: root.textColor; font.pixelSize: 15; font.weight: Font.Medium }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    InfoLabel { text: appModel.strings.desktop_representative; helpText: appModel.strings.representative_help }
                                    StyledComboBox {
                                        id: representativeCombo
                                        objectName: "representativeCombo"
                                        Layout.fillWidth: true
                                        activeFocusOnTab: true
                                        Accessible.name: appModel.strings.desktop_representative
                                        Accessible.description: appModel.strings.representative_help
                                        AppToolTip {
                                            requestedVisible: hovered || visualFocus
                                            text: appModel.strings.representative_help
                                        }
                                        FocusFrame { }
                                        model: appModel.collection
                                        textRole: "display"
                                        currentIndex: {
                                            for (let i = 0; i < model.length; ++i)
                                                if (model[i].selected) return i
                                            return 0
                                        }
                                        onActivated: appModel.chooseRepresentative(currentIndex)
                                    }
                                }
                                ToggleRow { label: appModel.strings.show_floating; detail: appModel.strings.show_floating_help; checked: appModel.petEnabled; onChanged: value => appModel.setPetEnabled(value) }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.size; helpText: appModel.strings.pet_size_help }
                                    Slider { objectName: "petSizeSlider"; Layout.fillWidth: true; from: 48; to: 192; stepSize: 8; value: appModel.petSize; enabled: appModel.petEnabled; activeFocusOnTab: true; Accessible.name: appModel.strings.pet_size; onMoved: appModel.setPetSize(value); FocusFrame { } }
                                    Text { text: appModel.petSize + " px"; color: root.mutedColor; font.pixelSize: 11 }
                                }
                                ToggleRow { label: appModel.strings.usage_bubbles; detail: appModel.strings.usage_bubbles_help; checked: appModel.petAlerts; onChanged: value => appModel.setPreference("petAlerts", value) }
                            }
                        }


                        Panel {
                            objectName: "limitsSettingsPanel"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 285
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 7
                                Text { text: appModel.strings.limits_section; color: root.textColor; font.pixelSize: 15; font.weight: Font.Medium }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.show_quota; helpText: appModel.strings.quota_help; Layout.fillWidth: true }
                                    SegmentedControl {
                                        objectName: "limitDisplayControl"
                                        options: [{label: appModel.strings.used, value: "used"}, {label: appModel.strings.remaining, value: "remaining"}]
                                        currentValue: appModel.limitDisplayMode
                                        accessibleName: appModel.strings.quota_percentage
                                        onSelected: value => appModel.setPreference("limitDisplayMode", value)
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.reset_format; helpText: appModel.strings.reset_format_help; Layout.fillWidth: true }
                                    SegmentedControl {
                                        objectName: "limitTimeControl"
                                        options: [{label: appModel.strings.time, value: "remaining"}, {label: appModel.strings.date, value: "datetime"}]
                                        currentValue: appModel.limitTimeMode
                                        accessibleName: appModel.strings.reset_format
                                        onSelected: value => appModel.setPreference("limitTimeMode", value)
                                    }
                                }
                                ToggleRow { label: appModel.strings.forecast_timed; detail: appModel.strings.forecast_help; checked: appModel.forecastEnabled; onChanged: value => appModel.setPreference("forecastEnabled", value) }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.warning; helpText: appModel.strings.warning_help; Layout.fillWidth: true }
                                    StyledSpinBox { objectName: "warningThresholdSpin"; from: 50; to: 95; stepSize: 5; value: appModel.warningThreshold; editable: false; activeFocusOnTab: true; Accessible.name: appModel.strings.warning_threshold; textFromValue: value => value + "%"; valueFromText: text => parseInt(text); onValueModified: appModel.setPreference("warningThreshold", value); contentItem.activeFocusOnTab: false; FocusFrame { } }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.critical; helpText: appModel.strings.critical_help; Layout.fillWidth: true }
                                    StyledSpinBox { objectName: "criticalThresholdSpin"; from: 80; to: 100; stepSize: 5; value: appModel.criticalThreshold; editable: false; activeFocusOnTab: true; Accessible.name: appModel.strings.critical_threshold; textFromValue: value => value + "%"; valueFromText: text => parseInt(text); onValueModified: appModel.setPreference("criticalThreshold", value); contentItem.activeFocusOnTab: false; FocusFrame { } }
                                }
                            }
                        }

                        Panel {
                            objectName: "notificationSettingsPanel"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 245
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 7
                                Text { text: appModel.strings.notifications_section; color: root.textColor; font.pixelSize: 15; font.weight: Font.Medium }
                                ToggleRow { label: appModel.strings.limit_notifications; detail: appModel.strings.limit_notifications_help; checked: appModel.limitNotifications; onChanged: value => appModel.setPreference("limitNotifications", value) }
                                ToggleRow { label: appModel.strings.limit_reset_notifications; detail: appModel.strings.limit_reset_notifications_help; checked: appModel.limitResetNotifications; onChanged: value => appModel.setPreference("limitResetNotifications", value) }
                                ToggleRow { label: appModel.strings.banked_reset_notifications; detail: appModel.strings.banked_reset_notifications_help; checked: appModel.bankedResetNotifications; onChanged: value => appModel.setPreference("bankedResetNotifications", value) }
                                ToggleRow { label: appModel.strings.pokemon_notifications; detail: appModel.strings.pokemon_notifications_help; checked: appModel.companionNotifications; onChanged: value => appModel.setPreference("companionNotifications", value) }
                            }
                        }

                        Panel {
                            objectName: "appearanceSettingsPanel"
                            Layout.fillWidth: true
                            Layout.preferredHeight: appearanceContent.implicitHeight + 24
                            ColumnLayout {
                                id: appearanceContent
                                anchors.fill: parent; anchors.margins: 12; spacing: 7
                                Text { text: appModel.strings.appearance_data; color: root.textColor; font.pixelSize: 15; font.weight: Font.Medium }
                                RowLayout {
                                    Layout.fillWidth: true
                                    InfoLabel { text: appModel.strings.theme; helpText: appModel.strings.theme_help; Layout.fillWidth: true }
                                    StyledComboBox {
                                        objectName: "themeCombo"
                                        activeFocusOnTab: true
                                        Accessible.name: appModel.strings.interface_theme
                                        FocusFrame { }
                                        model: [appModel.strings.theme_system, appModel.strings.theme_light, appModel.strings.theme_dark]
                                        currentIndex: appModel.theme === "light" ? 1 : (appModel.theme === "dark" ? 2 : 0)
                                        onActivated: appModel.setPreference("theme", ["system", "light", "dark"][currentIndex])
                                    }
                                }
                                ToggleRow { label: appModel.strings.tray_today; detail: appModel.strings.tray_today_help; checked: appModel.trayShowTokens; onChanged: value => appModel.setPreference("trayShowTokens", value) }
                                ToggleRow { label: appModel.strings.tray_cost; detail: appModel.strings.tray_cost_help; checked: appModel.trayShowCost; onChanged: value => appModel.setPreference("trayShowCost", value) }
                                ToggleRow { objectName: "trayLimitToggle"; label: appModel.strings.tray_limit; detail: appModel.strings.tray_limit_help; checked: appModel.trayShowLimit; onChanged: value => appModel.setPreference("trayShowLimit", value) }
                                RowLayout {
                                    Layout.fillWidth: true
                                    AppButton {
                                        objectName: "exportBackupButton"
                                        text: appModel.strings.export_backup
                                        AppToolTip { requestedVisible: parent.hovered; text: appModel.strings.backup_help }
                                        onClicked: appModel.requestExport()
                                    }
                                    AppButton {
                                        objectName: "importBackupButton"
                                        text: appModel.strings.import_backup
                                        AppToolTip { requestedVisible: parent.hovered; text: appModel.strings.backup_help }
                                        onClicked: appModel.requestImport()
                                    }
                                }
                            }
                        }
                    }
                    Panel {
                        id: aboutSettingsPanel
                        objectName: "aboutSettingsPanel"
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.preferredHeight: aboutContent.implicitHeight + 24
                        ColumnLayout {
                            id: aboutContent
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            Text {
                                text: appModel.strings.about_title
                                color: root.textColor
                                font.pixelSize: 15
                                font.weight: Font.Medium
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 5
                                    Text {
                                        objectName: "aboutBuildVersion"
                                        Layout.fillWidth: true
                                        text: appModel.strings.about_version + " " + appModel.buildVersion
                                        color: root.mutedColor
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    }
                                    Text {
                                        objectName: "aboutUpdateStatus"
                                        Layout.fillWidth: true
                                        text: {
                                            switch (appModel.updateStatus) {
                                            case "checking": return appModel.strings.update_checking
                                            case "available": return root.format(appModel.strings.update_available, {version: appModel.latestVersion})
                                            case "current": return root.format(appModel.strings.update_current, {version: appModel.latestVersion})
                                            case "no_release": return appModel.strings.update_no_release
                                            case "offline": return appModel.strings.update_offline
                                            case "invalid": return appModel.strings.update_invalid
                                            default: return appModel.strings.update_idle
                                            }
                                        }
                                        color: appModel.updateStatus === "available" ? root.warningColor : root.mutedColor
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    spacing: 6
                                    AppButton {
                                        objectName: "checkUpdatesButton"
                                        Layout.alignment: Qt.AlignRight
                                        text: appModel.strings.update_check
                                        enabled: appModel.updateStatus !== "checking"
                                        onClicked: appModel.checkUpdates()
                                    }
                                    AppButton {
                                        objectName: "viewReleaseButton"
                                        Layout.alignment: Qt.AlignRight
                                        text: appModel.strings.update_view_release
                                        visible: appModel.updateStatus === "available"
                                        highlighted: true
                                        onClicked: appModel.openRelease()
                                    }
                                }
                            }
                        }
                    }
                    Item { Layout.preferredHeight: 10 }
                }
            }
        }
        Rectangle {
            id: shellFooter
            objectName: "shellFooter"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: root.panelColor
            border.color: root.borderColor
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 7
                Rectangle {
                    objectName: "dataStatusDot"
                    width: 7
                    height: 7
                    radius: 4
                    color: appModel.dataStatus === "error" ? root.dangerColor
                        : (appModel.dataStatus === "warning" || appModel.dataStatus === "loading")
                            ? root.warningColor : root.successColor
                }
                Text {
                    objectName: "footerDataStatus"
                    text: appModel.strings.data_status + ": " + appModel.statusText
                    color: root.mutedColor
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Accessible.name: text
                }
                Button {
                    id: footerUpdateLink
                    objectName: "footerUpdateLink"
                    visible: appModel.updateStatus === "available"
                    text: root.format(appModel.strings.update_footer, {version: appModel.latestVersion})
                    implicitHeight: 24
                    leftPadding: 5
                    rightPadding: 5
                    activeFocusOnTab: true
                    Accessible.name: root.format(appModel.strings.update_available, {version: appModel.latestVersion})
                    Accessible.role: Accessible.Button
                    onClicked: appModel.openRelease()
                    FocusFrame { }
                    contentItem: Text {
                        text: footerUpdateLink.text
                        color: root.accentColor
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 4
                        color: footerUpdateLink.hovered ? root.accentSurface : "transparent"
                    }
                }
                Text {
                    objectName: "footerVersion"
                    text: appModel.versionShort
                    color: root.mutedColor
                    font.pixelSize: 10
                }
            }
        }
    }

    ResizeHandle { objectName: "leftResizeHandle"; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 8; resizeEdges: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor }
    ResizeHandle { objectName: "rightResizeHandle"; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 8; resizeEdges: Qt.RightEdge; cursorShape: Qt.SizeHorCursor }
    ResizeHandle { objectName: "topResizeHandle"; anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 8; resizeEdges: Qt.TopEdge; cursorShape: Qt.SizeVerCursor }
    ResizeHandle { objectName: "bottomResizeHandle"; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 8; resizeEdges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor }
    ResizeHandle { objectName: "topLeftResizeHandle"; anchors.left: parent.left; anchors.top: parent.top; width: 12; height: 12; resizeEdges: Qt.TopEdge | Qt.LeftEdge; cursorShape: Qt.SizeFDiagCursor }
    ResizeHandle { objectName: "topRightResizeHandle"; anchors.right: parent.right; anchors.top: parent.top; width: 12; height: 12; resizeEdges: Qt.TopEdge | Qt.RightEdge; cursorShape: Qt.SizeBDiagCursor }
    ResizeHandle { objectName: "bottomLeftResizeHandle"; anchors.left: parent.left; anchors.bottom: parent.bottom; width: 12; height: 12; resizeEdges: Qt.BottomEdge | Qt.LeftEdge; cursorShape: Qt.SizeBDiagCursor }
    ResizeHandle { objectName: "bottomRightResizeHandle"; anchors.right: parent.right; anchors.bottom: parent.bottom; width: 12; height: 12; resizeEdges: Qt.BottomEdge | Qt.RightEdge; cursorShape: Qt.SizeFDiagCursor }

    Rectangle {
        visible: appModel.feedbackText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: Math.min(parent.width - 30, feedbackText.implicitWidth + 30)
        height: 38
        radius: 9
        color: root.darkMode ? "#dce7ff" : "#21365e"
        z: 30
        Text { id: feedbackText; anchors.centerIn: parent; text: appModel.feedbackText; color: root.darkMode ? "#17233c" : "#ffffff"; font.pixelSize: 12 }
    }

    Rectangle {
        visible: appModel.toastText.length > 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10
        width: Math.min(parent.width - 30, toastText.implicitWidth + 40)
        height: 42
        radius: 10
        color: appModel.toastShiny ? (root.darkMode ? "#4b3e17" : "#fff2bd") : root.panelColor
        border.color: appModel.toastShiny ? root.warningColor : root.borderColor
        z: 40
        Text { id: toastText; anchors.centerIn: parent; text: (appModel.toastShiny ? "✨  " : "") + appModel.toastText; color: root.textColor; font.pixelSize: 13; font.weight: Font.Medium }
    }
}
