/* Auto: A physics Engine is basically divided into these steps:
    
    1. Rigid body and integrater 
    2. Board phrase collision
    3. Narrow phrase collision
    4. Generate contacts from collision detection
    5. Resolve contacts and solve constraints 

    Reference: 
    https://allenchou.net/game-physics-series/
    http://mft-spirit.nl/files/MTamis_ConstraintBasedPhysicsSolver.pdf
*/

physics_current_time: float = 0;
physics_time_accumlator: float = 0;
physics_dt: float = 1.0 / 120.0;

physics_gravity: Vector3 = .{0, -98, 0};
physics_damping_factor: float = 0.95;

physics_velocity_iterations := 30;
physics_position_iterations := 4;

set_damping_factor :: (x: float)
{
    physics_damping_factor = x;
}

set_physics_gravity :: (x: float)
{
    physics_gravity.y = x;
}

Rigid_Body :: struct
{
    shapes: [..] Convex_Shape;
    position: Vector3;
    velocity: Vector3;
    force: Vector3;

    // Auto: We store the inverse mass instead of mass to speed up calculations since most of the times when we are dealing with physics equation we have to divide the mass, if we just store the inverse mass when we create a rigid body we can just use multiplication which is significantly faster than division. 
    inverse_mass: float;

    orientation: Quaternion;
    angular_velocity: Vector3;
    torque: Vector3;
    inverse_inertia: Matrix3;

    restitution: float;
    friction: float;

    freeze_orientation: bool;

    color: Color = GRAY;
}

Warm_Start_Contact :: struct
{
    a_index, b_index: int;
    normal: Vector3;
    impulse: float;
}

Simulated_World :: struct 
{
    bodies: [..] Rigid_Body;
    collision_resolutions: [..] Resolution;
    warm_start: [..] Warm_Start_Contact;
}

make_rigid_body :: (p: Vector3, v: Vector3, s: Vector3, mass: float, body_type: Polygon_Type = .Rect) -> Rigid_Body
{
    body: Rigid_Body;
    body.position = p;
    body.velocity = v;
    body.orientation = Quaternion.{0, 0, 0, 1};
    body.inverse_mass = ifx mass > 0 then 1.0/mass else 0;

    if body_type ==
    {
        case .Rect; array_add(*body.shapes, make_rect(p, s));
    }
    
    if mass > 0
    {
        one_twelve := 1.0 / 12.0;
        x_x := s.x * s.x;
        y_y := s.y * s.y;

        //Auto: I will probably just use this for all types of shapes for simplicity sake, most shapes can be combined with just rects anyways so all we need to do is add up the inertia tensor of each rects in the body
        inertia_tensor: Matrix3;
        inertia_tensor._11 = one_twelve * mass * y_y;
        inertia_tensor._22 = one_twelve * mass * x_x;
        inertia_tensor._33 = one_twelve * mass * (x_x + y_y);

        success, i := inverse(inertia_tensor);
        body.inverse_inertia = ifx success then i else Matrix3_Identity;
    }

    return body;
}

