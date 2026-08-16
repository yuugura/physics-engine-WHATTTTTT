#import "Math";
#import "Basic";
#import "raylib";

convex_shape :: struct {
    vertices: []Vector2;
};

aabb :: struct {
    min: Vector2;
    max: Vector2;
};

DrawConvexShape :: (shape: convex_shape, posX: s32, posY: s32, color: Color) {
    for 0..(shape.vertices.count - 3) {
        DrawTriangle(v1=Vector2.{ x=posX + shape.vertices[0].x, y=posY + shape.vertices[0].y },
                     v2=Vector2.{ x=posX + shape.vertices[it + 2].x, y=posY + shape.vertices[it + 2].y },
                     v3=Vector2.{ x=posX + shape.vertices[it + 1].x, y=posY + shape.vertices[it + 1].y },
                     color=color);
    }
};

ComputeAABB :: (shape: convex_shape, posX: s32, posY: s32) -> aabb {
    minX := posX + shape.vertices[0].x;
    minY := posY + shape.vertices[0].y;
    maxX := posX + shape.vertices[0].x;
    maxY := posY + shape.vertices[0].y;

    for shape.vertices {
        minX = min(minX, posX + it.x);
        minY = min(minY, posY + it.y);
        maxX = max(maxX, posX + it.x);
        maxY = max(maxY, posY + it.y);
    }

    return aabb.{ min=Vector2.{ x=minX, y=minY }, max=Vector2.{ x=maxX, y=maxY } };
};

AABBOverlap :: (a: aabb, b: aabb) -> bool {
    return !(a.max.x < b.min.x || a.min.x > b.max.x || a.max.y < b.min.y || a.min.y > b.max.y);
};
