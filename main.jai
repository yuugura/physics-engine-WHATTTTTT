#import "raylib";

#load "shapes.jai";

SCREEN_WIDTH  :: 1024;
SCREEN_HEIGHT :: 768;

velocity := 0.0;
positionY := 0.0;
acceleration :: 981.0;

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