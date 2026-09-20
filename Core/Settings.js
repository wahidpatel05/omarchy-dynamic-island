.pragma library

// Writing the island's own config back to disk.
//
// The island reads `bar.island` out of ~/.config/omarchy/shell.json, and the
// shell hands that subtree back on every save — which is what makes the whole
// thing hot-reload. The Studio closes that loop: it writes to the same place
// the user would have typed into, through `shell.mutateShellConfig`, and the
// change arrives back through the ordinary config channel a frame later.
//
// So there is no separate settings store and no second source of truth. What
// the Studio writes is exactly what a hand-edited shell.json would say, which
// means the two can be mixed freely and neither surprises the other.
//
// Paths are dotted, relative to `bar.island`: "shape.collapsedHeight",
// "style.capsuleOpacity", "right". Array and object values are written
// wholesale; there is deliberately no merge, because the arrays *are* the
// answer — "right" is the set of modules in that capsule, not an annotation
// on some default set.

function isPlainObject(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

// Walk to the container that holds the last path segment, creating plain
// objects on the way. Returns null if the path runs through something that is
// not an object — a user who wrote `"shape": 4` should get their config left
// alone rather than silently restructured.
function containerFor(root, segments, create) {
    var node = root;
    for (var i = 0; i < segments.length - 1; i++) {
        var key = segments[i];
        if (!isPlainObject(node[key])) {
            if (!create)
                return null;
            if (node[key] !== undefined && node[key] !== null)
                return null;
            node[key] = {};
        }
        node = node[key];
    }
    return node;
}

function split(path) {
    return String(path || "").split(".").filter(function (part) {
        return part.length > 0;
    });
}

// Set one value in the island's subtree of a whole shell config object.
// Mutates in place; the caller hands us the clone `mutateShellConfig` made.
function set(config, path, value) {
    var segments = split(path);
    if (segments.length === 0)
        return false;

    if (!isPlainObject(config.bar))
        config.bar = {};
    if (!isPlainObject(config.bar.island))
        config.bar.island = {};

    var container = containerFor(config.bar.island, segments, true);
    if (!container)
        return false;
    container[segments[segments.length - 1]] = value;
    return true;
}

// Drop a value so the built-in default takes over again. Empty objects left
// behind are pruned, because a `"shape": {}` that the user never asked for is
// noise in a file they are expected to read.
function reset(config, path) {
    var segments = split(path);
    if (segments.length === 0 || !isPlainObject(config.bar) || !isPlainObject(config.bar.island))
        return false;

    var container = containerFor(config.bar.island, segments, false);
    if (!container)
        return false;
    delete container[segments[segments.length - 1]];

    // Prune upward: walk the path again from the top, deleting any object we
    // just emptied. Cheap, and it keeps hand-editing pleasant.
    for (var depth = segments.length - 1; depth > 0; depth--) {
        var parent = containerFor(config.bar.island, segments.slice(0, depth), false);
        if (!parent)
            break;
        var key = segments[depth - 1];
        if (isPlainObject(parent[key]) && Object.keys(parent[key]).length === 0)
            delete parent[key];
        else
            break;
    }

    if (Object.keys(config.bar.island).length === 0)
        delete config.bar.island;
    return true;
}

// Read what the user has actually written, as opposed to what they are
// getting. The Studio needs both: the resolved value to show, and whether it
// is an override, to say whether "reset" would do anything.
function userValue(barConfig, path) {
    var segments = split(path);
    if (segments.length === 0 || !barConfig || !isPlainObject(barConfig.island))
        return undefined;

    var node = barConfig.island;
    for (var i = 0; i < segments.length; i++) {
        if (!isPlainObject(node) && !Array.isArray(node))
            return undefined;
        node = node[segments[i]];
        if (node === undefined)
            return undefined;
    }
    return node;
}

// The resolved value currently in force, from the config the island built.
function resolvedValue(config, path) {
    var segments = split(path);
    var node = config;
    for (var i = 0; i < segments.length; i++) {
        if (node === undefined || node === null)
            return undefined;
        node = node[segments[i]];
    }
    return node;
}
