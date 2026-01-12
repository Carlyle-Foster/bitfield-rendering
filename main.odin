package bfr

import "core:log"
import ba "core:container/bit_array"
import rl "vendor:raylib"

WIDTH :: 800
HEIGHT :: 600

Color :: rl.Color

dbg :: proc(value: any, expr := #caller_expression(value)) {
    log.debug(expr, "=", value)
}

pos_2_index :: proc(pos, dim: [3]int) -> int {
    return pos.x + pos.y*dim.x + pos.z*dim.x*dim.z
}

State :: struct {
    dim: [3]int,
    bit_array: ba.Bit_Array,
    object_refs: []Object_ID,
    objects: [dynamic]Object,
}
state_create :: proc(dimensions: [3]int, allocator := context.allocator) -> State {
    context.allocator = allocator

    size := dimensions.x * dimensions.y * dimensions.z

    bit_array := ba.Bit_Array{}
    ba.init(&bit_array, size)

    return {
        dim = dimensions,
        bit_array = bit_array,
        object_refs = make([]Object_ID, size),
        objects = make([dynamic]Object),
    }
}
state_lookup :: proc(s: State, pos: [3]int) -> Color {
    s := s

    index := pos_2_index(pos, s.dim)

    if ba.get(&s.bit_array, index) {
        object := s.objects[s.object_refs[index]]
        return object_lookup(object, pos)
    }

    return {}
}

Object :: struct {
    pos: [3]int,
    dim: [3]int,
    bit_array: ba.Bit_Array,
    pixels: []Color,
}
Object_ID :: distinct u32
object_create :: proc(s: ^State, pos: [3]int, dimensions: [3]int) -> Object_ID {
    size := dimensions.x * dimensions.y * dimensions.z
    bit_array := ba.Bit_Array{}
    ba.init(&bit_array, size)

    append(&s.objects, Object{
        pos = pos,
        dim = dimensions,
        bit_array = bit_array,
        pixels = make([]Color, size)
    })

    return Object_ID(len(s.objects) - 1)
}
object_init_cube :: proc(s: ^State, id: Object_ID, color: Color) {
    o := &s.objects[id]

    for x in 0..<o.dim.x {
        for y in 0..<o.dim.y {
            for z in 0..<o.dim.z {
                object_add_pixel(s, id, {x,y,z}, color)
            }
        }
    }
}
object_init_cube_hollow :: proc(s: ^State, id: Object_ID, Color: Color) {
    o := &s.objects[id]
    
    object_init_cube(s, id, Color)

    for x in 1..<o.dim.x-1 {
        for y in 1..<o.dim.y-1 {
            for z in 1..<o.dim.z-1 {
                object_remove_pixel(s, id, {x,y,z})
            }
        }
    }
}
object_add_pixel :: proc(s: ^State, id: Object_ID, pos: [3]int, color: Color) {
    o := &s.objects[id]

    object_index := pos_2_index(pos, o.dim)
    ba.set(&o.bit_array, object_index)
    o.pixels[object_index] = color

    world_pos := pos + o.pos
    world_index := pos_2_index(world_pos, s.dim)
    ba.set(&s.bit_array, world_index)
    s.object_refs[world_index] = id
}
object_remove_pixel :: proc(s: ^State, id: Object_ID, pos: [3]int) {
    o := &s.objects[id]

    object_index := pos_2_index(pos, o.dim)
    ba.set(&o.bit_array, object_index, false)

    world_pos := pos + o.pos
    world_index := pos_2_index(world_pos, s.dim)
    ba.set(&s.bit_array, world_index, false)
}
object_lookup :: proc(o: Object, pos: [3]int) -> Color {
    o   := o
    pos := pos
    
    pos = pos - o.pos
    index := pos_2_index(pos, o.dim)

    if ba.get(&o.bit_array, index) {
        return o.pixels[index]
    }
    
    return {}
}

render_frame :: proc(s: State, canvas: []Color) {
    px_size := 100
    for x in 0..<WIDTH/px_size {
        for y in 0..<HEIGHT/px_size {
            color := state_lookup(s, {7+x, 7+y, 8})
            rl.DrawRectangle(i32(x*px_size), i32(y*px_size), i32(px_size), i32(px_size), color)
        }
    }
}

main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_console_logger(context.logger)

    rl.SetConfigFlags({ .VSYNC_HINT })
    rl.InitWindow(WIDTH, HEIGHT, "bitfield-rendering")

    texture := rl.LoadTextureFromImage(rl.GenImageColor(WIDTH, HEIGHT, rl.GetColor(0x181818ff)))
    canvas := make([]Color, texture.width * texture.height)

    state := state_create(16)
    cube := object_create(&state, 7, 3)
    object_init_cube_hollow(&state, cube, rl.GetColor(0x9AA628ff))

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()

        rl.ClearBackground(rl.VIOLET)
        rl.UpdateTexture(texture, raw_data(canvas))
        rl.DrawTexture(texture, 0, 0, rl.WHITE)

        render_frame(state, canvas)
        
        rl.EndDrawing()
    }
}