make_compound_rect_body :: (pieces: [..] Rect_Piece, mass: float) -> Rigid_Body
{
    total_area := 0.0;
    for p : pieces total_area += p.scale.x * p.scale.y;

    // combined center of mass (same frame as the piece centers)
    com := Vector3.{};
    for p : pieces com += p.center * (p.scale.x * p.scale.y);
    if total_area > 0 com = com / total_area;

    body: Rigid_Body;
    body.position = .{};
    body.velocity = .{};
    body.orientation = Quaternion.{0, 0, 0, 1};
    body.inverse_mass = ifx mass > 0 then 1.0/mass else 0;

    for p : pieces
    {
        shape := make_rect(.{}, p.scale);
        shape.local_offset = p.center - com;
        array_add(*body.shapes, shape);
    }

    // combined moments of inertia about the COM (parallel axis theorem). All three axes are filled so the inertia matrix stays invertible.
    i_xx := 0.0;
    i_yy := 0.0;
    i_zz := 0.0;

    one_twelve := 1.0 / 12.0;

    for p : pieces
    {
        a := p.scale.x * p.scale.y;
        m := ifx total_area > 0 then mass * a / total_area else 0;
        offset := p.center - com;
        ox_ox := offset.x * offset.x;
        oy_oy := offset.y * offset.y;
        sx_sx := p.scale.x * p.scale.x;
        sy_sy := p.scale.y * p.scale.y;

        i_xx += m * (sy_sy * one_twelve + oy_oy);
        i_yy += m * (sx_sx * one_twelve + ox_ox);
        i_zz += m * ((sx_sx + sy_sy) * one_twelve + ox_ox + oy_oy);
    }

    if mass > 0
    {
        inertia_tensor: Matrix3;
        inertia_tensor._11 = i_xx;
        inertia_tensor._22 = i_yy;
        inertia_tensor._33 = i_zz;
        success, i := inverse(inertia_tensor);
        body.inverse_inertia = ifx success then i else Matrix3_Identity;
    }

    return body;
}

add_body :: (using world: *Simulated_World, p: Vector3, v: Vector3, s: Vector3, mass: float = 10) -> *Rigid_Body
{
    body := make_rigid_body(p, v, s, mass);
    array_add(*bodies, body);

    return *bodies[bodies.count-1];
}

simulate_world :: (using world: *Simulated_World)
{
    array_reset(*collision_resolutions);

    // Auto: Broad-phase collision detection using AABB 
    for i : 0 .. bodies.count-1
    {
        for a_shape : bodies[i].shapes
        {
            a_aabb := get_aabb(a_shape);

            for j : i+1 .. bodies.count-1
            {
                for b_shape : bodies[j].shapes
                {
                    b_aabb := get_aabb(b_shape); 

                    if a_aabb.min.x <= b_aabb.max.x && a_aabb.max.x >= b_aabb.min.x &&
                       a_aabb.min.y <= b_aabb.max.y && a_aabb.max.y >= b_aabb.min.y &&
                       a_aabb.min.z <= b_aabb.max.z && a_aabb.max.z >= b_aabb.min.z
                    {
                        // Auto: If AABB overlaps we can proceed to narrow phrase
                        resolution: Resolution;
                        resolution.cp.allocator = temp;
                        resolution.contacts.allocator = temp;
                        resolution.body_a = *bodies[i];
                        resolution.body_b = *bodies[j];
                        resolution.a_index = i;
                        resolution.b_index = j;

                        if test_SAT(a_shape, b_shape, *resolution)
                        {
                            // Auto: If it detects collision we add the resolution that we need to solve later
                            array_add(*collision_resolutions, resolution);
                        }
                    }
                }
            }
        }
    }

    new_time := GetTime();
    frame_time := new_time - physics_current_time;
    physics_current_time = xx new_time;

    physics_time_accumlator += xx frame_time;

    for *body : bodies
    {
        // NOTE: gravity is applied as an acceleration inside integrate_for_velocity,
        // so every dynamic body falls at the same rate regardless of its mass.
        integrate_for_velocity(body, physics_dt);
    }

    // Auto: re-apply last frame's accumulated contact impulses so the stack starts near its equilibrium. Without this, each frame the solver had to rebuild the entire stack's support from zero, and dropping a new body onto a tall stack overwhelmed it (the stack collapsed and bodies sank into each other).
    for *r : collision_resolutions
    {
        cached: Warm_Start_Contact;
        found := false;
        for ws : warm_start
        {
            if ws.a_index == r.a_index && ws.b_index == r.b_index && dot(ws.normal, r.normal) > 0.9
            {
                cached = ws;
                found = true;
                break;
            }
        }

        if found && r.contacts.count > 0
        {
            per_contact := cached.impulse / cast(float)r.contacts.count;
            for *c : r.contacts
            {
                c.sum_impulse_contact = per_contact;
                apply_normal_impulse(r, c, per_contact);
            }
        }
    }

    for iteration : 0 .. physics_velocity_iterations-1
    {
        for *r : collision_resolutions
        {
            for *c : r.contacts
            {
                resolve_contact(r, c);
            }
        }
    }

    // Auto: Store the accumulated normal impulses so they can warm-start the next frame.
    array_reset(*warm_start);
    for r : collision_resolutions
    {
        total := 0.0;
        for c : r.contacts total += c.sum_impulse_contact;
        if total > 0.01
        {
            array_add(*warm_start, Warm_Start_Contact.{ a_index = r.a_index, b_index = r.b_index, normal = r.normal, impulse = total });
        }
    }

    // Auto: Separate bodies that are still penetrating. This is what makes resting contacts stable, so objects rest and slide cleanly on slopes instead of sinking and being violently pushed back out by the velocity solver. This is also needed for solving the stacking issues.
    for iteration : 0 .. physics_position_iterations-1
    {
        for collision_resolutions
        {
            correct_position(*it);
        }
    }
    
    for bodies
    {
        integrate_for_position(*it, physics_dt);
    }

    while physics_time_accumlator >= physics_dt
    {
        physics_time_accumlator -= physics_dt;
    }
}

