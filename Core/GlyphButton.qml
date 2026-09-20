import QtQuick
import qs.Commons

// A single glyph sitting in one of the glass capsules.
//
// The slot is square by default — as wide as the row is tall — which is what
// gives the status corner its even pitch no matter how wide the individual
// glyphs happen to be.
SlotButton {
    id: root

    property string glyph: ""
    property string fontFamily: ""
    property real fontSize: 0

    // An image to draw instead of the glyph. Set it and the glyph becomes the
    // fallback: an icon file that has gone missing leaves a working button
    // rather than an empty slot you cannot click.
    property url iconSource: ""
    property real iconSize: 0

    readonly property bool usingIcon: String(iconSource) !== "" && icon.status === Image.Ready

    implicitWidth: Math.max(root.height, (usingIcon ? icon.width : label.implicitWidth) + Style.space(8))
    implicitHeight: parent ? parent.height : Style.font.icon

    Text {
        id: label
        anchors.centerIn: parent
        visible: !root.usingIcon
        text: root.glyph
        color: root.foreground
        font.family: root.fontFamily !== "" ? root.fontFamily : Style.font.family
        font.pixelSize: root.fontSize > 0 ? root.fontSize : Style.font.icon
        textFormat: Text.PlainText
    }

    Image {
        id: icon
        anchors.centerIn: parent
        visible: root.usingIcon

        source: root.iconSource
        // Rasterised at the size it is drawn at, so an SVG comes out crisp
        // rather than scaled from whatever the file happened to declare.
        readonly property int box: Math.round(root.iconSize > 0 ? root.iconSize : (root.fontSize > 0 ? root.fontSize : Style.font.icon) * 1.15)
        width: box
        height: box
        sourceSize.width: box * 2
        sourceSize.height: box * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }
}
