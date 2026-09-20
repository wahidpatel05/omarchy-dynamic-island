import QtQuick
import QtQuick.Shapes
import "Geometry.js" as Geometry

// The painted island shape.
//
// Sizing and animation belong to the caller; this item only knows how to draw
// the outline it is handed. Keeping it dumb means the morph logic never has to
// reason about path maths, and the shape can be reused for the drop shadow and
// the input mask without duplicating geometry.
//
// The item is wider than the body by `fillet` on each side, because the
// concave shoulders that blend the island into the screen edge live outside
// the body's own box. `bodyX` reports where the body actually starts so
// callers can lay content out against it rather than against the item.
Item {
    id: root

    property real bodyWidth: 0
    property real bodyHeight: 0
    property real radiusTop: 0
    property real radiusBottom: 0
    // Concave shoulders blending the top edge into the island's sides. Only
    // meaningful when the island is flush against the screen edge — floating
    // above it, there is no edge to blend into, so callers pass 0.
    property real fillet: 0
    // 2 is a circle; larger values ramp curvature in more gradually. ~5 sits
    // close to the shape Apple uses.
    property real exponent: 5
    property int segments: 14

    property color color: "black"
    property color borderColor: "transparent"
    property real borderWidth: 0

    readonly property real bodyX: fillet
    implicitWidth: bodyWidth + 2 * fillet
    implicitHeight: bodyHeight

    readonly property var outline: Geometry.islandOutline({
        width: root.bodyWidth,
        height: root.bodyHeight,
        radiusTop: root.radiusTop,
        radiusBottom: root.radiusBottom,
        fillet: root.fillet,
        exponent: root.exponent,
        segments: root.segments,
        originX: root.fillet
    })

    Shape {
        anchors.fill: parent
        // The curve renderer antialiases in the fragment shader instead of
        // relying on multisampling, which matters here: the outline is
        // re-tessellated on every frame of a morph, and the geometry renderer
        // visibly stairsteps a shape that is changing size.
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor: root.color
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth > 0 ? root.borderWidth : -1
            // The fill implicitly closes the path along the top edge, which is
            // exactly where the island meets the screen bezel — there is
            // nothing there to draw.
            PathPolyline {
                path: Geometry.toPath(root.outline, function (x, y) {
                    return Qt.point(x, y);
                })
            }
        }
    }
}
