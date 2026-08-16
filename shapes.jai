#import "Math";
#import "Basic";
#import "raylib";

Polygon_Type :: enum u32
{
    Rect;
    Triangle;
}

// Auto: Will use 3D coords here to make the physics implementation easier  
Convex_Shape :: struct {
    local_vertices: [..] Vector3; // vertices in local space
    global_vertices: [..] Vector3; // vertices in world space
    vertices_count: s32;

    center: Vector3;
    local_offset: Vector3;
    scale: Vector3;

    radius: float;

    model: Matrix4; // model matrix (rotation, transition, scale)

    type: Polygon_Type;
};

make_rect :: (position: Vector3 = .{}, scale: Vector3 = .{}) -> Convex_Shape
{
    rect: Convex_Shape;
    rect.type = .Rect;
    rect.center = position;
    rect.scale = scale;
    update_shape_model(*rect);
    rect.vertices_count = 4;

    array_add(*rect.local_vertices, Vector3.{-0.5, 0.5, 0});
    array_add(*rect.local_vertices, Vector3.{-0.5, -0.5, 0});
    array_add(*rect.local_vertices, Vector3.{0.5, -0.5, 0});
    array_add(*rect.local_vertices, Vector3.{0.5, 0.5, 0});
    for 0 .. rect.vertices_count-1 
    {
        array_add(*rect.global_vertices, .{});
    }
    update_shape_vertices(*rect);

    return rect;
}

update_shape_model :: (using shape: *Convex_Shape)
{
    model = make_model_matrix(center, scale);
}

get_furthest_vertex :: (using shape: Convex_Shape) -> Vector3
{
    max: float = -FLOAT32_MAX;
    index := 0;

    for global_vertices
    {
        d := length(it - center);
        if d > max 
        {
            max = d;
            index = it_index;
        }
    }

    return global_vertices[index];
}

get_furthest_point_index_in_direction :: (using shape: Convex_Shape, dir: Vector3) -> int
{
    max: float = -FLOAT32_MAX;
    index: int = 0;

    for global_vertices
    {
        projection := dot(it, dir);
        if projection > max
        {
            max = projection;
            index = it_index;
        }
    }

    return index;
}

get_shape_radius :: (using shape: Convex_Shape) -> float
{
    return length(get_furthest_vertex(shape) - center);
}

update_shape_vertices :: (using shape: *Convex_Shape)
{
    for local_vertices
    {
        updated_vertex := Vector4.{it.x, it.y, it.z, 1};
        updated_vertex = model * updated_vertex; 
        global_vertices[it_index] = updated_vertex.xyz;
    }

    radius = get_shape_radius(shape);
}

update_shape_model :: (using shape: *Convex_Shape, new_position: Vector3, new_scale: Vector3, axis: Vector3 = .{}, angle: float = 0)
{
    center = new_position;
    scale = new_scale;
    model = make_model_matrix(new_position, new_scale, axis, angle);
}

update_shape_model :: (using shape: *Convex_Shape, new_position: Vector3, new_scale: Vector3, q: Quaternion)
{
    center = new_position;
    scale = new_scale;
    model = make_model_matrix(new_position, new_scale, q);
}

update_shape :: (using shape: *Convex_Shape, body_position: Vector3, q: Quaternion)
{
    world_center := body_position + rotate(q, local_offset);
    update_shape_model(shape, world_center, scale, q);
    update_shape_vertices(shape);
}

draw_convex_shape :: (shape: Convex_Shape, offset: Vector3 = .{}, color: Color = WHITE) {
    for 0..(shape.global_vertices.count - 3) {
        DrawTriangle(v1=Vector2.{ offset.x + shape.global_vertices[0].x,      (offset.y + shape.global_vertices[0].y) },
                     v2=Vector2.{ offset.x + shape.global_vertices[it + 2].x, (offset.y + shape.global_vertices[it + 2].y) },
                     v3=Vector2.{ offset.x + shape.global_vertices[it + 1].x, (offset.y + shape.global_vertices[it + 1].y) },
                     color);
    }
};

AABB :: struct {
    min: Vector3;
    max: Vector3;
};

get_aabb :: (shape: Convex_Shape) -> AABB
{
    aabb: AABB;

    aabb.min = shape.global_vertices[0];
    aabb.max = shape.global_vertices[0];
    
    for vertex: shape.global_vertices
    {
        aabb.min.x = min(aabb.min.x, vertex.x);
        aabb.min.y = min(aabb.min.y, vertex.y);
        aabb.min.z = min(aabb.min.z, vertex.z);
        
        aabb.max.x = max(aabb.max.x, vertex.x);
        aabb.max.y = max(aabb.max.y, vertex.y);
        aabb.max.z = max(aabb.max.z, vertex.z);
    }
    
    return aabb;
}

aabb_overlap :: (a: AABB, b: AABB) -> bool {
    return a.min.x <= b.max.x && a.max.x >= b.min.x &&
           a.min.y <= b.max.y && a.max.y >= b.min.y &&
           a.min.z <= b.max.z && a.max.z >= b.min.z;
};