apply_force :: (body: *Rigid_Body, f: Vector3, at: Vector3)
{
    body.force += f;
    body.torque += cross(at - body.position, f);
}

integrate_for_velocity :: (body: *Rigid_Body, dt: float)
{
    if body.inverse_mass > 0
    {
        body.velocity += physics_gravity * dt;
        body.velocity += body.force * body.inverse_mass*dt;

        // Auto: damping factor is the fraction of velocity retained per second (1.0 = no damping).
        body.velocity = body.velocity * pow(physics_damping_factor, physics_dt);
    }

    // Auto: If it's not a static body proceed to calculate the angular momentum.
    if !body.freeze_orientation
    {
        body.angular_velocity += body.inverse_inertia * body.torque * dt;
        body.angular_velocity = body.angular_velocity * pow(physics_damping_factor, physics_dt);
    }
}

integrate_for_position :: (body: *Rigid_Body, dt: float)
{
    body.position += body.velocity * dt;
    
    if(!body.freeze_orientation)
    {
        av := body.angular_velocity * dt * 0.5;
        body.orientation = body.orientation + (Quaternion.{av.x, av.y, av.z, 0} * body.orientation);
    }
    
    update_body_shapes(body);
    body.orientation = normalize(body.orientation);
}

update_body_shapes :: (body: *Rigid_Body)
{
    for *s : body.shapes
    {
        update_shape(s, body.position, body.orientation);
    }
}

update_contact :: (using resolution: *Resolution, c: *Contact)
{
    c.sum_impulse_contact = 0;
    c.sum_impulse_friction = .{};
    c.b = 0;

    baumgrate_scalar := 0.1;
    baumgrate_slop := 0.001;
    penetration_slop := min(c.depth + baumgrate_slop, 0);

    c.b += -(baumgrate_scalar / physics_dt) * penetration_slop;

    elasticity := body_a.restitution * body_b.restitution;
    elasticity_term := dot(c.normal, body_a.velocity + 
                        cross(c.rel_pos_a, body_a.angular_velocity) - body_b.velocity - cross(c.rel_pos_b, body_b.angular_velocity));

    c.b += (elasticity * elasticity_term) / contacts.count;
}

correct_position :: (using resolution: *Resolution)
{
    percent: float = 0.25;  
    slop: float = 0.005;

    if depth <= slop return;

    inverse_mass_sum: float = body_a.inverse_mass + body_b.inverse_mass;
    if inverse_mass_sum == 0 return;

    correction: float = max(depth - slop, 0) / inverse_mass_sum * percent;
    correction = min(correction, 2.0);  // Auto: safety clamp so deep penetration can't teleport bodies.

    // Auto: normal points from A to B, so push A out along -normal and B out along +normal
    body_a.position -= normal * (correction * body_a.inverse_mass);
    body_b.position += normal * (correction * body_b.inverse_mass);
}

