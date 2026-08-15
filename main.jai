#import "raylib";
#import "Math";
#import "Basic";

SCREEN_WIDTH  :: 1024;
SCREEN_HEIGHT :: 768;

velocity := 0.0;
positionY := 0.0;
acceleration :: 981.0;

convex_shape :: struct {
    vertices: [4]Vector2;
};

aabb :: struct {
    min: Vector2;
    max: Vector2;
};

DrawConvexShape :: (shape: convex_shape, posX: s32, posY: s32, color: Color) {
    DrawTriangle(v1=Vector2.{ x=posX + shape.vertices[0].x, y=posY + shape.vertices[0].y },
                 v2=Vector2.{ x=posX + shape.vertices[2].x, y=posY + shape.vertices[2].y },
                 v3=Vector2.{ x=posX + shape.vertices[1].x, y=posY + shape.vertices[1].y },
                 color=color);
    DrawTriangle(v1=Vector2.{ x=posX + shape.vertices[0].x, y=posY + shape.vertices[0].y },
                 v2=Vector2.{ x=posX + shape.vertices[3].x, y=posY + shape.vertices[3].y },
                 v3=Vector2.{ x=posX + shape.vertices[2].x, y=posY + shape.vertices[2].y },
                 color=color);
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

main :: () {
    InitWindow(width=SCREEN_WIDTH, height=SCREEN_HEIGHT, title=get_c_string("metal box falling.mp4"));
    defer CloseWindow();

    rectangle := convex_shape.{
            vertices = .[
                Vector2.{ x=-50, y=-50 },
                Vector2.{ x=50, y=-50 },
                Vector2.{ x=50, y=50 },
                Vector2.{ x=-50, y=50 }
            ]
        };
    
    floor := convex_shape.{
            vertices = .[
                Vector2.{ x=0, y=0 },
                Vector2.{ x=SCREEN_WIDTH, y=0 },
                Vector2.{ x=SCREEN_WIDTH, y=50 },
                Vector2.{ x=0, y=50 }
            ]
        };

    floor_aabb := ComputeAABB(shape=floor, posX=0, posY=SCREEN_HEIGHT - 50);

    while !WindowShouldClose() {
        BeginDrawing();
        ClearBackground(RAYWHITE);

        DrawConvexShape(shape=rectangle, posX=SCREEN_WIDTH/2 - 50, posY=cast(s32)positionY, color=BLACK);
        DrawConvexShape(shape=floor, posX=0, posY=SCREEN_HEIGHT - 50, color=GRAY);

        velocity += acceleration * GetFrameTime();
        positionY += velocity * GetFrameTime();

        box_aabb := ComputeAABB(shape=rectangle, posX=SCREEN_WIDTH/2 - 50, posY=cast(s32)positionY);
        if (AABBOverlap(a=box_aabb, b=floor_aabb)) {
            positionY -= (box_aabb.max.y - floor_aabb.min.y);
            velocity = 0;
        }
        EndDrawing();
    }
}