const zss = @import("../zss.zig");
usingnamespace zss.types;
const used = zss.used_properties;

pub fn getThreeBoxes(offset: Offset, box_offsets: BoxOffsets, borders: used.Borders) ThreeBoxes {
    const border_x = offset.x + box_offsets.border_top_left.x;
    const border_y = offset.y + box_offsets.border_top_left.y;
    const border_w = box_offsets.border_bottom_right.x - box_offsets.border_top_left.x;
    const border_h = box_offsets.border_bottom_right.y - box_offsets.border_top_left.y;

    return ThreeBoxes{
        .border = CSSRect{
            .x = border_x,
            .y = border_y,
            .w = border_w,
            .h = border_h,
        },
        .padding = CSSRect{
            .x = border_x + borders.left,
            .y = border_y + borders.top,
            .w = border_w - borders.left - borders.right,
            .h = border_h - borders.top - borders.bottom,
        },
        .content = CSSRect{
            .x = offset.x + box_offsets.content_top_left.x,
            .y = offset.y + box_offsets.content_top_left.y,
            .w = box_offsets.content_bottom_right.x - box_offsets.content_top_left.x,
            .h = box_offsets.content_bottom_right.y - box_offsets.content_top_left.y,
        },
    };
}

pub fn divCeil(comptime T: type, a: T, b: T) T {
    return @divFloor(a, b) + @boolToInt(@mod(a, b) != 0);
}
