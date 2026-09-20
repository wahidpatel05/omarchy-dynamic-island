import QtQuick
import Quickshell
import qs.Commons

// A notification, as the island renders it.
//
// The card owns all of its own padding and reports its natural size; the
// island simply springs to whatever that is. Nothing here animates the
// container — the only motion this file is responsible for is the swap when
// one notification replaces another while the island is already open.
//
// That swap matters. Collapsing and re-expanding between two messages reads as
// a glitch, so instead the container holds its ground and the *content*
// cross-slides: the outgoing message lifts and fades, the incoming one rises
// into its place. The island resizes underneath, smoothly, because its height
// is bound to whatever the card currently measures.
Item {
    id: root

    property var activity: null
    property var options: ({})
    property color foreground: "white"
    property color accent: "white"
    property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

    // Not `data`: that name is taken by Item's default children property.
    readonly property var payload: activity ? activity.data : null

    // What is actually on screen. Lags `payload` by exactly one swap animation.
    property var shown: null

    readonly property int pad: Style.space(15)
    readonly property int iconSize: Style.space(34)
    readonly property int gap: Style.space(12)
    readonly property int maxTextWidth: Style.space(options.maxTextWidth || 290)
    readonly property int maxBodyLines: options.maxBodyLines === undefined ? 2 : options.maxBodyLines

    implicitWidth: pad * 2 + iconSize + gap + textColumn.width
    implicitHeight: Math.max(iconSize, textColumn.implicitHeight) + pad * 2

    function iconSource(icon) {
        var value = String(icon || "");
        if (value.length === 0)
            return "";
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0)
            return value;
        if (value.charAt(0) === "/")
            return Qt.resolvedUrl("file://" + value);
        return Quickshell.iconPath(value, true);
    }

    // Notification bodies may carry the freedesktop markup subset. Images are
    // stripped rather than rendered: an <img> in a one-line island card can
    // only wreck the layout.
    function sanitize(text) {
        return String(text || "").replace(/<img[^>]*>/gi, "").replace(/\s+/g, " ").trim();
    }

    onPayloadChanged: {
        if (!payload)
            return;
        if (!shown) {
            // First notification of a run: the island is opening around it, so
            // there is nothing to swap away from.
            shown = payload;
            return;
        }
        if (shown === payload)
            return;
        swap.restart();
    }

    SequentialAnimation {
        id: swap

        // Out: lift and fade. Short, because nobody needs to watch a message
        // they have already been shown leave.
        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 110
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: content
                property: "y"
                to: -Style.space(10)
                duration: 110
                easing.type: Easing.InCubic
            }
        }

        // Swap under cover of the fade, and drop the incoming message below
        // the baseline so it has somewhere to rise from.
        ScriptAction {
            script: {
                root.shown = root.payload;
                content.y = Style.space(12);
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: content
                property: "opacity"
                to: 1
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: content
                property: "y"
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: content
        anchors.fill: parent

        Item {
            id: iconWrap

            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize

            readonly property string primary: root.shown ? root.iconSource(root.shown.image) : ""
            readonly property string fallback: root.shown ? root.iconSource(root.shown.appIcon) : ""
            readonly property string glyph: root.shown && root.shown.glyph ? String(root.shown.glyph) : "󰂚"

            Rectangle {
                anchors.fill: parent
                radius: width * 0.28
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                visible: image.status !== Image.Ready
            }

            Image {
                id: image
                anchors.fill: parent
                // The sender's own image wins; its desktop icon is the
                // fallback. Either is better than a generic bell.
                source: iconWrap.primary !== "" ? iconWrap.primary : iconWrap.fallback
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.iconSize * 2
                sourceSize.height: root.iconSize * 2
                smooth: true
                asynchronous: true
                visible: false
            }

            // Rounding the image without a mask layer: the image paints itself
            // into a rounded rect via an opacity mask would cost a render
            // target, so a plain clipped container does the same job here.
            Rectangle {
                anchors.fill: parent
                radius: width * 0.28
                clip: true
                color: "transparent"
                visible: image.status === Image.Ready

                Image {
                    anchors.fill: parent
                    source: image.source
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: root.iconSize * 2
                    sourceSize.height: root.iconSize * 2
                    smooth: true
                    asynchronous: true
                }
            }

            Text {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                text: iconWrap.glyph
                color: root.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.iconLarge
                textFormat: Text.PlainText
            }
        }

        Column {
            id: textColumn

            x: root.pad + root.iconSize + root.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            // Width is measured from the content but capped, so a chatty
            // notification elides instead of stretching the island off-screen.
            //
            // The body is measured through TextMetrics rather than through its
            // own implicitWidth. A word-wrapped Text reports an implicitWidth
            // derived from the width it was given, so sizing the column from it
            // closes a loop: column width -> body width -> body implicitWidth ->
            // column width. With a Behavior driving the island's size off the
            // far end of that chain, the loop does not just thrash, it recurses
            // until the stack gives out.
            width: Math.min(root.maxTextWidth, Math.max(appLabel.implicitWidth, summaryLabel.implicitWidth, bodyMetrics.width))

            Text {
                id: appLabel
                width: parent.width
                text: root.shown ? String(root.shown.app || "") : ""
                visible: text.length > 0
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }

            Text {
                id: summaryLabel
                width: parent.width
                text: root.shown ? root.sanitize(root.shown.summary) : ""
                visible: text.length > 0
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }

            // Unwrapped measurement of the body, used only for sizing.
            TextMetrics {
                id: bodyMetrics
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                text: root.shown ? root.sanitize(root.shown.body) : ""
            }

            Text {
                id: bodyLabel
                width: parent.width
                text: root.shown ? root.sanitize(root.shown.body) : ""
                visible: text.length > 0 && root.maxBodyLines > 0
                color: root.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: root.maxBodyLines
                textFormat: Text.StyledText
            }
        }
    }
}
