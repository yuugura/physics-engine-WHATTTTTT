#import "raylib";
#import "Basic";

#load "shapes.jai";
#load "math_helper.jai";

SCREEN_WIDTH  :: 1024;
SCREEN_HEIGHT :: 768;

velocity := 0.0;
acceleration :: 981.0;

main :: () {
    InitWindow(width=SCREEN_WIDTH, height=SCREEN_HEIGHT, title=get_c_string("metal box falling.mp4"));
    defer CloseWindow();

    camera: Camera2D;
    camera.target = .{ 0, 0 };
    camera.offset = .{ SCREEN_WIDTH, SCREEN_HEIGHT};
    camera.rotation = 0.0;
    camera.zoom = -1.0;

    rectangle := make_rect(.{SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 0}, .{100, 100, 0});
    
    floor := make_rect(.{SCREEN_WIDTH/2, 0, 0}, .{SCREEN_WIDTH, 100, 0});

    floor_aabb := get_aabb(floor);

    SetTargetFPS(120);

    while !WindowShouldClose() {

        delta_position := rectangle.center;

        velocity += acceleration * GetFrameTime();
        delta_position.y -= velocity * GetFrameTime();

        box_aabb := get_aabb(rectangle);
        if (aabb_overlap(a=box_aabb, b=floor_aabb)) {
            delta_position.y += velocity * GetFrameTime();
        }
        
        update_shape_model(*rectangle, delta_position, rectangle.scale);
        update_shape_vertices(*rectangle);

        BeginDrawing();
        ClearBackground(RAYWHITE);

        // Auto: Because y axis in screen space by default is flipped (positive goes down) we have to flip it back so that positive goes up when drawing objects. This is so we can do the physics calculations like in real world.  
        flip_y := MatrixScale(1.0, -1.0, 1.0);
        rlSetMatrixModelview(flip_y);

        BeginMode2D(camera);

        draw_convex_shape(shape=rectangle, color=BLACK);
        draw_convex_shape(shape=floor, color=GRAY);
        
        EndMode2D();
        EndDrawing();
    }
}