apply_normal_impulse :: (using resolution: *Resolution, c: *Contact, impulse: float)
{
    r1 := c.rel_pos_a;
    r2 := c.rel_pos_b;

    j1: Vector3 = ifx body_a.inverse_mass == 0 then .{} else -c.normal;
    j2: Vector3 = ifx body_a.inverse_mass == 0 then .{} else cross(r1, c.normal);
    j3: Vector3 = ifx body_b.inverse_mass == 0 then .{} else c.normal;
    j4: Vector3 = ifx body_b.inverse_mass == 0 then .{} else cross(r2, c.normal);

    // Auto: A gets -impulse*n, B gets +impulse*n at the contact.
    body_a.velocity += body_a.inverse_mass * j1 * impulse;
    body_b.velocity += body_b.inverse_mass * j3 * impulse;

    body_a.angular_velocity -= body_a.inverse_inertia * j2 * impulse;
    body_b.angular_velocity += body_b.inverse_inertia * j4 * impulse;
}

resolve_contact :: (using resolution: *Resolution, c: *Contact)
{
    r1 := c.rel_pos_a;
    r2 := c.rel_pos_b;

    j1: Vector3 = ifx body_a.inverse_mass == 0 then .{} else -c.normal;
    j2: Vector3 = ifx body_a.inverse_mass == 0 then .{} else cross(r1, c.normal);
    j3: Vector3 = ifx body_b.inverse_mass == 0 then .{} else c.normal;
    j4: Vector3 = ifx body_b.inverse_mass == 0 then .{} else cross(r2, c.normal);

    k: float = body_a.inverse_mass + dot(j2, body_a.inverse_inertia * j2) +
              body_b.inverse_mass + dot(j4, body_b.inverse_inertia * j4);

    if(k != 0)
    {
        effective_mass: float = 1.0 / k;

        //Auto: Normal component of the relative velocity at the contact (positive = separating)
        vn: float = dot((body_b.velocity + cross(body_b.angular_velocity, r2)) -
                        (body_a.velocity + cross(body_a.angular_velocity, r1)), c.normal);

        restitution: float = body_a.restitution * body_b.restitution;
        bias: float = restitution * min(vn, 0);

        desired: float = effective_mass * (-(vn + bias));
        new_impulse := max(c.sum_impulse_contact + desired, 0);
        delta := new_impulse - c.sum_impulse_contact;
        c.sum_impulse_contact = new_impulse;
        apply_normal_impulse(resolution, c, delta);

        // Auto: Friction calculations
        va := body_a.velocity + cross(body_a.angular_velocity, r1);
        vb := body_b.velocity + cross(body_b.angular_velocity, r2);
        vab := vb - va;
        tangent := vab - c.normal * dot(vab, c.normal);
        tangent_length: float = length(tangent);

        if(tangent_length > 0.000001)
        {
            tangent = tangent / tangent_length;

            d: float = dot(tangent, cross(body_a.inverse_inertia * cross(r1, tangent), r1) +
                           cross(body_b.inverse_inertia * cross(r2, tangent), r2));

            friction_mass: float = body_a.inverse_mass + body_b.inverse_mass + d;

            if(friction_mass > 0)
            {
                friction_coeff: float = sqrt(body_a.friction * body_b.friction);
                jt: float = -dot(vab, tangent) * friction_coeff;
                jt = jt / friction_mass;

                // Coulomb friction: clamp so friction can't exceed the normal impulse
                max_friction: float = new_impulse * friction_coeff;
                jt = max(min(jt, max_friction), -max_friction);

                body_a.velocity -= tangent * (jt * body_a.inverse_mass);
                body_b.velocity += tangent * (jt * body_b.inverse_mass);

                body_a.angular_velocity -= body_a.inverse_inertia * cross(r1, tangent * jt);
                body_b.angular_velocity += body_b.inverse_inertia * cross(r2, tangent * jt);
            }
        }
    }
}