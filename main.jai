#import "raylib";

SCREEN_WIDTH  :: 1024;
SCREEN_HEIGHT :: 768;

velocity := 0.0;
positionY := 0.0;
acceleration :: 981.0;

main :: () {
    InitWindow(width=SCREEN_WIDTH, height=SCREEN_HEIGHT, title=get_c_string("metal box falling.mp4"));
    defer CloseWindow();

    while !WindowShouldClose() {
        BeginDrawing();
        ClearBackground(RAYWHITE);
        DrawRectangle(posX=SCREEN_WIDTH/2-50, posY=cast(s32)positionY, width=100, height=100, color=BLACK);

        velocity += acceleration * GetFrameTime();
        positionY += velocity * GetFrameTime();

        if positionY > SCREEN_HEIGHT - 100 {
            positionY = SCREEN_HEIGHT - 100;
            velocity = 0.0;
        }
        EndDrawing();
    }
}