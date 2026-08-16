#import "raylib";
#import "Basic";
#import "Random";

#load "physics.jai";

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

    world: Simulated_World;
    rectangle := add_body(*world, .{SCREEN_WIDTH/2, SCREEN_HEIGHT/2, 0}, .{}, .{100, 100, 0}, 50);
    rectangle.color = BLACK;
    
    floor := add_body(*world, .{SCREEN_WIDTH/2, 0, 0}, .{}, .{SCREEN_WIDTH, 50, 0}, 0);
    floor.color = GRAY;
    floor.friction = 0.9;

    wall1 := add_body(*world, .{0, SCREEN_HEIGHT/2, 0}, .{}, .{50, SCREEN_HEIGHT, 0}, 0);
    wall2 := add_body(*world, .{SCREEN_WIDTH, SCREEN_HEIGHT/2, 0}, .{}, .{50, SCREEN_HEIGHT, 0}, 0);

    SetTargetFPS(120);

    while !WindowShouldClose() {
        
        if IsMouseButtonPressed(.MOUSE_BUTTON_LEFT)
        {
            p := GetMousePosition();
            p.x = (SCREEN_WIDTH - p.x);
            p.y = (SCREEN_HEIGHT - p.y);
            //p.x = -p.x;
            print("p: %\n", p);
            s := Vector3.{random_get_within_range(20, 50), random_get_within_range(20, 50), 0};
            body := add_body(*world, .{p.x, p.y, 0}, .{}, s, s.x + s.y);
            r := random_get_zero_to_one_open() * 255;
            g := random_get_zero_to_one_open() * 255;
            b := random_get_zero_to_one_open() * 255;
            body.color = Color.{xx r, xx g, xx b, 255};
            body.friction = 0.8;
        }

        simulate_world(*world);

        BeginDrawing();
        ClearBackground(RAYWHITE);

        // Auto: Because y axis in screen space by default is flipped (positive goes down) we have to flip it back so that positive goes up when drawing objects. This is so we can do the physics calculations like in real world.  
        flip_y := MatrixScale(1.0, -1.0, 1.0);
        rlSetMatrixModelview(flip_y);

        BeginMode2D(camera);

        for world.bodies 
        {
            draw_convex_shape(it.shapes[0], color=it.color);
        }
        //draw_convex_shape(shape=rectangle.shapes[0], color=BLACK);
        //draw_convex_shape(shape=floor.shapes[0], color=GRAY);
        
        EndMode2D();
        EndDrawing();
    }
}